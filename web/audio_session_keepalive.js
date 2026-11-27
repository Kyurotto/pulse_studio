// Keeps a silent Web Audio API session active so desktop browsers (Chrome,
// Brave, Edge) register an audio stream in the Windows Volume Mixer as soon as
// the app opens (or on the very first user gesture if autoplay is suspended).
(function () {
  'use strict';

  if (window.__pulseAudioKeepaliveInitialized) {
    return;
  }
  window.__pulseAudioKeepaliveInitialized = true;

  var AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) {
    return;
  }

  var ctx = null;
  var sourceStarted = false;

  function ensureGraph() {
    if (!ctx) {
      try {
        ctx = new AudioCtx({ latencyHint: 'playback' });
      } catch (_) {
        ctx = new AudioCtx();
      }
    }
    if (!sourceStarted && ctx) {
      var gain = ctx.createGain();
      gain.gain.value = 0;
      gain.connect(ctx.destination);

      if (typeof ctx.createConstantSource === 'function') {
        var constant = ctx.createConstantSource();
        constant.offset.value = 0;
        constant.connect(gain);
        constant.start(0);
      } else {
        var buffer = ctx.createBuffer(1, 128, ctx.sampleRate || 44100);
        var bufSource = ctx.createBufferSource();
        bufSource.buffer = buffer;
        bufSource.loop = true;
        bufSource.connect(gain);
        bufSource.start(0);
      }
      sourceStarted = true;
    }
  }

  function tryResume() {
    try {
      ensureGraph();
      if (ctx && ctx.state === 'suspended') {
        var p = ctx.resume();
        if (p && typeof p.catch === 'function') {
          p.catch(function () {});
        }
      }
    } catch (_) {
      // Ignore autoplay restrictions until the next user interaction.
    }
  }

  function onUserGesture() {
    tryResume();
  }

  var gestureEvents = ['pointerdown', 'mousedown', 'keydown', 'touchstart'];
  for (var i = 0; i < gestureEvents.length; i++) {
    window.addEventListener(gestureEvents[i], onUserGesture, {
      capture: true,
      passive: true,
    });
  }

  // Attempt immediate startup right on page load.
  tryResume();
})();
