const appShell = document.querySelector('.app-shell');
const state = { view: appShell?.dataset.initialView || 'overview', q: '', modal: null };
const csrf = document.querySelector('meta[name="flow-admin-csrf"]')?.content || '';
const apiUrl = appShell?.dataset.apiUrl || '?ajax=api';
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
  view_user: 'View/Edit',
  update_group: 'View/Edit',
};

const modalBackdrop = document.getElementById('modalBackdrop');
const actionModal = document.getElementById('actionModal');
const modalTitle = document.getElementById('modalTitle');
const modalFields = document.getElementById('modalFields');
const modalSubmit = document.getElementById('modalSubmit');

document.querySelectorAll('button.nav-item[data-view]').forEach((button) => {
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
  if (state.modal?.action === 'update_user_password' && payload.password != null && !String(payload.password).trim()) {
    closeModal();
    return;
  }
  if (payload.password != null && !String(payload.password).trim()) {
    showNotice('Password cannot be empty.', true);
    return;
  }
  if (payload.room_name != null && !String(payload.room_name).trim()) {
    showNotice('Name cannot be empty.', true);
    return;
  }
  const modalAction = state.modal.action;
  const basePayload = { ...state.modal.basePayload };
  closeModal();
  await postAction(modalAction, { ...basePayload, ...payload });
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
    const response = await fetch(`${apiUrl}&${params.toString()}`, { credentials: 'same-origin' });
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
  if (state.view === 'users') return renderUserMasterDetail(rows);
  if (['groups', 'channels'].includes(state.view)) return renderGroupMasterDetail(rows);
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

function renderUserMasterDetail(rows) {
  const content = document.getElementById('content');
  content.innerHTML = `
    <section class="master-detail-shell">
      <aside class="master-list-panel">
        <div class="master-head"><h2>Users</h2><span>${escapeHtml(rows.length)} records</span></div>
        <div class="master-list">${rows.length ? rows.map(userMasterItem).join('') : '<div class="empty compact">No users found.</div>'}</div>
      </aside>
      <section id="detailPane" class="detail-pane"><div class="empty">Select a user to view and edit details.</div></section>
    </section>
  `;
  document.querySelectorAll('.master-item[data-user-id]').forEach((button) => {
    button.addEventListener('click', () => selectMasterItem(button, () => openUserInline(button.dataset.userId)));
  });
  document.querySelector('.master-item[data-user-id]')?.click();
}

function userMasterItem(row) {
  const name = row.name || row.username || `Employee ${row.emp_id}`;
  const designation = row.designation || 'No designation';
  return `<button class="master-item" type="button" data-user-id="${escapeHtml(row.emp_id)}">
    <span class="master-title">${escapeHtml(name)}</span>
    <span class="master-subtitle">${escapeHtml(designation)}</span>
    <span class="master-badge">${escapeHtml(row.status || '-')}</span>
  </button>`;
}

function renderGroupMasterDetail(rows) {
  const content = document.getElementById('content');
  const title = state.view === 'channels' ? 'Channels' : 'Groups';
  content.innerHTML = `
    <section class="master-detail-shell">
      <aside class="master-list-panel">
        <div class="master-head"><h2>${title}</h2><span>${escapeHtml(rows.length)} records</span></div>
        <div class="master-list">${rows.length ? rows.map(groupMasterItem).join('') : '<div class="empty compact">No records found.</div>'}</div>
      </aside>
      <section id="detailPane" class="detail-pane"><div class="empty">Select a ${state.view === 'channels' ? 'channel' : 'group'} to view and edit details.</div></section>
    </section>
  `;
  document.querySelectorAll('.master-item[data-group-id]').forEach((button) => {
    button.addEventListener('click', () => selectMasterItem(button, () => openGroupInline(button.dataset.groupId)));
  });
  document.querySelector('.master-item[data-group-id]')?.click();
}

function groupMasterItem(row) {
  const kind = row.channel_kind || row.group_type || 'group';
  return `<button class="master-item" type="button" data-group-id="${escapeHtml(row.id)}">
    <span class="master-title">${escapeHtml(row.room_name || '-')}</span>
    <span class="master-subtitle">${escapeHtml(kind)}</span>
    <span class="master-badge">${escapeHtml(row.members || 0)} members</span>
  </button>`;
}

function selectMasterItem(button, callback) {
  document.querySelectorAll('.master-item').forEach((item) => item.classList.remove('active'));
  button.classList.add('active');
  callback();
}

async function openUserInline(empId) {
  const pane = document.getElementById('detailPane');
  if (!pane) return openUserDetailModal(empId);
  pane.innerHTML = '<div class="empty">Loading user information...</div>';
  try {
    const response = await fetch(`${apiUrl}&action=user_detail&id=${encodeURIComponent(empId)}`, { credentials: 'same-origin' });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Unable to load user details.');
    pane.innerHTML = `<form id="inlineUserForm" class="inline-detail-form">${userDetailHtml(data)}<footer class="inline-actions"><button class="secondary" type="button" id="clearPasswordBtn">Clear</button><button type="submit">Save User</button></footer></form>`;
    wireUserMembershipLinks(pane);
    document.getElementById('clearPasswordBtn')?.addEventListener('click', () => {
      const input = pane.querySelector('input[name="password"]');
      if (input) input.value = '';
    });
    document.getElementById('inlineUserForm')?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const password = pane.querySelector('input[name="password"]')?.value.trim() || '';
      if (!password) { showNotice('No password change entered.', true); return; }
      await postAction('update_user_password', { id: empId, password });
    });
  } catch (error) {
    pane.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

async function openGroupInline(groupId) {
  const pane = document.getElementById('detailPane');
  if (!pane) return openGroupDetailModal(groupId);
  pane.innerHTML = '<div class="empty">Loading group information...</div>';
  try {
    const response = await fetch(`${apiUrl}&action=group_detail&id=${encodeURIComponent(groupId)}`, { credentials: 'same-origin' });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Unable to load group details.');
    pane.innerHTML = `<form id="inlineGroupForm" class="inline-detail-form">${groupDetailHtml(data)}<footer class="inline-actions"><button type="submit">Save Group</button></footer></form>`;
    wireGroupMemberActions(groupId, pane, true);
    document.getElementById('inlineGroupForm')?.addEventListener('submit', async (event) => {
      event.preventDefault();
      const form = new FormData(event.currentTarget);
      const payload = Object.fromEntries(form.entries());
      payload.wakeup_enabled = form.has('wakeup_enabled') ? '1' : '0';
      payload.is_archived = form.has('is_archived') ? '1' : '0';
      await postAction('update_group', { id: groupId, ...payload });
    });
  } catch (error) {
    pane.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
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
  if (action === 'view_user') { openUserDetailModal(id); return; }
  if (action === 'update_group') { openGroupDetailModal(id); return; }
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

  document.body.classList.add('modal-open');
  modalBackdrop.classList.remove('hidden');
  setTimeout(() => modalFields.querySelector('input:not([disabled])')?.focus(), 0);
}

function closeModal() {
  if (!modalBackdrop) return;
  modalBackdrop.classList.add('hidden');
  document.body.classList.remove('modal-open');
  actionModal?.classList.remove('modal-wide', 'user-detail-modal', 'group-detail-modal');
  state.modal = null;
  modalSubmit?.classList.remove('danger');
}


async function openGroupDetailModal(groupId) {
  modalTitle.textContent = 'Group / Channel Details';
  modalSubmit.textContent = 'Save Group';
  modalSubmit.classList.remove('danger');
  actionModal.classList.add('modal-wide', 'user-detail-modal', 'group-detail-modal');
  document.body.classList.add('modal-open');
  state.modal = { action: 'update_group', basePayload: { id: groupId } };
  modalFields.innerHTML = '<div class="empty">Loading group information...</div>';
  modalBackdrop.classList.remove('hidden');

  try {
    const response = await fetch(`${apiUrl}&action=group_detail&id=${encodeURIComponent(groupId)}`, { credentials: 'same-origin' });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Unable to load group details.');
    modalFields.innerHTML = groupDetailHtml(data);
    wireGroupMemberActions(groupId);
  } catch (error) {
    modalFields.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

function groupDetailHtml(data) {
  const group = data.group || {};
  const stats = data.stats || {};
  const members = data.members || [];
  const type = group.group_type || group.channel_kind || 'group';
  return `
    <div class="user-detail-scroll group-detail-scroll">
      <section class="user-hero">
        <div class="avatar-large">${escapeHtml(String(group.room_name || 'G').charAt(0) || 'G')}</div>
        <div class="user-hero-main">
          <span class="eyebrow">${escapeHtml(type)} #${escapeHtml(group.id || '-')}</span>
          <h3>${escapeHtml(group.room_name || '-')}</h3>
          <p>${escapeHtml(group.room_jid || '-')}</p>
        </div>
        <div class="user-hero-side">
          <span class="pill">${Number(group.is_archived || 0) === 1 ? 'Archived' : 'Active'}</span>
          <strong>${escapeHtml(group.created_at || '-')}</strong>
          <small>Created</small>
        </div>
      </section>

      <section class="detail-metrics">
        ${metricCard('Members', stats.members || 0, 'Total users')}
        ${metricCard('Owners', stats.owners || 0, 'Owner role')}
        ${metricCard('Admins', stats.admins || 0, 'Admin role')}
        ${metricCard('Messages', stats.messages || 0, 'Group messages')}
        ${metricCard('Files', stats.files || 0, 'Shared files')}
        ${metricCard('Images', stats.images || 0, 'Shared images')}
      </section>

      <section class="detail-grid">
        <div class="detail-panel">
          <h4>Edit Details</h4>
          <label>Name<input name="room_name" value="${escapeHtml(group.room_name || '')}" required></label>
          <label>Channel type / kind<input name="channel_kind" value="${escapeHtml(group.channel_kind || group.group_type || '')}"></label>
          <div class="toggle-row"><input id="groupWakeupEnabled" name="wakeup_enabled" type="checkbox" value="1" ${Number(group.wakeup_enabled || 0) === 1 ? 'checked' : ''}><label for="groupWakeupEnabled">Wake-up notifications</label></div>
          <div class="toggle-row"><input id="groupIsArchived" name="is_archived" type="checkbox" value="1" ${Number(group.is_archived || 0) === 1 ? 'checked' : ''}><label for="groupIsArchived">Archived</label></div>
        </div>
        ${detailPanel('Technical Details', {
          'Room JID': group.room_jid,
          'Group Type': group.group_type,
          'Channel Kind': group.channel_kind,
          'Priority': group.priority,
          'Storage': stats.storage_label || '0 B',
          'Updated': group.updated_at,
        })}
      </section>

      <section class="detail-panel members-panel">
        <div class="members-head"><h4>Members, Owners & Admins</h4><span>${escapeHtml(members.length)} members</span></div>
        ${membersHtml(members)}
      </section>
    </div>
  `;
}

function membersHtml(members) {
  if (!members.length) return '<div class="empty compact">No members found.</div>';
  return `<div class="member-list">${members.map((member) => `
    <div class="member-row" data-emp-id="${escapeHtml(member.emp_id)}">
      <div class="member-main">
        <strong>${escapeHtml(member.name || `Employee ${member.emp_id}`)}</strong>
        <span>${escapeHtml(member.designation || member.jid || '-')}</span>
      </div>
      <select class="member-role" data-emp-id="${escapeHtml(member.emp_id)}">
        ${['owner', 'admin', 'member'].map((role) => `<option value="${role}" ${String(member.role || 'member').toLowerCase() === role ? 'selected' : ''}>${label(role)}</option>`).join('')}
      </select>
      <span class="member-date">${escapeHtml(member.joined_at || '-')}</span>
      <button class="member-remove" type="button" data-emp-id="${escapeHtml(member.emp_id)}">Remove</button>
    </div>
  `).join('')}</div>`;
}

function wireGroupMemberActions(groupId, container = modalFields, inline = false) {
  container.querySelectorAll('.member-role').forEach((select) => {
    select.addEventListener('change', async () => {
      await postAction('set_member_role', { group_id: groupId, emp_id: select.dataset.empId, role: select.value });
      inline ? await openGroupInline(groupId) : await openGroupDetailModal(groupId);
    });
  });
  container.querySelectorAll('.member-remove').forEach((button) => {
    button.addEventListener('click', async () => {
      if (!confirm(`Remove employee ${button.dataset.empId} from this group/channel?`)) return;
      await postAction('remove_member', { group_id: groupId, emp_id: button.dataset.empId });
      inline ? await openGroupInline(groupId) : await openGroupDetailModal(groupId);
    });
  });
}
async function openUserDetailModal(empId) {
  modalTitle.textContent = 'User Details';
  modalSubmit.textContent = 'Save Password';
  modalSubmit.classList.remove('danger');
  state.modal = { action: 'update_user_password', basePayload: { id: empId } };
  actionModal.classList.add('modal-wide', 'user-detail-modal');
  document.body.classList.add('modal-open');
  modalFields.innerHTML = '<div class="empty">Loading user information...</div>';
  modalBackdrop.classList.remove('hidden');

  try {
    const response = await fetch(`${apiUrl}&action=user_detail&id=${encodeURIComponent(empId)}`, { credentials: 'same-origin' });
    const data = await response.json();
    if (!response.ok || data.status !== true) throw new Error(data.error || 'Unable to load user details.');
    modalFields.innerHTML = userDetailHtml(data);
    wireUserMembershipLinks();
  } catch (error) {
    modalFields.innerHTML = `<div class="empty">${escapeHtml(error.message)}</div>`;
  }
}

function userDetailHtml(data) {
  const user = data.user || {};
  const profile = data.profile || {};
  const messages = data.messages || {};
  const files = data.files || {};
  const presence = data.presence || {};
  const location = data.location || {};
  const systems = data.systems || [];
  const memberships = data.memberships || { groups: 0, channels: 0, total: 0, rows: [] };
  const displayName = profile.name || profile.emp_name || profile.employee_name || profile.full_name || user.username || user.emp_id || '-';
  const designation = profile.designation || profile.desig || profile.role || profile.job_title || profile.position || '-';
  const statusText = user.status === '1' || user.status === 1 ? 'Active' : (user.status || '-');
  return `
    <div class="user-detail-scroll">
      <section class="user-hero">
        <div class="avatar-large">${escapeHtml(String(displayName).charAt(0) || 'U')}</div>
        <div class="user-hero-main">
          <span class="eyebrow">Employee ${escapeHtml(user.emp_id || '-')}</span>
          <h3>${escapeHtml(displayName)}</h3>
          <p>${escapeHtml(designation)}</p>
        </div>
        <div class="user-hero-side">
          <span class="pill">${escapeHtml(statusText)}</span>
          <strong>${escapeHtml(presence.last_seen_at || '-')}</strong>
          <small>Last seen</small>
        </div>
      </section>

      <section class="detail-metrics">
        ${metricCard('Messages', messages.total || 0, 'Total chat activity')}
        ${metricCard('Sent', messages.sent || 0, 'Outgoing messages')}
        ${metricCard('Received', messages.received || 0, 'Incoming messages')}
        ${metricCard('Files', files.count || 0, 'Shared attachments')}
        ${metricCard('Storage', files.storage_label || '0 B', 'Consumed file size')}
        ${metricCard('Systems', systems.length || 0, 'Active devices')}
        ${metricCard('Groups', memberships.groups || 0, 'Involved groups')}
        ${metricCard('Channels', memberships.channels || 0, 'Involved channels')}
      </section>

      <section class="detail-grid">
        ${detailPanel('Identity', {
          'Employee ID': user.emp_id,
          'Username': user.username,
          'Designation': designation,
          'Account Created': user.created_at,
          'Last Updated': user.updated_at,
        })}
        ${detailPanel('Last Location', {
          'Address': location.address || '-',
          'Latitude': location.lat || '-',
          'Longitude': location.lng || '-',
          'Updated': location.updated_at || '-',
          'Source': location.source || '-',
        })}
      </section>

      ${membershipsHtml(memberships)}
      ${systemsHtml(systems)}
      ${profileHtml(profile)}

      <section class="password-panel">
        <div>
          <h4>Password Update</h4>
          <p>Enter a new password only when this user password must be changed.</p>
        </div>
        <label>New chat password<input name="password" type="password" autocomplete="new-password" placeholder="Leave empty to keep current password"></label>
      </section>
    </div>
  `;
}

function metricCard(title, value, hint) {
  return `<div><span>${escapeHtml(title)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(hint)}</small></div>`;
}
function detailPanel(title, values) {
  return `<div class="detail-panel"><h4>${escapeHtml(title)}</h4>${Object.entries(values).map(([key, value]) => `
    <div class="detail-row"><span>${escapeHtml(key)}</span><strong>${escapeHtml(value == null || value === '' ? '-' : value)}</strong></div>
  `).join('')}</div>`;
}

function membershipsHtml(memberships) {
  const rows = memberships.rows || [];
  if (!rows.length) return '<section class="detail-panel memberships-panel"><h4>Groups & Channels</h4><div class="empty compact">No group or channel memberships found.</div></section>';
  return `<section class="detail-panel memberships-panel">
    <div class="members-head"><h4>Groups & Channels</h4><span>${escapeHtml(memberships.total || rows.length)} total</span></div>
    <div class="membership-list">${rows.map((item) => `
      <button class="membership-row" type="button" data-group-id="${escapeHtml(item.id)}">
        <div>
          <strong>${escapeHtml(item.room_name || '-')}</strong>
          <span>${escapeHtml(item.channel_kind || item.group_type || item.kind || '-')}</span>
        </div>
        <span class="pill">${escapeHtml(item.role || 'member')}</span>
        <small>${escapeHtml(item.joined_at || '-')}</small>
      </button>
    `).join('')}</div>
  </section>`;
}

function wireUserMembershipLinks(container = modalFields) {
  container.querySelectorAll('.membership-row').forEach((button) => {
    button.addEventListener('click', () => document.getElementById('detailPane') ? openGroupInline(button.dataset.groupId) : openGroupDetailModal(button.dataset.groupId));
  });
}
function systemsHtml(systems) {
  if (!systems.length) return '<section class="detail-panel"><h4>Active Systems</h4><div class="empty compact">No active systems found.</div></section>';
  return `<section class="detail-panel"><h4>Active Systems</h4><div class="system-list">${systems.map((system) => `
    <div class="system-row">
      <strong>${escapeHtml(system.device || '-')}</strong>
      <span>${escapeHtml(system.app_version || '-')}</span>
      <span>${escapeHtml(system.ip_address || '-')}</span>
      <span>${escapeHtml(system.last_seen_at || '-')}</span>
    </div>
  `).join('')}</div></section>`;
}

function profileHtml(profile) {
  const entries = Object.entries(profile || {}).filter(([key, value]) => value != null && String(value) !== '').slice(0, 18);
  if (!entries.length) return '';
  return `<section class="detail-panel"><h4>Full Profile</h4><div class="profile-list">${entries.map(([key, value]) => `
    <div class="detail-row"><span>${escapeHtml(label(key))}</span><strong>${escapeHtml(value)}</strong></div>
  `).join('')}</div></section>`;
}
async function postAction(action, payload) {
  const notice = document.getElementById('notice');
  notice.classList.add('hidden');
  const form = new FormData();
  form.set('csrf', csrf);
  Object.entries(payload).forEach(([key, value]) => form.set(key, value));
  try {
    const response = await fetch(`${apiUrl}&action=${encodeURIComponent(action)}`, {
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

