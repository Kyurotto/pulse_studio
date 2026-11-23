package com.ryanheise.just_audio;

import android.content.Context;

import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.audio.AudioSink;
import androidx.media3.exoplayer.audio.DefaultAudioSink;

/**
 * Renderers factory that installs {@link MonoAudioProcessor} into the audio
 * sink's processor chain. The rest of the sink configuration mirrors the
 * media3 default so gapless playback, speed changes and audio offload keep
 * working as before.
 */
final class MonoRenderersFactory extends DefaultRenderersFactory {
    private final MonoAudioProcessor monoAudioProcessor;

    MonoRenderersFactory(Context context, MonoAudioProcessor monoAudioProcessor) {
        super(context);
        this.monoAudioProcessor = monoAudioProcessor;
    }

    @Override
    protected AudioSink buildAudioSink(
            Context context,
            boolean enableFloatOutput,
            boolean enableAudioTrackPlaybackParams
    ) {
        return new DefaultAudioSink.Builder(context)
                .setAudioProcessorChain(
                        new DefaultAudioSink.DefaultAudioProcessorChain(monoAudioProcessor)
                )
                // MonoAudioProcessor only handles 16-bit PCM. Float output would
                // bypass it entirely, so the sink stays on the PCM16 path.
                .setEnableFloatOutput(false)
                .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                .build();
    }
}
