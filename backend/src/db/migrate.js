// Creates the tables from schema.sql.
// Usage: npm run db:migrate          (safe to run again)
//        npm run db:migrate -- --reset (drops all tables first, deletes data)
import { readFile } from 'node:fs/promises';
import { db } from './client.js';

// Child tables first, so dropping does not break foreign keys.
const TABLES = [
  'interruption_feeders',
  'interruption_areas',
  'power_interruptions',
  'feeders',
  'areas',
];

if (process.argv.includes('--reset')) {
  for (const table of TABLES) {
    await db.execute(`DROP TABLE IF EXISTS ${table}`);
  }
  console.log('Dropped existing tables.');
}

const schema = await readFile(new URL('./schema.sql', import.meta.url), 'utf8');
await db.executeMultiple(schema);
console.log('Database schema is up to date.');
