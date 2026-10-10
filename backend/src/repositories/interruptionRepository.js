import { db } from '../db/client.js';

export const STATUSES = ['scheduled', 'ongoing', 'restored', 'cancelled'];

// Collects the affected areas and feeders into JSON lists, so each row is one interruption.
const SELECT_INTERRUPTIONS = `
  SELECT pi.*,
    (SELECT json_group_array(json_object('id', a.id, 'label', a.name || ', ' || a.city))
       FROM interruption_areas ia JOIN areas a ON a.id = ia.area_id
      WHERE ia.interruption_id = pi.id) AS areas_json,
    (SELECT json_group_array(json_object('id', f.id, 'label', f.name))
       FROM interruption_feeders inf JOIN feeders f ON f.id = inf.feeder_id
      WHERE inf.interruption_id = pi.id) AS feeders_json
  FROM power_interruptions pi`;

// Shapes a database row into the JSON the Flutter app expects (snake_case keys).
// Names are plain strings for display; the *_ids lists are for the admin edit form.
function toInterruption(row) {
  const areaList = JSON.parse(row.areas_json);
  const feederList = JSON.parse(row.feeders_json);
  return {
    id: Number(row.id),
    title: row.title,
    description: row.description,
    affected_areas: areaList.map((a) => a.label),
    area_ids: areaList.map((a) => a.id),
    feeders: feederList.map((f) => f.label),
    feeder_ids: feederList.map((f) => f.id),
    date: row.date,
    start_time: row.start_time,
    end_time: row.end_time,
    reason: row.reason,
    status: row.status,
    estimated_restoration: row.estimated_restoration,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

export async function findAllInterruptions({ areaId } = {}) {
  const result = areaId
    ? await db.execute({
        sql: `${SELECT_INTERRUPTIONS}
              WHERE pi.id IN (SELECT interruption_id FROM interruption_areas WHERE area_id = ?)
              ORDER BY pi.date, pi.start_time`,
        args: [areaId],
      })
    : await db.execute(`${SELECT_INTERRUPTIONS} ORDER BY pi.date, pi.start_time`);
  return result.rows.map(toInterruption);
}

export async function findInterruptionById(id) {
  const result = await db.execute({
    sql: `${SELECT_INTERRUPTIONS} WHERE pi.id = ?`,
    args: [id],
  });
  return result.rows.length ? toInterruption(result.rows[0]) : null;
}

// Replaces the area and feeder links of one interruption inside a transaction.
async function setLinks(tx, interruptionId, areaIds, feederIds) {
  if (areaIds) {
    await tx.execute({ sql: 'DELETE FROM interruption_areas WHERE interruption_id = ?', args: [interruptionId] });
    for (const areaId of areaIds) {
      await tx.execute({
        sql: 'INSERT INTO interruption_areas (interruption_id, area_id) VALUES (?, ?)',
        args: [interruptionId, areaId],
      });
    }
  }
  if (feederIds) {
    await tx.execute({ sql: 'DELETE FROM interruption_feeders WHERE interruption_id = ?', args: [interruptionId] });
    for (const feederId of feederIds) {
      await tx.execute({
        sql: 'INSERT INTO interruption_feeders (interruption_id, feeder_id) VALUES (?, ?)',
        args: [interruptionId, feederId],
      });
    }
  }
}

// The interruption and its links are saved together, or not at all.
export async function createInterruption(data) {
  const tx = await db.transaction('write');
  try {
    const result = await tx.execute({
      sql: `INSERT INTO power_interruptions
              (title, description, date, start_time, end_time, reason, status, estimated_restoration)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`,
      args: [
        data.title,
        data.description ?? '',
        data.date,
        data.startTime,
        data.endTime,
        data.reason ?? '',
        data.status ?? 'scheduled',
        data.estimatedRestoration ?? null,
      ],
    });
    const id = Number(result.rows[0].id);
    await setLinks(tx, id, data.areaIds ?? [], data.feederIds ?? []);
    await tx.commit();
    return findInterruptionById(id);
  } catch (error) {
    await tx.rollback();
    throw error;
  } finally {
    tx.close();
  }
}

// Only the fields that are passed in get changed. Passing areaIds or
// feederIds replaces the existing links.
export async function updateInterruption(id, changes) {
  const columns = {
    title: 'title',
    description: 'description',
    date: 'date',
    startTime: 'start_time',
    endTime: 'end_time',
    reason: 'reason',
    status: 'status',
    estimatedRestoration: 'estimated_restoration',
  };
  const keys = Object.keys(columns).filter((key) => changes[key] !== undefined);

  const tx = await db.transaction('write');
  try {
    const exists = await tx.execute({ sql: 'SELECT id FROM power_interruptions WHERE id = ?', args: [id] });
    if (exists.rows.length === 0) {
      await tx.rollback();
      return null;
    }
    if (keys.length > 0) {
      await tx.execute({
        sql: `UPDATE power_interruptions SET ${keys.map((k) => `${columns[k]} = ?`).join(', ')}
              WHERE id = ?`,
        args: [...keys.map((k) => changes[k]), id],
      });
    }
    await setLinks(tx, id, changes.areaIds, changes.feederIds);
    await tx.commit();
  } catch (error) {
    await tx.rollback();
    throw error;
  } finally {
    tx.close();
  }
  return findInterruptionById(id);
}

// Links in the join tables are removed automatically (ON DELETE CASCADE).
export async function deleteInterruption(id) {
  const result = await db.execute({ sql: 'DELETE FROM power_interruptions WHERE id = ?', args: [id] });
  return result.rowsAffected > 0;
}
