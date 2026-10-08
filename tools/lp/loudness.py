"""How loud sound files are to the ear, to set them level with one another.

python tools/lp/loudness.py <file.wav|ogg ...>             -> measures
python tools/lp/loudness.py --set <LUFS> <file.wav ...>    -> rewrites each WAV (16 bits) at that loudness

Loudness is measured the way broadcasting does (ITU-R BS.1770: the "K" weighting, which
counts the frequencies the ear hears best), in LUFS, over the loudest 0.4 s of the sound: a
very short sound counts for less than a long one of the same strength, as it does for the
ear. Peak values alone say little: a sparse tinkling and a dense chord with the same peak are
far from equally loud. A file set to a loudness is never pushed past a peak of 0.89: if it
would be, it is left that much quieter and the tool says so.
"""
import sys
import numpy as np
import soundfile as sf
from scipy.signal import lfilter, resample_poly

WINDOW = 0.4
PEAK_MAX = 0.89

def k_weighted(x, sr):
    if sr != 48000:                                  # the weighting is given for 48 kHz
        x = resample_poly(x, 48000, sr, axis=0)
    y = lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585], x, axis=0)
    return lfilter([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621], y, axis=0)

def measure(x, sr):
    """(loudness of the loudest 0.4 s, loudness over the whole sound, peak)"""
    y = k_weighted(x, sr)
    power = (y ** 2).sum(axis=1)                     # the channels add up
    n = int(48000 * WINDOW)
    if len(power) < n: power = np.concatenate([power, np.zeros(n - len(power))])
    csum = np.concatenate([[0.0], np.cumsum(power)])
    hop = 480
    best = max((csum[i + n] - csum[i]) / n for i in range(0, len(power) - n + 1, hop))
    lufs = lambda p: -0.691 + 10 * np.log10(p + 1e-12)
    return lufs(best), lufs(power.mean()), float(np.abs(x).max())

def main():
    args = sys.argv[1:]
    target = None
    if args and args[0] == '--set':
        target, args = float(args[1]), args[2:]
    for path in args:
        x, sr = sf.read(path, always_2d=True)
        loud, whole, peak = measure(x, sr)
        name = path.replace('\\', '/').split('/')[-1]
        line = '%-22s %5.2f s  %d canal(aux)  crête %.2f  le plus fort (0,4 s) %6.1f LUFS  en entier %6.1f LUFS' % (
            name, len(x) / sr, x.shape[1], peak, loud, whole)
        if target is not None:
            gain = 10 ** ((target - loud) / 20)
            held = peak * gain > PEAK_MAX
            if held: gain = PEAK_MAX / peak
            x = x * gain
            sf.write(path, x, sr, subtype='PCM_16')
            loud2, _, peak2 = measure(x, sr)
            line += '  ->  %+.1f dB : %.1f LUFS, crête %.2f%s' % (20 * np.log10(gain), loud2, peak2,
                                                                  ' (retenu par la crête)' if held else '')
        print(line)

if __name__ == '__main__':
    main()
