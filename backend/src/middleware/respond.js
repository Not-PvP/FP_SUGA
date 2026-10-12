// Every successful response has the same shape:
//   one item:  { success: true, data: {...} }
//   a list:    { success: true, count: n, data: [...] }
// Errors are shaped by errorHandler in errors.js.
export function sendItem(res, data, status = 200) {
  res.status(status).json({ success: true, data });
}

export function sendList(res, list) {
  res.status(200).json({ success: true, count: list.length, data: list });
}
