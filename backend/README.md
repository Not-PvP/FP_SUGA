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
| `PORT` | API port. Defaults to 3000. |
| `ADMIN_API_KEY` | Secret for admin routes, sent as the `x-api-key` header. If unset, admin routes return 503. |

`.env` is ignored by git, so the token never reaches the public repository.

## Scripts

| Command | What it does |
| --- | --- |
| `npm run db:migrate` | Creates any missing tables. Safe to run again. |
| `npm run db:seed` | Adds starting data. Safe to run again; existing rows are skipped. |
| `npm run db:reset` | Drops every table, recreates them and reseeds. **Deletes all data.** |
| `npm start` | Starts the API (`npm run dev` restarts on file changes). |
| `npm run test:api` | Checks the area endpoints against the real database, using a temporary test area. |
| `npm run db:verify` | Runs create, read, update and delete checks using temporary test rows. |

## Area API

Success: `{ "success": true, "data": ... }` (the list also has `count`). Error: `{ "success": false, "error": { "code", "message", "details?" } }`.

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/api/areas` | none | List areas. Optional `?search=` (name or city, partial) and `?city=` (exact). |
| GET | `/api/areas/:id` | none | One area, with its feeders. |
| POST | `/api/areas` | admin | Create. Body: `name`, `city`, `latitude`, `longitude`. Returns 201. |
| PATCH | `/api/areas/:id` | admin | Update any of those fields. |
| DELETE | `/api/areas/:id` | admin | Delete the area, its feeders and interruption links. Returns 204. |

Status codes: 400 invalid input or id, 401 missing or wrong key, 404 not found, 409 duplicate name in the same city (ignoring case), 503 admin key not configured.

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
    ├── app.js, index.js        Express app and server start
    ├── routes/                 area endpoints
    ├── middleware/             admin key check, error responses
    ├── validation/             area input checks
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
