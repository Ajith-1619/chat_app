<?php
require '/var/www/html/admin/_bootstrap.php';
$ep = flow_admin_employee_db();
$rows=$ep->query("SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND (COLUMN_NAME='emp_type' OR COLUMN_NAME IN ('emp_id','employee_id','id','name','emp_name','employee_name')) ORDER BY TABLE_NAME, COLUMN_NAME LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
foreach($rows as $r){ echo 'empcol='.$r['TABLE_NAME'].'.'.$r['COLUMN_NAME'].PHP_EOL; }
foreach(['employees','employee','tbl_employee','employee_master','tbl_employees'] as $t){
 try{ $cols=$ep->query('SHOW COLUMNS FROM `'.$t.'`')->fetchAll(PDO::FETCH_COLUMN); echo 'EMP_TABLE '.$t.' '.implode(',',$cols).PHP_EOL; break; }catch(Throwable $e){}
}
$cp=flow_admin_db();
foreach(['xmpp_user_presence','xmpp_user_devices','xmpp_devices','device_sessions','xmpp_sessions'] as $t){
 if(!flow_admin_table_exists($cp,$t)) continue;
 echo 'TABLE '.$t.PHP_EOL;
 echo implode(',', $cp->query('SHOW COLUMNS FROM `'.$t.'`')->fetchAll(PDO::FETCH_COLUMN)).PHP_EOL;
}
