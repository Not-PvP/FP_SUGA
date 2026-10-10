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

// Every error leaves as { success: false, error: { code, message, details? } }.
export function errorHandler(err, _req, res, _next) {
  if (err instanceof HttpError) {
    const error = { code: err.code, message: err.message };
    if (err.details) error.details = err.details;
    return res.status(err.status).json({ success: false, error });
  }
  if (err.type === 'entity.parse.failed') {
    return res
      .status(400)
      .json({ success: false, error: { code: 'INVALID_JSON', message: 'Request body is not valid JSON' } });
  }
  console.error(err);
  res
    .status(500)
    .json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Something went wrong' } });
}
