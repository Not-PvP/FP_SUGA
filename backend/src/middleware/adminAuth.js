import { timingSafeEqual } from 'node:crypto';
import { hashToken } from '../auth/tokens.js';
import * as admins from '../repositories/adminRepository.js';
import { HttpError } from './errors.js';

function safeEqual(a, b) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

// Reads "Authorization: Bearer <token>". Returns undefined when the header is missing.
function bearerToken(req) {
  const header = req.get('authorization');
  if (header === undefined) return undefined;
  const match = /^Bearer\s+(\S+)\s*$/i.exec(header);
  if (!match) throw new HttpError(401, 'INVALID_TOKEN', 'Send the token as "Authorization: Bearer <token>"');
  return match[1];
}

// Looks up the session for a token. Expired sessions are deleted and rejected,
// so the app can tell "expired" (sign in again) apart from "never valid".
async function sessionFor(token) {
  const tokenHash = hashToken(token);
  const session = await admins.findSession(tokenHash);
  if (!session) {
    throw new HttpError(401, 'INVALID_TOKEN', 'Your session is no longer valid. Sign in again.');
  }
  if (Date.parse(session.expiresAt) <= Date.now()) {
    await admins.deleteSession(tokenHash);
    throw new HttpError(401, 'SESSION_EXPIRED', 'Your session has expired. Sign in again.');
  }
  return { ...session, tokenHash };
}

// Server scripts and the API checks can use the ADMIN_API_KEY instead of signing in.
function checkApiKey(provided) {
  const expected = process.env.ADMIN_API_KEY;
  if (!expected) {
    throw new HttpError(503, 'ADMIN_DISABLED', 'API key access is not configured on this server');
  }
  if (!safeEqual(provided, expected)) {
    throw new HttpError(401, 'UNAUTHORIZED', 'The x-api-key header is not valid');
  }
}

// Protects admin-only routes (create, update and delete).
// Accepts a signed-in admin's token, or the server's x-api-key.
// Sets req.admin when the request comes from a signed-in admin.
export async function requireAdmin(req, _res, next) {
  const token = bearerToken(req);
  if (token !== undefined) {
    const session = await sessionFor(token);
    req.admin = session.admin;
    req.session = session;
    return next();
  }

  const apiKey = req.get('x-api-key');
  if (apiKey !== undefined) {
    checkApiKey(apiKey);
    return next();
  }

  throw new HttpError(401, 'UNAUTHORIZED', 'Sign in as an admin to do this');
}

// For routes about the signed-in admin (who am I, sign out). The API key is not enough here.
export async function requireAdminSession(req, _res, next) {
  const token = bearerToken(req);
  if (token === undefined) throw new HttpError(401, 'UNAUTHORIZED', 'Sign in as an admin to do this');
  const session = await sessionFor(token);
  req.admin = session.admin;
  req.session = session;
  next();
}
