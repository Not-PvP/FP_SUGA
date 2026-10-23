import express from 'express';
import { areasRouter } from './routes/areas.js';
import { authRouter } from './routes/auth.js';
import { interruptionsRouter } from './routes/interruptions.js';
import { cors } from './middleware/cors.js';
import { errorHandler, notFound, requireJsonBody } from './middleware/errors.js';

export function createApp() {
  const app = express();
  app.use(cors);
  app.use(requireJsonBody);
  app.use(express.json({ limit: '100kb' }));

  app.get('/api/health', (_req, res) => res.json({ success: true, data: { status: 'ok' } }));
  app.use('/api/auth', authRouter);
  app.use('/api/areas', areasRouter);
  app.use('/api/interruptions', interruptionsRouter);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
