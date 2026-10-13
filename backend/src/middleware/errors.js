export class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function notFound(_req, _res, next) {
  next(new HttpError(404, 'NOT_FOUND', 'Route not found'));
}

// POST, PUT and PATCH bodies must be JSON. Without this check, a form or plain-text
// body is skipped by express.json() and would reach validation as an empty request.
export function requireJsonBody(req, _res, next) {
  const hasBody = req.get('content-length') > 0 || req.get('transfer-encoding') !== undefined;
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && hasBody && !req.is('application/json')) {
    return next(new HttpError(415, 'UNSUPPORTED_MEDIA_TYPE', 'Send the request body as JSON with Content-Type: application/json'));
  }
  next();
}

// Errors thrown by express.json() while reading the body.
const BODY_ERRORS = {
  'entity.parse.failed': [400, 'INVALID_JSON', 'Request body is not valid JSON'],
  'entity.too.large': [413, 'PAYLOAD_TOO_LARGE', 'Request body is too large'],
  'encoding.unsupported': [415, 'UNSUPPORTED_MEDIA_TYPE', 'Request body encoding is not supported'],
  'charset.unsupported': [415, 'UNSUPPORTED_MEDIA_TYPE', 'Request body charset is not supported'],
};

// Last line of defence: validation should catch bad data first, but if the database
// still rejects a write, answer with a clear 4xx instead of a 500.
function fromDatabaseError(err) {
  const text = `${err.code ?? ''} ${err.message ?? ''}`;
  if (!/SQLITE_CONSTRAINT/.test(text)) return null;
  if (/UNIQUE/.test(text)) return new HttpError(409, 'CONFLICT', 'A record with the same unique value already exists');
  if (/FOREIGN KEY/.test(text)) return new HttpError(400, 'INVALID_REFERENCE', 'A linked record does not exist');
  return new HttpError(400, 'INVALID_DATA', 'The data does not meet the database rules');
}

// Every error leaves as { success: false, error: { code, message, details? } }.
export function errorHandler(err, _req, res, _next) {
  let httpError = err instanceof HttpError ? err : null;
  if (!httpError && BODY_ERRORS[err.type]) httpError = new HttpError(...BODY_ERRORS[err.type]);
  if (!httpError) httpError = fromDatabaseError(err);

  if (!httpError) {
    console.error(err);
    httpError = new HttpError(500, 'INTERNAL_ERROR', 'Something went wrong');
  }
  const error = { code: httpError.code, message: httpError.message };
  if (httpError.details) error.details = httpError.details;
  res.status(httpError.status).json({ success: false, error });
}
