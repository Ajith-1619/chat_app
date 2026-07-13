CREATE TABLE IF NOT EXISTS xmpp_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL UNIQUE,
  jid VARCHAR(255) NOT NULL UNIQUE,
  xmpp_password VARCHAR(255) NOT NULL,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_groups (
  id INT AUTO_INCREMENT PRIMARY KEY,
  room_name VARCHAR(150) NOT NULL,
  room_jid VARCHAR(255) NOT NULL UNIQUE,
  avatar_url VARCHAR(500) NULL,
  group_type VARCHAR(20) NOT NULL DEFAULT 'group',
  is_archived TINYINT NOT NULL DEFAULT 0,
  archived_at DATETIME NULL,
  created_by_emp_id INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_group_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  group_id INT NOT NULL,
  emp_id INT NOT NULL,
  role ENUM('owner','admin','member') NOT NULL DEFAULT 'member',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_xmpp_group_member (group_id, emp_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  from_jid VARCHAR(255) NOT NULL,
  to_jid VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  file_url VARCHAR(500) NULL,
  file_name VARCHAR(255) NULL,
  file_type VARCHAR(100) NULL,
  file_size BIGINT NOT NULL DEFAULT 0,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  message_type VARCHAR(24) NOT NULL DEFAULT 'chat',
  reply_to_id BIGINT NULL,
  mentions_json TEXT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'sent',
  read_at DATETIME NULL,
  deleted_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_xmpp_messages_from_created (from_jid, created_at),
  INDEX idx_xmpp_messages_to_created (to_jid, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_group_reads (
  group_id INT NOT NULL,
  emp_id INT NOT NULL,
  last_read_message_id BIGINT NOT NULL DEFAULT 0,
  read_at DATETIME NULL,
  PRIMARY KEY (group_id, emp_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_user_presence (
  emp_id INT PRIMARY KEY,
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_reminders (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  kind VARCHAR(20) NOT NULL DEFAULT 'reminder',
  title VARCHAR(255) NOT NULL,
  notes TEXT NULL,
  created_by_emp_id INT NOT NULL,
  assignee_ids_json TEXT NOT NULL,
  source_conversation_jid VARCHAR(255) NULL,
  source_conversation_name VARCHAR(160) NULL,
  source_message_id BIGINT NULL,
  source_message_text TEXT NULL,
  starts_at DATETIME NOT NULL,
  next_due_at DATETIME NULL,
  recurrence_type VARCHAR(20) NOT NULL DEFAULT 'once',
  custom_interval INT NOT NULL DEFAULT 1,
  custom_unit VARCHAR(12) NOT NULL DEFAULT 'week',
  weekdays_json TEXT NULL,
  month_days_json TEXT NULL,
  active TINYINT NOT NULL DEFAULT 1,
  stopped_at DATETIME NULL,
  stopped_by_emp_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reminders_creator_active (created_by_emp_id, active, starts_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_notification_events (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  emp_id INT NOT NULL,
  event_key VARCHAR(190) NOT NULL,
  event_type VARCHAR(30) NOT NULL,
  reminder_id BIGINT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  viewed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_notification_event (event_key),
  INDEX idx_notification_emp_viewed (emp_id, viewed_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS xmpp_scheduled_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  created_by_emp_id INT NOT NULL,
  body TEXT NOT NULL,
  scheduled_at DATETIME NOT NULL,
  silent TINYINT NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
  completed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_scheduled_due (status, scheduled_at),
  INDEX idx_scheduled_creator (created_by_emp_id, scheduled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS xmpp_scheduled_message_targets (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  schedule_id BIGINT NOT NULL,
  target_jid VARCHAR(255) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  attempts INT NOT NULL DEFAULT 0,
  message_id BIGINT NULL,
  last_error VARCHAR(500) NULL,
  sent_at DATETIME NULL,
  UNIQUE KEY uq_scheduled_target (schedule_id, target_jid),
  INDEX idx_scheduled_target_status (status, schedule_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;