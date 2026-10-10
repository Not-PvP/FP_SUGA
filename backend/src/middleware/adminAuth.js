import { timingSafeEqual } from 'node:crypto';
import { HttpError } from './errors.js';

function safeEqual(a, b) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

// Admin routes need the header `x-api-key: <ADMIN_API_KEY>`.
// If ADMIN_API_KEY is not set, admin routes stay locked.
export function requireAdmin(req, _res, next) {
  const expected = process.env.ADMIN_API_KEY;
  if (!expected) {
    return next(new HttpError(503, 'ADMIN_DISABLED', 'Admin access is not configured on this server'));
  }
  const provided = req.get('x-api-key');
  if (!provided || !safeEqual(provided, expected)) {
    return next(new HttpError(401, 'UNAUTHORIZED', 'A valid x-api-key header is required'));
  }
  next();
}
