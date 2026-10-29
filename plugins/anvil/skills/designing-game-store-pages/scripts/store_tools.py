#!/usr/bin/env python3
"""Small tools for a game's store-page kit. Needs Pillow; `frames` also needs ffmpeg.

  ticks  --every N --until M --dir D [--from F] [--fps 60]
                                                  print a harness --stills list: [[tick, "D/t000120_s002.0.png"], ...]
                                                  (with --fps the name also carries the second in the movie)
  frames MOVIE --every S --out D                  extract one frame every S seconds as D/s0012.0.png
  sheet  IMG... --out sheet.jpg [--cols 6] [--width 320]
                                                  contact sheet, each tile labelled below with its file stem
                                                  (tick and/or second), to pick screenshot and trailer moments
  shots  DIR [--min 5] [--fix]                    check Steam screenshots: count, >= 1920x1080, 16:9, no alpha;
                                                  --fix flattens fully opaque RGBA (Godot saves RGBA) to RGB in place
  trim   IN.png OUT.png [--fit 1280x720]          crop a transparent logo to its visible pixels, then scale it to
                                                  touch the box (1280 wide and/or 720 tall for the library logo)
  ico    IN.png OUT.ico                           Windows icon with 16..256 px sizes (Steam shortcut icon)
Exit 1 when a check fails, 2 on bad input.
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw


def opt(args, name, default=None, cast=str):
    if name in args:
        i = args.index(name)
        v = args[i + 1]
        del args[i:i + 2]
        return cast(v)
    return default


def ticks(args):
    every, until = opt(args, '--every', cast=int), opt(args, '--until', cast=int)
    d, start, fps = opt(args, '--dir'), opt(args, '--from', 0, int), opt(args, '--fps', 0, int)
    if not (every and until and d):
        sys.exit(2)
    first = start if start > 0 else every
    name = lambda t: f't{t:06d}' + (f'_s{t / fps:05.1f}' if fps else '') + '.png'
    print(json.dumps([[t, os.path.join(d, name(t))] for t in range(first, until, every)]))


def frames(args):
    every, out = opt(args, '--every', cast=float), opt(args, '--out')
    if not (args and every and out):
        sys.exit(2)
    os.makedirs(out, exist_ok=True)
    r = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', args[0]],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(2)
    dur, t, n = float(r.stdout.strip()), 0.0, 0
    while t < dur - 0.05:   # seek each timestamp, so a file's label is exactly where its frame sits
        f = os.path.join(out, f's{t:06.1f}.png')
        if subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', f'{t:.3f}', '-i', args[0],
                           '-frames:v', '1', f]).returncode:
            sys.exit(2)
        t += every; n += 1
    print(f'{n} frames in {out}')


def sheet(args):
    out, cols, width = opt(args, '--out'), opt(args, '--cols', 6, int), opt(args, '--width', 320, int)
    files = sorted(args)
    if not (out and files):
        sys.exit(2)
    tiles = []
    for f in files:   # the label sits in a strip below the frame, so it never covers a HUD corner
        src = Image.open(f).convert('RGB')
        h = round(src.height * width / src.width)
        im = Image.new('RGB', (width, h + 16), (0, 0, 0))
        im.paste(src.resize((width, h), Image.LANCZOS), (0, 0))
        ImageDraw.Draw(im).text((4, h + 2), os.path.splitext(os.path.basename(f))[0], fill=(255, 255, 0))
        tiles.append(im)
    th = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    S = Image.new('RGB', (cols * width + (cols - 1) * 4, rows * th + (rows - 1) * 4), (40, 40, 40))
    for i, t in enumerate(tiles):
        S.paste(t, ((i % cols) * (width + 4), (i // cols) * (th + 4)))
    S.save(out, quality=88)
    print(f'{out}: {len(tiles)} tiles, {S.width}x{S.height}')


def shots(args):
    mn = opt(args, '--min', 5, int)
    fix = '--fix' in args
    if fix:
        args.remove('--fix')
    if not args:
        sys.exit(2)
    d = args[0]
    files = sorted(f for f in os.listdir(d) if f.lower().endswith(('.png', '.jpg', '.jpeg')))
    bad = []
    for f in files:
        im = Image.open(os.path.join(d, f))
        w, h = im.size
        why = []
        if w < 1920 or h < 1080:
            why.append(f'{w}x{h} below 1920x1080')
        if abs(w / h - 16 / 9) > 0.01:
            why.append(f'ratio {w / h:.3f} is not 16:9')
        if 'A' in im.getbands() or 'transparency' in im.info:
            a = im.convert('RGBA').getchannel('A').getextrema()
            if fix and a[0] == 255:
                im.convert('RGB').save(os.path.join(d, f))
                im = Image.open(os.path.join(d, f))
            else:
                why.append('has alpha' + (' (not opaque: fix the capture)' if a[0] < 255 else ' (run with --fix)'))
        print(f'{f}: {w}x{h} {im.mode}' + (' FAIL ' + '; '.join(why) if why else ' ok'))
        bad += why
    if len(files) < mn:
        print(f'FAIL {len(files)} screenshots, Steam needs at least {mn}')
        bad.append('count')
    sys.exit(1 if bad else 0)


def trim(args):
    fit = opt(args, '--fit', '1280x720')
    if len(args) != 2:
        sys.exit(2)
    im = Image.open(args[0]).convert('RGBA')
    box = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if not box:
        print('FAIL no visible pixels'); sys.exit(1)
    im = im.crop(box)
    W, H = (int(v) for v in fit.lower().split('x'))
    k = min(W / im.width, H / im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    im.save(args[1])
    print(f'{args[1]}: {im.width}x{im.height} (box {W}x{H}; touches {"width" if im.width == W else "height"})')


def ico(args):
    if len(args) != 2:
        sys.exit(2)
    im = Image.open(args[0]).convert('RGBA')
    if im.width != im.height or im.width < 256:
        print(f'FAIL source must be square and at least 256 px, got {im.width}x{im.height}'); sys.exit(1)
    im.save(args[1], format='ICO', sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print(f'{args[1]}: 16..256 px')


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in ('ticks', 'frames', 'sheet', 'shots', 'trim', 'ico'):
        print(__doc__); sys.exit(2)
    globals()[sys.argv[1]](sys.argv[2:])
