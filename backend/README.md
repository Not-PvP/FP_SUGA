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
| `CORS_ORIGIN` | Origins allowed to call the API from a browser (the Flutter web build), comma separated. Unset or `*` allows any origin. |

`.env` is ignored by git, so the token never reaches the public repository.

## Scripts

| Command | What it does |
| --- | --- |
| `npm run db:migrate` | Creates any missing tables. Safe to run again. |
| `npm run db:seed` | Adds starting data. Safe to run again; existing rows are skipped. |
| `npm run db:reset` | Drops every table, recreates them and reseeds. **Deletes all data.** |
| `npm start` | Starts the API (`npm run dev` restarts on file changes). |
| `npm run test:api` | Checks the area and interruption endpoints, including validation and error responses, against the real database. Uses a temporary test area and interruption. |
| `npm run db:verify` | Runs create, read, update and delete checks using temporary test rows. |

## API responses

Every response is JSON with the same shape, so the app can check `success` first.

```jsonc
// One item
{ "success": true, "data": { ... } }

// A list
{ "success": true, "count": 2, "data": [ ... ] }

// An error: `details` lists each invalid field when there is one
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid power interruption data",
    "details": { "end_time": "end_time (08:00) must be later than start_time (12:00) on the same date" }
  }
}
```

`DELETE` returns `204 No Content` with no body.

### Status codes and error codes

| Status | `error.code` | When |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | A field is missing, has the wrong type or format, is out of range, or the body is not a JSON object. See `details`. |
| 400 | `INVALID_JSON` | The body could not be parsed as JSON. |
| 400 | `INVALID_ID` | An id in the path or in `?area_id=` is not a positive integer. |
| 400 | `INVALID_QUERY` | A query parameter is unknown (e.g. `?areaId=` instead of `?area_id=`) or was sent more than once. `details` names the parameter. |
| 400 | `INVALID_REFERENCE`, `INVALID_DATA` | The database rejected a write that got past validation. Nothing was saved. |
| 401 | `UNAUTHORIZED` | The `x-api-key` header is missing or wrong on an admin route. |
| 404 | `NOT_FOUND`, `AREA_NOT_FOUND`, `INTERRUPTION_NOT_FOUND` | The route or record does not exist. |
| 409 | `DUPLICATE_AREA`, `CONFLICT` | An area with the same name already exists in that city (ignoring case). |
| 413 | `PAYLOAD_TOO_LARGE` | The body is over 100 KB. |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | A body was sent without `Content-Type: application/json`. |
| 500 | `INTERNAL_ERROR` | Unexpected server error. Details are logged on the server, not sent to the app. |
| 503 | `ADMIN_DISABLED` | `ADMIN_API_KEY` is not set on the server. |

Admin routes need the header `x-api-key: <ADMIN_API_KEY>`. Requests with a body need `Content-Type: application/json`.

List routes only accept the query parameters listed below. Anything else returns `400 INVALID_QUERY`, so a typo never silently returns the unfiltered list.

## Area API

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/api/areas` | none | List areas. Optional `?search=` (name or city, partial) and `?city=` (exact). |
| GET | `/api/areas/:id` | none | One area, with its feeders. |
| POST | `/api/areas` | admin | Create an area. Returns 201. |
| PATCH | `/api/areas/:id` | admin | Change any of the fields below. Only the fields sent are changed. |
| DELETE | `/api/areas/:id` | admin | Delete the area, its feeders and interruption links. Returns 204. |

| Field | Type | Rules |
| --- | --- | --- |
| `name` | string | Required. 1 to 100 characters. Extra spaces are removed. |
| `city` | string | Required. 1 to 100 characters. Extra spaces are removed. |
| `latitude` | number | Required. -90 to 90. |
| `longitude` | number | Required. -180 to 180. |

Any other field is rejected.

## Interruption API

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/api/interruptions` | none | List interruptions, soonest first. Optional `?area_id=` for one area. |
| GET | `/api/interruptions/:id` | none | One interruption, with its affected areas and feeders. |
| POST | `/api/interruptions` | admin | Create an interruption. Returns 201 with the saved item. |
| PATCH | `/api/interruptions/:id` | admin | Change any writable field. Only the fields sent are changed. |
| DELETE | `/api/interruptions/:id` | admin | Delete the interruption and its links. Returns 204. |

Requests use the same snake_case keys that responses return.

| Field | Type | Rules |
| --- | --- | --- |
| `title` | string | Required. 1 to 120 characters. Extra spaces are removed. |
| `date` | string | Required. A real calendar date, `YYYY-MM-DD` (so `2026-02-30` is rejected). |
| `start_time` | string | Required. 24-hour `HH:MM`, e.g. `08:00`. |
| `end_time` | string | Required. 24-hour `HH:MM`, later than `start_time` on the same date. |
| `area_ids` | integer[] | Required. 1 to 50 existing area ids, no repeats. |
| `feeder_ids` | integer[] | Optional, default `[]`. Existing feeder ids, no repeats, each in one of `area_ids`. |
| `description` | string or null | Optional, default `""`. Up to 1000 characters. |
| `reason` | string or null | Optional, default `""`. Up to 200 characters. |
| `status` | string | Optional, default `scheduled`. One of `scheduled`, `ongoing`, `restored`, `cancelled`. |
| `estimated_restoration` | string or null | Optional. 24-hour `HH:MM`, not before `start_time`. |

- Server fields (`id`, `affected_areas`, `feeders`, `created_at`, `updated_at`) and unknown fields are rejected. camelCase keys such as `startTime` are rejected with a hint to use `start_time`.
- On `PATCH`, the time rules are checked against the stored values for any time field you leave out. Sending `area_ids` or `feeder_ids` replaces the existing links.
- Every problem is reported at once in `error.details`, and nothing is saved unless the whole request is valid.

Example request:

```http
POST /api/interruptions
Content-Type: application/json
x-api-key: <ADMIN_API_KEY>

{
  "title": "Jaro Power Interruption",
  "date": "2026-10-12",
  "start_time": "09:00",
  "end_time": "14:00",
  "area_ids": [3],
  "feeder_ids": [4, 5],
  "reason": "Scheduled Maintenance",
  "estimated_restoration": "14:00"
}
```

Each item in a response uses snake_case keys: `id`, `title`, `description`, `affected_areas`, `area_ids`, `feeders`, `feeder_ids`, `date`, `start_time`, `end_time`, `reason`, `status`, `estimated_restoration`, `created_at`, `updated_at`. See the full example at the end of this file.

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
    ├── routes/                 area and interruption endpoints
    ├── middleware/             admin key check, JSON body check, success and error responses
    ├── validation/             request checks for areas and interruptions
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
