<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        flow_admin_login((string)($_POST['username'] ?? ''), (string)($_POST['password'] ?? ''));
        header('Location: index.php');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}
$admin = null;
try {
    $admin = flow_admin_current_emp_id() > 0 ? flow_admin_require() : null;
} catch (Throwable $e) {
    $error = $error !== '' ? $error : $e->getMessage();
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flow Master Admin</title>
  <link rel="stylesheet" href="app.css">
</head>
<body>
<?php if (!$admin): ?>
  <main class="login-shell">
    <form class="login-card" method="post" autocomplete="on">
      <div class="brand-mark">F</div>
      <h1>Flow Master Admin</h1>
      <p>Restricted access for employee IDs 302 and 116.</p>
      <?php if ($error !== ''): ?><div class="alert"><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></div><?php endif; ?>
      <label>Employee ID
        <input name="username" inputmode="numeric" placeholder="302" required autofocus>
      </label>
      <label>Password
        <input name="password" type="password" required>
      </label>
      <button type="submit">Sign in</button>
    </form>
  </main>
<?php else: ?>
  <div class="app-shell" data-admin-name="<?= htmlspecialchars((string)$admin['name'], ENT_QUOTES, 'UTF-8') ?>">
    <aside class="sidebar">
      <div class="brand">
        <div class="brand-mark">F</div>
        <div>
          <strong>Flow Admin</strong>
          <span>Master Console</span>
        </div>
      </div>
      <nav>
        <button class="nav-item active" data-view="overview">Overview</button>
        <button class="nav-item" data-view="users">Users</button>
        <button class="nav-item" data-view="channels">Groups & Channels</button>
        <button class="nav-item" data-view="messages">Messages</button>
        <button class="nav-item" data-view="attachments">Files</button>
        <button class="nav-item" data-view="tasks">Tasks</button>
        <button class="nav-item" data-view="location">Location</button>
        <button class="nav-item" data-view="notifications">Notifications</button>
        <button class="nav-item" data-view="releases">Releases</button>
        <button class="nav-item" data-view="diagnostics">Diagnostics</button>
      </nav>
    </aside>
    <main class="workspace">
      <header class="topbar">
        <div>
          <h1 id="pageTitle">Overview</h1>
          <p id="pageSubtitle">Chat application control center</p>
        </div>
        <div class="top-actions">
          <input id="globalSearch" placeholder="Search users, channels, messages">
          <button id="refreshBtn" type="button">Refresh</button>
          <a class="logout" href="logout.php">Logout</a>
        </div>
      </header>
      <section id="notice" class="notice hidden"></section>
      <section id="content" class="content-grid"></section>
    </main>
  </div>
  <script src="app.js"></script>
<?php endif; ?>
</body>
</html>

