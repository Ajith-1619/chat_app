const state = { view: 'overview', q: '', modal: null };
const csrf = document.querySelector('meta[name="flow-admin-csrf"]')?.content || '';
const titles = {
  overview: ['Overview', 'Chat application control center'],
  users: ['Users', 'Employee access, presence and profile identity'],
  groups: ['Groups', 'Group list, members, wake-up and admin controls'],
  channels: ['Channels', 'Channel list, type, wake-up and admin controls'],
  messages: ['Messages', 'Latest chat history records'],
  attachments: ['Files', 'Uploaded images, documents, videos and voice files'],
  tasks: ['Tasks', 'MyHub task master records'],
  location: ['Location', 'Location visibility and presence policy'],
  notifications: ['Notifications', 'Push queue and delivery status'],
  releases: ['Releases', 'Draft/live app release management'],
  diagnostics: ['Diagnostics', 'API, database and notification timings'],
  audit: ['Audit Log', 'All super-admin changes and security events'],
};
const destructiveActions = new Set(['delete_message', 'rollback_release', 'remove_member', 'set_user_status']);
const actionLabels = {
  archive_channel: 'Archive',
  unarchive_channel: 'Unarchive',
  delete_message: 'Hide',
  restore_message: 'Restore',
  retry_notification: 'Retry',
  approve_release: 'Approve Live',
  rollback_release: 'Rollback',
  update_user_password: 'Edit Password',
  update_group: 'View/Edit',
};

const modalBackdrop = document.getElementById('modalBackdrop');
const actionModal = document.getElementById('actionModal');
const modalTitle = document.getElementById('modalTitle');
const modalFields = document.getElementById('modalFields');
const modalSubmit = document.getElementById('modalSubmit');

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

document.querySelectorAll('[data-modal-close]').forEach((button) => button.addEventListener('click', closeModal));
modalBackdrop?.addEventListener('click', (event) => {
  if (event.target === modalBackdrop) closeModal();
});
actionModal?.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!state.modal) return;
  const form = new FormData(actionModal);
  const payload = Object.fromEntries(form.entries());
  if (payload.password != null && !String(payload.password).trim()) {
    showNotice('Password cannot be empty.', true);
    return;
  }
  if (payload.room_name != null && !String(payload.room_name).trim()) {
    showNotice('Name cannot be empty.', true);
    return;
  }
  closeModal();
  await postAction(state.modal.action, { ...state.modal.basePayload, ...payload });
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeModal();
});

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
  document.getElementById('content').innerHTML = `<section class="card"><div class="card-head"><h2>${escapeHtml(titles[state.view][0])}</h2><span>${rows.length} records</span></div>${table(rows)}</section>`;
  wireActions();
}

function renderOverview(data) {
  const metrics = data.metrics || {};
  const metricHtml = Object.entries(metrics).map(([key, value]) => `
    <div class="metric"><span>${label(key)}</span><strong>${escapeHtml(value)}</strong></div>
  `).join('');
  document.getElementById('content').innerHTML = `
    <section class="metrics">${metricHtml}</section>
    <section class="card"><div class="card-head"><h2>24h Diagnostics</h2><span>Live system samples</span></div>${table(data.diagnostics || [])}</section>
  `;
  wireActions();
}

function table(rows) {
  if (!rows.length) return '<div class="empty">No records found.</div>';
  const keys = Object.keys(rows[0]).filter((key) => key !== 'admin_action' && key !== 'department').slice(0, 10);
  const hasActions = rows.some((row) => row.admin_action);
  return `<div class="table-wrap"><table><thead><tr>${keys.map((key) => `<th>${label(key)}</th>`).join('')}${hasActions ? '<th>Action</th>' : ''}</tr></thead><tbody>${
    rows.map((row) => `<tr>${keys.map((key) => `<td>${formatCell(row[key], key)}</td>`).join('')}${hasActions ? `<td>${actionButton(row)}</td>` : ''}</tr>`).join('')
  }</tbody></table></div>`;
}

