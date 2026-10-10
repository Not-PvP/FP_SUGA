// Checks that the backend can create, read, update and delete data.
// Uses its own test rows and removes them at the end, so seeded data is untouched.
import assert from 'node:assert/strict';
import { db } from './client.js';
import * as areas from '../repositories/areaRepository.js';
import * as interruptions from '../repositories/interruptionRepository.js';

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let testArea;
let interruptionId;

function pass(message) {
  console.log(`  ✓ ${message}`);
}

try {
  console.log('Areas');
  testArea = await areas.createArea({ name: 'Verify Test Area', city: 'Test City', latitude: 10.7, longitude: 122.5 });
  assert.ok(testArea.id, 'area should get an id');
  pass('create area');

  const feeder = await areas.createFeeder({ areaId: testArea.id, name: 'Verify Test Feeder' });
  const loadedArea = await areas.findAreaById(testArea.id);
  assert.equal(loadedArea.feeders.length, 1);
  pass('read area with its feeders');

  await wait(1100); // timestamps have one-second precision
  const renamed = await areas.updateArea(testArea.id, { name: 'Verify Test Area Renamed' });
  assert.equal(renamed.name, 'Verify Test Area Renamed');
  assert.notEqual(renamed.updated_at, testArea.created_at, 'updated_at should change');
  pass('update area (updated_at refreshed)');

  console.log('Power interruptions');
  const created = await interruptions.createInterruption({
    title: 'Verify Test Interruption',
    date: '2026-12-01',
    startTime: '09:00',
    endTime: '12:00',
    reason: 'Testing',
    areaIds: [testArea.id],
    feederIds: [feeder.id],
  });
  interruptionId = created.id;
  assert.equal(created.status, 'scheduled', 'status defaults to scheduled');
  assert.deepEqual(created.area_ids, [testArea.id]);
  assert.deepEqual(created.feeder_ids, [feeder.id]);
  pass('create interruption linked to an area and a feeder');

  const forArea = await interruptions.findAllInterruptions({ areaId: testArea.id });
  assert.equal(forArea.length, 1);
  pass('read interruptions filtered by area');

  const updated = await interruptions.updateInterruption(interruptionId, { status: 'ongoing', feederIds: [] });
  assert.equal(updated.status, 'ongoing');
  assert.equal(updated.feeders.length, 0);
  pass('update interruption status and replace feeder links');

  await assert.rejects(
    interruptions.updateInterruption(interruptionId, { status: 'not-a-status' }),
    'invalid status should be rejected',
  );
  pass('invalid status is rejected');

  await assert.rejects(
    interruptions.createInterruption({ title: 'Bad link', date: '2026-12-01', startTime: '09:00', endTime: '10:00', areaIds: [999999] }),
    'unknown area id should be rejected',
  );
  const leftover = await db.execute("SELECT COUNT(*) AS n FROM power_interruptions WHERE title = 'Bad link'");
  assert.equal(Number(leftover.rows[0].n), 0, 'failed create should roll back');
  pass('unknown area is rejected and the insert is rolled back');

  assert.equal(await interruptions.deleteInterruption(interruptionId), true);
  assert.equal(await interruptions.findInterruptionById(interruptionId), null);
  const links = await db.execute({ sql: 'SELECT COUNT(*) AS n FROM interruption_areas WHERE interruption_id = ?', args: [interruptionId] });
  assert.equal(Number(links.rows[0].n), 0);
  interruptionId = null;
  pass('delete interruption (links removed by cascade)');

  console.log('Cleanup');
  assert.equal(await areas.deleteArea(testArea.id), true);
  const feeders = await db.execute({ sql: 'SELECT COUNT(*) AS n FROM feeders WHERE area_id = ?', args: [testArea.id] });
  assert.equal(Number(feeders.rows[0].n), 0);
  testArea = null;
  pass('delete area (feeders removed by cascade)');

  console.log('\nAll database checks passed.');
} catch (error) {
  console.error('\nDatabase check failed:', error.message);
  process.exitCode = 1;
} finally {
  if (interruptionId) await interruptions.deleteInterruption(interruptionId);
  if (testArea) await areas.deleteArea(testArea.id);
}
