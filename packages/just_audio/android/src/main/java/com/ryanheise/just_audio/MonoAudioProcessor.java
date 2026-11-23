package com.ryanheise.just_audio;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor.AudioFormat;
import androidx.media3.common.audio.BaseAudioProcessor;

import java.nio.ByteBuffer;

/**
 * Downmixes stereo PCM16 to mono while enabled.
 *
 * <p>Installed into the ExoPlayer audio sink chain by {@link MonoRenderersFactory}
 * so the Settings "Mono Audio" toggle works on Android. The processor is a
 * passthrough when it is disabled, when the stream is already mono, or when the
 * stream uses an encoding other than signed 16-bit PCM.
 */
final class MonoAudioProcessor extends BaseAudioProcessor {
    private volatile boolean enabled;

    void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    boolean isEnabled() {
        return enabled;
    }

    @Override
    protected AudioFormat onConfigure(AudioFormat inputAudioFormat) {
        if (!enabled) {
            return AudioFormat.NOT_SET;
        }
        if (inputAudioFormat.channelCount != 2) {
            return AudioFormat.NOT_SET;
        }
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            return AudioFormat.NOT_SET;
        }
        return new AudioFormat(inputAudioFormat.sampleRate, 1, C.ENCODING_PCM_16BIT);
    }

    @Override
    public void queueInput(ByteBuffer inputBuffer) {
        int remaining = inputBuffer.remaining();
        int frameCount = remaining / inputAudioFormat.bytesPerFrame;
        if (frameCount == 0) {
            return;
        }
        ByteBuffer outputBuffer = replaceOutputBuffer(frameCount * 2);
        for (int i = 0; i < frameCount; i++) {
            int left = inputBuffer.getShort();
            int right = inputBuffer.getShort();
            // Same equal-power-free average used by the Windows FFmpeg
            // downmix: (L + R) / 2 for each sample.
            int mono = (left + right) / 2;
            outputBuffer.putShort((short) mono);
        }
        outputBuffer.flip();
        inputBuffer.position(inputBuffer.limit());
    }
}
