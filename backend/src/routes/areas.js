import { Router } from 'express';
import * as areas from '../repositories/areaRepository.js';
import { requireAdmin } from '../middleware/adminAuth.js';
import { HttpError } from '../middleware/errors.js';
import { sendItem, sendList } from '../middleware/respond.js';
import { validateAreaInput } from '../validation/areaValidation.js';
import { parseId as parseIdAs, queryValue } from '../validation/common.js';

export const areasRouter = Router();

const parseId = (raw) => parseIdAs(raw, 'Area id');

// Rejects a name + city pair that another area already uses (ignoring case).
async function assertNotDuplicate(name, city, ignoreId) {
  const existing = await areas.findAreaByNameAndCity(name, city);
  if (existing && existing.id !== ignoreId) {
    throw new HttpError(409, 'DUPLICATE_AREA', `Area "${name}" already exists in ${city}`);
  }
}

// GET /api/areas?search=jaro&city=Iloilo City
areasRouter.get('/', async (req, res) => {
  const list = await areas.findAllAreas({
    search: queryValue(req.query, 'search'),
    city: queryValue(req.query, 'city'),
  });
  sendList(res, list);
});

// GET /api/areas/:id  (includes the area's feeders)
areasRouter.get('/:id', async (req, res) => {
  const area = await areas.findAreaById(parseId(req.params.id));
  if (!area) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  sendItem(res, area);
});

// POST /api/areas  (admin)
areasRouter.post('/', requireAdmin, async (req, res) => {
  const data = validateAreaInput(req.body);
  await assertNotDuplicate(data.name, data.city);
  sendItem(res, await areas.createArea(data), 201);
});

// PATCH /api/areas/:id  (admin) - only the fields sent are changed
areasRouter.patch('/:id', requireAdmin, async (req, res) => {
  const id = parseId(req.params.id);
  const changes = validateAreaInput(req.body, { partial: true });
  const current = await areas.findAreaById(id);
  if (!current) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  await assertNotDuplicate(changes.name ?? current.name, changes.city ?? current.city, id);
  sendItem(res, await areas.updateArea(id, changes));
});

// DELETE /api/areas/:id  (admin)
areasRouter.delete('/:id', requireAdmin, async (req, res) => {
  const deleted = await areas.deleteArea(parseId(req.params.id));
  if (!deleted) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  res.status(204).end();
});
