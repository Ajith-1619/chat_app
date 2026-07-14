# Watchtower Flow Environment

Last updated: 2026-07-14

This document records the database environment used by the Watchtower Flow / Skylink Chat application as found in this repository. The PHP deployment keeps the actual connection helpers in external files referenced by `server_patch/chat/bootstrap.php`:

- `../config.php`
- `../db.php`

Those files are not present in this workspace, so database names, hosts, usernames, and passwords are deployment-owned values. The application code uses these connection helpers:

- `getDB()` / `chat_db()` for the primary chat database.
- `getTaskDB()` for the legacy task/location database, with fallback to chat DB.
- `getEmployeeDB()` for employee, attendance, and leave data, with fallback to chat DB.

## Database Groups

### 1. Primary Chat Database

Purpose: XMPP chat persistence, groups/channels, messages, files, read receipts, reminders, notifications, release management, location visibility, diagnostics, and channel architecture.

Main schema source:

- `server_patch/chat/bootstrap.php`
- `server_patch/chat/chat_schema.sql`

The schema is auto-created/extended by `chat_ensure_schema(PDO $pdo)`. Existing installations are migrated through `chat_ensure_column(...)`, so production tables may contain extra legacy columns.

### 2. Task Database

Purpose: My Hub tasks, task creation, task details, task updates, task followers, location tracking mirror tables.

Main source:

- `server_patch/chat/myhub.php`
- `server_patch/chat/task_update.php`
- `server_patch/chat/location_update.php`
- `server_patch/chat/attendance.php`

The app detects columns through `INFORMATION_SCHEMA.COLUMNS`, so it supports legacy variations.

### 3. Employee / HR Database

Purpose: employee directory, attendance punch data, leave requests, leave OTP workflow.

Main source:

- `server_patch/chat/myhub.php`
- `server_patch/chat/attendance.php`

The app detects employee table and column names dynamically.

## Primary Chat Tables

### `xmpp_users`

Purpose: Maps internal employee IDs to XMPP JIDs and profile avatars.

Columns:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL UNIQUE`
- `jid VARCHAR(255) NOT NULL UNIQUE`
- `avatar_url VARCHAR(500) NULL`
- `xmpp_password VARCHAR(255) NOT NULL`
- `status TINYINT NOT NULL DEFAULT 1`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Used by:

- Login/session setup
- user profile
- group member avatar lookup
- XMPP account ensure flow

### `xmpp_groups`

Purpose: Common table for groups and channels.

Columns:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `room_name VARCHAR(150) NOT NULL`
- `room_jid VARCHAR(255) NOT NULL UNIQUE`
- `avatar_url VARCHAR(500) NULL`
- `group_type VARCHAR(20) NOT NULL DEFAULT 'group'`
- `channel_kind VARCHAR(40) NOT NULL DEFAULT 'operational'`
- `channel_definition_id INT NULL`
- `channel_template_key VARCHAR(80) NULL`
- `status VARCHAR(40) NOT NULL DEFAULT 'Open'`
- `target_date DATETIME NULL`
- `next_action_date DATETIME NULL`
- `sla_minutes INT NULL`
- `priority VARCHAR(20) NOT NULL DEFAULT 'Normal'`
- `owner_emp_id INT NULL`
- `stale_alert_minutes INT NULL`
- `metadata_json TEXT NULL`
- `wakeup_enabled TINYINT NOT NULL DEFAULT 0`
- `wakeup_interval_minutes INT NOT NULL DEFAULT 1440`
- `wakeup_last_sent_at DATETIME NULL`
- `wakeup_updated_by_emp_id INT NULL`
- `wakeup_updated_at DATETIME NULL`
- `is_archived TINYINT NOT NULL DEFAULT 0`
- `archived_at DATETIME NULL`
- `created_by_emp_id INT NOT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `UNIQUE(room_jid)`
- `idx_xmpp_groups_archived_type_created (is_archived, group_type, created_at)`

Used by:

- group/channel creation
- channel profile
- wake-up notification
- archived channels
- channel dashboard
- recent chats
- channel architecture

### `xmpp_group_members`

Purpose: Group/channel membership and role control.

