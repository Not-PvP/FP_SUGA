import { HttpError } from '../middleware/errors.js';

// Path ids and id query values must be plain positive integers ("12", not "12abc" or "-1").
export function parseId(raw, label) {
  // isSafeInteger also rejects 16-digit values too big to store exactly in a JS number.
  if (typeof raw !== 'string' || !/^[1-9]\d{0,15}$/.test(raw) || !Number.isSafeInteger(Number(raw))) {
    throw new HttpError(400, 'INVALID_ID', `${label} must be a positive integer`);
  }
  return Number(raw);
}

// Rejects query parameters a route does not use. Without this, a typo such as
// ?areaId=3 is ignored and the app silently gets the unfiltered list.
// `renamed` maps common mistakes to the right name, e.g. { areaId: 'area_id' }.
export function allowOnlyQuery(query, allowed, renamed = {}) {
  const details = {};
  for (const key of Object.keys(query)) {
    if (allowed.includes(key)) continue;
    details[key] = key in renamed ? `Unknown query parameter. Use "${renamed[key]}" instead` : 'Unknown query parameter';
  }
  if (Object.keys(details).length > 0) {
    const accepted = allowed.length ? `Accepted: ${allowed.join(', ')}` : 'This route takes no query parameters';
    throw new HttpError(400, 'INVALID_QUERY', `Unknown query parameter. ${accepted}`, details);
  }
}

// Reads one query parameter. Sending it twice (?city=a&city=b) is rejected
// instead of silently using one of the values. Blank values count as missing.
export function queryValue(query, name) {
  const value = query[name];
  if (value === undefined) return undefined;
  if (typeof value !== 'string') {
    throw new HttpError(400, 'INVALID_QUERY', `Query parameter "${name}" must be sent once, as plain text`);
  }
  const trimmed = value.trim();
  return trimmed === '' ? undefined : trimmed;
}

export function requireObject(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Request body must be a JSON object');
  }
}

// Collapses runs of spaces so " Jaro   Feeder " and "Jaro Feeder" are the same value.
export function cleanText(value) {
  return typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value;
}