function actionButton(row) {
  const action = row.admin_action;
  if (!action) return '';
  const id = row.id || row.emp_id || row.message_id || row.release_id || '';
  const labelText = actionLabels[action] || label(action);
  const danger = destructiveActions.has(action) || action.includes('delete') || action.includes('rollback');
  return `<button class="row-action ${danger ? 'danger' : ''}" data-action="${escapeHtml(action)}" data-id="${escapeHtml(id)}" data-row="${escapeHtml(JSON.stringify(row))}">${escapeHtml(labelText)}</button>`;
}

function wireActions() {
  document.querySelectorAll('.row-action').forEach((button) => {
    button.addEventListener('click', () => {
      const action = button.dataset.action;
      const id = button.dataset.id;
      const row = JSON.parse(button.dataset.row || '{}');
      openActionModal(action, id, row, button.textContent.trim(), button.classList.contains('danger'));
    });
  });
}

function openActionModal(action, id, row, labelText, danger) {
  const title = action === 'update_group' ? 'Edit Group / Channel' : action === 'update_user_password' ? 'Edit User Password' : labelText;
  modalTitle.textContent = title;
  modalSubmit.textContent = danger ? 'Confirm' : action.startsWith('update_') ? 'Save' : 'Run Action';
  modalSubmit.classList.toggle('danger', danger);
  state.modal = { action, basePayload: { id } };

  if (action === 'update_user_password') {
    modalFields.innerHTML = `
      <label>Employee ID<input name="employee" value="${escapeHtml(id)}" disabled></label>
      <label>New chat password<input name="password" type="password" required autocomplete="new-password"></label>
    `;
  } else if (action === 'update_group') {
    modalFields.innerHTML = `
      <label>Name<input name="room_name" value="${escapeHtml(row.room_name || '')}" required></label>
      <label>Channel type / kind<input name="channel_kind" value="${escapeHtml(row.channel_kind || row.group_type || '')}"></label>
      <div class="toggle-row"><input id="wakeupEnabled" name="wakeup_enabled" type="checkbox" value="1" ${Number(row.wakeup_enabled || 0) === 1 ? 'checked' : ''}><label for="wakeupEnabled">Wake-up notifications</label></div>
      <div class="toggle-row"><input id="isArchived" name="is_archived" type="checkbox" value="1" ${Number(row.is_archived || 0) === 1 ? 'checked' : ''}><label for="isArchived">Archived</label></div>
    `;
  } else {
    modalFields.innerHTML = `
      <div class="confirm-panel ${danger ? 'danger' : ''}">
        <strong>${escapeHtml(labelText)} record ${escapeHtml(id)}</strong>
        <span>This operation will be recorded in the admin audit log.</span>
      </div>
    `;
  }

  modalBackdrop.classList.remove('hidden');
  setTimeout(() => modalFields.querySelector('input:not([disabled])')?.focus(), 0);
}

function closeModal() {
  if (!modalBackdrop) return;
  modalBackdrop.classList.add('hidden');
  state.modal = null;
  modalSubmit?.classList.remove('danger');
}

async function postAction(action, payload) {
  const notice = document.getElementById('notice');
  notice.classList.add('hidden');
  const form = new FormData();
  form.set('csrf', csrf);
  Object.entries(payload).forEach(([key, value]) => form.set(key, value));
  try {
    const response = await fetch(`api.php?action=${encodeURIComponent(action)}`, {
      method: 'POST',
      body: form,
      credentials: 'same-origin',
      headers: { 'X-Flow-Admin-CSRF': csrf },
    });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Admin action failed.');
    showNotice(data.message || 'Admin action completed.', false);
    await load();
  } catch (error) {
    showNotice(error.message, true);
  }
}

function showNotice(text, isError) {
  const notice = document.getElementById('notice');
  notice.textContent = text;
  notice.classList.toggle('error', isError);
  notice.classList.remove('hidden');
}

function formatCell(value, key) {
  const text = value == null ? '' : String(value);
  if (['status', 'message_type', 'group_type', 'file_type', 'channel_kind', 'stage'].includes(key)) return `<span class="pill">${escapeHtml(text || '-')}</span>`;
  if (key === 'artifact_url' && text) return `<span class="mono">${escapeHtml(text.length > 70 ? `${text.slice(0, 70)}...` : text)}</span>`;
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