Columns:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `group_id INT NOT NULL`
- `emp_id INT NOT NULL`
- `role VARCHAR(16) NOT NULL DEFAULT 'member'`
- `joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `UNIQUE KEY uq_xmpp_group_member (group_id, emp_id)`
- `idx_xmpp_group_members_emp_group (emp_id, group_id)`

Roles used:

- `owner`
- `admin`
- `member`

Used by:

- group member list
- @ mention user list
- admin add/remove member
- access checks
- recent group list

### `xmpp_messages`

Purpose: Main message store for direct chats, group chats, attachments, location metadata, read metadata, edits, deletes, replies, forwarding, and checklist/contact/location cards.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `from_jid VARCHAR(255) NOT NULL`
- `to_jid VARCHAR(255) NOT NULL`
- `body TEXT NOT NULL`
- `file_url VARCHAR(500) NULL`
- `file_name VARCHAR(255) NULL`
- `file_type VARCHAR(255) NULL`
- `file_size BIGINT NOT NULL DEFAULT 0`
- `latitude DECIMAL(10,7) NULL`
- `longitude DECIMAL(10,7) NULL`
- `location_address VARCHAR(500) NULL`
- `read_latitude DECIMAL(10,7) NULL`
- `read_longitude DECIMAL(10,7) NULL`
- `read_location_address VARCHAR(500) NULL`
- `message_type VARCHAR(24) NOT NULL DEFAULT 'chat'`
- `reply_to_id BIGINT NULL`
- `thread_root_id BIGINT NULL`
- `mentions_json TEXT NULL`
- `client_message_id VARCHAR(80) NULL`
- `forwarded_from_message_id BIGINT NULL`
- `original_sender_jid VARCHAR(255) NULL`
- `original_sender_name VARCHAR(255) NULL`
- `original_source_name VARCHAR(160) NULL`
- `source_device VARCHAR(32) NOT NULL DEFAULT 'unknown'`
- `source_name VARCHAR(120) NULL`
- `read_source_device VARCHAR(32) NULL`
- `read_source_name VARCHAR(160) NULL`
- `status VARCHAR(24) NOT NULL DEFAULT 'sent'`
- `read_at DATETIME NULL`
- `deleted_at DATETIME NULL`
- `edited_at DATETIME NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_xmpp_messages_from_created (from_jid, created_at)`
- `idx_xmpp_messages_to_created (to_jid, created_at)`
- `uq_xmpp_messages_client_id (from_jid, client_message_id)`
- `idx_xmpp_messages_to_id_deleted (to_jid, id, deleted_at)`
- `idx_xmpp_messages_from_to_id (from_jid, to_jid, id)`
- `idx_xmpp_messages_created_id (created_at, id)`

Important behavior:

- Normal messages can store send/read latitude, longitude, and address as metadata.
- Explicit current/live location messages are represented as location-style message payloads and map cards in the UI.
- `file_type` is widened to `VARCHAR(255)` for arbitrary MIME/file identifiers.

Used by:

- send message
- history
- message info
- read receipt
- copy/reply/forward/pin/star/reaction/edit/delete
- scheduled messages
- system notifications
- wake-up notifications

### `xmpp_group_reads`

Purpose: Per-user group/channel read positions and read location metadata.

Columns:

- `group_id INT NOT NULL`
- `emp_id INT NOT NULL`
- `last_read_message_id BIGINT NOT NULL DEFAULT 0`
- `read_at DATETIME NULL`
- `read_latitude DECIMAL(10,7) NULL`
- `read_longitude DECIMAL(10,7) NULL`
- `read_location_address VARCHAR(500) NULL`
- `read_source_device VARCHAR(32) NULL`
- `read_source_name VARCHAR(160) NULL`

Primary key:

- `(group_id, emp_id)`

Used by:

- group unread count
- group message info
- group read address

### `xmpp_push_tokens`

Purpose: Stores device push tokens.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL`
- `token VARCHAR(512) NOT NULL UNIQUE`
- `platform VARCHAR(32) NOT NULL DEFAULT 'android'`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Indexes:

- `idx_xmpp_push_tokens_emp (emp_id)`

Used by:

- `register_push_token.php`
- push notification dispatch

### `xmpp_push_queue`

