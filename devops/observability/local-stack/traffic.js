// Generated traffic for the lab: a steady request rate with a set share of
// errors and slow requests, so dashboards have data and alerts fire.
//
// With the defaults (2% errors, 4% slow) the availability page alert fires
// within about 5 minutes, and the latency ticket after about 20. Set
// ERROR_PERCENT=0 and SLOW_PERCENT=0 to watch the alerts resolve.
import http from 'k6/http';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:9898';
const ERROR_PERCENT = Number(__ENV.ERROR_PERCENT || 2);
const SLOW_PERCENT = Number(__ENV.SLOW_PERCENT || 4);

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 20),
      timeUnit: '1s',
      duration: __ENV.DURATION || '8h',
      preAllocatedVUs: 20,
      maxVUs: 100,
    },
  },
  // This script generates failures on purpose; don't fail the run because of them.
  thresholds: {},
};

export default function () {
  const roll = Math.random() * 100;
  if (roll < ERROR_PERCENT) {
    http.get(`${BASE_URL}/status/500`, { tags: { name: 'status/500' } });
  } else if (roll < ERROR_PERCENT + SLOW_PERCENT) {
    http.get(`${BASE_URL}/delay/1`, { tags: { name: 'delay' } });
  } else if (roll < 60) {
    http.get(`${BASE_URL}/`, { tags: { name: 'root' } });
  } else {
    http.get(`${BASE_URL}/api/info`, { tags: { name: 'api/info' } });
  }
}
