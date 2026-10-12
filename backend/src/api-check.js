// Starts the API on a random port and checks the area and interruption endpoints
// against the real database. Uses a temporary test area and test interruption,
// which are deleted at the end.
import assert from 'node:assert/strict';
process.env.ADMIN_API_KEY = 'test-key';
const { createApp } = await import('./app.js');

const server = createApp().listen(0);
const root = `http://localhost:${server.address().port}/api`;
const json = { 'content-type': 'application/json' };
const admin = { ...json, 'x-api-key': 'test-key' };

const request = async (path, { method = 'GET', headers, body } = {}) => {
  const res = await fetch(root + path, {
    method,
    headers,
    body: body === undefined || typeof body === 'string' ? body : JSON.stringify(body),
  });
  return { status: res.status, body: res.status === 204 ? null : await res.json() };
};
const send = (method, path, body) => request(path, { method, headers: admin, body });
const pass = (m) => console.log(`  ok  ${m}`);

// Asserts a 400 validation error that mentions each of the given fields.
function assertInvalid(r, fields) {
  assert.equal(r.status, 400, JSON.stringify(r.body));
  assert.equal(r.body.success, false);
  assert.equal(r.body.error.code, 'VALIDATION_ERROR');
  for (const f of fields) assert.ok(r.body.error.details?.[f], `expected an error for ${f}: ${JSON.stringify(r.body)}`);
}

let areaId;
let interruptionId;