Purpose: Async push queue so message send is not blocked by push notification latency.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `sender_emp_id INT NOT NULL`
- `sender_name VARCHAR(160) NOT NULL`
- `to_jid VARCHAR(255) NOT NULL`
- `body TEXT NOT NULL`
- `file_name VARCHAR(255) NULL`
- `group_name VARCHAR(160) NULL`
- `mentioned_emp_ids TEXT NULL`
- `status VARCHAR(20) NOT NULL DEFAULT 'pending'`
- `attempts INT NOT NULL DEFAULT 0`
- `error VARCHAR(500) NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Used by:

- `chat_enqueue_push_notification`
- `push_worker.php`
- send message performance flow

### `xmpp_user_presence`

Purpose: User online/last seen state.

Columns:

- `emp_id INT PRIMARY KEY`
- `last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Indexes:

- `idx_xmpp_user_presence_seen (last_seen_at)`

Used by:

- presence API
- recent chats online filter
- profile last seen

### `xmpp_app_sessions`

Purpose: Tracks logged-in app/browser/device sessions.

Columns:

- `session_id VARCHAR(128) PRIMARY KEY`
- `emp_id INT NOT NULL`
- `device_id VARCHAR(255) NOT NULL`
- `device_name VARCHAR(160) NOT NULL`
- `platform VARCHAR(32) NOT NULL`
- `app_source VARCHAR(32) NOT NULL DEFAULT 'mobile'`
- `ip_address VARCHAR(64) NULL`
- `last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `revoked_at DATETIME NULL`

Indexes:

- `UNIQUE KEY uq_app_session_device (emp_id, device_id)`

Used by:

- sessions screen
- profile launched sessions
- presence fallback

### `xmpp_location_visibility`

Purpose: Controls which users are allowed to see location metadata under messages and in Message Info.

Columns:

- `emp_id INT NOT NULL PRIMARY KEY`
- `enabled TINYINT NOT NULL DEFAULT 0`
- `updated_by_emp_id INT NULL`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_location_visibility_enabled (enabled, emp_id)`

Default seed:

- Emp `116` enabled by `302`
- Emp `302` enabled by `302`

Used by:

- location visibility API
- message location address display
- Message Info send/read address visibility

### `xmpp_location_tracking`

Purpose: Stores active attendance/live tracking sessions.

Columns:

- `emp_id INT NOT NULL PRIMARY KEY`
- `token_hash CHAR(64) NOT NULL UNIQUE`
- `shift_id INT NULL`
- `active TINYINT NOT NULL DEFAULT 1`
- `started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `stopped_at DATETIME NULL`
- `last_location_at DATETIME NULL`

Indexes:

- `idx_location_tracking_token (token_hash, active)`

Used by:

- attendance start/stop tracking
- background location update token validation
- offline monitor

### `xmpp_offline_alerts`

Purpose: Tracks offline/location missing alerts for monitored employees.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL`
- `manager_emp_id INT NULL`
- `offline_seconds INT NOT NULL DEFAULT 0`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_offline_alert_emp_created (emp_id, created_at)`

Used by:

- `offline_alert.php`
- `offline_monitor.php`

### `xmpp_geocode_cache`

Purpose: Caches reverse geocoded addresses for latitude/longitude metadata.

Columns:

- `lat_key VARCHAR(32) NOT NULL`
- `lng_key VARCHAR(32) NOT NULL`
- `address VARCHAR(500) NOT NULL`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Primary key:

- `(lat_key, lng_key)`

Used by:

- `chat_reverse_geocode_address`
- message send/read address enrichment

### `xmpp_saved_messages`

Purpose: Saved/bookmarked personal messages.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL`
- `body TEXT NOT NULL`
- `file_url VARCHAR(500) NULL`
- `file_name VARCHAR(255) NULL`
- `file_type VARCHAR(100) NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_saved_emp_created (emp_id, created_at)`

### `xmpp_reminders`

