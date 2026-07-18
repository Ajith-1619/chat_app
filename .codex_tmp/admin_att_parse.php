<?php
$raw=file_get_contents('/tmp/flow_admin_user_detail.json'); $pos=strpos($raw,'{'); if($pos!==false)$raw=substr($raw,$pos); $j=json_decode($raw,true);
print_r($j['attendance'] ?? null);
