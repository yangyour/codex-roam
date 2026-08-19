import http from 'node:http';
import { spawn } from 'node:child_process';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { readFile, stat, writeFile } from 'node:fs/promises';
import { existsSync, watch } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';

const root = dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 4174);
const host = process.env.HOST || '0.0.0.0';
const tokenFile = join(root, '.codex-console-token');
let token = process.env.CODEX_CONSOLE_TOKEN;
if (!token) {
  token = await readFile(tokenFile, 'utf8').then(value => value.trim()).catch(() => '');
  if (!token) {
    token = randomBytes(18).toString('base64url');
    await writeFile(tokenFile, `${token}\n`, { mode: 0o600 });
  }
}
const clientToken = token;
const clients = new Set();
const pendingRequests = new Map();
const loadedThreads = new Set();
let rpcId = 1;
let codex;
let ready;
let lastError = null;
let sessionsWatcher;
const rolloutTimers = new Map();

function log(...args) { console.log('[codex-roam]', ...args); }

function locateCodex() {
  if (process.env.CODEX_BIN) return process.env.CODEX_BIN;
  const candidates = [
    join(process.env.LOCALAPPDATA || '', 'OpenAI', 'Codex', 'bin', 'e305f1c75d8da435', 'codex.exe'),
    join(process.env.LOCALAPPDATA || '', 'OpenAI', 'Codex', 'bin', 'codex.exe'),
    'codex'
  ];
  return candidates.find(existsSync) || 'codex';
}

function sendRaw(message) {
  if (!codex?.stdin?.writable) throw new Error('Codex app-server is not running');
  codex.stdin.write(`${JSON.stringify(message)}\n`);
}

function call(method, params = {}) {
  const id = rpcId++;
  return new Promise((resolve, reject) => {
    pendingRequests.set(id, { resolve, reject, method });
    try { sendRaw({ jsonrpc: '2.0', id, method, params }); }
    catch (error) { pendingRequests.delete(id); reject(error); }
  });
}

function broadcast(message) {
  const payload = `data: ${JSON.stringify(message)}\n\n`;
  for (const res of clients) {
    try { res.write(payload); } catch { clients.delete(res); }
  }
}

function handleCodexMessage(message) {
  if (message.id != null && pendingRequests.has(message.id)) {
    const pending = pendingRequests.get(message.id);
    pendingRequests.delete(message.id);
    if (message.error) pending.reject(new Error(message.error.message || 'Codex request failed'));
    else pending.resolve(message.result);
    return;
  }
  if (message.method && message.id != null) {
    pendingRequests.set(`server:${message.id}`, { serverRequest: true, method: message.method });
    broadcast({ type: 'approval', method: message.method, id: message.id, params: message.params || {} });
    return;
  }
  if (message.method) broadcast({ type: 'notification', method: message.method, params: message.params || {} });
}

function startCodex() {
  const bin = locateCodex();
  log(`starting app-server via ${bin}`);
  codex = spawn(bin, ['app-server', '--listen', 'stdio://'], { cwd: process.cwd(), windowsHide: true });
  let buffer = '';
  codex.stdout.setEncoding('utf8');
  codex.stdout.on('data', chunk => {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.trim()) continue;
      try { handleCodexMessage(JSON.parse(line)); }
      catch (error) { log('invalid app-server message', error.message); }
    }
  });
  codex.stderr.setEncoding('utf8');
  codex.stderr.on('data', chunk => { log(chunk.toString().trim()); });
  codex.on('exit', (code, signal) => {
    lastError = `Codex app-server exited (${code ?? signal})`;
    broadcast({ type: 'server', status: 'offline', error: lastError });
  });
  ready = call('initialize', {
    clientInfo: { name: 'codex-roam', title: 'CodexRoam', version: '1.0.0' },
    capabilities: { experimentalApi: true, requestAttestation: false }
  }).then(async result => {
    sendRaw({ jsonrpc: '2.0', method: 'initialized' });
    broadcast({ type: 'server', status: 'online', userAgent: result?.userAgent });
  });
  ready.catch(error => { lastError = error.message; log(error.message); });
}