Purpose: Reminder/follow-up records created from chat or My Hub.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `kind VARCHAR(20) NOT NULL DEFAULT 'reminder'`
- `title VARCHAR(255) NOT NULL`
- `notes TEXT NULL`
- `created_by_emp_id INT NOT NULL`
- `assignee_ids_json TEXT NOT NULL`
- `source_conversation_jid VARCHAR(255) NULL`
- `source_conversation_name VARCHAR(160) NULL`
- `source_message_id BIGINT NULL`
- `source_message_text TEXT NULL`
- `starts_at DATETIME NOT NULL`
- `next_due_at DATETIME NULL`
- `recurrence_type VARCHAR(20) NOT NULL DEFAULT 'once'`
- `custom_interval INT NOT NULL DEFAULT 1`
- `custom_unit VARCHAR(12) NOT NULL DEFAULT 'week'`
- `weekdays_json TEXT NULL`
- `month_days_json TEXT NULL`
- `active TINYINT NOT NULL DEFAULT 1`
- `stopped_at DATETIME NULL`
- `stopped_by_emp_id INT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Indexes:

- `idx_reminders_creator_active (created_by_emp_id, active, starts_at)`

### `xmpp_notification_events`

Purpose: In-app notification feed and reminder notification dedupe.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL`
- `event_key VARCHAR(190) NOT NULL`
- `event_type VARCHAR(30) NOT NULL`
- `reminder_id BIGINT NULL`
- `title VARCHAR(255) NOT NULL`
- `body TEXT NOT NULL`
- `viewed_at DATETIME NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `UNIQUE KEY uq_notification_event (event_key)`
- `idx_notification_emp_viewed (emp_id, viewed_at, id)`

### `xmpp_scheduled_messages`

Purpose: Scheduled chat messages.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `created_by_emp_id INT NOT NULL`
- `body TEXT NOT NULL`
- `scheduled_at DATETIME NOT NULL`
- `silent TINYINT NOT NULL DEFAULT 0`
- `status VARCHAR(20) NOT NULL DEFAULT 'scheduled'`
- `completed_at DATETIME NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_scheduled_due (status, scheduled_at)`
- `idx_scheduled_creator (created_by_emp_id, scheduled_at)`

### `xmpp_scheduled_message_targets`

Purpose: Per-recipient delivery state for scheduled messages.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `schedule_id BIGINT NOT NULL`
- `target_jid VARCHAR(255) NOT NULL`
- `status VARCHAR(20) NOT NULL DEFAULT 'pending'`
- `attempts INT NOT NULL DEFAULT 0`
- `message_id BIGINT NULL`
- `last_error VARCHAR(500) NULL`
- `sent_at DATETIME NULL`

Indexes:

- `UNIQUE KEY uq_scheduled_target (schedule_id, target_jid)`
- `idx_scheduled_target_status (status, schedule_id)`

### `xmpp_mutes`

Purpose: Per-user conversation mute state.

Columns:

- `emp_id INT NOT NULL`
- `target_jid VARCHAR(255) NOT NULL`
- `muted_until DATETIME NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Primary key:

- `(emp_id, target_jid)`

### `xmpp_message_pins`

Purpose: Pinned messages per conversation.

Columns:

- `message_id BIGINT NOT NULL`
- `conversation_jid VARCHAR(255) NOT NULL`
- `pinned_by_emp_id INT NOT NULL`
- `pinned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Primary key:

- `(message_id, conversation_jid)`

Indexes:

- `idx_message_pins_conversation (conversation_jid, pinned_at)`

### `xmpp_message_reactions`

Purpose: Emoji/reaction state.

Columns:

- `message_id BIGINT NOT NULL`
- `emp_id INT NOT NULL`
- `reaction VARCHAR(16) NOT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Primary key:

- `(message_id, emp_id)`

### `xmpp_message_stars`

Purpose: Star/bookmark state.

Columns:

- `message_id BIGINT NOT NULL`
- `emp_id INT NOT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Primary key:

- `(message_id, emp_id)`

### `xmpp_conversation_preferences`

Purpose: Per-user pinned/starred conversation settings.

Columns:

- `emp_id INT NOT NULL`
- `target_jid VARCHAR(255) NOT NULL`
- `is_pinned TINYINT NOT NULL DEFAULT 0`
- `is_starred TINYINT NOT NULL DEFAULT 0`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Primary key:

- `(emp_id, target_jid)`

### `xmpp_drafts`

Purpose: Message composer draft persistence.

Columns:

- `emp_id INT NOT NULL`
- `conversation_jid VARCHAR(255) NOT NULL`
- `body TEXT NOT NULL`
- `reply_to_id BIGINT NULL`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Primary key:

- `(emp_id, conversation_jid)`

### `xmpp_read_positions`

Purpose: Per-conversation direct read position.

Columns:

- `emp_id INT NOT NULL`
- `conversation_jid VARCHAR(255) NOT NULL`
- `message_id BIGINT NOT NULL DEFAULT 0`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Primary key:

- `(emp_id, conversation_jid)`

### `xmpp_diagnostic_traces`

Purpose: Performance diagnostics for selected users.

Columns used by code:

- `emp_id`
- `trace_id`
- `category`
- `operation`
- `duration_ms`
- `status`
- `metadata_json`

Used by:

- send message timing
- diagnostics report
- API performance audit

### `xmpp_release_builds`

Purpose: Release management records for Android, Windows, Linux/Web build artifacts.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `platform VARCHAR(24) NOT NULL DEFAULT 'android'`
- `version VARCHAR(32) NOT NULL`
- `build_number INT NOT NULL DEFAULT 0`
- `stage VARCHAR(24) NOT NULL DEFAULT 'Development'`
- `status VARCHAR(24) NOT NULL DEFAULT 'Draft'`
- `apk_url VARCHAR(500) NULL`
- `notes TEXT NULL`
- `rollout_percent INT NOT NULL DEFAULT 0`
- `force_update TINYINT NOT NULL DEFAULT 0`
- `uploaded_by_emp_id INT NOT NULL`
- `approved_by_emp_id INT NULL`
- `approved_at DATETIME NULL`
- `deployed_at DATETIME NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `UNIQUE KEY uq_release_platform_version_build (platform, version, build_number)`
- `idx_release_lookup (platform, stage, status, created_at)`

