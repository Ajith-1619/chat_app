<?php
require '/var/www/html/admin/_bootstrap.php';
$pdo = flow_admin_db();
$cols = $pdo->query("SHOW COLUMNS FROM xmpp_messages")->fetchAll(PDO::FETCH_COLUMN);
echo "columns=" . implode(',', array_values(array_filter($cols, fn($c) => stripos($c,'file')!==false || stripos($c,'attach')!==false || stripos($c,'media')!==false || stripos($c,'url')!==false || stripos($c,'path')!==false || stripos($c,'size')!==false))) . "\n";
foreach (['file_url','file_path','file_name','file_type','file_size','attachment_url','attachment_path','media_url','media_path','url'] as $c) {
  if (in_array($c,$cols,true)) {
    $q = $pdo->query("SELECT COUNT(*) FROM xmpp_messages WHERE `$c` IS NOT NULL AND CAST(`$c` AS CHAR) <> ''");
    echo $c . '=' . $q->fetchColumn() . "\n";
  }
}
$s = $pdo->query("SELECT id, from_jid, to_jid, file_name, file_type, file_size, file_url, created_at FROM xmpp_messages WHERE (file_name IS NOT NULL AND file_name <> '') OR (file_url IS NOT NULL AND file_url <> '') ORDER BY id DESC LIMIT 5");
foreach ($s->fetchAll(PDO::FETCH_ASSOC) as $r) {
  echo 'row=' . json_encode($r, JSON_UNESCAPED_SLASHES) . "\n";
}
