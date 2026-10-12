import { Router } from 'express';
import * as interruptions from '../repositories/interruptionRepository.js';
import { HttpError } from '../middleware/errors.js';

export const interruptionsRouter = Router();

function parsePositiveInt(raw, field) {
  if (!/^[1-9]\d*$/.test(raw)) {
    throw new HttpError(400, 'INVALID_ID', `${field} must be a positive integer`);
  }
  return Number(raw);
}

// GET /api/interruptions?area_id=3
interruptionsRouter.get('/', async (req, res) => {
  const areaId =
    typeof req.query.area_id === 'string' ? parsePositiveInt(req.query.area_id, 'area_id') : undefined;
  const list = await interruptions.findAllInterruptions({ areaId });
  res.status(200).json({ success: true, count: list.length, data: list });
});

// GET /api/interruptions/:id
interruptionsRouter.get('/:id', async (req, res) => {
  const item = await interruptions.findInterruptionById(parsePositiveInt(req.params.id, 'Interruption id'));
  if (!item) throw new HttpError(404, 'INTERRUPTION_NOT_FOUND', 'Interruption not found');
  res.status(200).json({ success: true, data: item });
});
