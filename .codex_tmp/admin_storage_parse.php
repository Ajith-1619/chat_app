<?php
$raw=file_get_contents('/tmp/flow_admin_storage_user.json');
$pos=strpos($raw,'{'); if($pos!==false)$raw=substr($raw,$pos);
$j=json_decode($raw,true);
echo 'json='.(is_array($j)?'ok':'bad').PHP_EOL;
echo 'status='.(($j['status']??false)?'true':'false').PHP_EOL;
echo 'messages_total='.($j['messages']['total']??'').PHP_EOL;
echo 'messages_sent='.($j['messages']['sent']??'').PHP_EOL;
echo 'messages_received='.($j['messages']['received']??'').PHP_EOL;
echo 'files_total='.($j['files']['count']??'').PHP_EOL;
echo 'files_sent='.($j['files']['sent_count']??'').PHP_EOL;
echo 'files_received='.($j['files']['received_count']??'').PHP_EOL;
echo 'storage_label='.($j['files']['storage_label']??'').PHP_EOL;
echo 'limit_label='.($j['files']['quota']['limit_label']??'').PHP_EOL;
