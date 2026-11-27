#include "audio_session_keepalive.h"

#include <audioclient.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <atomic>

namespace {

using Microsoft::WRL::ComPtr;

// 100ms in 100-nanosecond units.
constexpr REFERENCE_TIME kBufferDurationHns = 1000000;
constexpr DWORD kIdleRetryDelayMs = 2000;

// Notifies the keepalive loop when the user switches the default playback
// device (e.g. speakers -> FxSound / headphones) so the mixer entry follows.
class DefaultDeviceChangeNotifier final : public IMMNotificationClient {
 public:
  explicit DefaultDeviceChangeNotifier(HANDLE event_handle)
      : event_handle_(event_handle) {}

  ULONG STDMETHODCALLTYPE AddRef() override {
    return static_cast<ULONG>(ref_count_.fetch_add(1) + 1);
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const LONG next = ref_count_.fetch_sub(1) - 1;
    if (next == 0) {
      delete this;
    }
    return static_cast<ULONG>(next);
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                           void** ppv_object) override {
    if (!ppv_object) return E_POINTER;
    if (riid == __uuidof(IUnknown) || riid == __uuidof(IMMNotificationClient)) {
      *ppv_object = static_cast<IMMNotificationClient*>(this);
      AddRef();
      return S_OK;
    }
    *ppv_object = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { return S_OK; }

  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow,
                                                   ERole role,
                                                   LPCWSTR) override {
    if (flow == eRender && role == eConsole && event_handle_) {
      ::SetEvent(event_handle_);
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,
                                                   const PROPERTYKEY) override {
    return S_OK;
  }

 private:
  ~DefaultDeviceChangeNotifier() = default;

  std::atomic<LONG> ref_count_{1};
  HANDLE event_handle_;
};

}  // namespace

AudioSessionKeepalive::~AudioSessionKeepalive() {
  Stop();
}

void AudioSessionKeepalive::Start() {
  if (stop_event_ != nullptr) {
    return;
  }
  stop_event_ = ::CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (stop_event_ == nullptr) {
    return;
  }
  worker_thread_ = std::thread(&AudioSessionKeepalive::RunLoop, this);
}

void AudioSessionKeepalive::Stop() {
  if (stop_event_ != nullptr) {
    ::SetEvent(stop_event_);
  }
  if (worker_thread_.joinable()) {
    worker_thread_.join();
  }
  if (stop_event_ != nullptr) {
    ::CloseHandle(stop_event_);
    stop_event_ = nullptr;
  }
}

void AudioSessionKeepalive::RunLoop() {
  const HRESULT co_hr = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);

  HANDLE device_changed_event = ::CreateEvent(nullptr, FALSE, FALSE, nullptr);

  ComPtr<IMMDeviceEnumerator> enumerator;
  ComPtr<IMMNotificationClient> notifier;
  if (SUCCEEDED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                   CLSCTX_ALL, IID_PPV_ARGS(&enumerator))) &&
      device_changed_event != nullptr) {
    notifier.Attach(new DefaultDeviceChangeNotifier(device_changed_event));
    enumerator->RegisterEndpointNotificationCallback(notifier.Get());
  }

  while (::WaitForSingleObject(stop_event_, 0) != WAIT_OBJECT_0) {
    RunSessionOnce(device_changed_event);

    // Wait briefly before retrying if the endpoint was missing or invalidated,
    // waking immediately if the app is shutting down or default device changed.
    HANDLE wait_handles[2] = {stop_event_, device_changed_event};
    const DWORD handle_count = device_changed_event ? 2 : 1;
    const DWORD wait_result =
        ::WaitForMultipleObjects(handle_count, wait_handles, FALSE, kIdleRetryDelayMs);
    if (wait_result == WAIT_OBJECT_0) {
      break;
    }
  }

  if (enumerator && notifier) {
    enumerator->UnregisterEndpointNotificationCallback(notifier.Get());
  }
  if (device_changed_event != nullptr) {
    ::CloseHandle(device_changed_event);
  }
  if (SUCCEEDED(co_hr)) {
    ::CoUninitialize();
  }
}

