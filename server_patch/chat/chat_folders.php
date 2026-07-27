<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

function chat_ensure_folders_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS xmpp_chat_folders (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        emp_id INT NOT NULL,
        folder_name VARCHAR(120) NOT NULL,
        chat_jids_json LONGTEXT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_chat_folder_emp_name (emp_id, folder_name),
        INDEX idx_chat_folder_emp_order (emp_id, sort_order, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function chat_folder_valid_jid(string $jid): bool
{
    $jid = strtolower(trim($jid));
    return $jid === 'saved@chat.skylinkonline.net'
        || chat_is_user_jid($jid)
        || chat_is_room_jid($jid)
        || chat_is_system_notification_jid($jid);
}

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_folders_table($pdo);

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare('SELECT folder_name, chat_jids_json, sort_order, updated_at
        FROM xmpp_chat_folders
        WHERE emp_id = :emp_id
        ORDER BY sort_order ASC, id ASC');
    $stmt->execute([':emp_id' => $empId]);
    $folders = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $jids = json_decode((string)($row['chat_jids_json'] ?? '[]'), true);
        if (!is_array($jids)) $jids = [];
        $folders[] = [
            'name' => (string)$row['folder_name'],
            'chat_jids' => array_values(array_filter(array_map('strval', $jids))),
            'sort_order' => (int)$row['sort_order'],
            'updated_at' => (string)($row['updated_at'] ?? ''),
        ];
    }
    chat_json(['status' => true, 'folders' => $folders]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    chat_json(['status' => false, 'error' => 'Unsupported method'], 405);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$rawFolders = $input['folders'] ?? [];
if (!is_array($rawFolders)) chat_json(['status' => false, 'error' => 'Folders must be a list'], 422);

$folders = [];
$seen = [];
$order = 0;
foreach ($rawFolders as $item) {
    if (!is_array($item)) continue;
    $name = mb_substr(trim((string)($item['name'] ?? '')), 0, 120);
    if ($name === '') continue;
    $key = mb_strtolower($name);
    if (isset($seen[$key])) continue;
    $seen[$key] = true;
    $jids = [];
    foreach ((array)($item['chat_jids'] ?? []) as $rawJid) {
        $jid = strtolower(trim((string)$rawJid));
        if ($jid !== '' && chat_folder_valid_jid($jid)) {
            $jids[$jid] = true;
        }
    }
    $folders[] = [
        'name' => $name,
        'chat_jids' => array_keys($jids),
        'sort_order' => $order++,
    ];
    if (count($folders) >= 40) break;
}

$pdo->beginTransaction();
try {
    $delete = $pdo->prepare('DELETE FROM xmpp_chat_folders WHERE emp_id = :emp_id');
    $delete->execute([':emp_id' => $empId]);
    $insert = $pdo->prepare('INSERT INTO xmpp_chat_folders (emp_id, folder_name, chat_jids_json, sort_order)
        VALUES (:emp_id, :folder_name, :chat_jids_json, :sort_order)');
    foreach ($folders as $folder) {
        $insert->execute([
            ':emp_id' => $empId,
            ':folder_name' => $folder['name'],
            ':chat_jids_json' => json_encode($folder['chat_jids'], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            ':sort_order' => $folder['sort_order'],
        ]);
    }
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}

chat_json(['status' => true, 'folders' => $folders]);

