import express from 'express';
import { areasRouter } from './routes/areas.js';
import { interruptionsRouter } from './routes/interruptions.js';
import { errorHandler, notFound } from './middleware/errors.js';

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get('/api/health', (_req, res) => res.json({ success: true, data: { status: 'ok' } }));
  app.use('/api/areas', areasRouter);
  app.use('/api/interruptions', interruptionsRouter);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
