@extends('admin.layout')

@section('content')
<meta name="flow-admin-csrf" content="{{ $legacyCsrf }}">
<div class="app-shell" data-admin-name="{{ $admin['name'] ?? 'Admin' }}" data-initial-view="{{ $activeView }}" data-api-url="{{ route('admin.api') }}?admin=1">
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">F</div>
      <div>
        <strong>Flow Admin</strong>
        <span>Laravel Console</span>
      </div>
    </div>
    <nav aria-label="Admin modules">
      @foreach($modules as $view => $meta)
        <a class="nav-item {{ $activeView === $view ? 'active' : '' }}" href="{{ route('admin.dashboard', $view === 'overview' ? [] : ['module' => $view]) }}" data-view="{{ $view }}">{{ $meta['title'] }}</a>
      @endforeach
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
        <h1 id="pageTitle">{{ $pageTitle }}</h1>
        <p id="pageSubtitle">{{ $pageSubtitle }}</p>
      </div>
      <div class="top-actions">
        <input id="globalSearch" placeholder="Search users, channels, messages">
        <button id="refreshBtn" type="button">Refresh</button>
        <a class="logout" href="{{ route('admin.dashboard', ['logout' => 1]) }}">Logout</a>
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

<script src="{{ asset('admin/app.js') }}?v={{ filemtime(public_path('admin/app.js')) }}"></script>
@endsection


