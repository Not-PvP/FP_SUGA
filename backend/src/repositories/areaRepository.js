import { db } from '../db/client.js';

function toArea(row) {
  return {
    id: Number(row.id),
    name: row.name,
    city: row.city,
    latitude: row.latitude,
    longitude: row.longitude,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

function toFeeder(row) {
  return { id: Number(row.id), area_id: Number(row.area_id), name: row.name };
}

// `search` matches part of the name or city; `city` must match exactly. Both ignore case.
export async function findAllAreas({ search, city } = {}) {
  const where = [];
  const args = [];
  if (search) {
    where.push("(name LIKE ? ESCAPE '\\' OR city LIKE ? ESCAPE '\\')");
    const pattern = `%${search.replace(/[\\%_]/g, '\\$&')}%`;
    args.push(pattern, pattern);
  }
  if (city) {
    where.push('city = ? COLLATE NOCASE');
    args.push(city);
  }
  const clause = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const result = await db.execute({
    sql: `SELECT * FROM areas ${clause} ORDER BY name, city`,
    args,
  });
  return result.rows.map(toArea);
}

// Finds an area with the same name and city, ignoring case. Used to reject duplicates.
export async function findAreaByNameAndCity(name, city) {
  const result = await db.execute({
    sql: 'SELECT * FROM areas WHERE name = ? COLLATE NOCASE AND city = ? COLLATE NOCASE',
    args: [name, city],
  });
  return result.rows.length ? toArea(result.rows[0]) : null;
}

// Returns the area with its feeders, or null if it does not exist.
export async function findAreaById(id) {
  const [areaResult, feederResult] = await db.batch(
    [
      { sql: 'SELECT * FROM areas WHERE id = ?', args: [id] },
      { sql: 'SELECT * FROM feeders WHERE area_id = ? ORDER BY name', args: [id] },
    ],
    'read',
  );
  if (areaResult.rows.length === 0) return null;
  return { ...toArea(areaResult.rows[0]), feeders: feederResult.rows.map(toFeeder) };
}

export async function createArea({ name, city, latitude, longitude }) {
  const result = await db.execute({
    sql: `INSERT INTO areas (name, city, latitude, longitude)
          VALUES (?, ?, ?, ?) RETURNING *`,
    args: [name, city, latitude, longitude],
  });
  return toArea(result.rows[0]);
}

// Only the fields that are passed in get changed.
export async function updateArea(id, changes) {
  const allowed = ['name', 'city', 'latitude', 'longitude'];
  const fields = allowed.filter((key) => changes[key] !== undefined);
  if (fields.length === 0) return findAreaById(id);

  const result = await db.execute({
    sql: `UPDATE areas SET ${fields.map((f) => `${f} = ?`).join(', ')} WHERE id = ?`,
    args: [...fields.map((f) => changes[f]), id],
  });
  // Read the row again so updated_at includes the trigger's change.
  return result.rowsAffected > 0 ? findAreaById(id) : null;
}

// Also deletes the area's feeders and its links to interruptions (ON DELETE CASCADE).
export async function deleteArea(id) {
  const result = await db.execute({ sql: 'DELETE FROM areas WHERE id = ?', args: [id] });
  return result.rowsAffected > 0;
}

export async function createFeeder({ areaId, name }) {
  const result = await db.execute({
    sql: 'INSERT INTO feeders (area_id, name) VALUES (?, ?) RETURNING *',
    args: [areaId, name],
  });
  return toFeeder(result.rows[0]);
}
