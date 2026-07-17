<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <?php if (!empty($csrf)): ?><meta name="flow-admin-csrf" content="<?= flow_admin_html((string)$csrf) ?>"><?php endif; ?>
  <title><?= flow_admin_html((string)($title ?? 'Flow Master Admin')) ?></title>
  <link rel="stylesheet" href="app.css">
</head>
<body>
<?= $content ?>
</body>
</html>
