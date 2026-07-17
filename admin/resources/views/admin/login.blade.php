@extends('admin.layout')

@section('content')
<main class="login-shell">
  <form class="login-card" method="post" autocomplete="on" action="{{ route('admin.dashboard') }}">
    @csrf
    <div class="login-brand">
      <div class="brand-mark">F</div>
      <div>
        <h1>Flow Master Admin</h1>
        <p>Secure Laravel web console for enterprise communication operations.</p>
      </div>
    </div>
    @if($error !== '')
      <div class="alert">{{ $error }}</div>
    @endif
    <label>Employee ID
      <input name="username" inputmode="numeric" placeholder="302" required autofocus>
    </label>
    <label>Password
      <input name="password" type="password" required>
    </label>
    <button type="submit">Sign in</button>
    <small class="config-note">Uses the same chat identity and password for master-admin access.</small>
  </form>
</main>
@endsection
