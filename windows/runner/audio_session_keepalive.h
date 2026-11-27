#ifndef RUNNER_AUDIO_SESSION_KEEPALIVE_H_
#define RUNNER_AUDIO_SESSION_KEEPALIVE_H_

#include <windows.h>

#include <thread>

// Keeps a silent shared-mode WASAPI audio session open for the lifetime of the
// application so Pulse Studio appears in the Windows Volume Mixer immediately on
// launch (even before any track plays or while playback is paused/idle).
class AudioSessionKeepalive {
 public:
  AudioSessionKeepalive() = default;
  ~AudioSessionKeepalive();

  AudioSessionKeepalive(const AudioSessionKeepalive&) = delete;
  AudioSessionKeepalive& operator=(const AudioSessionKeepalive&) = delete;

  // Starts the background WASAPI silent session thread. Safe to call once.
  void Start();

  // Signals the background thread to stop and waits for it to exit.
  void Stop();

 private:
  void RunLoop();
  void RunSessionOnce(HANDLE device_changed_event);

  HANDLE stop_event_ = nullptr;
  std::thread worker_thread_;
};

#endif  // RUNNER_AUDIO_SESSION_KEEPALIVE_H_
