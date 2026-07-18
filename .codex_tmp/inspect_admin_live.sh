#!/bin/sh
echo INDEX
grep -n "app\.js\|app\.css\|data-api-url" /var/www/html/admin/index.php || true
echo JS
grep -n "response\.json\|response\.text\|function postAction\|employeeTypePanel\|openLocationMapModal" /var/www/html/admin/app.js | tail -30 || true
