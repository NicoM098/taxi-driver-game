"""Generates every sound effect in res://assets/audio/ (Iteration 11, D-066).

Why generated and not sampled: there is no clean CC0 car-engine loop to be had (Kenney has no
vehicle audio pack at all; the Freesound CC0 candidates are a truck idle, a sci-fi hover vehicle
and a 1:48 contact-mic recording with no marked loop point). Generating them means the loops are
seamless by construction, the licence is not a question, and the whole bank is reproducible: this
script is the source, the WAVs are the build.

Run from the project root with a plain Python 3 that has numpy:

    python -I tools/gen_sfx.py

Then re-import in Godot. Loop points live in the .import files (see D-066) - if you regenerate,
check that the loop flags survived.

Everything is 22050 Hz mono 16-bit: PS1-era fidelity, and small.
"""
import math
import os
import sys
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(20261114)   # fixed seed: regenerating gives the same bank


def write(name, data, peak=0.7):
    """Normalise to `peak` and write 16-bit mono."""
    data = np.asarray(data, dtype=np.float64)
    m = float(np.max(np.abs(data))) or 1.0
    data = data / m * peak
    pcm = np.clip(data * 32767.0, -32768, 32767).astype("<i2")
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    rms = float(np.sqrt(np.mean(data ** 2)))
    seam = float(abs(data[0] - data[-1]))
    print("  %-22s %6.3f s  peak %.2f  rms %.3f  seam %.4f" % (name, len(data) / SR, peak, rms, seam))


def periodic_noise(n, lo, hi, tilt=0.0):
    """Noise that loops perfectly: random phases on a shaped spectrum, so it IS periodic in n."""
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mag = np.zeros_like(freqs)
    band = (freqs >= lo) & (freqs <= hi)
    mag[band] = 1.0
    if tilt:
        mag[1:] *= (freqs[1:] / max(lo, 1.0)) ** tilt
    phase = RNG.uniform(0.0, 2.0 * math.pi, size=freqs.shape)
    return np.fft.irfft(mag * np.exp(1j * phase), n)


def env(n, attack, decay, power=1.0):
    """Percussive envelope: `attack` and `decay` in seconds."""
    a = max(int(attack * SR), 1)
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    d = np.linspace(0.0, 1.0, max(n - a, 1))
    e[a:] = (1.0 - d) ** (3.0 * power)
    return e


def engine(cycles, f0_target, harmonics, noise_mix, rough):
    """One seamless cycle set of a four-stroke-ish engine.

    Harmonics of the firing rate plus combustion noise pulsing at that same rate. The buffer holds
    exactly `cycles` periods, so it loops with no click, and it is played back with pitch_scale by
    speed/throttle - which is how arcade games have always done engines.
    """
    n = int(round(SR * cycles / f0_target))
    f0 = cycles * SR / float(n)          # the exact rate that fits this buffer
    t = np.arange(n) / float(SR)
    sig = np.zeros(n)
    for k in range(1, harmonics + 1):
        amp = 1.0 / (k ** 1.35)
        if k % 2 == 0:
            amp *= 0.6                    # even harmonics quieter: lumpier, less organ-like
        sig += amp * np.sin(2 * math.pi * f0 * k * t + RNG.uniform(0, 2 * math.pi))
    puff = periodic_noise(n, 180.0, 5200.0, tilt=-0.4)
    gate = (0.5 + 0.5 * np.sin(2 * math.pi * f0 * t)) ** 3.0
    sig += noise_mix * puff / (np.max(np.abs(puff)) or 1.0) * gate
    # one slow wobble across the whole buffer so it is not a perfectly static synth pad
    sig *= 1.0 + rough * np.sin(2 * math.pi * t / (n / float(SR)))
    return sig


