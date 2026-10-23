import { HttpError } from '../middleware/errors.js';
import { requireObject } from './common.js';

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const MAX_EMAIL = 254;
const MAX_PASSWORD = 200;

// POST /api/auth/login body: { email, password }.
// Only the format is checked here. Whether the pair is right is checked against the database.
export function validateLoginInput(body) {
  requireObject(body);
  const errors = {};

  for (const key of Object.keys(body)) {
    if (key !== 'email' && key !== 'password') errors[key] = 'Unknown field';
  }

  const email = typeof body.email === 'string' ? body.email.trim() : body.email;
  if (typeof email !== 'string' || email.length === 0) {
    errors.email = 'email is required';
  } else if (email.length > MAX_EMAIL || !EMAIL.test(email)) {
    errors.email = 'email must be a valid email address';
  }

  // The password is not trimmed: spaces can be part of it.
  const { password } = body;
  if (typeof password !== 'string' || password.length === 0) {
    errors.password = 'password is required';
  } else if (password.length > MAX_PASSWORD) {
    errors.password = `password must be at most ${MAX_PASSWORD} characters`;
  }

  if (Object.keys(errors).length > 0) {
    throw new HttpError(400, 'VALIDATION_ERROR', 'Invalid login data', errors);
  }
  return { email: email.toLowerCase(), password };
}