void AudioSessionKeepalive::RunSessionOnce(HANDLE device_changed_event) {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, IID_PPV_ARGS(&enumerator)))) {
    return;
  }

  ComPtr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device)) ||
      !device) {
    return;
  }

  ComPtr<IAudioClient> audio_client;
  if (FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                              reinterpret_cast<void**>(
                                  audio_client.GetAddressOf()))) ||
      !audio_client) {
    return;
  }

  WAVEFORMATEX* mix_format = nullptr;
  if (FAILED(audio_client->GetMixFormat(&mix_format)) || !mix_format) {
    return;
  }

  HANDLE buffer_event = ::CreateEvent(nullptr, FALSE, FALSE, nullptr);
  bool event_mode = buffer_event != nullptr;

  // Omit AUDCLNT_STREAMFLAGS_NOPERSIST so Windows remembers the user's mixer
  // volume for Pulse Studio across restarts.
  HRESULT init_hr = audio_client->Initialize(
      AUDCLNT_SHAREMODE_SHARED,
      event_mode ? AUDCLNT_STREAMFLAGS_EVENTCALLBACK : 0, kBufferDurationHns, 0,
      mix_format, nullptr);
  if (FAILED(init_hr) && event_mode) {
    event_mode = false;
    init_hr = audio_client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0,
                                       kBufferDurationHns, 0, mix_format,
                                       nullptr);
  }
  ::CoTaskMemFree(mix_format);
  mix_format = nullptr;

  if (FAILED(init_hr)) {
    if (buffer_event) ::CloseHandle(buffer_event);
    return;
  }

  if (event_mode && FAILED(audio_client->SetEventHandle(buffer_event))) {
    event_mode = false;
  }

  UINT32 buffer_frame_count = 0;
  if (FAILED(audio_client->GetBufferSize(&buffer_frame_count)) ||
      buffer_frame_count == 0) {
    if (buffer_event) ::CloseHandle(buffer_event);
    return;
  }

  ComPtr<IAudioRenderClient> render_client;
  if (FAILED(audio_client->GetService(
          __uuidof(IAudioRenderClient),
          reinterpret_cast<void**>(render_client.GetAddressOf()))) ||
      !render_client) {
    if (buffer_event) ::CloseHandle(buffer_event);
    return;
  }

  BYTE* data = nullptr;
  if (SUCCEEDED(render_client->GetBuffer(buffer_frame_count, &data))) {
    render_client->ReleaseBuffer(buffer_frame_count,
                                 AUDCLNT_BUFFERFLAGS_SILENT);
  }

  if (FAILED(audio_client->Start())) {
    if (buffer_event) ::CloseHandle(buffer_event);
    return;
  }

  while (true) {
    HANDLE wait_handles[3] = {stop_event_, nullptr, nullptr};
    DWORD handle_count = 1;
    if (device_changed_event) {
      wait_handles[handle_count++] = device_changed_event;
    }
    if (event_mode && buffer_event) {
      wait_handles[handle_count++] = buffer_event;
    }

    const DWORD timeout_ms = event_mode ? 2000 : 50;
    const DWORD wait_result =
        ::WaitForMultipleObjects(handle_count, wait_handles, FALSE, timeout_ms);
    if (wait_result == WAIT_OBJECT_0) {
      break;
    }
    if (device_changed_event && wait_result == WAIT_OBJECT_0 + 1) {
      // Default output device changed; re-open on the new endpoint.
      break;
    }

    UINT32 padding = 0;
    const HRESULT pad_hr = audio_client->GetCurrentPadding(&padding);
    if (FAILED(pad_hr)) {
      break;
    }

    if (buffer_frame_count > padding) {
      const UINT32 frames_available = buffer_frame_count - padding;
      if (FAILED(render_client->GetBuffer(frames_available, &data))) {
        break;
      }
      if (FAILED(render_client->ReleaseBuffer(frames_available,
                                              AUDCLNT_BUFFERFLAGS_SILENT))) {
        break;
      }
    }
  }

  audio_client->Stop();
  if (buffer_event) {
    ::CloseHandle(buffer_event);
  }
}
