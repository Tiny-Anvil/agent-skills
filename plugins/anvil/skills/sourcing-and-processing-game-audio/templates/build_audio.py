#!/usr/bin/env python3
"""build_audio.py - rebuild every game sound from the untouched originals, from one recipe file.

    python3 build_audio.py audio_recipes.json [only_name ...]

Originals are never modified. Each sound = layers (trimmed, sped, filtered, gained excerpts of originals) mixed,
faded, levelled (LUFS target, or peak-normalised when too short to measure), limited, encoded by length
(one-shots: 48 kHz 16-bit WAV, longer: OGG Vorbis q6). Loops get a crossfaded seam. Then every output is
measured and audio_report.md is written: duration, rate, channels, integrated LUFS, true peak, and for loops the
level jump and the click ratio at the seam (> 5 = audible click). `"loop": true` marks a loop that needs no crossfade.

Recipe (paths relative to the recipe file):
{
  "out_dir": "game/assets/audio", "report": "audio_report.md",
  "defaults": {"rate": 48000, "long_s": 2.0, "peak_db": -1.0, "channels": 1},
  "sounds": {
    "wpn_fire_01": {"lufs": -14, "fade_out": 0.05,
       "layers": [{"src": "audio_src/A/ak74.mp3", "start": 0.0, "len": 0.30, "gain_db": -4, "speed": 0.96,
                   "filters": "highpass=f=60"}]},
    "amb_city_loop": {"lufs": -28, "channels": 2, "loop_crossfade": 2.0,
       "layers": [{"src": "audio_src/B/city.mp3", "start": 5.0, "len": 62.0}]}
  }
}
"""
import json, math, os, re, subprocess, sys

FF = os.environ.get("FFMPEG", "ffmpeg")


