<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>{{ $title ?? 'Flow Master Admin' }}</title>
  <link rel="stylesheet" href="{{ asset('admin/app.css') }}?v={{ filemtime(public_path('admin/app.css')) }}">
</head>
<body>
  @yield('content')
</body>
</html>
