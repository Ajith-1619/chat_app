<?php
chdir('/var/www/html/admin');
require '/var/www/html/admin/api.php';
$a = admin_user_attendance(24);
print_r($a);
