import { HttpError } from './errors.js';

// Slows down password guessing: after MAX_FAILURES wrong passwords for the same
// email from the same address, that pair is blocked until the window has passed.
// Counts live in memory, so they reset when the server restarts.
const MAX_FAILURES = 5;
const WINDOW_MS = 15 * 60 * 1000;
const MAX_TRACKED = 10_000;

const failures = new Map(); // key -> { count, firstAt }

const keyFor = (req, email) => `${req.ip}|${email}`;

function current(key, now) {
  const entry = failures.get(key);
  if (entry && now - entry.firstAt >= WINDOW_MS) {
    failures.delete(key);
    return undefined;
  }
  return entry;
}

export function assertNotLimited(req, email, now = Date.now()) {
  const entry = current(keyFor(req, email), now);
  if (entry && entry.count >= MAX_FAILURES) {
    const retryAfter = Math.ceil((entry.firstAt + WINDOW_MS - now) / 1000);
    const minutes = Math.ceil(retryAfter / 60);
    const error = new HttpError(
      429,
      'TOO_MANY_ATTEMPTS',
      `Too many failed sign-in attempts. Try again in ${minutes} minute${minutes === 1 ? '' : 's'}.`,
    );
    error.retryAfter = retryAfter;
    throw error;
  }
}

export function recordFailure(req, email, now = Date.now()) {
  const key = keyFor(req, email);
  const entry = current(key, now);
  if (entry) {
    entry.count += 1;
    return;
  }
  // Keep memory bounded if someone sprays many different emails.
  if (failures.size >= MAX_TRACKED) failures.delete(failures.keys().next().value);
  failures.set(key, { count: 1, firstAt: now });
}

export function clearFailures(req, email) {
  failures.delete(keyFor(req, email));
}
