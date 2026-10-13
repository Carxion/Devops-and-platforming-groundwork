// Shared helpers for the Items API k6 tests.
import http from 'k6/http';
import { check } from 'k6';
import exec from 'k6/execution';

export const BASE_URL = (__ENV.BASE_URL || 'http://127.0.0.1:8080').replace(/\/$/, '');
const TOKEN = __ENV.TOKEN || '';

export const params = (name) => ({
  headers: {
    'Content-Type': 'application/json',
    ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
  },
  // Group every request for an operation under one name, so per-ID URLs
  // don't create a separate metric series each.
  tags: { name },
});

// Unique per VU and iteration, so concurrent VUs never share an item.
export function newItemId() {
  return `k6-${exec.vu.idInTest}-${exec.scenario.iterationInTest}-${Date.now()}`;
}

// One full lifecycle: create, read, delete, confirm gone.
export function itemLifecycle() {
  const id = newItemId();
  const url = `${BASE_URL}/items/${id}`;

  const put = http.put(url, JSON.stringify({ status: 'pending', quantity: 1 }), params('PUT /items/{id}'));
  check(put, { 'PUT 200': (r) => r.status === 200 });

  const get = http.get(url, params('GET /items/{id}'));
  check(get, {
    'GET 200': (r) => r.status === 200,
    'GET returns the item': (r) => r.status === 200 && r.json('id') === id,
  });

  const del = http.del(url, null, params('DELETE /items/{id}'));
  check(del, { 'DELETE 204': (r) => r.status === 204 });

  // 404 is expected here, so don't count it as a failed request.
  const gone = http.get(url, {
    ...params('GET /items/{id} (deleted)'),
    responseCallback: http.expectedStatuses(404),
  });
  check(gone, { 'GET after DELETE 404': (r) => r.status === 404 });
}
