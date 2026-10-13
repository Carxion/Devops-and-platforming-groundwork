// Smoke test: one virtual user, a few lifecycles. Run after every deployment.
//   k6 run -e BASE_URL=http://127.0.0.1:8080 k6/smoke.js
import { itemLifecycle } from './lib/items.js';

export const options = {
  vus: 1,
  iterations: 5,
  thresholds: {
    checks: ['rate==1.0'], // every check passes
    http_req_failed: ['rate==0'],
    http_req_duration: ['p(95)<1000'],
  },
};

export default function () {
  itemLifecycle();
}
