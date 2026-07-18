<?php
require '/var/www/html/admin/_bootstrap.php';
$ep = flow_admin_employee_db();
$src = admin_employee_source($ep);
echo 'employee_table=' . ($src['table'] ?? '') . ';id=' . ($src['id'] ?? '') . PHP_EOL;
if ($src) {
  $cols=$ep->query('SHOW COLUMNS FROM `' . $src['table'] . '`')->fetchAll(PDO::FETCH_COLUMN);
  echo 'emp_type_exists=' . (in_array('emp_type',$cols,true)?'yes':'no') . PHP_EOL;
  foreach(array_filter($cols, fn($c)=>stripos($c,'type')!==false || stripos($c,'emp')!==false || stripos($c,'name')!==false) as $c) echo 'col='.$c.PHP_EOL;
}
$cp=flow_admin_db();
foreach(['xmpp_user_presence','xmpp_user_devices','xmpp_devices','device_sessions','xmpp_sessions'] as $t){
 if(!flow_admin_table_exists($cp,$t)) continue;
 echo 'TABLE '.$t.PHP_EOL;
 echo implode(',', $cp->query('SHOW COLUMNS FROM `'.$t.'`')->fetchAll(PDO::FETCH_COLUMN)).PHP_EOL;
 $s=$cp->prepare('SELECT * FROM `'.$t.'` WHERE emp_id=24 LIMIT 2');
 try{$s->execute(); foreach($s->fetchAll(PDO::FETCH_ASSOC) as $r){ foreach($r as $k=>$v){ if(in_array($k,['emp_id','device','device_name','platform','app_version','version','ip_address','ip','last_seen_at','updated_at','status','online','last_activity_at','user_agent','device_model'],true)) echo $k.'='.$v.';'; } echo PHP_EOL; }} catch(Throwable $e){ echo 'sample_err='.$e->getMessage().PHP_EOL; }
}