Approval rule:

- Production approval is restricted to employee `302`.

### `xmpp_release_history`

Purpose: Audit trail for release actions.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `release_id BIGINT NOT NULL`
- `actor_emp_id INT NOT NULL`
- `action VARCHAR(40) NOT NULL`
- `from_status VARCHAR(24) NULL`
- `to_status VARCHAR(24) NULL`
- `notes TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_release_history_release (release_id, created_at)`

### `xmpp_release_notes`

Purpose: Release notes shown in app.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `platform VARCHAR(24) NOT NULL DEFAULT 'android'`
- `version VARCHAR(32) NOT NULL`
- `release_date DATE NOT NULL`
- `new_features TEXT NULL`
- `improvements TEXT NULL`
- `bug_fixes TEXT NULL`
- `security_updates TEXT NULL`
- `implementation_details TEXT NULL`
- `created_by_emp_id INT NULL`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `UNIQUE KEY uq_release_notes_platform_version (platform, version)`
- `idx_release_notes_lookup (platform, version, release_date)`

### `xmpp_release_note_views`

Purpose: Tracks which users viewed release notes.

Columns:

- `release_note_id BIGINT NOT NULL`
- `emp_id INT NOT NULL`
- `viewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Primary key:

- `(release_note_id, emp_id)`

Indexes:

- `idx_release_note_views_emp (emp_id, viewed_at)`

### `xmpp_channel_definitions`

Purpose: Metadata-driven channel type definitions. A channel type controls behavior, not just label.

Columns:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `type_key VARCHAR(40) NOT NULL UNIQUE`
- `name VARCHAR(80) NOT NULL`
- `description TEXT NULL`
- `ui_schema_json TEXT NULL`
- `ai_marshal_json TEXT NULL`
- `sop_json TEXT NULL`
- `sla_json TEXT NULL`
- `kpi_json TEXT NULL`
- `checklist_json TEXT NULL`
- `permissions_json TEXT NULL`
- `widgets_json TEXT NULL`
- `workflows_json TEXT NULL`
- `extension_table VARCHAR(80) NULL`
- `active TINYINT NOT NULL DEFAULT 1`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

Indexes:

- `idx_channel_definitions_active (active, type_key)`

Default channel types:

- `incident`
- `action`
- `operational`
- `project`
- `announcement`

### `xmpp_channel_relationships`

Purpose: Links channels together with relationship metadata.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `source_group_id INT NOT NULL`
- `target_group_id INT NOT NULL`
- `relationship_type VARCHAR(40) NOT NULL`
- `metadata_json TEXT NULL`
- `created_by_emp_id INT NOT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_channel_relationship_source (source_group_id, relationship_type)`
- `idx_channel_relationship_target (target_group_id, relationship_type)`
- `UNIQUE KEY uq_channel_relationship (source_group_id, target_group_id, relationship_type)`

Examples:

- Incident to Action
- Operational to Incident
- Project to Action

### `xmpp_channel_audit_log`

Purpose: Full audit history for channel changes and relationships.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `group_id INT NOT NULL`
- `event_type VARCHAR(80) NOT NULL`
- `actor_emp_id INT NULL`
- `old_json TEXT NULL`
- `new_json TEXT NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_channel_audit_group_created (group_id, created_at)`
- `idx_channel_audit_event (event_type, created_at)`

### `xmpp_channel_timeline`

Purpose: Channel event stream/timeline.

Columns:

- `id BIGINT AUTO_INCREMENT PRIMARY KEY`
- `group_id INT NOT NULL`
- `event_type VARCHAR(80) NOT NULL`
- `body TEXT NOT NULL`
- `actor_emp_id INT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_channel_timeline_group (group_id, created_at)`

### Channel Extension Tables

Each extension table is keyed by `group_id` and stores type-specific fields plus `metadata_json`.

#### `xmpp_channel_incident`

- `group_id INT NOT NULL PRIMARY KEY`
- `severity VARCHAR(20) NULL`
- `impact_scope VARCHAR(120) NULL`
- `root_cause TEXT NULL`
- `resolution_summary TEXT NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

