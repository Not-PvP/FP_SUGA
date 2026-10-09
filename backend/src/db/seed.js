// Fills the database with starting data. Safe to run more than once:
// existing areas and feeders are skipped, and sample advisories are only
// added when the power_interruptions table is empty.
import { db } from './client.js';
import { AREAS, FEEDERS, INTERRUPTIONS } from './seed-data.js';
import { createInterruption } from '../repositories/interruptionRepository.js';

await db.batch(
  AREAS.map((area) => ({
    sql: `INSERT OR IGNORE INTO areas (name, city, latitude, longitude) VALUES (?, ?, ?, ?)`,
    args: [area.name, area.city, area.latitude, area.longitude],
  })),
  'write',
);

const areaIds = new Map(
  (await db.execute('SELECT id, name FROM areas')).rows.map((r) => [r.name, Number(r.id)]),
);

await db.batch(
  FEEDERS.map((feeder) => ({
    sql: 'INSERT OR IGNORE INTO feeders (area_id, name) VALUES (?, ?)',
    args: [areaIds.get(feeder.area), feeder.name],
  })),
  'write',
);

const feederIds = new Map(
  (await db.execute('SELECT id, name FROM feeders')).rows.map((r) => [r.name, Number(r.id)]),
);

const { rows } = await db.execute('SELECT COUNT(*) AS count FROM power_interruptions');
if (Number(rows[0].count) === 0) {
  for (const item of INTERRUPTIONS) {
    await createInterruption({
      ...item,
      areaIds: item.areas.map((name) => areaIds.get(name)),
      feederIds: item.feeders.map((name) => feederIds.get(name)),
    });
  }
  console.log(`Added ${INTERRUPTIONS.length} sample power interruptions.`);
} else {
  console.log('Power interruptions already exist, skipped sample advisories.');
}

console.log(`Seeded ${areaIds.size} areas and ${feederIds.size} feeders.`);
