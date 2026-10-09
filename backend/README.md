# SUGA Backend

Database and data layer for the SUGA brownout notifier app.

- **Runtime:** Node.js 18 or newer
- **Database:** libSQL (SQLite). It runs as a local file during development and on [Turso](https://turso.tech) in production, with the same code.

## Setup

```bash
cd backend
npm install
cp .env.example .env        # Windows: copy .env.example .env
npm run db:migrate          # create the tables
npm run db:seed             # add areas, feeders and sample advisories
npm run db:verify           # check create, read, update and delete
```

## Environment variables

| Variable | Description |
| --- | --- |
| `DATABASE_URL` | `file:./data/suga.db` for local development, or `libsql://<name>.turso.io` for Turso |
| `DATABASE_AUTH_TOKEN` | Turso auth token. Leave empty for a local file. |

`.env` is ignored by git, so the token never reaches the public repository.

## Scripts

| Command | What it does |
| --- | --- |
| `npm run db:migrate` | Creates any missing tables. Safe to run again. |
| `npm run db:seed` | Adds starting data. Safe to run again; existing rows are skipped. |
| `npm run db:reset` | Drops every table, recreates them and reseeds. **Deletes all data.** |
| `npm run db:verify` | Runs create, read, update and delete checks using temporary test rows. |

## Schema

```
areas 1 ──< feeders
areas >──< power_interruptions   (through interruption_areas)
feeders >──< power_interruptions (through interruption_feeders)
```

| Table | Purpose |
| --- | --- |
| `areas` | Iloilo City districts, with coordinates for the weather lookup |
| `feeders` | Power lines that belong to an area |
| `power_interruptions` | Brownout advisories: date, time, reason, status, estimated restoration |
| `interruption_areas` | Which areas each interruption affects |
| `interruption_feeders` | Which feeders each interruption affects |

- `status` is limited to `scheduled`, `ongoing`, `restored` or `cancelled`.
- Every main table has `created_at` and `updated_at`; triggers refresh `updated_at` on each change.
- Deleting an area or interruption also removes its feeders and links (`ON DELETE CASCADE`).

## Seed data

- **Areas:** Iloilo City's seven districts (Arevalo, City Proper, Jaro, La Paz, Lapuz, Mandurriao, Molo). Coordinates are approximate district centers.
- **Feeders and advisories:** development samples only. Replace the feeder names in `src/db/seed-data.js` with names from official MORE Power advisories.

## Folder structure

```
backend/
├── data/                       local database file (ignored by git)
└── src/
    ├── db/
    │   ├── client.js           database connection
    │   ├── schema.sql          tables, indexes and triggers
    │   ├── migrate.js          creates the tables
    │   ├── seed-data.js        starting data
    │   ├── seed.js             inserts the starting data
    │   └── verify.js           CRUD checks
    └── repositories/
        ├── areaRepository.js           areas and feeders
        └── interruptionRepository.js   power interruptions
```

## Example interruption JSON

```json
{
  "id": 1,
  "title": "Jaro Power Interruption",
  "description": "Power will be interrupted in parts of Jaro District for scheduled line maintenance.",
  "affected_areas": ["Jaro, Iloilo City"],
  "area_ids": [3],
  "feeders": ["Jaro Feeder 1", "Jaro Feeder 2"],
  "feeder_ids": [4, 5],
  "date": "2026-10-12",
  "start_time": "09:00",
  "end_time": "14:00",
  "reason": "Scheduled Maintenance",
  "status": "scheduled",
  "estimated_restoration": "14:00",
  "created_at": "2026-10-09 13:41:03",
  "updated_at": "2026-10-09 13:41:03"
}
```