def run(args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("ffmpeg failed: %s\n%s" % (" ".join(args), r.stderr[-1500:]))
    return r.stderr


def measure(path):
    """Integrated loudness (LUFS) and true peak (dBTP); LUFS is None when the clip is too short to gate."""
    err = run([FF, "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=print_format=json", "-f", "null", "-"])
    m = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
    i = float(m["input_i"]) if m["input_i"] not in ("-inf", "inf") else None
    return (i if i is not None and i > -70 else None), float(m["input_tp"])


def rms_db(path, start, dur):
    err = run([FF, "-hide_banner", "-nostats", "-ss", str(max(start, 0)), "-t", str(dur), "-i", path,
               "-af", "volumedetect", "-f", "null", "-"])
    mm = re.search(r"mean_volume: (-?[\d.]+) dB", err)
    return float(mm.group(1)) if mm else float("nan")


def seam_click(path, dur):
    """A loop's wrap: |first sample - last sample| over the median sample-to-sample step near the ends.
    About 1 = continuous; well above 5 = an audible click at the seam. Channel 1 only."""
    import array
    def pcm(start, length):
        raw = subprocess.run([FF, "-v", "error", "-ss", str(max(start, 0.0)), "-t", str(length), "-i", path,
                              "-ac", "1", "-f", "f32le", "-"], capture_output=True).stdout
        a = array.array("f"); a.frombytes(raw[: len(raw) // 4 * 4]); return a
    head, tail = pcm(0.0, 0.01), pcm(dur - 0.01, 0.02)
    if len(head) < 3 or len(tail) < 3:
        return float("nan")
    steps = sorted(abs(head[i + 1] - head[i]) for i in range(len(head) - 1)) + \
        sorted(abs(tail[i + 1] - tail[i]) for i in range(len(tail) - 1))
    med = sorted(steps)[len(steps) // 2] or 1e-9
    return abs(head[0] - tail[-1]) / med


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=sample_rate,channels:format=duration",
                          "-of", "json", path], capture_output=True, text=True).stdout
    j = json.loads(out)
    s = j["streams"][0]
    return float(j["format"]["duration"]), int(s["sample_rate"]), int(s["channels"])


def build(name, spec, d, base, out_dir):
    rate = int(spec.get("rate", d["rate"]))
    ch = int(spec.get("channels", d["channels"]))
    xf = float(spec.get("loop_crossfade", 0.0))
    args = [FF, "-hide_banner", "-y"]
    chains = []
    for k, L in enumerate(spec["layers"]):
        args += ["-i", os.path.join(base, L["src"])]
        ln = float(L["len"]) + (xf if k == 0 and xf > 0 else 0.0)   # a loop needs xf seconds past its end
        f = ["atrim=start=%g:duration=%g" % (float(L.get("start", 0.0)), ln), "asetpts=PTS-STARTPTS",
             "aresample=%d" % rate]
        sp = float(L.get("speed", 1.0))
        if sp != 1.0:   # speed + pitch together (resampling), the way the originals were edited
            f += ["asetrate=%d" % round(rate * sp), "aresample=%d" % rate]
        if L.get("filters"):
            f.append(L["filters"])
        f.append("volume=%gdB" % float(L.get("gain_db", 0.0)))
        chains.append("[%d:a]%s[l%d]" % (k, ",".join(f), k))
    n = len(spec["layers"])
    graph = ";".join(chains) + ";" + "".join("[l%d]" % k for k in range(n)) + \
        ("amix=inputs=%d:normalize=0:duration=longest[m]" % n if n > 1 else "anull[m]")
    if xf > 0:   # seamless loop: the xf seconds after the end fade out over the first xf seconds
        body = float(spec["layers"][0]["len"])
        graph += (";[m]asplit=2[a][b];[a]atrim=0:%g,asetpts=PTS-STARTPTS[body];"
                  "[b]atrim=%g:%g,asetpts=PTS-STARTPTS[tail];[tail][body]acrossfade=d=%g:c1=tri:c2=tri[m2]"
                  % (body, body, body + xf, xf))
        last = "m2"
    else:
        last = "m"
    fo = float(spec.get("fade_out", 0.0))
    fi = float(spec.get("fade_in", 0.0))
    post = []
    if fi > 0:
        post.append("afade=t=in:d=%g" % fi)
    if fo > 0:
        post.append("areverse,afade=t=in:d=%g,areverse" % fo)
    graph += ";[%s]%s[pre]" % (last, ",".join(post) if post else "anull")
    tmp = os.path.join(out_dir, ".%s.pre.wav" % name)
    run(args + ["-filter_complex", graph, "-map", "[pre]", "-ac", str(ch), "-ar", str(rate), "-c:a", "pcm_f32le", tmp])
    lufs, tp = measure(tmp)
    peak_db = float(spec.get("peak_db", d["peak_db"]))
    if spec.get("lufs") is not None and lufs is not None:
        gain = float(spec["lufs"]) - lufs
    else:
        gain = peak_db - tp   # too short to gate (or no target): peak-normalise
    dur = probe(tmp)[0]
    long_ = dur >= float(d["long_s"]) or xf > 0
    out = os.path.join(out_dir, name + (".ogg" if long_ else ".wav"))
    codec = ["-c:a", "libvorbis", "-q:a", "6"] if long_ else ["-c:a", "pcm_s16le"]
    limit = 10 ** (peak_db / 20.0)
    # latency=1: alimiter looks ahead and by default DELAYS the audio (leading silence): measured, it put ~5 ms of
    # zeros at the head of every loop (an audible click at the seam) and would late-start every transient.
    run([FF, "-hide_banner", "-y", "-i", tmp, "-af", "volume=%gdB,alimiter=limit=%g:level=disabled:latency=1" % (gain, limit),
         "-ar", str(rate), "-ac", str(ch)] + codec + [out])
    os.remove(tmp)
    return out, xf > 0 or bool(spec.get("loop", False))


def main():
    recipe = sys.argv[1]
    only = set(sys.argv[2:])
    base = os.path.dirname(os.path.abspath(recipe))
    r = json.load(open(recipe))
    d = {"rate": 48000, "long_s": 2.0, "peak_db": -1.0, "channels": 1}
    d.update(r.get("defaults", {}))
    out_dir = os.path.join(base, r.get("out_dir", "game/assets/audio"))
    os.makedirs(out_dir, exist_ok=True)
    rows = ["| sound | file | s | Hz | ch | LUFS | dBTP | loop seam dB | seam click | target |",
            "|---|---|---|---|---|---|---|---|---|---|"]
    for name, spec in r["sounds"].items():
        if only and name not in only:
            continue
        out, is_loop = build(name, spec, d, base, out_dir)
        dur, hz, ch = probe(out)
        lufs, tp = measure(out)
        seam = abs(rms_db(out, dur - 0.05, 0.05) - rms_db(out, 0.0, 0.05)) if is_loop else float("nan")
        click = seam_click(out, dur) if is_loop else float("nan")
        rows.append("| %s | %s | %.2f | %d | %d | %s | %.1f | %s | %s | %s |" % (
            name, os.path.basename(out), dur, hz, ch, "%.1f" % lufs if lufs is not None else "short",
            tp, "%.1f" % seam if is_loop else "-", ("%.1f%s" % (click, " CLICK" if click > 5 else "")) if is_loop else "-",
            spec.get("lufs", "peak %g" % d["peak_db"])))
        print(rows[-1])
    rep = os.path.join(base, r.get("report", "audio_report.md"))
    open(rep, "w").write("# Audio build report\n\n" + "\n".join(rows) + "\n")
    print("report:", rep)


if __name__ == "__main__":
    main()