#### `xmpp_channel_action`

- `group_id INT NOT NULL PRIMARY KEY`
- `action_owner_emp_id INT NULL`
- `due_at DATETIME NULL`
- `completion_notes TEXT NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

#### `xmpp_channel_operational`

- `group_id INT NOT NULL PRIMARY KEY`
- `ops_area VARCHAR(120) NULL`
- `cadence VARCHAR(40) NULL`
- `escalation_policy VARCHAR(120) NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

#### `xmpp_channel_project`

- `group_id INT NOT NULL PRIMARY KEY`
- `project_code VARCHAR(80) NULL`
- `milestone VARCHAR(160) NULL`
- `budget_ref VARCHAR(120) NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

#### `xmpp_channel_announcement`

- `group_id INT NOT NULL PRIMARY KEY`
- `audience VARCHAR(160) NULL`
- `publish_at DATETIME NULL`
- `expires_at DATETIME NULL`
- `metadata_json TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`

## Task Database Tables

### `task_master`

Purpose: Main task table used by My Hub task list, create task, task detail, and task filtering.

Known production structure from user-provided table screenshot and code:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `title LONGTEXT`
- `priority VARCHAR(50)`
- `emp_id VARCHAR(200)`
- `task_followers VARCHAR(200)`
- `task_groups VARCHAR(200)`
- `task_type VARCHAR(100)`
- `deadline DATETIME`
- `description LONGTEXT`
- `created_by INT`
- `meet_type VARCHAR(100)`
- `status INT`
- `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- `updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- `next_followup_date VARCHAR(100)`
- `vertical VARCHAR(100)`

Supported alternate columns:

- `due_date` instead of `deadline`
- `task_description` instead of `description`
- `followed_by` instead of `task_followers`

Important behavior:

- App shows tasks where current user is creator, assignee, or follower.
- `emp_id` and follower fields are comma-separated employee ID lists.
- Status `2` is treated as active/open.
- Status `3`, `4`, `5` are treated as closed.
- Status `1` is treated as request-close.

### `task_explained`

Purpose: Task updates/comments/audit rows.

Columns used by code:

- `task_id`
- `comments`
- `updated_by`
- `comment_type`

Optional columns detected in detail view:

- `id`
- `file_path`
- `created_at`
- `updated_at`
- `next_followup_date`

Used by:

- task creation audit row
- task update from chat
- task detail timeline

### `task_updates` / `task_comments`

Purpose: Legacy fallback update tables if `task_explained` is not present.

Supported column variants:

- task key: `task_id`, `task_master_id`
- comment: `comments`, `comment`, `description`, `remarks`, `update_text`
- updater: `updated_by`, `created_by`, `emp_id`
- file: `file_path`, `attachment`, `file_url`
- created timestamp: `created_at`, `updated_at`, `date`, `created_on`
- updated timestamp: `updated_at`, `created_at`, `date`, `updated_on`
- follow-up: `next_followup_date`, `followup_date`, `next_action_date`
- type: `comment_type`, `type`, `update_type`

### `tbl_location_track_inch`

Purpose: Legacy location tracking bridge for attendance/location.

Columns used by code:

- `emp_id`
- `chat_id`
- `current_status`
- `updated_at`
- `id`

Status values written:

- `Punched in`
- `Location Off`

Used by:

- attendance start/stop tracking
- location update to resolve `chat_id`

### `locations_test`

Purpose: Stores periodic location samples from active tracking sessions.

Columns used by code:

- `user_id`
- `latitude`
- `longitude`
- `timestamp`
- `date_created`
- `username`
- `ip_address`

Used by:

- `location_update.php`

## Employee / HR Tables

### Employee Directory Table

Purpose: Search and resolve employee details for My Hub, group membership, mentions, task assignees, and task followers.

Supported table names:

- `employee`
- `employees`
- `users`
- `tbl_employee`

Supported ID columns:

- `emp_id`
- `employee_id`
- `user_id`
- `id`

Supported name columns:

- `name`
- `employee_name`
- `emp_name`
- `full_name`
- `username`

Supported designation columns:

- `designation`
- `role`
- `position`
- `department`
- `emp_type`

Supported phone columns:

- `mobile`
- `mobile_no`
- `contact_no`
- `contact_number`
- `phone`
- `phone_number`
- `official_mobile`
- `personal_mobile`

Optional status behavior:

- If `status` exists, active employees are filtered by `1`, `'1'`, `active`, or `working`.

### `punch`

Purpose: Attendance punch-in/punch-out data.

Columns used by code:

- `id`
- `emp_id`
- `shift_id`
- `punch_in`
- `punch_out`
- `date_created`
- `out_time`

Important behavior:

- Current day attendance is selected by `DATE(date_created) = CURDATE()`.
- Last 7 days and current month are loaded from this table.
- `punch_in` and `punch_out` may be epoch values; fallback display uses `date_created` and `out_time`.

### `track_leave_request`

Purpose: Leave request storage.

Columns used by code:

- employee key: `emp_id`, `employee_id`, or `user_id`
- `from_date`
- `to_date`
- `leave_type_id`
- `approval_status`
- reason: `reason` or `leave_reason`
- days: `no_of_days`, `nodays`, `total_days`, `leave_days`, or `days_count`
- `created_at`

Behavior:

- Leave list reads latest 120 requests.
- Leave apply inserts after OTP verification.
- `approval_status` is inserted as `0` when column exists.

### `xmpp_leave_otp_requests`

Purpose: Leave approval OTP workflow.

This table is created in the employee/HR DB connection used by My Hub leave flow.

Columns:

- `id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY`
- `emp_id INT NOT NULL`
- `approver_emp_id INT NOT NULL DEFAULT 232`
- `request_key VARCHAR(64) NOT NULL`
- `from_date DATE NOT NULL`
- `to_date DATE NOT NULL`
- `leave_type_id INT NOT NULL DEFAULT 2`
- `reason TEXT NULL`
- `no_of_days DECIMAL(6,2) NOT NULL DEFAULT 0`
- `otp_code VARCHAR(12) NOT NULL`
- `requested_at DATETIME NOT NULL`
- `expires_at DATETIME NOT NULL`
- `verified_at DATETIME NULL`
- `consumed_at DATETIME NULL`
- `notification_message_id BIGINT NULL`

Indexes:

- `UNIQUE KEY uniq_request_key (request_key)`
- `KEY idx_emp_pending (emp_id, consumed_at, expires_at)`

Behavior:

- OTP is sent to approver employee `232` using system notification.
- OTP expires after 3 days.
- Consumed OTP cannot be reused.

## Filesystem / Upload Environment

Upload handling is database-backed through `xmpp_messages.file_url`, with files stored under the server upload path returned by upload APIs.

Relevant behavior:

- `file_url`, `file_name`, `file_type`, and `file_size` are persisted in `xmpp_messages`.
- Optional encrypted restricted uploads use `SKYLINK_UPLOAD_ENCRYPTION_KEY`.
- Encryption format marker is `SKYENC1`.
- Upload metadata sidecar file stores MIME, original name, encryption flag, and plain size.

## External Services / Constants

Defined in `server_patch/chat/bootstrap.php`:

- `SKYCHAT_DOMAIN = chat.skylinkonline.net`
- `SKYCHAT_MUC_DOMAIN = conference.chat.skylinkonline.net`
- `SKYCHAT_UPLOAD_DOMAIN = upload.chat.skylinkonline.net`
- `SKYCHAT_SYSTEM_NOTIFICATION_JID = notification@chat.skylinkonline.net`
- `SKYCHAT_WEBSOCKET_URL = wss://chat.skylinkonline.net:5280/xmpp-websocket`
- `SKYCHAT_BOSH_URL = https://chat.skylinkonline.net:5443/bosh`
- `SKYCHAT_RELEASE_APPROVER_EMP_ID = 302`

