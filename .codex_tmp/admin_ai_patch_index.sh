#!/bin/sh
if ! grep -q 'data-view="ai_access"' /var/www/html/admin/index.php; then
  perl -0pi -e 's#(<button class="nav-item" data-view="location" type="button">Location</button>)#$1\n      <button class="nav-item" data-view="ai_access" type="button">AI Access</button>#' /var/www/html/admin/index.php
fi
perl -0pi -e 's/href="app\.css(?:\?v=[^"]*)?"/href="app.css?v=202607181720"/g; s/src="app\.js(?:\?v=[^"]*)?"/src="app.js?v=202607181720"/g' /var/www/html/admin/index.php
php -l /var/www/html/admin/api.php
echo INDEX
grep -n "ai_access\|app\.js\|app\.css" /var/www/html/admin/index.php || true
echo JS
grep -n "renderAiAccess\|save_ai_provider\|save_ai_type_rule\|aiAccessPanel" /var/www/html/admin/app.js || true
echo API
grep -n "admin_ai_access\|save_ai_provider\|save_ai_type_rule\|'ai_access'" /var/www/html/admin/api.php || true
