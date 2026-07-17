@extends('admin.layout')

@section('content')
<meta name="flow-admin-csrf" content="{{ $legacyCsrf }}">
<div class="app-shell" data-admin-name="{{ $admin['name'] ?? 'Admin' }}">
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">F</div>
      <div>
        <strong>Flow Admin</strong>
        <span>Laravel Console</span>
      </div>
    </div>
    <nav aria-label="Admin modules">
      <button class="nav-item active" data-view="overview" type="button">Overview</button>
      <button class="nav-item" data-view="users" type="button">Users</button>
      <button class="nav-item" data-view="groups" type="button">Groups</button>
      <button class="nav-item" data-view="channels" type="button">Channels</button>
      <button class="nav-item" data-view="tasks" type="button">Tasks</button>
      <button class="nav-item" data-view="location" type="button">Location</button>
      <button class="nav-item" data-view="notifications" type="button">Notifications</button>
      <button class="nav-item" data-view="releases" type="button">Releases</button>
      <button class="nav-item" data-view="diagnostics" type="button">Diagnostics</button>
      <button class="nav-item" data-view="audit" type="button">Audit Log</button>
    </nav>
    <footer class="side-footer">
      <span>{{ $admin['name'] ?? 'Admin' }}</span>
      <small>{{ $admin['designation'] ?? 'Master Admin' }}</small>
    </footer>
  </aside>

  <main class="workspace">
    <header class="topbar">
      <div>
        <span class="eyebrow">Operations</span>
        <h1 id="pageTitle">Overview</h1>
        <p id="pageSubtitle">Chat application control center</p>
      </div>
      <div class="top-actions">
        <input id="globalSearch" placeholder="Search users, channels, messages">
        <button id="refreshBtn" type="button">Refresh</button>
        <a class="logout" href="{{ route('admin.logout') }}">Logout</a>
      </div>
    </header>

    <section id="notice" class="notice hidden"></section>
    <section id="content" class="content-grid"></section>

    <footer class="app-footer">
      <span>Flow Master Admin</span>
      <span>Laravel {{ app()->version() }}</span>
    </footer>
  </main>
</div>

<div id="modalBackdrop" class="modal-backdrop hidden" role="presentation">
  <form id="actionModal" class="modal" role="dialog" aria-modal="true" aria-labelledby="modalTitle">
    <header class="modal-header">
      <div>
        <span class="eyebrow">Admin Action</span>
        <h2 id="modalTitle">Edit</h2>
      </div>
      <button class="icon-button" type="button" data-modal-close aria-label="Close">x</button>
    </header>
    <div id="modalFields" class="modal-fields"></div>
    <footer class="modal-actions">
      <button type="button" class="secondary" data-modal-close>Cancel</button>
      <button id="modalSubmit" type="submit">Save</button>
    </footer>
  </form>
</div>

<script src="{{ asset('admin/app.js') }}"></script>
@endsection