Environment/config values:

- `GOOGLE_MAPS_API_KEY` for reverse geocoding.
- `SKYLINK_UPLOAD_ENCRYPTION_KEY` for restricted/encrypted uploads.
- Firebase push credentials are handled by `FirebasePush.php`.
- Ejabberd admin/API config is handled by `EjabberdApi.php` and deployment config.

## API To Table Mapping

### Chat

- `send_message.php` -> `xmpp_messages`, `xmpp_group_members`, `xmpp_groups`, `xmpp_push_queue`
- `history.php` -> `xmpp_messages`, `xmpp_group_reads`
- `recent_chats.php` -> `xmpp_messages`, `xmpp_groups`, `xmpp_group_members`, `xmpp_group_reads`, `xmpp_conversation_preferences`, `xmpp_user_presence`
- `message_action.php` -> `xmpp_messages`, `xmpp_message_reactions`, `xmpp_message_stars`, `xmpp_message_pins`, `xmpp_group_reads`
- `delete_message.php` -> `xmpp_messages.deleted_at`
- `edit_message.php` -> `xmpp_messages.edited_at`
- `checklist_toggle.php` -> `xmpp_messages.body`, `xmpp_messages.edited_at`

### Groups / Channels

- `create_channel.php` -> `xmpp_groups`, `xmpp_group_members`, `xmpp_channel_audit_log`, channel extension tables
- `manage_group.php` -> `xmpp_group_members`, `xmpp_group_reads`, system message in `xmpp_messages`
- `group_members.php` -> `xmpp_group_members`, employee directory, `xmpp_users`, `xmpp_user_presence`
- `channel_definitions.php` -> `xmpp_channel_definitions`
- `channel_relationship.php` -> `xmpp_channel_relationships`, `xmpp_channel_audit_log`
- `channel_timeline.php` -> `xmpp_channel_timeline`
- `close_channel.php` -> `xmpp_groups`, `xmpp_channel_timeline`

