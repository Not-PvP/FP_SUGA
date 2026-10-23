// Creates an admin account, or resets its password if the email already exists.
// Usage:
//   npm run admin:create -- --email admin@suga.ph --password "a long password" --name "SUGA Admin"
// or set ADMIN_EMAIL, ADMIN_PASSWORD (and optionally ADMIN_NAME) in .env and run
//   npm run admin:create
// Resetting a password signs that admin out on every device.
import { parseArgs } from 'node:util';
import { MIN_PASSWORD_LENGTH, hashPassword } from '../auth/password.js';
import { saveAdmin } from '../repositories/adminRepository.js';

const { values } = parseArgs({
  options: {
    email: { type: 'string' },
    password: { type: 'string' },
    name: { type: 'string' },
  },
});

const email = (values.email ?? process.env.ADMIN_EMAIL ?? '').trim().toLowerCase();
const password = values.password ?? process.env.ADMIN_PASSWORD ?? '';
const name = (values.name ?? process.env.ADMIN_NAME ?? '').trim();

const problems = [];
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) problems.push('a valid --email (or ADMIN_EMAIL)');
if (password.length < MIN_PASSWORD_LENGTH) {
  problems.push(`a --password (or ADMIN_PASSWORD) of at least ${MIN_PASSWORD_LENGTH} characters`);
}
if (problems.length > 0) {
  console.error(`Cannot create the admin. Provide ${problems.join(' and ')}.`);
  process.exit(1);
}

const { admin, created } = await saveAdmin({ email, name, passwordHash: await hashPassword(password) });
console.log(created ? `Created admin ${admin.email}.` : `Updated the password for ${admin.email} and signed it out everywhere.`);
