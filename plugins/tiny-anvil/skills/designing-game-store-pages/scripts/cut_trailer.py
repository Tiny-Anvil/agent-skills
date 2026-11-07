#!/usr/bin/env python3
"""Cut a gameplay trailer from recorded footage, by recipe, and measure the result against Steam's spec.

Usage: python3 cut_trailer.py trailer.json [--dry-run]

Recipe (paths relative to the recipe file; see ../templates/trailer.json):
  out          output .mp4
  fps          30 or 60 (from the spec's list)
  segments     [{"src": "footage/run.avi", "start": 12.0, "end": 15.5, "beat": "hook"}, ...] in trailer order,
               hard cuts; gameplay first, so the trailer shows play from 0 s
  end_card     {"image": "end_card.png", "seconds": 4}: logo card after a hard cut; the only place for the logo
  fade_out     seconds of video and audio fade at the very end (default 0.6)
  thumbnail    {"src": ..., "at": 14.2, "out": "thumbnail.jpg"}: one frame of footage, no text

The spec (size, fps, bitrate floor, codecs, loudness) is read from designing-app-listing-images/scripts/sizes.json
→ "trailer", the one place it lives. Writes <out dir>/trailer_report.md with measured values; exit 1 on a failed
check, 2 on a bad recipe or a missing tool.
"""
import json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = os.path.join(HERE, '..', '..', 'designing-app-listing-images', 'scripts', 'sizes.json')


def die(msg, code=2):
    print('cut_trailer: ' + msg, file=sys.stderr)
    sys.exit(code)


def probe(path):
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', path],
                       capture_output=True, text=True)
    if r.returncode:
        die(f'ffprobe failed on {path}: {r.stderr.strip()[:300]}')
    return json.loads(r.stdout)


def fnum(s):
    if '/' in str(s):
        a, b = str(s).split('/')
        return float(a) / float(b) if float(b) else 0.0
    return float(s)


