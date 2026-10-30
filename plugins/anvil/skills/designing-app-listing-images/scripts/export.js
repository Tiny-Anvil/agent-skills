// Export every .panel of a listing-images page as a store-ready image (no alpha channel, exact pixel size).
// Based on aso-shots by ceorkm (MIT, see ../NOTICE-aso-shots).
//
// Usage: node export.js page.html outDir <preset | WxH> [--jpeg] [--keep-radius] [--wait ms] [--no-gl]
//        node export.js --list            print the presets from sizes.json (the one source of sizes)
// --no-gl: launch without the software-WebGL flags (use when the page has no live WebGL)
// Output: PNG, RGB only (stores reject alpha). --jpeg writes quality-95 JPEG instead.
// Panels are exported with square corners (stores show rectangles); --keep-radius keeps the design radius.
const fs = require('fs'), path = require('path'), zlib = require('zlib');

const SIZES = JSON.parse(fs.readFileSync(path.join(__dirname, 'sizes.json'), 'utf8')).presets;

function crc32(buf) { let c, crc = 0xffffffff; for (let n = 0; n < buf.length; n++) { c = (crc ^ buf[n]) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; } return (crc ^ 0xffffffff) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }
function pngRGB(rgba, w, h) {   // 8-bit RGB PNG (colour type 2): no alpha channel
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 3 + 1)] = 0; for (let x = 0; x < w; x++) { const s = (y * w + x) * 4, d = y * (w * 3 + 1) + 1 + x * 3; raw[d] = rgba[s]; raw[d + 1] = rgba[s + 1]; raw[d + 2] = rgba[s + 2]; } }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

(async () => {
  const args = process.argv.slice(2), [page, outDir, sizeArg] = args;
  if (page === '--list') {
    for (const [k, v] of Object.entries(SIZES)) console.log(`${k.padEnd(13)} ${(v.w + 'x' + v.h).padEnd(10)} ${v.target.padEnd(12)} ${v.use}`);
    return;
  }
  if (!page || !outDir || !sizeArg) { console.error('usage: node export.js page.html outDir <preset | WxH> [--jpeg] [--keep-radius] [--wait ms] [--no-gl]'); process.exit(2); }
  const preset = SIZES[sizeArg], [W, H] = preset ? [preset.w, preset.h] : sizeArg.split('x').map(Number);
  if (!(W > 0 && H > 0)) { console.error(`unknown preset or size: ${sizeArg} (see --list)`); process.exit(2); }
  const { chromium } = require('playwright');
  const jpeg = args.includes('--jpeg'), keepRadius = args.includes('--keep-radius');
  const wi = args.indexOf('--wait'), wait = wi > 0 ? +args[wi + 1] : 4000;
  fs.mkdirSync(outDir, { recursive: true });
  const b = await chromium.launch(args.includes('--no-gl') ? {} : { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const url = page.startsWith('http') ? page : 'file://' + path.resolve(page);
  const prep = async (q) => { await q.goto(url); await q.evaluate(() => document.fonts.ready); await q.waitForTimeout(wait); if (!keepRadius) await q.addStyleTag({ content: '.panel{border-radius:0!important;clip-path:none!important}' }); };
  let p = await b.newPage({ viewport: { width: 1600, height: 1000 } }); await prep(p);
  const rects = await p.$$eval('.panel', ps => ps.map(e => { const r = e.getBoundingClientRect(); return { x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height }; }));
  await p.close();
  if (!rects.length) { console.error('no .panel elements found'); process.exit(1); }
  for (let i = 0; i < rects.length; i++) {
    // render at high resolution, centre-crop to the exact store ratio, then resample to the exact pixel size
    const r = rects[i], scale = Math.max(W / r.w, H / r.h), cw = W / scale, ch = H / scale;
    if (Math.abs(r.w / r.h - W / H) / (W / H) > 0.01) console.warn(`panel ${i + 1}: ratio ${(r.w / r.h).toFixed(4)} vs target ${(W / H).toFixed(4)} — edges get cropped; build this store's set at its own ratio`);
    const q = await b.newPage({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: scale }); await prep(q);
    const shot = await q.screenshot({ fullPage: true, clip: { x: r.x + (r.w - cw) / 2, y: r.y + (r.h - ch) / 2, width: cw, height: ch } });
    await q.close();
    const fix = await b.newPage();
    const data = await fix.evaluate(async ([s, w, h, jpeg]) => {
      const img = new Image(); img.src = 'data:image/png;base64,' + s; await img.decode();
      const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d');
      x.fillStyle = '#fff'; x.fillRect(0, 0, w, h); x.imageSmoothingQuality = 'high'; x.drawImage(img, 0, 0, w, h);
      if (jpeg) return c.toDataURL('image/jpeg', .95).split(',')[1];
      const d = x.getImageData(0, 0, w, h).data; let bin = ''; for (let k = 0; k < d.length; k += 32768) bin += String.fromCharCode.apply(null, d.subarray(k, k + 32768)); return btoa(bin);
    }, [shot.toString('base64'), W, H, jpeg]);
    await fix.close();
    const file = path.join(outDir, String(i + 1).padStart(2, '0') + (jpeg ? '.jpg' : '.png'));
    fs.writeFileSync(file, jpeg ? Buffer.from(data, 'base64') : pngRGB(Buffer.from(data, 'base64'), W, H));
    console.log(file, `${W}x${H}`);
  }
  await b.close();
})();
