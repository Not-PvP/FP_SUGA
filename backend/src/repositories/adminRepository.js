import { db } from '../db/client.js';

// The public shape of an admin. The password hash never leaves this file.
function toAdmin(row) {
  return {
    id: Number(row.id),
    email: row.email,
    name: row.name,
  };
}

export async function findAdminByEmail(email) {
  const result = await db.execute({
    sql: 'SELECT * FROM admins WHERE email = ? COLLATE NOCASE',
    args: [email],
  });
  const row = result.rows[0];
  return row ? { ...toAdmin(row), passwordHash: row.password_hash } : null;
}

// Creates the admin, or changes the password (and the name, if given) when the email
// already exists. Changing the password signs the admin out everywhere.
export async function saveAdmin({ email, name, passwordHash }) {
  const existing = await findAdminByEmail(email);
  if (existing) {
    const newName = name || existing.name;
    await db.batch(
      [
        { sql: 'UPDATE admins SET password_hash = ?, name = ? WHERE id = ?', args: [passwordHash, newName, existing.id] },
        { sql: 'DELETE FROM admin_sessions WHERE admin_id = ?', args: [existing.id] },
      ],
      'write',
    );
    return { admin: { ...toAdmin(existing), name: newName }, created: false };
  }
  const result = await db.execute({
    sql: 'INSERT INTO admins (email, name, password_hash) VALUES (?, ?, ?) RETURNING *',
    args: [email, name ?? '', passwordHash],
  });
  return { admin: toAdmin(result.rows[0]), created: true };
}

export async function deleteAdmin(id) {
  const result = await db.execute({ sql: 'DELETE FROM admins WHERE id = ?', args: [id] });
  return result.rowsAffected > 0;
}

export async function createSession({ adminId, tokenHash, expiresAt }) {
  await db.execute({
    sql: 'INSERT INTO admin_sessions (admin_id, token_hash, expires_at) VALUES (?, ?, ?)',
    args: [adminId, tokenHash, expiresAt],
  });
}

// Returns { admin, expiresAt } for a token hash, or null if there is no such session.
export async function findSession(tokenHash) {
  const result = await db.execute({
    sql: `SELECT s.expires_at, a.id, a.email, a.name
          FROM admin_sessions s JOIN admins a ON a.id = s.admin_id
          WHERE s.token_hash = ?`,
    args: [tokenHash],
  });
  const row = result.rows[0];
  return row ? { admin: toAdmin(row), expiresAt: row.expires_at } : null;
}

export async function deleteSession(tokenHash) {
  const result = await db.execute({
    sql: 'DELETE FROM admin_sessions WHERE token_hash = ?',
    args: [tokenHash],
  });
  return result.rowsAffected > 0;
}

// expires_at is ISO 8601 in UTC, so comparing the text compares the times.
export async function deleteExpiredSessions(now = new Date()) {
  await db.execute({
    sql: 'DELETE FROM admin_sessions WHERE expires_at <= ?',
    args: [now.toISOString()],
  });
}
