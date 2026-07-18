#!/bin/sh
perl -0pi -e 's/href="app\.css(?:\?v=[^"]*)?"/href="app.css?v=202607181650"/g; s/src="app\.js(?:\?v=[^"]*)?"/src="app.js?v=202607181650"/g' /var/www/html/admin/index.php
php -l /var/www/html/admin/api.php
echo INDEX
grep -n "app\.js\|app\.css" /var/www/html/admin/index.php || true
echo JS
grep -n "response\.text\|employeeTypePanel(employeeType, user.emp_id)\|data-location-map.*openLocationMapModal\|options.reload" /var/www/html/admin/app.js || true
