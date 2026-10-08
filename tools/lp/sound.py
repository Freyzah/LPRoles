"""Turns a sound file into a WAV the mod can play (the game's media player reads WAV and MP3,
not OGG).

python tools/lp/sound.py <input: ogg, flac, wav...> <output.wav> [peak]
Decodes with the "soundfile" Python module, keeps one channel when both are the same, removes
the silence at both ends, brings the loudest point to `peak` (0.89 by default, i.e. -1 dB:
nothing else is changed in the sound) and writes 16-bit samples, the only kind the mod can
fade out when it cuts a sound to a length.
"""
import sys
import numpy as np
import soundfile as sf

def main():
    src, dst = sys.argv[1], sys.argv[2]
    peak = float(sys.argv[3]) if len(sys.argv) > 3 else 0.89
    x, sr = sf.read(src, always_2d=True)
    before = (x.shape[1], len(x) / sr, float(np.abs(x).max()))
    if x.shape[1] > 1 and np.abs(x - x[:, :1]).max() < 1e-4:
        x = x[:, :1]                                # every channel carries the same sound
    loud = np.where(np.abs(x).max(axis=1) > 10 ** (-60 / 20))[0]
    if len(loud): x = x[loud[0]:loud[-1] + 1]
    top = float(np.abs(x).max())
    if top > 0: x = x * (peak / top)
    sf.write(dst, x, sr, subtype='PCM_16')
    print('%s : %d canal(aux), %.2f s, crête %.2f' % (src, before[0], before[1], before[2]))
    print('%s : %d canal(aux), %.2f s, crête %.2f, %d Hz, 16 bits (gain x%.1f)' % (
        dst, x.shape[1], len(x) / sr, peak, sr, peak / top if top else 1))

if __name__ == '__main__':
    main()
