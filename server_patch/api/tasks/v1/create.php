<?php
declare(strict_types=1);

require_once __DIR__ . '/../../_shared/bootstrap.php';

flow_api_cors();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$auth = flow_api_auth(['tasks:write']);

try {
    if ($method !== 'POST') {
        flow_api_error('Use POST to create a task.', 405, 'METHOD_NOT_ALLOWED', [
            'debug' => ['handler' => 'physical_task_create_v1', 'method' => $method],
        ]);
    }

    $rawBody = file_get_contents('php://input') ?: '';
    $decoded = $rawBody !== '' ? json_decode($rawBody, true) : [];
    $input = is_array($decoded) ? $decoded : [];
    if (!$input && $_POST) $input = $_POST;
    $input = array_merge($_GET, $input);

    $debug = [
        'handler' => 'physical_task_create_v1',
        'method' => $method,
        'content_type' => $_SERVER['CONTENT_TYPE'] ?? '',
        'raw_length' => strlen($rawBody),
        'json_error' => $rawBody === '' ? 'empty_body' : json_last_error_msg(),
        'input_keys' => array_keys($input),
    ];

    $title = trim((string)($input['title'] ?? ''));
    if ($title === '') {
        flow_api_error('title is required.', 422, 'VALIDATION_ERROR', ['debug' => $debug]);
    }

    $pdo = flow_api_task_db();
    $cols = flow_api_columns($pdo, 'task_master');
    if (!$cols) {
        flow_api_error('task_master schema not mapped.', 500, 'TASK_SCHEMA_MISSING', ['debug' => $debug]);
    }

    $assigneesRaw = $input['assignees'] ?? $input['assignee_emp_ids'] ?? $input['emp_ids'] ?? [$auth['actor_emp_id']];
    $followersRaw = $input['followers'] ?? $input['follower_emp_ids'] ?? [$auth['actor_emp_id']];
    $assignees = array_values(array_unique(array_filter(array_map('intval', (array)$assigneesRaw), static fn(int $id): bool => $id > 0)));
    $followers = array_values(array_unique(array_filter(array_map('intval', (array)$followersRaw), static fn(int $id): bool => $id > 0)));
    if (!$assignees) $assignees = [(int)$auth['actor_emp_id']];
    if (!$followers) $followers = [(int)$auth['actor_emp_id']];

    $deadline = trim((string)($input['deadline'] ?? $input['due_at'] ?? ''));
    if ($deadline === '') $deadline = date('Y-m-d 00:00:00');
    $deadlineTs = strtotime($deadline);
    if ($deadlineTs !== false) $deadline = date('Y-m-d H:i:s', $deadlineTs);

    $data = [
        'title' => mb_substr($title, 0, 4000),
        'description' => (string)($input['description'] ?? $input['details'] ?? ''),
        'priority' => (string)($input['priority'] ?? 'medium'),
        'emp_id' => implode(',', $assignees),
        'task_followers' => implode(',', $followers),
        'task_groups' => (string)($input['task_groups'] ?? $input['group_id'] ?? '99'),
        'task_type' => (string)($input['task_type'] ?? 'general'),
        'deadline' => $deadline,
        'created_by' => (int)$auth['actor_emp_id'],
        'meet_type' => (string)($input['meet_type'] ?? '1'),
        'status' => (int)($input['status'] ?? 0),
        'next_followup_date' => (string)($input['next_followup_date'] ?? ''),
        'vertical' => (string)($input['vertical'] ?? 'general'),
    ];

    $fields = [];
    $values = [];
    $params = [];
    foreach ($data as $field => $value) {
        if (in_array($field, $cols, true)) {
            $fields[] = $field;
            $values[] = ':' . $field;
            $params[':' . $field] = $value;
        }
    }
    if (!$fields) {
        flow_api_error('task_master schema not mapped.', 500, 'TASK_SCHEMA_MISSING', ['debug' => $debug]);
    }

    $stmt = $pdo->prepare('INSERT INTO task_master (' . implode(',', $fields) . ') VALUES (' . implode(',', $values) . ')');
    $stmt->execute($params);
    $id = (int)$pdo->lastInsertId();

    try {
        $updateCols = flow_api_columns($pdo, 'task_explained');
        $taskCol = flow_api_pick($updateCols, ['task_id', 'task_master_id']);
        $commentCol = flow_api_pick($updateCols, ['comments', 'comment', 'description']);
        $updatedByCol = flow_api_pick($updateCols, ['updated_by', 'created_by', 'emp_id']);
        $typeCol = flow_api_pick($updateCols, ['comment_type', 'type']);
        if ($taskCol && $commentCol) {
            $auditFields = [$taskCol, $commentCol];
            $auditValues = [':task_id', ':comments'];
            $auditParams = [':task_id' => $id, ':comments' => 'Task created from external API'];
            if ($updatedByCol) {
                $auditFields[] = $updatedByCol;
                $auditValues[] = ':updated_by';
                $auditParams[':updated_by'] = (int)$auth['actor_emp_id'];
            }
            if ($typeCol) {
                $auditFields[] = $typeCol;
                $auditValues[] = ':comment_type';
                $auditParams[':comment_type'] = 'External API';
            }
            $audit = $pdo->prepare('INSERT INTO task_explained (' . implode(',', $auditFields) . ') VALUES (' . implode(',', $auditValues) . ')');
            $audit->execute($auditParams);
        }
    } catch (Throwable $e) {
        error_log('Flow API task create audit skipped: ' . $e->getMessage());
    }

    flow_api_success($auth, 'tasks:write', [
        'task' => [
            'id' => $id,
            'title' => $title,
            'assignees' => $assignees,
            'followers' => $followers,
            'deadline' => $deadline,
            'handler' => 'physical_task_create_v1',
        ],
    ], 201, 'task', (string)$id);
} catch (PDOException $e) {
    flow_api_audit($auth, 'tasks:write', 500, 'error', $e->getMessage());
    flow_api_error('Database error: ' . $e->getMessage(), 500, 'DATABASE_ERROR');
} catch (Throwable $e) {
    flow_api_audit($auth, 'tasks:write', 500, 'error', $e->getMessage());
    flow_api_error('Server error: ' . $e->getMessage(), 500, 'SERVER_ERROR');
}
