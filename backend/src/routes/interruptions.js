import { Router } from 'express';
import * as interruptions from '../repositories/interruptionRepository.js';
import { requireAdmin } from '../middleware/adminAuth.js';
import { HttpError } from '../middleware/errors.js';
import { sendItem, sendList } from '../middleware/respond.js';
import { parseId, queryValue } from '../validation/common.js';
import { assertLinksExist, validateInterruptionInput } from '../validation/interruptionValidation.js';

export const interruptionsRouter = Router();

const parseInterruptionId = (raw) => parseId(raw, 'Interruption id');

async function findOr404(id) {
  const item = await interruptions.findInterruptionById(id);
  if (!item) throw new HttpError(404, 'INTERRUPTION_NOT_FOUND', 'Interruption not found');
  return item;
}

// GET /api/interruptions?area_id=3
interruptionsRouter.get('/', async (req, res) => {
  const rawAreaId = queryValue(req.query, 'area_id');
  const areaId = rawAreaId === undefined ? undefined : parseId(rawAreaId, 'area_id');
  sendList(res, await interruptions.findAllInterruptions({ areaId }));
});

// GET /api/interruptions/:id
interruptionsRouter.get('/:id', async (req, res) => {
  sendItem(res, await findOr404(parseInterruptionId(req.params.id)));
});

// POST /api/interruptions  (admin)
// Nothing is saved unless every field and every area/feeder link is valid.
interruptionsRouter.post('/', requireAdmin, async (req, res) => {
  const data = validateInterruptionInput(req.body);
  await assertLinksExist(data.areaIds, data.feederIds ?? []);
  sendItem(res, await interruptions.createInterruption(data), 201);
});

// PATCH /api/interruptions/:id  (admin) - only the fields sent are changed.
// Times are checked against the stored values for any time field left out.
interruptionsRouter.patch('/:id', requireAdmin, async (req, res) => {
  const id = parseInterruptionId(req.params.id);
  const current = await findOr404(id);
  const changes = validateInterruptionInput(req.body, { current });
  if (changes.areaIds || changes.feederIds) {
    await assertLinksExist(changes.areaIds ?? current.area_ids, changes.feederIds ?? current.feeder_ids);
  }
  const updated = await interruptions.updateInterruption(id, changes);
  if (!updated) throw new HttpError(404, 'INTERRUPTION_NOT_FOUND', 'Interruption not found');
  sendItem(res, updated);
});

// DELETE /api/interruptions/:id  (admin)
interruptionsRouter.delete('/:id', requireAdmin, async (req, res) => {
  const deleted = await interruptions.deleteInterruption(parseInterruptionId(req.params.id));
  if (!deleted) throw new HttpError(404, 'INTERRUPTION_NOT_FOUND', 'Interruption not found');
  res.status(204).end();
});
