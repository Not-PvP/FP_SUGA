import { Router } from 'express';
import { burnPasswordCheck, verifyPassword } from '../auth/password.js';
import { generateToken, hashToken, sessionLengthMs } from '../auth/tokens.js';
import { requireAdminSession } from '../middleware/adminAuth.js';
import { HttpError } from '../middleware/errors.js';
import { assertNotLimited, clearFailures, recordFailure } from '../middleware/loginLimiter.js';
import { sendItem } from '../middleware/respond.js';
import * as admins from '../repositories/adminRepository.js';
import { validateLoginInput } from '../validation/authValidation.js';

export const authRouter = Router();

// The same message for a wrong email and a wrong password, so the API
// does not reveal which emails belong to an admin.
const invalidCredentials = () =>
  new HttpError(401, 'INVALID_CREDENTIALS', 'Incorrect email or password');

// POST /api/auth/login  { email, password }
// Returns a token for "Authorization: Bearer <token>" and when it expires.
authRouter.post('/login', async (req, res) => {
  const { email, password } = validateLoginInput(req.body);
  assertNotLimited(req, email);

  const admin = await admins.findAdminByEmail(email);
  const valid = admin
    ? await verifyPassword(password, admin.passwordHash)
    : (await burnPasswordCheck(password), false);

  if (!valid) {
    recordFailure(req, email);
    throw invalidCredentials();
  }
  clearFailures(req, email);

  await admins.deleteExpiredSessions();
  const token = generateToken();
  const expiresAt = new Date(Date.now() + sessionLengthMs()).toISOString();
  await admins.createSession({ adminId: admin.id, tokenHash: hashToken(token), expiresAt });

  sendItem(res, {
    token,
    token_type: 'Bearer',
    expires_at: expiresAt,
    admin: { id: admin.id, email: admin.email, name: admin.name },
  });
});

// GET /api/auth/me  - checks that a saved token still works.
authRouter.get('/me', requireAdminSession, (req, res) => {
  sendItem(res, { admin: req.admin, expires_at: req.session.expiresAt });
});

// POST /api/auth/logout  - ends this session. The token stops working at once.
authRouter.post('/logout', requireAdminSession, async (req, res) => {
  await admins.deleteSession(req.session.tokenHash);
  res.status(204).end();
});
