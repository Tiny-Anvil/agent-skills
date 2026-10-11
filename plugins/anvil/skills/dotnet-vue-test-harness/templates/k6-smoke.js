// k6 run -e BASE_URL=http://localhost:5001 -e VUS=50 -e DURATION=60s \
//   --summary-export data/run/qa/k6-<testid>.json k6-smoke.js
// Thresholds come from the brief's test row. Raise the API's rate limits for the run and say so in the evidence.
import http from 'k6/http'
import { check } from 'k6'

export const options = {
  vus: Number(__ENV.VUS ?? 50),
  duration: __ENV.DURATION ?? '60s',
  thresholds: {
    http_req_duration: [`p(95)<${__ENV.P95_MS ?? 200}`],
    http_req_failed: ['rate==0'],
  },
}

const base = __ENV.BASE_URL ?? 'http://localhost:5001'

export default function () {
  const res = http.get(`${base}/api/v1/items?page=1&pageSize=20`, { headers: { Accept: 'application/json' } })
  check(res, { 'status 200': (r) => r.status === 200 })
}