def tone(freq_seq, dur, peak, name, noise=0.0):
    n = int(dur * SR)
    t = np.arange(n) / float(SR)
    sig = np.zeros(n)
    seg = max(n // len(freq_seq), 1)
    for i, f in enumerate(freq_seq):
        s = i * seg
        e = n if i == len(freq_seq) - 1 else min((i + 1) * seg, n)
        if e <= s:
            continue
        tt = t[s:e] - t[s]
        sig[s:e] = np.sin(2 * math.pi * f * tt) * env(e - s, 0.002, (e - s) / float(SR), 1.2)
    if noise:
        sig += noise * RNG.normal(0, 1, n) * env(n, 0.001, dur, 2.0)
    write(name, sig, peak)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Writing to", os.path.normpath(OUT))

    print("engine loops (pitched at runtime):")
    write("engine_idle.wav", engine(12, 38.0, 12, 0.55, 0.22), 0.45)
    write("engine_mid.wav", engine(16, 64.0, 14, 0.42, 0.12), 0.5)
    write("engine_high.wav", engine(20, 96.0, 15, 0.34, 0.07), 0.55)

    print("tyres:")
    # A tyre squeal is not hiss: it is a few sharp resonances in the 600-1800 Hz range, each
    # wobbling at its own rate (the chaotic stick-slip of rubber on tarmac), over a quieter band
    # of broadband scrub and a little low rumble from the contact patch. One second long, and
    # every modulation completes a whole number of cycles in it, so it still loops dead.
    n = SR
    t = np.arange(n) / float(SR)
    screech = np.zeros(n)
    for centre, width, rate, depth, gain in [
        (690.0, 55.0, 7.0, 0.55, 1.00),
        (1180.0, 80.0, 11.0, 0.45, 0.72),
        (1760.0, 120.0, 17.0, 0.40, 0.42),
        (2550.0, 180.0, 23.0, 0.35, 0.20),
    ]:
        band = periodic_noise(n, centre - width, centre + width)
        band /= np.max(np.abs(band)) or 1.0
        screech += gain * band * (1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * math.pi * rate * t)))
    scrub = periodic_noise(n, 1200.0, 6000.0, tilt=-0.3)
    scrub /= np.max(np.abs(scrub)) or 1.0
    screech += 0.30 * scrub * (0.75 + 0.25 * np.sin(2 * math.pi * 29.0 * t))
    rumble = periodic_noise(n, 70.0, 260.0)
    screech += 0.22 * rumble / (np.max(np.abs(rumble)) or 1.0)
    write("tyre_screech.wav", screech, 0.55)

    print("impacts:")
    for name, dur, thump, peak in [
        ("impact_soft.wav", 0.22, 70.0, 0.55),
        ("impact_hard.wav", 0.45, 48.0, 0.8),
        ("wreck.wav", 0.9, 38.0, 0.85),
    ]:
        n = int(dur * SR)
        t = np.arange(n) / float(SR)
        body = RNG.normal(0.0, 1.0, n) * env(n, 0.001, dur, 1.4)
        body = np.convolve(body, np.ones(5) / 5.0, mode="same")      # dull it a little
        low = np.sin(2 * math.pi * thump * t * np.exp(-3.0 * t)) * env(n, 0.002, dur, 0.8)
        write(name, body * 0.7 + low, peak)

    print("guns:")
    # revolver: loud, low, short. smg: tighter and brighter. sawed-off: the biggest body.
    for name, dur, crack, body_f, peak in [
        ("shot_revolver.wav", 0.34, 1.0, 110.0, 0.9),
        ("shot_smg.wav", 0.16, 1.3, 190.0, 0.7),
        ("shot_shotgun.wav", 0.52, 0.8, 72.0, 0.95),
    ]:
        n = int(dur * SR)
        t = np.arange(n) / float(SR)
        crack_n = RNG.normal(0.0, 1.0, n) * env(n, 0.0005, dur, 2.2 / crack)
        thump = np.sin(2 * math.pi * body_f * t * np.exp(-5.0 * t)) * env(n, 0.001, dur, 1.1)
        tail = periodic_noise(n, 200.0, 3000.0) * env(n, 0.02, dur, 0.5) * 0.25
        write(name, crack_n * crack + thump * 0.9 + tail, peak)

    n = int(0.5 * SR)
    clicks = np.zeros(n)
    for at in (0.0, 0.12, 0.33):                                     # magazine out / in / slide
        i = int(at * SR)
        ln = min(int(0.05 * SR), n - i)
        clicks[i:i + ln] += RNG.normal(0, 1, ln) * env(ln, 0.0005, 0.05, 2.5)
    write("reload.wav", clicks, 0.5)

    n = int(0.09 * SR)
    write("empty_click.wav", RNG.normal(0, 1, n) * env(n, 0.0005, 0.09, 3.0), 0.4)

    print("feedback:")
    tone([1480.0], 0.07, 0.35, "hit_confirm.wav")
    tone([880.0, 1320.0, 1760.0], 0.42, 0.6, "cash.wav", noise=0.08)   # register: ding upwards
    tone([660.0, 990.0], 0.22, 0.5, "pickup.wav")
    tone([520.0], 0.05, 0.3, "ui_click.wav", noise=0.15)
    tone([300.0, 460.0], 0.18, 0.4, "ui_open.wav", noise=0.2)          # paper-ish
    tone([460.0, 300.0], 0.18, 0.4, "ui_close.wav", noise=0.2)
    tone([220.0, 140.0], 0.5, 0.6, "player_hit.wav", noise=0.3)

    n = int(1.3 * SR)
    t = np.arange(n) / float(SR)
    boom = RNG.normal(0, 1, n) * env(n, 0.002, 1.3, 0.7)
    boom = np.convolve(boom, np.ones(9) / 9.0, mode="same")
    rumble = np.sin(2 * math.pi * 44.0 * t * np.exp(-1.2 * t)) * env(n, 0.004, 1.3, 0.5)
    write("explosion.wav", boom * 0.8 + rumble, 0.95)

    n = int(0.6 * SR)
    t = np.arange(n) / float(SR)
    down = np.sin(2 * math.pi * (900.0 * np.exp(-2.5 * t)) * t) * env(n, 0.003, 0.6, 1.0)
    write("enemy_destroyed.wav", down, 0.6)

    print("done:", len([f for f in os.listdir(OUT) if f.endswith(".wav")]), "wav files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
