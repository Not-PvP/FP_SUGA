import 'dotenv/config';
import { createClient } from '@libsql/client';

const url = process.env.DATABASE_URL;

if (!url) {
  throw new Error(
    'DATABASE_URL is not set. Copy backend/.env.example to backend/.env first.',
  );
}

// Works with a local SQLite file (file:...) and with Turso (libsql://...).
export const db = createClient({
  url,
  authToken: process.env.DATABASE_AUTH_TOKEN || undefined,
});

// SQLite does not enforce foreign keys unless this is turned on.
await db.execute('PRAGMA foreign_keys = ON');
