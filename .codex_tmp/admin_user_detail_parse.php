<?php
$raw = file_get_contents('/tmp/flow_admin_user_detail.json');
$pos = strpos($raw, '{'); if ($pos !== false) $raw = substr($raw, $pos);
$j = json_decode($raw, true);
echo 'json=' . (is_array($j) ? 'ok' : 'bad') . PHP_EOL;
echo 'status=' . (($j['status'] ?? false) ? 'true' : 'false') . PHP_EOL;
echo 'location_updated=' . ($j['location']['updated_at'] ?? '') . PHP_EOL;
echo 'location_source=' . ($j['location']['source'] ?? '') . PHP_EOL;
echo 'timeline_count=' . count($j['location_timeline'] ?? []) . PHP_EOL;
echo 'today_status=' . ($j['attendance']['today']['status'] ?? '') . PHP_EOL;
echo 'punch_in=' . ($j['attendance']['today']['punch_in'] ?? '') . PHP_EOL;
echo 'login_seconds=' . ($j['attendance']['today']['login_seconds'] ?? '') . PHP_EOL;
echo 'login_label=' . ($j['attendance']['today']['login_label'] ?? '') . PHP_EOL;
