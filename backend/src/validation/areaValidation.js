import { HttpError } from '../middleware/errors.js';

const MAX_TEXT = 100;

function cleanText(value) {
  return typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value;
}

function checkText(field, value, errors) {
  if (typeof value !== 'string' || value.length === 0) {
    errors[field] = `${field} is required and must be a non-empty string`;
  } else if (value.length > MAX_TEXT) {
    errors[field] = `${field} must be at most ${MAX_TEXT} characters`;
  }
}

function checkCoordinate(field, value, limit, errors) {
  if (typeof value !== 'number' || !Number.isFinite(value) || Math.abs(value) > limit) {
    errors[field] = `${field} must be a number between -${limit} and ${limit}`;
  }
}

// Returns cleaned fields. With partial = true, only the fields present are checked (for PATCH).
export function validateAreaInput(body, { partial = false } = {}) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Request body must be a JSON object');
  }
  const errors = {};
  const data = {};

  for (const field of ['name', 'city']) {
    if (partial && body[field] === undefined) continue;
    data[field] = cleanText(body[field]);
    checkText(field, data[field], errors);
  }
  for (const [field, limit] of [['latitude', 90], ['longitude', 180]]) {
    if (partial && body[field] === undefined) continue;
    data[field] = body[field];
    checkCoordinate(field, data[field], limit, errors);
  }

  if (partial && Object.keys(data).length === 0) {
    errors.body = 'Provide at least one of name, city, latitude, longitude';
  }
  if (Object.keys(errors).length > 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid area data', errors);
  }
  return data;
}

export function parseId(raw) {
  if (!/^[1-9]\d*$/.test(raw)) {
    throw new HttpError(400, 'INVALID_ID', 'Area id must be a positive integer');
  }
  return Number(raw);
}
