import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { Activity, ArrowLeft, Check, ChevronRight, CircleStop, Command, FileText, LoaderCircle, LockKeyhole, Menu, Plus, RefreshCw, Send, ShieldCheck, Smartphone, Terminal, X, Zap } from 'lucide-react';
import './styles.css';

const params = new URLSearchParams(location.search);
const tokenKey = 'codex-roam-token';
const token = params.get('token') || localStorage.getItem(tokenKey) || localStorage.getItem('codex-console-token') || '';
if (params.get('token')) localStorage.setItem(tokenKey, params.get('token'));

async function request(path, options = {}) {
  const response = await fetch(path, { ...options, headers: { 'content-type': 'application/json', 'x-codex-token': token, ...(options.headers || {}) } });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || '请求失败');
  return data;
}

function formatTime(value) { if (!value) return '刚刚'; return new Intl.DateTimeFormat('zh-CN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value * 1000)); }
function statusLabel(thread) { return thread?.status?.type === 'active' ? '运行中' : thread?.status?.type === 'systemError' ? '异常' : thread?.desktopOpen ? '桌面已打开' : '空闲'; }
function itemText(item) {
  if (item.type === 'userMessage') return item.content?.find(x => x.type === 'text')?.text || '';
  if (item.type === 'agentMessage' || item.type === 'plan') return item.text || '';
  if (item.type === 'commandExecution') return `$ ${item.command}\n${item.aggregatedOutput || ''}`;
  if (item.type === 'reasoning') return item.summary?.join('\n') || '';
  return '';
}

function App() {
  const [threads, setThreads] = useState([]); const [selectedId, setSelectedId] = useState(null); const [detail, setDetail] = useState(null);
  const [serverStatus, setServerStatus] = useState('connecting'); const [approval, setApproval] = useState(null); const [drawer, setDrawer] = useState(false); const [loading, setLoading] = useState(true); const [error, setError] = useState('');
  const [composer, setComposer] = useState(''); const [sending, setSending] = useState(false); const [newTask, setNewTask] = useState(false); const [cwd, setCwd] = useState('');
  const selected = useMemo(() => threads.find(x => x.id === selectedId) || detail?.thread, [threads, selectedId, detail]);
  const turns = detail?.thread?.turns || [];
  const runningTurn = [...turns].reverse().find(turn => turn.status === 'inProgress');

  async function loadThreads() { setLoading(true); try { const data = await request('/api/threads'); setThreads(data.data || []); if (!selectedId && data.data?.[0]) setSelectedId(data.data[0].id); setError(''); } catch (e) { setError(e.message); } finally { setLoading(false); } }
  async function loadDetail(id = selectedId) { if (!id) return; try { setDetail(await request(`/api/threads/${id}`)); } catch (e) { setError(e.message); } }
  useEffect(() => { if (!token) { setError('缺少访问令牌，请使用启动命令输出的手机地址'); setLoading(false); return; } loadThreads(); }, []);
  useEffect(() => { if (selectedId) loadDetail(selectedId); }, [selectedId]);
  useEffect(() => {
    if (!token) return; const source = new EventSource(`/events?token=${encodeURIComponent(token)}`);
    source.onopen = () => setServerStatus('online'); source.onerror = () => setServerStatus('offline');
    source.onmessage = event => { const message = JSON.parse(event.data); if (message.type === 'server') setServerStatus(message.status); if (message.type === 'approval') setApproval(message); if (message.type === 'notification') { if (message.method.startsWith('thread/') || message.method.startsWith('turn/')) { loadThreads(); loadDetail(); } } };
    return () => source.close();
  }, [selectedId]);
  useEffect(() => { if (!token) return; const timer = setInterval(() => { loadThreads(); loadDetail(); }, 5000); return () => clearInterval(timer); }, [selectedId]);
  async function sendTurn() { if (!composer.trim() || !selectedId || sending) return; setSending(true); try { await request(`/api/threads/${selectedId}/turns`, { method: 'POST', body: JSON.stringify({ text: composer.trim() }) }); setComposer(''); await loadDetail(); await loadThreads(); } catch (e) { setError(e.message); } finally { setSending(false); } }
  async function createThread(event) { event.preventDefault(); try { const data = await request('/api/threads', { method: 'POST', body: JSON.stringify({ cwd: cwd.trim() || undefined }) }); setNewTask(false); setCwd(''); setSelectedId(data.thread.id); await loadThreads(); } catch (e) { setError(e.message); } }
  async function approve(decision) { if (!approval) return; try { await request('/api/approval', { method: 'POST', body: JSON.stringify({ id: approval.id, decision }) }); setApproval(null); } catch (e) { setError(e.message); } }
  async function interruptTurn() { if (!runningTurn || !selectedId) return; try { await request(`/api/threads/${selectedId}/turns/${runningTurn.id}/interrupt`, { method: 'POST' }); await loadDetail(); } catch (e) { setError(e.message); } }
  const active = selected?.status?.type === 'active';

  return <div className="app-shell">
    <aside className={`sidebar ${drawer ? 'open' : ''}`}><div className="brand"><div className="brand-mark"><Command size={17}/></div><div><strong>CodexRoam</strong><span>REMOTE CONSOLE</span></div><button className="icon-button close-drawer" onClick={() => setDrawer(false)} aria-label="关闭侧栏"><X size={19}/></button></div>
      <div className="side-heading"><span>会话</span><button className="icon-button" onClick={() => setNewTask(true)} aria-label="新建会话"><Plus size={18}/></button></div>
      <div className="thread-list">{loading ? <div className="empty"><LoaderCircle className="spin" size={20}/><span>读取会话…</span></div> : threads.length ? threads.map(thread => <button className={`thread-row ${thread.id === selectedId ? 'selected' : ''}`} key={thread.id} onClick={() => { setSelectedId(thread.id); setDrawer(false); }}><span className={`status-dot ${thread.status?.type === 'active' ? 'active' : ''}`}></span><span className="thread-copy"><strong>{thread.name || thread.preview || '未命名会话'}</strong><small>{thread.cwd}</small></span><span className="thread-time">{formatTime(thread.updatedAt)}</span></button>) : <div className="empty"><FileText size={20}/><span>还没有会话</span></div>}</div>
      <div className="sidebar-footer"><div className="security-line"><ShieldCheck size={16}/><span>仅局域网 · 单设备令牌</span></div><div className="machine-line"><span className={`status-dot ${serverStatus === 'online' ? 'active' : ''}`}></span>{serverStatus === 'online' ? 'Codex 已连接' : serverStatus === 'connecting' ? '正在连接 Codex' : 'Codex 已断开'}</div></div>
    </aside>
    {drawer && <button className="scrim" onClick={() => setDrawer(false)} aria-label="关闭侧栏"/>}
    <main className="main"><header className="topbar"><button className="icon-button menu-button" onClick={() => setDrawer(true)} aria-label="打开会话列表"><Menu size={21}/></button><div className="topbar-title"><span className="eyebrow">LOCAL / CODEX</span><h1>{selected?.name || selected?.preview || '选择一个会话'}</h1></div><button className="icon-button" onClick={() => { loadThreads(); loadDetail(); }} aria-label="刷新"><RefreshCw size={18}/></button></header>
      {error && <div className="alert"><Activity size={16}/><span>{error}</span><button onClick={() => setError('')} aria-label="关闭提示"><X size={16}/></button></div>}
      <section className="overview"><div className="overview-copy"><div className="live-label"><span className={`pulse ${active ? 'running' : ''}`}></span>{active ? 'LIVE RUN' : selected?.desktopOpen ? 'DESKTOP OPEN' : 'READY'}</div><h2>{active ? 'Codex 正在工作' : selected?.desktopOpen ? '桌面会话已连接' : '工作台已就绪'}</h2><p>{selected ? `${selected.cwd} · ${statusLabel(selected)}` : '从左侧选择一个会话，或创建一个新的任务。'}</p></div><div className="overview-stats"><div><strong>{threads.length}</strong><span>本机会话</span></div><div><strong>{turns.length}</strong><span>当前轮次</span></div></div></section>
      {approval && <div className="approval"><div className="approval-icon"><LockKeyhole size={18}/></div><div className="approval-copy"><strong>Codex 请求执行操作</strong><span>{approval.params.command || approval.params.reason || '需要你的确认才能继续'}</span></div><button className="approve" onClick={() => approve('accept')}><Check size={16}/>允许</button><button className="deny" onClick={() => approve('decline')}><X size={16}/>拒绝</button></div>}
      <section className="conversation">{selected ? turns.length ? turns.map(turn => <div className="turn" key={turn.id}><div className="turn-meta"><span className={`turn-status ${turn.status}`}></span><span>{turn.status === 'inProgress' ? '进行中' : turn.status === 'failed' ? '失败' : '已完成'}</span><span className="turn-time">{formatTime(turn.startedAt)}</span></div><div className="turn-items">{turn.items?.map(item => { const text = itemText(item); return text ? <div key={item.id} className={`message ${item.type}`}><div className="message-label">{item.type === 'userMessage' ? '你' : item.type === 'commandExecution' ? <><Terminal size={13}/> 命令</> : item.type === 'reasoning' ? '思考摘要' : 'Codex'}</div><pre>{text}</pre></div> : null; })}</div></div>) : <div className="conversation-empty"><Zap size={22}/><strong>还没有消息</strong><span>在下方输入一条指令，Codex 会在这台电脑上继续工作。</span></div> : <div className="conversation-empty"><Smartphone size={22}/><strong>从手机控制你的 Codex</strong><span>选择左侧会话开始查看对话，所有数据都留在本机。</span></div>}</section>
      <section className="composer"><div className="composer-tools"><span><Terminal size={14}/> {selected?.cwd || '未选择工作目录'}</span><span className="secure"><ShieldCheck size={14}/> 本机执行</span></div><div className="composer-row"><textarea value={composer} onChange={e => setComposer(e.target.value)} onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendTurn(); } }} placeholder={selected ? '输入新的指令…' : '先选择一个会话'} disabled={!selected || sending}/><button className="send-button" onClick={sendTurn} disabled={!selected || !composer.trim() || sending} aria-label="发送"><Send size={18}/></button></div><div className="composer-foot"><span>Enter 发送 · Shift + Enter 换行</span>{runningTurn ? <button className="stop-button" onClick={interruptTurn}><CircleStop size={14}/>停止运行</button> : active && <span className="working"><LoaderCircle size={14} className="spin"/> Codex 正在响应</span>}</div></section>
    </main>
    {newTask && <div className="modal-backdrop"><form className="modal" onSubmit={createThread}><div className="modal-head"><div><span className="eyebrow">NEW SESSION</span><h3>创建一个新会话</h3></div><button type="button" className="icon-button" onClick={() => setNewTask(false)} aria-label="关闭"><X size={18}/></button></div><label>工作目录<input value={cwd} onChange={e => setCwd(e.target.value)} placeholder={navigator.platform.startsWith('Win') ? '例如 E:\\work\\project' : '/Users/me/project'} autoFocus/></label><p>新会话默认使用 workspace-write，并在需要时向你请求命令审批。</p><button className="primary-button" type="submit"><Plus size={17}/>创建会话</button></form></div>}
  </div>;
}

createRoot(document.getElementById('root')).render(<App />);
