const state = { view: 'overview', q: '' };
const titles = {
  overview: ['Overview', 'Chat application control center'],
  users: ['Users', 'Employee access, presence and profile identity'],
  channels: ['Groups & Channels', 'Membership, channel type and operational rooms'],
  messages: ['Messages', 'Latest chat history records'],
  attachments: ['Files', 'Uploaded images, documents, videos and voice files'],
  tasks: ['Tasks', 'MyHub task master records'],
  location: ['Location', 'Location visibility and presence policy'],
  notifications: ['Notifications', 'Push queue and delivery status'],
  releases: ['Releases', 'Draft/live app release management'],
  diagnostics: ['Diagnostics', 'API, database and notification timings'],
};

document.querySelectorAll('.nav-item').forEach((button) => {
  button.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
    button.classList.add('active');
    state.view = button.dataset.view;
    renderTitle();
    load();
  });
});
document.getElementById('refreshBtn')?.addEventListener('click', load);
document.getElementById('globalSearch')?.addEventListener('input', debounce((event) => {
  state.q = event.target.value.trim();
  load();
}, 280));

function debounce(fn, wait) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), wait);
  };
}

function renderTitle() {
  const [title, subtitle] = titles[state.view] || titles.overview;
  document.getElementById('pageTitle').textContent = title;
  document.getElementById('pageSubtitle').textContent = subtitle;
}

async function load() {
  const content = document.getElementById('content');
  content.innerHTML = '<div class="empty">Loading...</div>';
  const params = new URLSearchParams({ action: state.view });
  if (state.q) params.set('q', state.q);
  try {
    const response = await fetch(`api.php?${params.toString()}`, { credentials: 'same-origin' });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Unable to load admin data.');
    render(data);
  } catch (error) {
    content.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

function render(data) {
  if (state.view === 'overview') return renderOverview(data);
  const rows = data.rows || [];
  document.getElementById('content').innerHTML = `<section class="card"><h2>${escapeHtml(titles[state.view][0])}</h2>${table(rows)}</section>`;
}

function renderOverview(data) {
  const metrics = data.metrics || {};
  const metricHtml = Object.entries(metrics).map(([key, value]) => `
    <div class="metric"><span>${label(key)}</span><strong>${escapeHtml(value)}</strong></div>
  `).join('');
  document.getElementById('content').innerHTML = `
    <section class="metrics">${metricHtml}</section>
    <section class="card"><h2>Recent Messages</h2>${table(data.recent_messages || [])}</section>
    <section class="card"><h2>24h Diagnostics</h2>${table(data.diagnostics || [])}</section>
  `;
}

function table(rows) {
  if (!rows.length) return '<div class="empty">No records found.</div>';
  const keys = Object.keys(rows[0]).slice(0, 10);
  return `<div class="table-wrap"><table><thead><tr>${keys.map((key) => `<th>${label(key)}</th>`).join('')}</tr></thead><tbody>${
    rows.map((row) => `<tr>${keys.map((key) => `<td>${formatCell(row[key], key)}</td>`).join('')}</tr>`).join('')
  }</tbody></table></div>`;
}

function formatCell(value, key) {
  const text = value == null ? '' : String(value);
  if (['status', 'message_type', 'group_type', 'file_type'].includes(key)) return `<span class="pill">${escapeHtml(text || '-')}</span>`;
  if (text.length > 160) return escapeHtml(`${text.slice(0, 160)}...`);
  return escapeHtml(text);
}

function label(key) {
  return String(key).replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  }[char]));
}

renderTitle();
load();
