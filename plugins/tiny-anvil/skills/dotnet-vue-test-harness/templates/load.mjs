// scripts/load.mjs — N concurrent clients GET one URL for D seconds; p50/p95/p99, rps and error rate as JSON.
// For machines without k6. Thresholds come from the brief's test row.
//   node scripts/load.mjs <url> [out.json] [clients=10] [seconds=30] [p95ms=150]
import { writeFileSync } from 'node:fs'
import os from 'node:os'

const [url, out, clients = '10', seconds = '30', p95Max = '150'] = process.argv.slice(2)
if (!url) {
  console.error('usage: node scripts/load.mjs <url> [out.json] [clients] [seconds] [p95ms]')
  process.exit(2)
}

async function worker(until, samples, errors) {
  while (Date.now() < until) {
    const t0 = performance.now()
    try {
      const res = await fetch(url)
      await res.arrayBuffer()
      if (res.status !== 200) errors.push(res.status)
      else samples.push(performance.now() - t0)
    } catch (e) {
      errors.push(String(e))
    }
  }
}

// Warm-up: JIT and connection pools, not measured.
await Promise.all(Array.from({ length: 3 }, () => worker(Date.now() + 3000, [], [])))

const samples = []
const errors = []
const until = Date.now() + Number(seconds) * 1000
await Promise.all(Array.from({ length: Number(clients) }, () => worker(until, samples, errors)))

samples.sort((a, b) => a - b)
const pct = (p) =>
  samples.length ? Math.round(samples[Math.min(samples.length - 1, Math.floor((p / 100) * samples.length))] * 10) / 10 : null
const total = samples.length + errors.length
const result = {
  url,
  machine: `${os.hostname()} ${os.arch()} ${os.cpus().length} cpus`,
  clients: Number(clients),
  seconds: Number(seconds),
  requests: total,
  rps: Math.round(total / Number(seconds)),
  p50ms: pct(50),
  p95ms: pct(95),
  p99ms: pct(99),
  errorRatePct: Math.round((errors.length / Math.max(1, total)) * 10000) / 100,
  thresholds: { p95ms: Number(p95Max), errorRatePct: 0 },
}
console.log(JSON.stringify(result, null, 2))
if (out) writeFileSync(out, JSON.stringify(result, null, 2))
process.exitCode = result.p95ms !== null && result.p95ms <= Number(p95Max) && errors.length === 0 ? 0 : 1
