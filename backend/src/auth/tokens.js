import { createHash, randomBytes } from 'node:crypto';

// 32 random bytes: long enough that a token cannot be guessed.
export function generateToken() {
  return randomBytes(32).toString('base64url');
}

// The database stores only this hash. The app keeps the real token.
export function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

// How long a login lasts. Set ADMIN_SESSION_HOURS in .env to change it.
export function sessionLengthMs() {
  const hours = Number(process.env.ADMIN_SESSION_HOURS);
  return (Number.isFinite(hours) && hours > 0 ? hours : 12) * 60 * 60 * 1000;
}
