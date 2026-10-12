// Lets the Flutter web build (served on another port, e.g. localhost:51428) call this API.
// Browsers block cross-origin requests unless the server sends these headers.
// CORS_ORIGIN can list allowed origins, comma separated. Unset or "*" allows any origin,
// which is safe here because admin access uses the x-api-key header, not cookies.
export function cors(req, res, next) {
  const allowed = (process.env.CORS_ORIGIN ?? '*').split(',').map((o) => o.trim()).filter(Boolean);
  const origin = req.get('origin');

  if (allowed.includes('*')) {
    res.set('Access-Control-Allow-Origin', '*');
  } else if (origin && allowed.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
    res.vary('Origin');
  }
  res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, x-api-key');
  res.set('Access-Control-Max-Age', '600');

  // Browsers send a preflight OPTIONS request before POST/PATCH/DELETE with JSON or x-api-key.
  if (req.method === 'OPTIONS') return res.status(204).end();
  next();
}
