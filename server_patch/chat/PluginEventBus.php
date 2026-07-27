<?php
declare(strict_types=1);

/**
 * Flow Messenger plugin event bus.
 *
 * Core code only emits lifecycle events. Plugin-specific behavior lives in
 * plugin folders that declare manifest metadata and a handler class.
 */
final class FlowPluginEventBus
{
    private const HOOKS = ['message.received', 'message.sent', 'channel.created', 'member.added'];
    private const PLUGIN_ROOT = __DIR__ . '/plugins';
    private static bool $schemaReady = false;
    private static array $manifests = [];

    public static function ensureSchema(PDO $pdo): void
    {
        if (self::$schemaReady) return;
        $pdo->exec("CREATE TABLE IF NOT EXISTS flow_plugins (
            id INT AUTO_INCREMENT PRIMARY KEY,
            plugin_key VARCHAR(120) NOT NULL UNIQUE,
            name VARCHAR(160) NOT NULL,
            version VARCHAR(40) NOT NULL DEFAULT '1.0.0',
            hooks_json TEXT NOT NULL,
            permissions_json TEXT NOT NULL,
            data_access_json TEXT NULL,
            status TINYINT NOT NULL DEFAULT 1,
            installed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_flow_plugins_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        $pdo->exec("CREATE TABLE IF NOT EXISTS flow_plugin_event_logs (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            plugin_key VARCHAR(120) NOT NULL,
            hook VARCHAR(80) NOT NULL,
            event_id VARCHAR(80) NOT NULL,
            duration_ms DECIMAL(12,3) NOT NULL DEFAULT 0,
            status VARCHAR(24) NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_plugin_event_hook (hook, created_at),
            INDEX idx_plugin_event_plugin (plugin_key, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        $pdo->exec("CREATE TABLE IF NOT EXISTS flow_plugin_error_logs (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            plugin_key VARCHAR(120) NOT NULL,
            hook VARCHAR(80) NOT NULL,
            event_id VARCHAR(80) NOT NULL,
            error_type VARCHAR(120) NOT NULL,
            error_message TEXT NOT NULL,
            payload_preview TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_plugin_error_hook (hook, created_at),
            INDEX idx_plugin_error_plugin (plugin_key, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        $pdo->exec("CREATE TABLE IF NOT EXISTS flow_plugin_artifacts (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            plugin_key VARCHAR(120) NOT NULL,
            hook VARCHAR(80) NOT NULL,
            source_type VARCHAR(80) NOT NULL,
            source_id VARCHAR(120) NOT NULL,
            artifact_type VARCHAR(80) NOT NULL,
            artifact_json MEDIUMTEXT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_plugin_artifact_source (source_type, source_id),
            INDEX idx_plugin_artifact_plugin (plugin_key, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        self::$schemaReady = true;
    }

    public static function emit(PDO $pdo, string $hook, array $payload): void
    {
        if (!in_array($hook, self::HOOKS, true)) return;
        try {
            self::ensureSchema($pdo);
            self::syncManifests($pdo);
            $plugins = self::listeners($pdo, $hook);
        } catch (Throwable $e) {
            error_log('flow plugin bus bootstrap skipped: ' . $e->getMessage());
            return;
        }

        $eventId = $payload['event_id'] ?? (str_replace('.', '-', $hook) . '-' . bin2hex(random_bytes(8)));
        $payload['event_id'] = $eventId;
        $payload['hook'] = $hook;
        $payload['emitted_at'] = date('c');

        foreach ($plugins as $plugin) {
            self::runPlugin($pdo, $plugin, $hook, $payload);
        }
    }

    public static function artifact(PDO $pdo, string $pluginKey, string $hook, string $sourceType, string $sourceId, string $artifactType, array $artifact): void
    {
        self::ensureSchema($pdo);
        $stmt = $pdo->prepare('INSERT INTO flow_plugin_artifacts (plugin_key, hook, source_type, source_id, artifact_type, artifact_json) VALUES (:plugin, :hook, :source_type, :source_id, :artifact_type, :artifact_json)');
        $stmt->execute([
            ':plugin' => $pluginKey,
            ':hook' => $hook,
            ':source_type' => $sourceType,
            ':source_id' => $sourceId,
            ':artifact_type' => $artifactType,
            ':artifact_json' => json_encode($artifact, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ]);
    }

    private static function syncManifests(PDO $pdo): void
    {
        foreach (self::manifests() as $manifest) {
            $hooks = array_values(array_intersect(self::HOOKS, $manifest['hooks'] ?? []));
            if (!$hooks) continue;
            $stmt = $pdo->prepare('INSERT INTO flow_plugins (plugin_key, name, version, hooks_json, permissions_json, data_access_json, status) VALUES (:plugin_key, :name, :version, :hooks, :permissions, :data_access, :status) ON DUPLICATE KEY UPDATE name = VALUES(name), version = VALUES(version), hooks_json = VALUES(hooks_json), permissions_json = VALUES(permissions_json), data_access_json = VALUES(data_access_json)');
            $stmt->execute([
                ':plugin_key' => (string)$manifest['plugin_key'],
                ':name' => (string)$manifest['name'],
                ':version' => (string)($manifest['version'] ?? '1.0.0'),
                ':hooks' => json_encode($hooks),
                ':permissions' => json_encode($manifest['permissions'] ?? []),
                ':data_access' => json_encode($manifest['data_access'] ?? []),
                ':status' => (int)($manifest['enabled_by_default'] ?? 1),
            ]);
        }
    }

    private static function manifests(): array
    {
        if (self::$manifests) return self::$manifests;
        if (!is_dir(self::PLUGIN_ROOT)) return [];
        foreach (glob(self::PLUGIN_ROOT . '/*/manifest.php') ?: [] as $file) {
            try {
                $manifest = require $file;
                if (!is_array($manifest) || empty($manifest['plugin_key']) || empty($manifest['handler'])) continue;
                $manifest['_base_dir'] = dirname($file);
                self::$manifests[(string)$manifest['plugin_key']] = $manifest;
            } catch (Throwable $e) {
                error_log('flow plugin manifest skipped: ' . $e->getMessage());
            }
        }
        return self::$manifests;
    }

    private static function listeners(PDO $pdo, string $hook): array
    {
        $stmt = $pdo->prepare('SELECT plugin_key, hooks_json, permissions_json, data_access_json FROM flow_plugins WHERE status = 1');
        $stmt->execute();
        $listeners = [];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $hooks = json_decode((string)$row['hooks_json'], true);
            if (!is_array($hooks) || !in_array($hook, $hooks, true)) continue;
            $manifest = self::manifests()[(string)$row['plugin_key']] ?? null;
            if (!$manifest) continue;
            $manifest['_db_permissions'] = json_decode((string)$row['permissions_json'], true) ?: [];
            $manifest['_db_data_access'] = json_decode((string)$row['data_access_json'], true) ?: [];
            $listeners[] = $manifest;
        }
        return $listeners;
    }

    private static function runPlugin(PDO $pdo, array $plugin, string $hook, array $payload): void
    {
        $pluginKey = (string)$plugin['plugin_key'];
        $eventId = (string)($payload['event_id'] ?? 'unknown');
        $started = microtime(true);
        try {
            $handlerFile = rtrim((string)$plugin['_base_dir'], '/\\') . '/' . ltrim((string)$plugin['handler'], '/\\');
            if (!is_file($handlerFile)) throw new RuntimeException('Plugin handler file not found.');
            require_once $handlerFile;
            $class = (string)($plugin['handler_class'] ?? 'Plugin');
            if (!class_exists($class)) throw new RuntimeException('Plugin handler class not found: ' . $class);
            $context = new FlowPluginContext($pdo, $pluginKey, $plugin['_db_permissions'] ?? [], $plugin['_db_data_access'] ?? []);
            $handler = new $class();
            if (!method_exists($handler, 'handle')) throw new RuntimeException('Plugin handler must expose handle().');
            $handler->handle($hook, self::sandboxPayload($payload, $plugin['_db_data_access'] ?? []), $context);
            self::logEvent($pdo, $pluginKey, $hook, $eventId, (microtime(true) - $started) * 1000, 'success');
        } catch (Throwable $e) {
            self::logEvent($pdo, $pluginKey, $hook, $eventId, (microtime(true) - $started) * 1000, 'error');
            self::logError($pdo, $pluginKey, $hook, $eventId, $e, $payload);
        }
    }

    private static function sandboxPayload(array $payload, array $dataAccess): array
    {
        $allowed = $dataAccess['message_fields'] ?? null;
        if (!is_array($allowed) || empty($payload['message']) || !is_array($payload['message'])) return $payload;
        $payload['message'] = array_intersect_key($payload['message'], array_flip($allowed));
        return $payload;
    }

    private static function logEvent(PDO $pdo, string $pluginKey, string $hook, string $eventId, float $durationMs, string $status): void
    {
        $stmt = $pdo->prepare('INSERT INTO flow_plugin_event_logs (plugin_key, hook, event_id, duration_ms, status) VALUES (:plugin, :hook, :event, :duration, :status)');
        $stmt->execute([':plugin' => $pluginKey, ':hook' => $hook, ':event' => $eventId, ':duration' => $durationMs, ':status' => $status]);
    }

    private static function logError(PDO $pdo, string $pluginKey, string $hook, string $eventId, Throwable $e, array $payload): void
    {
        try {
            $stmt = $pdo->prepare('INSERT INTO flow_plugin_error_logs (plugin_key, hook, event_id, error_type, error_message, payload_preview) VALUES (:plugin, :hook, :event, :type, :message, :payload)');
            $stmt->execute([
                ':plugin' => $pluginKey,
                ':hook' => $hook,
                ':event' => $eventId,
                ':type' => get_class($e),
                ':message' => $e->getMessage(),
                ':payload' => substr(json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: '', 0, 4000),
            ]);
        } catch (Throwable $ignored) {
            error_log('flow plugin error log failed: ' . $ignored->getMessage());
        }
    }
}

final class FlowPluginContext
{
    public function __construct(
        private PDO $pdo,
        private string $pluginKey,
        private array $permissions,
        private array $dataAccess
    ) {}

    public function pdo(): PDO
    {
        if (!in_array('db.write_artifacts', $this->permissions, true) && !in_array('db.read', $this->permissions, true)) {
            throw new RuntimeException('Plugin does not have database permission.');
        }
        return $this->pdo;
    }

    public function saveArtifact(string $hook, string $sourceType, string $sourceId, string $artifactType, array $artifact): void
    {
        if (!in_array('db.write_artifacts', $this->permissions, true)) {
            throw new RuntimeException('Plugin does not have artifact write permission.');
        }
        FlowPluginEventBus::artifact($this->pdo, $this->pluginKey, $hook, $sourceType, $sourceId, $artifactType, $artifact);
    }
}

function flow_plugin_emit(PDO $pdo, string $hook, array $payload): void
{
    FlowPluginEventBus::emit($pdo, $hook, $payload);
}
