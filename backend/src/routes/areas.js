import { Router } from 'express';
import * as areas from '../repositories/areaRepository.js';
import { requireAdmin } from '../middleware/adminAuth.js';
import { HttpError } from '../middleware/errors.js';
import { parseId, validateAreaInput } from '../validation/areaValidation.js';

export const areasRouter = Router();

const ok = (res, data, status = 200) => res.status(status).json({ success: true, data });

function queryText(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

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
    search: queryText(req.query.search),
    city: queryText(req.query.city),
  });
  res.status(200).json({ success: true, count: list.length, data: list });
});

// GET /api/areas/:id  (includes the area's feeders)
areasRouter.get('/:id', async (req, res) => {
  const area = await areas.findAreaById(parseId(req.params.id));
  if (!area) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  ok(res, area);
});

// POST /api/areas  (admin)
areasRouter.post('/', requireAdmin, async (req, res) => {
  const data = validateAreaInput(req.body);
  await assertNotDuplicate(data.name, data.city);
  ok(res, await areas.createArea(data), 201);
});

// PATCH /api/areas/:id  (admin) - only the fields sent are changed
areasRouter.patch('/:id', requireAdmin, async (req, res) => {
  const id = parseId(req.params.id);
  const changes = validateAreaInput(req.body, { partial: true });
  const current = await areas.findAreaById(id);
  if (!current) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  await assertNotDuplicate(changes.name ?? current.name, changes.city ?? current.city, id);
  ok(res, await areas.updateArea(id, changes));
});

// DELETE /api/areas/:id  (admin)
areasRouter.delete('/:id', requireAdmin, async (req, res) => {
  const deleted = await areas.deleteArea(parseId(req.params.id));
  if (!deleted) throw new HttpError(404, 'AREA_NOT_FOUND', 'Area not found');
  res.status(204).end();
});
