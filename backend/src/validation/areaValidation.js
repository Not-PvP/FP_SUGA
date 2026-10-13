import { HttpError } from '../middleware/errors.js';
import { cleanText, requireObject } from './common.js';

const MAX_TEXT = 100;
const FIELDS = ['name', 'city', 'latitude', 'longitude'];

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
  requireObject(body);
  const errors = {};
  const data = {};

  for (const key of Object.keys(body)) {
    if (!FIELDS.includes(key)) errors[key] = 'Unknown field';
  }

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

  if (partial && Object.keys(body).length === 0) {
    errors.body = 'Provide at least one of name, city, latitude, longitude';
  }
  if (Object.keys(errors).length > 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid area data', errors);
  }
  return data;
}