def main():
    args = sys.argv[1:]
    if not args or args[0].startswith('-'):
        die(__doc__.strip().splitlines()[2])
    for tool in ('ffmpeg', 'ffprobe'):
        if not shutil.which(tool):
            die(f'{tool} not found on PATH')
    recipe_path = os.path.abspath(args[0])
    base = os.path.dirname(recipe_path)
    rp = lambda p: p if os.path.isabs(p) else os.path.join(base, p)
    R = json.load(open(recipe_path))
    spec = json.load(open(SIZES))['trailer']
    W, H, fps = spec['w'], spec['h'], int(R.get('fps', spec['fps'][-1]))
    if fps not in spec['fps']:
        die(f'fps {fps} not in {spec["fps"]}')
    segs = R.get('segments') or die('no segments')
    out = rp(R['out'])
    fade = float(R.get('fade_out', 0.6))
    card = R.get('end_card')

    # Inputs: each footage file once, then the end card image
    srcs, info = [], {}
    for s in segs:
        p = rp(s['src'])
        if p not in info:
            if not os.path.exists(p):
                die(f'missing footage {p}')
            pr = probe(p)
            dur = float(pr['format'].get('duration', 0))
            info[p] = {'idx': len(srcs), 'dur': dur, 'audio': any(x['codec_type'] == 'audio' for x in pr['streams'])}
            srcs.append(p)
        a, b = float(s['start']), float(s['end'])
        if not (0 <= a < b <= info[p]['dur'] + 0.05):
            die(f'segment {s} outside 0..{info[p]["dur"]:.2f} s of {p}')
    cmd = ['ffmpeg', '-hide_banner', '-y']
    for p in srcs:
        cmd += ['-i', p]
    vf_fit = (f'fps={fps},scale={W}:{H}:force_original_aspect_ratio=decrease:flags=lanczos,'
              f'pad={W}:{H}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p')
    af_fit = f'aresample={spec["audio_rate"]},aformat=sample_fmts=fltp:channel_layouts=stereo'
    parts, labels, total = [], [], 0.0
    for i, s in enumerate(segs):
        p = rp(s['src']); k = info[p]['idx']; a, b = float(s['start']), float(s['end']); d = b - a
        parts.append(f'[{k}:v]trim=start={a}:end={b},setpts=PTS-STARTPTS,{vf_fit}[v{i}]')
        if info[p]['audio']:
            parts.append(f'[{k}:a]atrim=start={a}:end={b},asetpts=PTS-STARTPTS,{af_fit}[a{i}]')
        else:
            parts.append(f'anullsrc=r={spec["audio_rate"]}:cl=stereo,atrim=duration={d},{af_fit}[a{i}]')
        labels.append(f'[v{i}][a{i}]'); total += d
    n = len(segs)
    if card:
        img = rp(card['image']); sec = float(card.get('seconds', 4))
        if not os.path.exists(img):
            die(f'missing end card {img}')
        k = len(srcs)
        cmd += ['-loop', '1', '-framerate', str(fps), '-t', str(sec), '-i', img]
        parts.append(f'[{k}:v]{vf_fit}[v{n}]')   # hard cut: a fade from black would put black frames in
        parts.append(f'anullsrc=r={spec["audio_rate"]}:cl=stereo,atrim=duration={sec},{af_fit}[a{n}]')
        labels.append(f'[v{n}][a{n}]'); n += 1; total += sec
    parts.append(''.join(labels) + f'concat=n={n}:v=1:a=1[vc][ac]')
    st = max(0.0, total - fade)
    parts.append(f'[vc]fade=t=out:st={st:.3f}:d={fade}[vout]')
    parts.append(f'[ac]loudnorm=I={spec["loudness_lufs"]}:TP={spec["true_peak_db"]}:LRA=11,{af_fit},'
                 f'afade=t=out:st={st:.3f}:d={fade}[aout]')
    kbps = max(spec['min_kbps'] * 2, 12000)
    cmd += ['-filter_complex', ';'.join(parts), '-map', '[vout]', '-map', '[aout]',
            '-c:v', 'libx264', '-preset', 'slow', '-profile:v', 'high', '-pix_fmt', 'yuv420p',
            '-b:v', f'{kbps}k', '-minrate', f'{spec["min_kbps"]}k', '-maxrate', f'{int(kbps * 1.5)}k',
            '-bufsize', f'{kbps * 2}k', '-x264-params', 'nal-hrd=vbr', '-g', str(fps * 2),
            '-c:a', 'aac', '-b:a', '320k', '-ar', str(spec['audio_rate']), '-ac', '2',
            '-movflags', '+faststart', '-t', f'{total:.3f}', out]
    if '--dry-run' in args:
        print(' '.join(cmd)); return
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        die('ffmpeg failed:\n' + r.stderr[-1500:])

    thumb = R.get('thumbnail')
    if thumb:
        tp = rp(thumb['out'])
        tw, th = spec['thumbnail']
        r = subprocess.run(['ffmpeg', '-hide_banner', '-y', '-ss', str(thumb['at']), '-i', rp(thumb['src']),
                            '-frames:v', '1', '-vf', f'scale={tw}:{th}:force_original_aspect_ratio=decrease:flags=lanczos,'
                            f'pad={tw}:{th}:(ow-iw)/2:(oh-ih)/2', '-q:v', '2', tp], capture_output=True, text=True)
        if r.returncode:
            die('thumbnail failed:\n' + r.stderr[-800:])

    # Measure the result
    pr = probe(out)
    v = next(x for x in pr['streams'] if x['codec_type'] == 'video')
    a = next((x for x in pr['streams'] if x['codec_type'] == 'audio'), None)
    dur = float(pr['format']['duration'])
    vkbps = (int(v['bit_rate']) if v.get('bit_rate') else int(pr['format']['bit_rate'])) / 1000
    e = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', out, '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True).stderr
    summ = e[e.rfind('Summary:'):] if 'Summary:' in e else ''
    m_i = re.search(r'I:\s+(-?[\d.]+|-inf) LUFS', summ)
    m_p = re.search(r'Peak:\s+(-?[\d.]+|-inf) dBFS', summ)
    lufs = float(m_i.group(1)) if m_i and m_i.group(1) != '-inf' else None
    peak = float(m_p.group(1)) if m_p and m_p.group(1) != '-inf' else None
    silent = lufs is None or lufs < -60
    # Frozen stretches in the gameplay part (the end card is still by design): a stuck bot, a paused replay
    play_end = total - (float(card.get('seconds', 4)) if card else 0.0)
    fz = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', out, '-map', '0:v',
                         '-vf', 'freezedetect=n=-55dB:d=1.2', '-f', 'null', '-'], capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r'freeze_start: ([\d.]+)', fz)]
    ends = [float(x) for x in re.findall(r'freeze_end: ([\d.]+)', fz)] + [dur]
    frozen = [(a, min(b, play_end)) for a, b in zip(starts, ends) if a < play_end - 0.05]
    # Black frames in the gameplay part: a fade, a loading screen, a camera inside a wall
    bk = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', out, '-map', '0:v',
                         '-vf', 'blackdetect=d=0.1:pix_th=0.08', '-f', 'null', '-'], capture_output=True, text=True).stderr
    black = [(float(a), float(b)) for a, b in re.findall(r'black_start:([\d.]+) black_end:([\d.]+)', bk)
             if float(a) < play_end - 0.05]
    checks = [
        ('size', f'{v["width"]}x{v["height"]}', v['width'] == W and v['height'] == H),
        ('fps', f'{fnum(v["r_frame_rate"]):.2f}', round(fnum(v['r_frame_rate'])) in spec['fps']),
        ('video codec', v['codec_name'], v['codec_name'] == spec['video_codec']),
        ('video bitrate', f'{vkbps:.0f} kbps (min {spec["min_kbps"]})', vkbps >= spec['min_kbps']),
        ('audio', f'{a["codec_name"]} {a["sample_rate"]} Hz {a["channels"]} ch' if a else 'none',
         bool(a) and a['codec_name'] == spec['audio_codec'] and int(a['sample_rate']) == spec['audio_rate'] and a['channels'] == 2),
        ('loudness', 'silent footage (no game audio)' if silent else f'{lufs:.1f} LUFS (target {spec["loudness_lufs"]})',
         silent or abs(lufs - spec['loudness_lufs']) <= 1.5),
        ('true peak', 'n/a' if peak is None else f'{peak:.1f} dBTP (max {spec["true_peak_db"]})',
         peak is None or peak <= spec['true_peak_db'] + 0.5),
        ('no black gameplay', 'none' if not black else ', '.join(f'{a:.1f}-{b:.1f} s' for a, b in black) +
         (' (black from 0 s: gameplay must start at frame 1)' if black[0][0] < 0.05 else ''), not black),
        ('no frozen gameplay', 'none' if not frozen else ', '.join(f'{a:.1f}-{b:.1f} s' for a, b in frozen) +
         ' (a stuck bot or a paused replay: pick other footage)', not frozen),
        ('end card last', 'yes' if card else 'no end card', bool(card)),
    ]
    notes = []
    if not 30 <= dur <= 90:
        notes.append(f'duration {dur:.1f} s is outside the 30-90 s default (trailer.md): fine for a teaser, '
                     'otherwise cut or extend')
    if silent:
        notes.append('no audio in the footage: Steam plays trailers muted at first, but say in RUN.md why it is silent')
    lines = [f'# Trailer report: {os.path.basename(out)}', '',
             f'Recipe: `{os.path.relpath(recipe_path, os.path.dirname(out))}`. Duration {dur:.2f} s, '
             f'{len(segs)} segments, spec: {spec["spec"]}', '', '| Check | Measured | Result |', '|---|---|---|']
    lines += [f'| {c} | {m} | {"PASS" if ok else "FAIL"} |' for c, m, ok in checks]
    lines += ['', '| # | Beat | Source | In | Out | Length |', '|---|---|---|---|---|---|']
    lines += [f'| {i + 1} | {s.get("beat", "")} | {s["src"]} | {float(s["start"]):.2f} | {float(s["end"]):.2f} | '
              f'{float(s["end"]) - float(s["start"]):.2f} |' for i, s in enumerate(segs)]
    if thumb:
        lines += ['', f'Thumbnail: `{thumb["out"]}` (frame at {thumb["at"]} s of `{thumb["src"]}`).']
    if notes:
        lines += [''] + [f'- {x}' for x in notes]
    rep = os.path.join(os.path.dirname(out), 'trailer_report.md')
    open(rep, 'w').write('\n'.join(lines) + '\n')
    failed = [c for c, _, ok in checks if not ok]
    print(f'{out} {dur:.2f}s {v["width"]}x{v["height"]} {vkbps:.0f}kbps -> {rep}' + (f' FAIL: {", ".join(failed)}' if failed else ' PASS'))
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