function startSessionWatcher() {
  const sessionsDir = join(process.env.CODEX_HOME || join(os.homedir(), '.codex'), 'sessions');
  if (!existsSync(sessionsDir)) return;
  sessionsWatcher = watch(sessionsDir, { recursive: true }, (_event, filename) => {
    const match = filename?.toString().match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$/i);
    const threadId = match?.[1];
    if (!threadId) return;
    clearTimeout(rolloutTimers.get(threadId));
    rolloutTimers.set(threadId, setTimeout(() => {
      rolloutTimers.delete(threadId);
      broadcast({ type: 'rollout', threadId });
    }, 100));
  });
  sessionsWatcher.on('error', error => log('session watcher error', error.message));
}

function authorized(req) {
  const supplied = req.headers['x-codex-token'] || new URL(req.url, `http://${req.headers.host}`).searchParams.get('token');
  if (typeof supplied !== 'string' || supplied.length !== clientToken.length) return false;
  return timingSafeEqual(Buffer.from(supplied), Buffer.from(clientToken));
}

function localNetworkOnly(req) {
  const address = (req.socket.remoteAddress || '').replace(/^::ffff:/, '');
  if (address === '::1' || address === 'localhost' || address.startsWith('fc') || address.startsWith('fd') || address.startsWith('fe80:')) return true;
  const octets = address.split('.').map(Number);
  if (octets.length !== 4 || octets.some(Number.isNaN)) return false;
  return octets[0] === 127 || octets[0] === 10 || (octets[0] === 192 && octets[1] === 168) || (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31);
}

async function body(req) {
  let data = '';
  for await (const chunk of req) data += chunk;
  return data ? JSON.parse(data) : {};
}

function json(res, status, payload) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'access-control-allow-origin': '*' });
  res.end(JSON.stringify(payload));
}

