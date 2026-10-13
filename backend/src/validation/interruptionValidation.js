import { HttpError } from '../middleware/errors.js';
import { STATUSES } from '../repositories/interruptionRepository.js';
import { findAreaIds, findFeedersByIds } from '../repositories/areaRepository.js';
import { cleanText, requireObject } from './common.js';

const LIMITS = { title: 120, description: 1000, reason: 200 };
const MAX_LINKS = 50;
const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

// Request keys (snake_case, the same keys the API returns) -> repository keys.
const WRITABLE = {
  title: 'title',
  description: 'description',
  date: 'date',
  start_time: 'startTime',
  end_time: 'endTime',
  reason: 'reason',
  status: 'status',
  estimated_restoration: 'estimatedRestoration',
  area_ids: 'areaIds',
  feeder_ids: 'feederIds',
};
const REQUIRED = ['title', 'date', 'start_time', 'end_time', 'area_ids'];
const READ_ONLY = ['id', 'affected_areas', 'feeders', 'created_at', 'updated_at'];
// Common mistakes, e.g. sending the Flutter model's toJson() keys.
const RENAMED = {
  startTime: 'start_time',
  endTime: 'end_time',
  estimatedRestoration: 'estimated_restoration',
  estimatedRestorationTime: 'estimated_restoration',
  areaIds: 'area_ids',
  affectedAreas: 'area_ids',
  feederIds: 'feeder_ids',
};

function isRealDate(value) {
  const match = DATE.exec(value);
  if (!match) return false;
  const [year, month, day] = match.slice(1).map(Number);
  const d = new Date(Date.UTC(year, month - 1, day));
  return year >= 2000 && year <= 2100 && d.getUTCMonth() === month - 1 && d.getUTCDate() === day;
}

function checkText(field, value, { required }) {
  if (value === null && !required) return { value: '' };
  if (typeof value !== 'string') return { error: `${field} must be a string` };
  const cleaned = field === 'description' ? value.trim() : cleanText(value);
  if (required && cleaned.length === 0) return { error: `${field} must not be empty` };
  if (cleaned.length > LIMITS[field]) return { error: `${field} must be at most ${LIMITS[field]} characters` };
  return { value: cleaned };
}

function checkIdList(field, value, { allowEmpty }) {
  if (!Array.isArray(value)) return { error: `${field} must be an array of ids` };
  if (!allowEmpty && value.length === 0) return { error: `${field} must list at least one id` };
  if (value.length > MAX_LINKS) return { error: `${field} can list at most ${MAX_LINKS} ids` };
  if (!value.every((id) => Number.isSafeInteger(id) && id > 0)) {
    return { error: `${field} must contain positive integer ids only` };
  }
  if (new Set(value).size !== value.length) return { error: `${field} must not repeat an id` };
  return { value };
}

function checkField(field, value) {
  switch (field) {
    case 'title':
      return checkText(field, value, { required: true });
    case 'description':
    case 'reason':
      return checkText(field, value, { required: false });
    case 'date':
      return typeof value === 'string' && isRealDate(value)
        ? { value }
        : { error: 'date must be a real calendar date in YYYY-MM-DD format' };
    case 'start_time':
    case 'end_time':
      return typeof value === 'string' && TIME.test(value)
        ? { value }
        : { error: `${field} must be a 24-hour time in HH:MM format` };
    case 'estimated_restoration':
      if (value === null) return { value: null };
      return typeof value === 'string' && TIME.test(value)
        ? { value }
        : { error: 'estimated_restoration must be null or a 24-hour time in HH:MM format' };
    case 'status':
      return STATUSES.includes(value) ? { value } : { error: `status must be one of: ${STATUSES.join(', ')}` };
    case 'area_ids':
      return checkIdList(field, value, { allowEmpty: false });
    case 'feeder_ids':
      return checkIdList(field, value, { allowEmpty: true });
  }
}

// Checks the body of POST (current = undefined) or PATCH (current = the stored interruption).
// Returns the cleaned changes with repository keys, or throws a 400 listing every problem.
export function validateInterruptionInput(body, { current } = {}) {
  requireObject(body);
  const partial = current !== undefined;
  const errors = {};
  const data = {};

  for (const key of Object.keys(body)) {
    if (key in WRITABLE) continue;
    if (READ_ONLY.includes(key)) errors[key] = `${key} is set by the server and cannot be sent`;
    else if (key in RENAMED) errors[key] = `Unknown field. Use "${RENAMED[key]}" instead`;
    else errors[key] = 'Unknown field';
  }

  for (const [field, target] of Object.entries(WRITABLE)) {
    const value = body[field];
    if (value === undefined) {
      if (!partial && REQUIRED.includes(field)) errors[field] = `${field} is required`;
      continue;
    }
    if (value === null && REQUIRED.includes(field)) {
      errors[field] = `${field} is required and cannot be null`;
      continue;
    }
    const result = checkField(field, value);
    if (result.error) errors[field] = result.error;
    else data[target] = result.value;
  }

  if (partial && Object.keys(body).length === 0) {
    errors.body = `Provide at least one of: ${Object.keys(WRITABLE).join(', ')}`;
  }

  // Time ranges are checked against the stored values for any field PATCH leaves out.
  const start = data.startTime ?? current?.start_time;
  const end = data.endTime ?? current?.end_time;
  const restoration =
    data.estimatedRestoration !== undefined ? data.estimatedRestoration : current?.estimated_restoration;
  const timesTouched = ['start_time', 'end_time', 'estimated_restoration'].some((f) => body[f] !== undefined);
  const timesValid = !errors.start_time && !errors.end_time && !errors.estimated_restoration;

  if (timesTouched && timesValid && start && end) {
    if (end <= start) {
      errors.end_time = `end_time (${end}) must be later than start_time (${start}) on the same date`;
    }
    if (restoration && restoration < start) {
      errors.estimated_restoration = `estimated_restoration (${restoration}) cannot be before start_time (${start})`;
    }
  }

  if (Object.keys(errors).length > 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid power interruption data', errors);
  }
  return data;
}

// Every area and feeder id must exist, and each feeder must belong to one of the affected areas.
export async function assertLinksExist(areaIds, feederIds) {
  const errors = {};
  const knownAreas = new Set(await findAreaIds(areaIds));
  const missingAreas = areaIds.filter((id) => !knownAreas.has(id));
  if (missingAreas.length) errors.area_ids = `Unknown area id(s): ${missingAreas.join(', ')}`;

  if (feederIds.length > 0) {
    const feeders = new Map((await findFeedersByIds(feederIds)).map((f) => [f.id, f.areaId]));
    const missing = feederIds.filter((id) => !feeders.has(id));
    const outside = feederIds.filter((id) => feeders.has(id) && !areaIds.includes(feeders.get(id)));
    const problems = [];
    if (missing.length) problems.push(`Unknown feeder id(s): ${missing.join(', ')}`);
    if (outside.length) problems.push(`Feeder id(s) ${outside.join(', ')} are not in any of the affected areas`);
    if (problems.length) errors.feeder_ids = problems.join('. ');
  }

  if (Object.keys(errors).length > 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid power interruption data', errors);
  }
}
