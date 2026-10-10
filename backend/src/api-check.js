// Starts the API on a random port and checks the area endpoints. Uses a temporary test area.
import assert from 'node:assert/strict';
process.env.ADMIN_API_KEY = 'test-key';
const { createApp } = await import('./app.js');

const server = createApp().listen(0);
const base = `http://localhost:${server.address().port}/api/areas`;
const admin = { 'content-type': 'application/json', 'x-api-key': 'test-key' };
const call = async (path, opts) => {
  const res = await fetch(base + path, opts);
  return { status: res.status, body: res.status === 204 ? null : await res.json() };
};
const pass = (m) => console.log(`  ok  ${m}`);
let id;

try {
  let r = await call('');
  assert.equal(r.status, 200);
  assert.equal(r.body.count, r.body.data.length);
  pass('list areas');

  r = await call('?search=jaro');
  assert.ok(r.body.data.length > 0 && r.body.data.every((a) => /jaro/i.test(a.name + a.city)));
  pass('search by name');

  r = await call('/abc');
  assert.equal(r.status, 400);
  r = await call('/999999');
  assert.equal(r.status, 404);
  pass('invalid id -> 400, missing -> 404');

  r = await call('', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
  assert.equal(r.status, 401);
  pass('create without key -> 401');

  r = await call('', { method: 'POST', headers: admin, body: JSON.stringify({ name: ' ', latitude: 99 }) });
  assert.equal(r.status, 400);
  assert.ok(r.body.error.details.name && r.body.error.details.latitude && r.body.error.details.city);
  pass('validation errors -> 400');

  const area = { name: 'Api Check Area', city: 'Test City', latitude: 10.7, longitude: 122.5 };
  r = await call('', { method: 'POST', headers: admin, body: JSON.stringify(area) });
  assert.equal(r.status, 201);
  id = r.body.data.id;
  pass('create area -> 201');

  r = await call('', { method: 'POST', headers: admin, body: JSON.stringify({ ...area, name: 'api check AREA' }) });
  assert.equal(r.status, 409);
  pass('duplicate (case-insensitive) -> 409');

  r = await call(`/${id}`, { method: 'PATCH', headers: admin, body: JSON.stringify({ latitude: 11 }) });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.latitude, 11);
  r = await call(`/${id}`, { method: 'PATCH', headers: admin, body: '{}' });
  assert.equal(r.status, 400);
  pass('partial update; empty update -> 400');
} finally {
  if (id) {
    const r = await call(`/${id}`, { method: 'DELETE', headers: admin });
    assert.equal(r.status, 204);
    assert.equal((await call(`/${id}`)).status, 404);
    pass('delete area -> 204, then 404');
  }
  server.close();
  process.exit(process.exitCode ?? 0);
}
