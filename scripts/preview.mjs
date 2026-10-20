import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const routes = new Map([
  ['/', [new URL('../prototype/index.html', import.meta.url), 'text/html; charset=utf-8']],
  ['/demo.json', [new URL('../demo/synthetic.json', import.meta.url), 'application/json; charset=utf-8']]
]);
const server = createServer(async (req, res) => {
  const route = routes.get(new URL(req.url, 'http://localhost').pathname);
  if (!route) { res.writeHead(404); res.end('Not found'); return; }
  try {
    const bytes = await readFile(route[0]);
    res.writeHead(200, { 'Content-Type': route[1], 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(bytes);
  } catch { res.writeHead(500); res.end('Preview files unavailable. Run npm run seed.'); }
});
server.listen(4310, '127.0.0.1', () => console.log('Local: http://127.0.0.1:4310 — synthetic review prototype'));
process.on('SIGINT', () => server.close(() => process.exit(0)));