try {
  // ---------- Areas ----------
  let r = await request('/areas');
  assert.equal(r.status, 200);
  assert.equal(r.body.success, true);
  assert.equal(r.body.count, r.body.data.length);
  pass('list areas');

  r = await request('/areas?search=jaro');
  assert.ok(r.body.data.length > 0 && r.body.data.every((a) => /jaro/i.test(a.name + a.city)));
  pass('search by name');

  r = await request('/areas?city=a&city=b');
  assert.equal(r.status, 400);
  assert.equal(r.body.error.code, 'INVALID_QUERY');
  pass('repeated query parameter -> 400');

  r = await request('/areas/abc');
  assert.equal(r.status, 400);
  r = await request('/areas/999999');
  assert.equal(r.status, 404);
  pass('invalid id -> 400, missing -> 404');

  r = await request('/areas', { method: 'POST', headers: json, body: '{}' });
  assert.equal(r.status, 401);
  pass('create without key -> 401');

  r = await send('POST', '/areas', { name: ' ', latitude: 99 });
  assertInvalid(r, ['name', 'latitude', 'city']);
  r = await send('POST', '/areas', { name: 'X', city: 'Y', latitude: 1, longitude: 1, colour: 'red' });
  assertInvalid(r, ['colour']);
  pass('area validation errors and unknown fields -> 400');

  const area = { name: 'Api Check Area', city: 'Test City', latitude: 10.7, longitude: 122.5 };
  r = await send('POST', '/areas', area);
  assert.equal(r.status, 201);
  areaId = r.body.data.id;
  pass('create area -> 201');

  r = await send('POST', '/areas', { ...area, name: 'api check AREA' });
  assert.equal(r.status, 409);
  pass('duplicate (case-insensitive) -> 409');

  r = await send('PATCH', `/areas/${areaId}`, { latitude: 11 });
  assert.equal(r.status, 200);
  assert.equal(r.body.data.latitude, 11);
  r = await send('PATCH', `/areas/${areaId}`, {});
  assert.equal(r.status, 400);
  pass('partial update; empty update -> 400');

  // ---------- Request body handling ----------
  r = await send('POST', '/interruptions', '{"title": ');
  assert.equal(r.status, 400);
  assert.equal(r.body.error.code, 'INVALID_JSON');
  pass('malformed JSON -> 400 INVALID_JSON');

  r = await request('/interruptions', {
    method: 'POST',
    headers: { 'content-type': 'text/plain', 'x-api-key': 'test-key' },
    body: 'title=hello',
  });
  assert.equal(r.status, 415);
  assert.equal(r.body.error.code, 'UNSUPPORTED_MEDIA_TYPE');
  pass('non-JSON body -> 415');

  r = await send('POST', '/interruptions', `{"title": "${'x'.repeat(200_000)}"}`);
  assert.equal(r.status, 413);
  pass('oversized body -> 413');

  r = await send('POST', '/interruptions', [1, 2]);
  assertInvalid(r, []);
  pass('array body -> 400');

  r = await request('/nope');
  assert.equal(r.status, 404);
  assert.deepEqual(Object.keys(r.body), ['success', 'error']);
  pass('unknown route -> 404 with the error shape');

  let res = await fetch(`${root}/areas`, { headers: { origin: 'http://localhost:51428' } });
  assert.equal(res.headers.get('access-control-allow-origin'), '*');
  res = await fetch(`${root}/interruptions`, {
    method: 'OPTIONS',
    headers: {
      origin: 'http://localhost:51428',
      'access-control-request-method': 'POST',
      'access-control-request-headers': 'content-type, x-api-key',
    },
  });
  assert.equal(res.status, 204);
  assert.match(res.headers.get('access-control-allow-headers'), /x-api-key/);
  pass('CORS headers and preflight for the Flutter web build');

  // ---------- Interruptions: reads ----------
  r = await request('/interruptions');
  assert.equal(r.status, 200);
  assert.equal(r.body.count, r.body.data.length);
  const before = r.body.count;
  const sample = r.body.data[0];
  assert.ok(sample, 'seed data should include an interruption');
  assert.ok(Array.isArray(sample.affected_areas) && sample.start_time && sample.status);
  pass('list interruptions');

  r = await request(`/interruptions/${sample.id}`);
  assert.equal(r.status, 200);
  assert.equal(r.body.data.id, sample.id);
  r = await request('/interruptions/999999');
  assert.equal(r.status, 404);
  r = await request('/interruptions/abc');
  assert.equal(r.status, 400);
  r = await request('/interruptions?area_id=abc');
  assert.equal(r.status, 400);
  r = await request('/interruptions?area_id=1&area_id=2');
  assert.equal(r.status, 400);
  pass('interruption by id; missing -> 404; bad or repeated id -> 400');

  // ---------- Interruptions: validation ----------
  r = await request('/interruptions', { method: 'POST', headers: json, body: {} });
  assert.equal(r.status, 401);
  pass('create interruption without key -> 401');

  r = await send('POST', '/interruptions', {});
  assertInvalid(r, ['title', 'date', 'start_time', 'end_time', 'area_ids']);
  pass('missing required fields -> 400, each one listed');

  const valid = {
    title: 'Api Check Interruption',
    date: '2026-11-03',
    start_time: '08:00',
    end_time: '12:00',
    area_ids: [areaId],
  };

  r = await send('POST', '/interruptions', { ...valid, date: '2026-02-30', start_time: '25:00', end_time: '9:00' });
  assertInvalid(r, ['date', 'start_time', 'end_time']);
  r = await send('POST', '/interruptions', { ...valid, date: '03/11/2026' });
  assertInvalid(r, ['date']);
  pass('impossible dates and badly formatted times -> 400');

  r = await send('POST', '/interruptions', { ...valid, start_time: '12:00', end_time: '08:00' });
  assertInvalid(r, ['end_time']);
  r = await send('POST', '/interruptions', { ...valid, end_time: '08:00' });
  assertInvalid(r, ['end_time']);
  r = await send('POST', '/interruptions', { ...valid, estimated_restoration: '07:00' });
  assertInvalid(r, ['estimated_restoration']);
  pass('end before start, zero length, restoration before start -> 400');

  r = await send('POST', '/interruptions', { ...valid, area_ids: [] });
  assertInvalid(r, ['area_ids']);
  r = await send('POST', '/interruptions', { ...valid, area_ids: [areaId, areaId] });
  assertInvalid(r, ['area_ids']);
  r = await send('POST', '/interruptions', { ...valid, area_ids: ['1'] });
  assertInvalid(r, ['area_ids']);
  r = await send('POST', '/interruptions', { ...valid, area_ids: [999999] });
  assertInvalid(r, ['area_ids']);
  pass('empty, repeated, non-numeric and unknown area ids -> 400');

  const jaro = (await request('/areas?search=jaro')).body.data[0];
  const jaroFeeder = (await request(`/areas/${jaro.id}`)).body.data.feeders[0];
  assert.ok(jaroFeeder, 'seed data should include a Jaro feeder');
  r = await send('POST', '/interruptions', { ...valid, feeder_ids: [jaroFeeder.id] });
  assertInvalid(r, ['feeder_ids']);
  r = await send('POST', '/interruptions', { ...valid, feeder_ids: [999999] });
  assertInvalid(r, ['feeder_ids']);
  pass('unknown feeder, or feeder outside the affected areas -> 400');

  r = await send('POST', '/interruptions', { ...valid, title: '   ', status: 'done', reason: 5 });
  assertInvalid(r, ['title', 'status', 'reason']);
  r = await send('POST', '/interruptions', { ...valid, title: 'x'.repeat(121) });
  assertInvalid(r, ['title']);
  pass('blank title, bad status, wrong type, too long -> 400');

  r = await send('POST', '/interruptions', { ...valid, id: 5, startTime: '08:00', colour: 'red' });
  assertInvalid(r, ['id', 'startTime', 'colour']);
  assert.match(r.body.error.details.startTime, /start_time/);
  pass('read-only, camelCase and unknown fields -> 400 with a hint');

  assert.equal((await request('/interruptions')).body.count, before);
  pass('rejected requests stored nothing');

  // ---------- Interruptions: writes ----------
  r = await send('POST', '/interruptions', { ...valid, title: '  Api   Check Interruption ', description: null });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  interruptionId = r.body.data.id;
  assert.equal(r.body.data.title, 'Api Check Interruption');
  assert.equal(r.body.data.description, '');
  assert.equal(r.body.data.status, 'scheduled');
  assert.equal(r.body.data.estimated_restoration, null);
  assert.deepEqual(r.body.data.area_ids, [areaId]);
  assert.equal((await request('/interruptions')).body.count, before + 1);
  pass('create interruption -> 201 with defaults and cleaned text');

  r = await send('PATCH', `/interruptions/${interruptionId}`, { start_time: '13:00' });
  assertInvalid(r, ['end_time']);
  r = await send('PATCH', `/interruptions/${interruptionId}`, { end_time: '07:00' });
  assertInvalid(r, ['end_time']);
  pass('partial update is checked against the stored times');

  r = await send('PATCH', `/interruptions/${interruptionId}`, { title: null });
  assertInvalid(r, ['title']);
  r = await send('PATCH', `/interruptions/${interruptionId}`, {});
  assertInvalid(r, ['body']);
  pass('null required field and empty update -> 400');

  r = await send('PATCH', `/interruptions/${interruptionId}`, {
    status: 'ongoing',
    end_time: '15:30',
    estimated_restoration: '15:00',
  });
  assert.equal(r.status, 200, JSON.stringify(r.body));
  assert.equal(r.body.data.status, 'ongoing');
  assert.equal(r.body.data.start_time, '08:00');
  assert.equal(r.body.data.end_time, '15:30');
  assert.equal(r.body.data.title, 'Api Check Interruption');
  pass('partial update changes only the fields sent');

  r = await send('PATCH', '/interruptions/999999', { status: 'ongoing' });
  assert.equal(r.status, 404);
  r = await send('DELETE', '/interruptions/999999');
  assert.equal(r.status, 404);
  pass('update or delete a missing interruption -> 404');
} finally {
  if (interruptionId) {
    const r = await send('DELETE', `/interruptions/${interruptionId}`);
    assert.equal(r.status, 204);
    assert.equal((await request(`/interruptions/${interruptionId}`)).status, 404);
    pass('delete interruption -> 204, then 404');
  }
  if (areaId) {
    const r = await send('DELETE', `/areas/${areaId}`);
    assert.equal(r.status, 204);
    assert.equal((await request(`/areas/${areaId}`)).status, 404);
    pass('delete area -> 204, then 404');
  }
  server.close();
  process.exit(process.exitCode ?? 0);
}