### My Hub

- `myhub.php?section=tasks` -> `task_master`
- `myhub.php?section=task_create` -> `task_master`, `task_explained`
- `myhub.php?section=task_detail` -> `task_master`, `task_explained`/`task_updates`/`task_comments`
- `task_update.php` -> `task_master`, `task_explained`
- `myhub.php?section=directory` -> employee table
- `myhub.php?section=leave` -> `track_leave_request`
- `myhub.php?section=leave_apply` -> `xmpp_leave_otp_requests`, `track_leave_request`, `xmpp_messages`

### Attendance / Location

- `attendance.php GET` -> `punch`
- `attendance.php POST start_tracking` -> `xmpp_location_tracking`, `tbl_location_track_inch`
- `attendance.php POST stop_tracking` -> `xmpp_location_tracking`, `tbl_location_track_inch`
- `location_update.php` -> `xmpp_location_tracking`, `tbl_location_track_inch`, `locations_test`
- `location_visibility.php` -> `xmpp_location_visibility`
- `offline_alert.php` / `offline_monitor.php` -> `xmpp_location_tracking`, `xmpp_offline_alerts`

### Notifications

- `register_push_token.php` -> `xmpp_push_tokens`
- `notification_send.php` -> `xmpp_messages`, `xmpp_push_tokens`
- `notification_feed.php` -> `xmpp_notification_events`
- `notification_helpers.php` -> `xmpp_notification_events`, `xmpp_reminders`

### Release Management

- `releases.php` -> `xmpp_release_builds`, `xmpp_release_history`, `xmpp_release_notes`
- `release_notes.php` -> `xmpp_release_notes`, `xmpp_release_note_views`, `xmpp_release_builds`
- `version.php` -> `xmpp_release_builds`

## Notes For Future Developers

- Do not assume all legacy columns exist. The current PHP code checks `INFORMATION_SCHEMA` and adapts to column names.
- Keep `xmpp_messages.file_type` wide enough for MIME and app-specific attachment types.
- Keep send/read latitude and longitude as metadata unless the user explicitly sends current/live location.
- Current/live location messages should render as app map cards.
- Location address visibility must be controlled by `xmpp_location_visibility`.
- Release production approval must remain restricted to employee `302`.
- Any new channel type should first be added as a row in `xmpp_channel_definitions`, with optional extension table only when the type needs stable relational fields.
