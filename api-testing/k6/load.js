// Load test: ramp to a target request rate, hold it, and fail if the SLOs
// aren't met. Run against a non-production environment sized like production.
//
//   k6 run -e BASE_URL=https://... -e TOKEN=... -e RATE=20 -e DURATION=5m k6/load.js
//
// RATE is lifecycles per second; each lifecycle is four requests.
// PROFILE=stress ramps to 4x RATE to find where the API starts failing.
// PROFILE=spike jumps straight to 4x RATE, as a sudden burst would.
//
// Check the AWS API Gateway throttle (throttle_rate_limit) and Lambda or
// Functions concurrency first: a load test that hits them measures the limit,
// not the API. Tell the platform's owners before running against a shared
// environment.
import { itemLifecycle } from './lib/items.js';

const RATE = Number(__ENV.RATE || 10);
const DURATION = __ENV.DURATION || '2m';
const PROFILE = __ENV.PROFILE || 'load';

const profiles = {
  load: [
    { target: RATE, duration: '1m' }, // ramp up
    { target: RATE, duration: DURATION }, // hold
    { target: 0, duration: '30s' }, // ramp down
  ],
  stress: [
    { target: RATE, duration: '1m' },
    { target: RATE * 2, duration: DURATION },
    { target: RATE * 4, duration: DURATION },
    { target: 0, duration: '30s' },
  ],
  spike: [
    { target: RATE * 4, duration: '10s' },
    { target: RATE * 4, duration: '1m' },
    { target: 0, duration: '10s' },
  ],
};

if (!profiles[PROFILE]) {
  throw new Error(`PROFILE must be one of: ${Object.keys(profiles).join(', ')}`);
}

export const options = {
  scenarios: {
    items: {
      // Arrival rate, not a fixed number of users: if the API slows down,
      // k6 keeps sending at the target rate instead of easing off, which
      // is how real traffic behaves.
      executor: 'ramping-arrival-rate',
      startRate: 0,
      timeUnit: '1s',
      preAllocatedVUs: Math.max(10, RATE * 2),
      maxVUs: Math.max(50, RATE * 10),
      stages: profiles[PROFILE],
    },
  },
  // Thresholds are the SLOs. Set them from the service's real objectives.
  thresholds: {
    http_req_failed: ['rate<0.001'], // 99.9% of requests succeed
    'http_req_duration{name:GET /items/{id}}': ['p(95)<300', 'p(99)<800'],
    'http_req_duration{name:PUT /items/{id}}': ['p(95)<500', 'p(99)<1000'],
    checks: ['rate>0.999'],
    dropped_iterations: ['count<1'], // k6 itself ran out of VUs
  },
};

export default function () {
  itemLifecycle();
}