function contentType(pathname) {
  if (pathname.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (pathname.endsWith('.css')) return 'text/css; charset=utf-8';
  if (pathname.endsWith('.svg')) return 'image/svg+xml';
  if (pathname.endsWith('.png')) return 'image/png';
  if (pathname.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}

async function decorateThread(thread) {
  if (!thread) return thread;
  let recentlyActive = false;
  if (thread.path) {
    const info = await stat(thread.path).catch(() => null);
    recentlyActive = Boolean(info && Date.now() - info.mtimeMs < 20_000);
  }
  const lockPath = join(process.env.CODEX_HOME || join(os.homedir(), '.codex'), 'thread-writer-locks', `${thread.id}.lock`);
  const desktopOpen = existsSync(lockPath);
  return { ...thread, desktopOpen, status: recentlyActive ? { type: 'active', activeFlags: [], source: 'rollout' } : thread.status };
}

async function api(req, res, pathname) {
  if (!authorized(req)) return json(res, 401, { error: 'Invalid or missing access token' });
  try {
    await ready;
    if (pathname === '/api/health') return json(res, 200, { ok: true, status: codex?.exitCode == null ? 'online' : 'offline', hostname: os.hostname(), platform: process.platform, error: lastError });
    if (pathname === '/api/threads' && req.method === 'GET') {
      const result = await call('thread/list', { limit: 100, sortKey: 'updated_at', sortDirection: 'desc', archived: false, useStateDbOnly: true });
      result.data = await Promise.all((result.data || []).map(decorateThread));
      return json(res, 200, result);
    }
    const threadMatch = pathname.match(/^\/api\/threads\/([^/]+)$/);
    if (threadMatch && req.method === 'GET') {
      const result = await call('thread/read', { threadId: threadMatch[1], includeTurns: true });
      result.thread = await decorateThread(result.thread);
      return json(res, 200, result);
    }
    const archiveMatch = pathname.match(/^\/api\/threads\/([^/]+)\/archive$/);
    if (archiveMatch && req.method === 'POST') return json(res, 200, await call('thread/archive', { threadId: archiveMatch[1] }));
    if (pathname === '/api/threads' && req.method === 'POST') {
      const input = await body(req);
      const result = await call('thread/start', { cwd: input.cwd || process.cwd(), approvalPolicy: input.approvalPolicy || 'on-request', sandbox: input.sandbox || 'workspace-write', model: input.model || null, historyMode: 'legacy', sessionStartSource: 'startup' });
      if (result?.thread?.id) loadedThreads.add(result.thread.id);
      return json(res, 200, result);
    }
    const turnMatch = pathname.match(/^\/api\/threads\/([^/]+)\/turns$/);
    if (turnMatch && req.method === 'POST') {
      const input = await body(req);
      if (!loadedThreads.has(turnMatch[1])) {
        await call('thread/resume', { threadId: turnMatch[1], excludeTurns: true, approvalPolicy: 'on-request', sandbox: 'workspace-write' });
        loadedThreads.add(turnMatch[1]);
      }
      const result = await call('turn/start', { threadId: turnMatch[1], input: [{ type: 'text', text: input.text || '', text_elements: [] }], effort: input.effort || null, summary: 'concise' });
      return json(res, 200, result);
    }
    const interruptMatch = pathname.match(/^\/api\/threads\/([^/]+)\/turns\/([^/]+)\/interrupt$/);
    if (interruptMatch && req.method === 'POST') return json(res, 200, await call('turn/interrupt', { threadId: interruptMatch[1], turnId: interruptMatch[2] }));
    if (pathname === '/api/approval' && req.method === 'POST') {
      const input = await body(req);
      const key = `server:${input.id}`;
      if (!pendingRequests.has(key)) return json(res, 404, { error: 'Approval request expired' });
      pendingRequests.delete(key);
      sendRaw({ jsonrpc: '2.0', id: input.id, result: input.decision === 'accept' ? { decision: 'accept' } : { decision: 'decline' } });
      return json(res, 200, { ok: true });
    }
    return json(res, 404, { error: 'Not found' });
  } catch (error) { return json(res, 500, { error: error.message }); }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if ((url.pathname.startsWith('/api/') || url.pathname === '/events' || url.pathname === '/config') && !localNetworkOnly(req)) return json(res, 403, { error: 'LAN access only' });
  if (url.pathname === '/events') {
    if (!authorized(req)) return json(res, 401, { error: 'Invalid or missing access token' });
    req.socket.setNoDelay(true);
    res.writeHead(200, {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache, no-transform',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
      'access-control-allow-origin': '*'
    });
    res.flushHeaders();
    res.write(`data: ${JSON.stringify({ type: 'server', status: codex?.exitCode == null ? 'online' : 'offline' })}\n\n`);
    const heartbeat = setInterval(() => res.write(': keep-alive\n\n'), 15_000);
    clients.add(res);
    req.on('close', () => { clearInterval(heartbeat); clients.delete(res); });
    return;
  }
  if (url.pathname.startsWith('/api/')) return api(req, res, url.pathname);
  if (url.pathname === '/config') return authorized(req) ? json(res, 200, { token, port, host }) : json(res, 401, { error: 'Invalid or missing access token' });
  if (url.pathname === '/' || url.pathname === '/index.html') {
    const html = await readFile(join(root, 'dist', 'index.html')).catch(() => null);
    if (html) { res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); res.end(html); return; }
  }
  if (/^\/assets\/[A-Za-z0-9._-]+$/.test(url.pathname)) {
    const file = join(root, 'dist', url.pathname.slice(1));
    try { const data = await readFile(file); res.writeHead(200, { 'content-type': contentType(file), 'cache-control': 'public, max-age=31536000, immutable' }); res.end(data); return; }
    catch { /* fall through to 404 */ }
  }
  res.writeHead(404); res.end('Not found');
});

startCodex();
startSessionWatcher();
server.listen(port, host, () => {
  const ips = Object.values(os.networkInterfaces()).flat().filter(x => x?.family === 'IPv4' && !x.internal).map(x => x.address).sort((a, b) => Number(b.startsWith('192.168.')) - Number(a.startsWith('192.168.')));
  log(`listening on http://127.0.0.1:${port}`);
  log(`phone access: ${ips.map(ip => `http://${ip}:${port}/?token=${token}`).join(' | ') || 'no LAN IPv4 found'}`);
  console.log(`CODEX_CONSOLE_URL=http://${ips[0] || '127.0.0.1'}:${port}/?token=${token}`);
});

process.on('SIGINT', () => {
  sessionsWatcher?.close();
  for (const timer of rolloutTimers.values()) clearTimeout(timer);
  codex?.kill();
  server.close(() => process.exit(0));
});
