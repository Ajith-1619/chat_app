import 'package:flutter/material.dart';

import 'app_cache.dart';

const List<String> flowStatusWorkflow = <String>[
  'Requested',
  'Approved',
  'In Development',
  'Implemented',
  'AI Audited',
  'UAT Tested',
  'Release Approved',
  'Released',
];

const List<String> flowPriorities = <String>['Low', 'Medium', 'High', 'Critical'];
const List<String> flowAuditCategories = <String>[
  'Functional Audit',
  'UI/UX Audit',
  'Technical Audit',
  'Performance Audit',
  'Business Outcome Audit',
];

bool canAccessFlowDevelopment({
  required String employeeId,
  required String name,
  required String designation,
}) {
  final normalizedName = name.toLowerCase();
  final normalizedDesignation = designation.toLowerCase();
  return const {'116', '302'}.contains(employeeId) ||
      normalizedName.contains('ajith') ||
      normalizedName.contains('radhakrishna') ||
      normalizedName.contains('rk') ||
      normalizedDesignation.contains('developer');
}

class FlowAuditEntry {
  const FlowAuditEntry({
    required this.category,
    required this.score,
    this.comments = '',
  });

  factory FlowAuditEntry.fromJson(Map<String, dynamic> json) {
    return FlowAuditEntry(
      category: '${json['category'] ?? ''}',
      score: (json['score'] as num?)?.round() ?? 0,
      comments: '${json['comments'] ?? ''}',
    );
  }

  final String category;
  final int score;
  final String comments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'category': category,
    'score': score,
    'comments': comments,
  };
}

class FlowFeatureRecord {
  const FlowFeatureRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.module,
    required this.requestedBy,
    required this.owner,
    required this.priority,
    required this.status,
    required this.requestedDate,
    this.firstDevelopedInVersion = '',
    this.firstReleasedInVersion = '',
    this.lastModifiedInVersion = '',
    this.dependencies = const <String>[],
    this.notes = '',
    this.auditEntries = const <FlowAuditEntry>[],
  });

  factory FlowFeatureRecord.fromJson(Map<String, dynamic> json) {
    return FlowFeatureRecord(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      module: '${json['module'] ?? ''}',
      requestedBy: '${json['requestedBy'] ?? ''}',
      owner: '${json['owner'] ?? ''}',
      priority: '${json['priority'] ?? 'Medium'}',
      status: '${json['status'] ?? 'Requested'}',
      requestedDate: '${json['requestedDate'] ?? ''}',
      firstDevelopedInVersion: '${json['firstDevelopedInVersion'] ?? ''}',
      firstReleasedInVersion: '${json['firstReleasedInVersion'] ?? ''}',
      lastModifiedInVersion: '${json['lastModifiedInVersion'] ?? ''}',
      dependencies: (json['dependencies'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => '$value')
          .where((String value) => value.trim().isNotEmpty)
          .toList(),
      notes: '${json['notes'] ?? ''}',
      auditEntries: (json['auditEntries'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FlowAuditEntry.fromJson)
          .toList(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String module;
  final String requestedBy;
  final String owner;
  final String priority;
  final String status;
  final String requestedDate;
  final String firstDevelopedInVersion;
  final String firstReleasedInVersion;
  final String lastModifiedInVersion;
  final List<String> dependencies;
  final String notes;
  final List<FlowAuditEntry> auditEntries;

  double get implementationConfidence {
    if (auditEntries.isEmpty) return 0;
    final total = auditEntries.fold<int>(0, (sum, entry) => sum + entry.score);
    return total / auditEntries.length;
  }

  bool meetsAuditThreshold(int threshold) {
    if (auditEntries.length < flowAuditCategories.length) return false;
    return auditEntries.every((FlowAuditEntry entry) => entry.score >= threshold);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'module': module,
    'requestedBy': requestedBy,
    'owner': owner,
    'priority': priority,
    'status': status,
    'requestedDate': requestedDate,
    'firstDevelopedInVersion': firstDevelopedInVersion,
    'firstReleasedInVersion': firstReleasedInVersion,
    'lastModifiedInVersion': lastModifiedInVersion,
    'dependencies': dependencies,
    'notes': notes,
    'auditEntries': auditEntries.map((FlowAuditEntry entry) => entry.toJson()).toList(),
  };

  FlowFeatureRecord copyWith({
    String? id,
    String? name,
    String? description,
    String? module,
    String? requestedBy,
    String? owner,
    String? priority,
    String? status,
    String? requestedDate,
    String? firstDevelopedInVersion,
    String? firstReleasedInVersion,
    String? lastModifiedInVersion,
    List<String>? dependencies,
    String? notes,
    List<FlowAuditEntry>? auditEntries,
  }) {
    return FlowFeatureRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      module: module ?? this.module,
      requestedBy: requestedBy ?? this.requestedBy,
      owner: owner ?? this.owner,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      requestedDate: requestedDate ?? this.requestedDate,
      firstDevelopedInVersion: firstDevelopedInVersion ?? this.firstDevelopedInVersion,
      firstReleasedInVersion: firstReleasedInVersion ?? this.firstReleasedInVersion,
      lastModifiedInVersion: lastModifiedInVersion ?? this.lastModifiedInVersion,
      dependencies: dependencies ?? this.dependencies,
      notes: notes ?? this.notes,
      auditEntries: auditEntries ?? this.auditEntries,
    );
  }
}

class FlowAiAuditReport {
  const FlowAiAuditReport({
    required this.generatedAt,
    required this.fullyImplemented,
    required this.partiallyImplemented,
    required this.missing,
    required this.filesChanged,
    required this.apisChanged,
    required this.databaseChanges,
    required this.uiChanges,
    required this.risks,
    required this.recommendations,
    required this.confidenceScore,
  });

  factory FlowAiAuditReport.fromJson(Map<String, dynamic> json) {
    List<String> listFromJson(String key) => (json[key] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic value) => '$value')
        .where((String value) => value.trim().isNotEmpty)
        .toList();
    return FlowAiAuditReport(
      generatedAt: '${json['generatedAt'] ?? ''}',
      fullyImplemented: listFromJson('fullyImplemented'),
      partiallyImplemented: listFromJson('partiallyImplemented'),
      missing: listFromJson('missing'),
      filesChanged: listFromJson('filesChanged'),
      apisChanged: listFromJson('apisChanged'),
      databaseChanges: listFromJson('databaseChanges'),
      uiChanges: listFromJson('uiChanges'),
      risks: listFromJson('risks'),
      recommendations: listFromJson('recommendations'),
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0,
    );
  }

  final String generatedAt;
  final List<String> fullyImplemented;
  final List<String> partiallyImplemented;
  final List<String> missing;
  final List<String> filesChanged;
  final List<String> apisChanged;
  final List<String> databaseChanges;
  final List<String> uiChanges;
  final List<String> risks;
  final List<String> recommendations;
  final double confidenceScore;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'generatedAt': generatedAt,
    'fullyImplemented': fullyImplemented,
    'partiallyImplemented': partiallyImplemented,
    'missing': missing,
    'filesChanged': filesChanged,
    'apisChanged': apisChanged,
    'databaseChanges': databaseChanges,
    'uiChanges': uiChanges,
    'risks': risks,
    'recommendations': recommendations,
    'confidenceScore': confidenceScore,
  };
}
class FlowReleaseRecord {
  const FlowReleaseRecord({
    required this.version,
    this.plannedFeatureIds = const <String>[],
    this.implementedFeatureIds = const <String>[],
    this.partiallyImplementedFeatureIds = const <String>[],
    this.deferredFeatureIds = const <String>[],
    this.missingFeatureIds = const <String>[],
    this.aiAudit,
  });

  factory FlowReleaseRecord.fromJson(Map<String, dynamic> json) {
    List<String> listFromJson(String key) => (json[key] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic value) => '$value')
        .where((String value) => value.trim().isNotEmpty)
        .toList();
    return FlowReleaseRecord(
      version: '${json['version'] ?? ''}',
      plannedFeatureIds: listFromJson('plannedFeatureIds'),
      implementedFeatureIds: listFromJson('implementedFeatureIds'),
      partiallyImplementedFeatureIds: listFromJson('partiallyImplementedFeatureIds'),
      deferredFeatureIds: listFromJson('deferredFeatureIds'),
      missingFeatureIds: listFromJson('missingFeatureIds'),
      aiAudit: json['aiAudit'] is Map<String, dynamic>
          ? FlowAiAuditReport.fromJson(json['aiAudit'] as Map<String, dynamic>)
          : null,
    );
  }

  final String version;
  final List<String> plannedFeatureIds;
  final List<String> implementedFeatureIds;
  final List<String> partiallyImplementedFeatureIds;
  final List<String> deferredFeatureIds;
  final List<String> missingFeatureIds;
  final FlowAiAuditReport? aiAudit;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'plannedFeatureIds': plannedFeatureIds,
    'implementedFeatureIds': implementedFeatureIds,
    'partiallyImplementedFeatureIds': partiallyImplementedFeatureIds,
    'deferredFeatureIds': deferredFeatureIds,
    'missingFeatureIds': missingFeatureIds,
    'aiAudit': aiAudit?.toJson(),
  };

  FlowReleaseRecord copyWith({
    String? version,
    List<String>? plannedFeatureIds,
    List<String>? implementedFeatureIds,
    List<String>? partiallyImplementedFeatureIds,
    List<String>? deferredFeatureIds,
    List<String>? missingFeatureIds,
    FlowAiAuditReport? aiAudit,
  }) {
    return FlowReleaseRecord(
      version: version ?? this.version,
      plannedFeatureIds: plannedFeatureIds ?? this.plannedFeatureIds,
      implementedFeatureIds: implementedFeatureIds ?? this.implementedFeatureIds,
      partiallyImplementedFeatureIds: partiallyImplementedFeatureIds ?? this.partiallyImplementedFeatureIds,
      deferredFeatureIds: deferredFeatureIds ?? this.deferredFeatureIds,
      missingFeatureIds: missingFeatureIds ?? this.missingFeatureIds,
      aiAudit: aiAudit ?? this.aiAudit,
    );
  }
}

class FlowReleaseSummary {
  const FlowReleaseSummary({
    required this.planned,
    required this.implemented,
    required this.partiallyImplemented,
    required this.deferred,
    required this.missing,
    required this.complianceScore,
  });

  final List<FlowFeatureRecord> planned;
  final List<FlowFeatureRecord> implemented;
  final List<FlowFeatureRecord> partiallyImplemented;
  final List<FlowFeatureRecord> deferred;
  final List<String> missing;
  final double complianceScore;
}

class FlowRegistryData {
  const FlowRegistryData({
    this.features = const <FlowFeatureRecord>[],
    this.releases = const <FlowReleaseRecord>[],
    this.minimumAuditThreshold = 90,
  });

  factory FlowRegistryData.fromJson(Map<String, dynamic> json) {
    return FlowRegistryData(
      features: (json['features'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FlowFeatureRecord.fromJson)
          .toList(),
      releases: (json['releases'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FlowReleaseRecord.fromJson)
          .toList(),
      minimumAuditThreshold: (json['minimumAuditThreshold'] as num?)?.round() ?? 90,
    );
  }

  final List<FlowFeatureRecord> features;
  final List<FlowReleaseRecord> releases;
  final int minimumAuditThreshold;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'features': features.map((FlowFeatureRecord feature) => feature.toJson()).toList(),
    'releases': releases.map((FlowReleaseRecord release) => release.toJson()).toList(),
    'minimumAuditThreshold': minimumAuditThreshold,
  };

  FlowRegistryData copyWith({
    List<FlowFeatureRecord>? features,
    List<FlowReleaseRecord>? releases,
    int? minimumAuditThreshold,
  }) {
    return FlowRegistryData(
      features: features ?? this.features,
      releases: releases ?? this.releases,
      minimumAuditThreshold: minimumAuditThreshold ?? this.minimumAuditThreshold,
    );
  }
}

class FlowRegistryStore {
  FlowRegistryStore._();

  static const String cacheKey = 'flow_registry_v1';
  static final FlowRegistryStore instance = FlowRegistryStore._();

  Future<FlowRegistryData> load() async {
    final cached = await AppCache.instance.readJson(cacheKey);
    final data = cached is Map<String, dynamic>
        ? FlowRegistryData.fromJson(cached)
        : const FlowRegistryData();
    final seeded = _ensureSeedFeatures(data);
    if (seeded.features.length != data.features.length) {
      await save(seeded);
    }
    return seeded;
  }

  Future<void> save(FlowRegistryData data) {
    return AppCache.instance.writeJson(cacheKey, data.toJson());
  }

  String nextFeatureId(List<FlowFeatureRecord> features) {
    var maxId = 0;
    for (final feature in features) {
      final match = RegExp(r'FLOW-(\d+)').firstMatch(feature.id);
      final value = int.tryParse(match?.group(1) ?? '0') ?? 0;
      if (value > maxId) maxId = value;
    }
    return 'FLOW-${(maxId + 1).toString().padLeft(3, '0')}';
  }

  FlowReleaseSummary summarizeRelease(FlowReleaseRecord release, List<FlowFeatureRecord> features) {
    final featureMap = <String, FlowFeatureRecord>{
      for (final feature in features) feature.id: feature,
    };
    final planned = <FlowFeatureRecord>[];
    final implemented = <FlowFeatureRecord>[];
    final partial = <FlowFeatureRecord>[];
    final deferred = <FlowFeatureRecord>[];
    final missing = <String>[];
    for (final id in release.plannedFeatureIds) {
      final feature = featureMap[id];
      if (feature == null) {
        missing.add(id);
        continue;
      }
      planned.add(feature);
      if (_implementedStatuses.contains(feature.status)) {
        implemented.add(feature);
      } else if (feature.status == 'In Development') {
        partial.add(feature);
      } else {
        deferred.add(feature);
      }
    }
    final plannedCount = planned.length + missing.length;
    final complianceScore = plannedCount == 0
        ? 0.0
        : (((implemented.length + (partial.length * 0.5)) / plannedCount) * 100)
              .clamp(0, 100)
              .toDouble();
    return FlowReleaseSummary(
      planned: planned,
      implemented: implemented,
      partiallyImplemented: partial,
      deferred: deferred,
      missing: missing,
      complianceScore: complianceScore,
    );
  }

  FlowAiAuditReport generateAiAudit(
    FlowReleaseRecord release,
    List<FlowFeatureRecord> features,
    int minimumThreshold,
  ) {
    final summary = summarizeRelease(release, features);
    final fullyImplemented = summary.implemented
        .where((FlowFeatureRecord feature) => feature.meetsAuditThreshold(minimumThreshold))
        .map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}')
        .toList();
    final partial = <String>[
      ...summary.partiallyImplemented.map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}'),
      ...summary.implemented
          .where((FlowFeatureRecord feature) => !feature.meetsAuditThreshold(minimumThreshold))
          .map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}'),
    ];
    final planned = summary.planned;
    final filesChanged = planned
        .map((FlowFeatureRecord feature) => 'lib/${feature.module.toLowerCase().replaceAll(' ', '_')}.dart')
        .toSet()
        .toList();
    final apisChanged = planned
        .where((FlowFeatureRecord feature) => feature.notes.toLowerCase().contains('api'))
        .map((FlowFeatureRecord feature) => feature.name)
        .toList();
    final databaseChanges = planned
        .where((FlowFeatureRecord feature) => feature.notes.toLowerCase().contains('db') || feature.notes.toLowerCase().contains('database'))
        .map((FlowFeatureRecord feature) => feature.name)
        .toList();
    final uiChanges = planned
        .where((FlowFeatureRecord feature) => feature.module.toLowerCase().contains('ui') || feature.description.toLowerCase().contains('screen'))
        .map((FlowFeatureRecord feature) => feature.name)
        .toList();
    final risks = <String>[
      if (partial.isNotEmpty) 'Some planned features are only partially implemented.',
      if (summary.missing.isNotEmpty) 'Some planned FLOW IDs are still missing from the registry.',
      if (planned.any((FlowFeatureRecord feature) => !feature.meetsAuditThreshold(minimumThreshold)))
        'One or more features do not meet the minimum audit threshold of $minimumThreshold.',
    ];
    final recommendations = <String>[
      if (partial.isNotEmpty) 'Complete implementation and re-run AI/UAT audits before release.',
      if (summary.missing.isNotEmpty) 'Attach all missing FLOW IDs to the release before sign-off.',
      if (risks.isEmpty) 'Release is ready for coordinated UAT and deployment.',
    ];
    final confidence = planned.isEmpty
        ? 0.0
        : planned.fold<double>(0, (sum, feature) => sum + feature.implementationConfidence) / planned.length;
    return FlowAiAuditReport(
      generatedAt: _todayStamp(),
      fullyImplemented: fullyImplemented,
      partiallyImplemented: partial,
      missing: summary.missing,
      filesChanged: filesChanged,
      apisChanged: apisChanged,
      databaseChanges: databaseChanges,
      uiChanges: uiChanges,
      risks: risks,
      recommendations: recommendations,
      confidenceScore: confidence,
    );
  }
  bool canRelease(FlowReleaseRecord release, List<FlowFeatureRecord> features, int minimumThreshold) {
    final featureMap = <String, FlowFeatureRecord>{
      for (final feature in features) feature.id: feature,
    };
    for (final id in release.plannedFeatureIds) {
      final feature = featureMap[id];
      if (feature == null) return false;
      if (!_releaseReadyStatuses.contains(feature.status)) return false;
      if (!feature.meetsAuditThreshold(minimumThreshold)) return false;
    }
    return release.plannedFeatureIds.isNotEmpty;
  }

  Map<String, Map<String, List<FlowFeatureRecord>>> changelog(List<FlowFeatureRecord> features) {
    final result = <String, Map<String, List<FlowFeatureRecord>>>{};
    void add(String version, String bucket, FlowFeatureRecord feature) {
      if (version.trim().isEmpty) return;
      result.putIfAbsent(version, () => <String, List<FlowFeatureRecord>>{
        'introduced': <FlowFeatureRecord>[],
        'modified': <FlowFeatureRecord>[],
        'completed': <FlowFeatureRecord>[],
      });
      result[version]![bucket]!.add(feature);
    }

    for (final feature in features) {
      add(feature.firstDevelopedInVersion, 'introduced', feature);
      if (feature.lastModifiedInVersion.isNotEmpty &&
          feature.lastModifiedInVersion != feature.firstDevelopedInVersion) {
        add(feature.lastModifiedInVersion, 'modified', feature);
      }
      add(feature.firstReleasedInVersion, 'completed', feature);
    }
    return result;
  }

  List<String> releaseNotesForVersion(String version, List<FlowFeatureRecord> features) {
    return features.where((FlowFeatureRecord feature) {
      return feature.firstDevelopedInVersion == version ||
          feature.lastModifiedInVersion == version ||
          feature.firstReleasedInVersion == version;
    }).map((FlowFeatureRecord feature) {
      final flags = <String>[];
      if (feature.firstDevelopedInVersion == version) flags.add('introduced');
      if (feature.lastModifiedInVersion == version) flags.add('modified');
      if (feature.firstReleasedInVersion == version) flags.add('completed');
      return '${feature.id} ${feature.name} (${flags.join(', ')})';
    }).toList();
  }

  FlowRegistryData _ensureSeedFeatures(FlowRegistryData data) {
    final existing = <String, FlowFeatureRecord>{
      for (final feature in data.features) feature.id: feature,
    };
    for (final feature in _seedFeatures()) {
      existing.putIfAbsent(feature.id, () => feature);
    }
    final merged = existing.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return data.copyWith(features: merged);
  }

  List<FlowFeatureRecord> _seedFeatures() {
    return <FlowFeatureRecord>[
      FlowFeatureRecord(
        id: 'FLOW-001',
        name: 'Feature Registry and Implementation Audit System',
        description: 'Trace every feature from request through release with backlog, release register, AI audit, changelog and compliance dashboard.',
        module: 'Settings / Development',
        requestedBy: 'Ajith',
        owner: 'AI + Dev Team',
        priority: 'Critical',
        status: 'In Development',
        requestedDate: _todayStamp(),
        firstDevelopedInVersion: 'v1.4.3',
        lastModifiedInVersion: 'v1.4.3',
        notes: 'Registry bootstrap for Flow governance. Covers UI, audit scoring and release traceability.',
        auditEntries: flowAuditCategories
            .map((String category) => FlowAuditEntry(category: category, score: 85, comments: 'Initial scaffold created.'))
            .toList(),
      ),
      FlowFeatureRecord(
        id: 'FLOW-002',
        name: 'Web Popup Dialogs and App Modals',
        description: 'Improve desktop and web popup flows for chat actions, previews and management dialogs.',
        module: 'Chat UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'In Development',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v1.4.3',
        notes: 'Covers web application popups and dialog ergonomics.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-003',
        name: 'Composer Keyboard Controls',
        description: 'Enter should send, while Ctrl+Enter should insert a new line in the web and desktop message composer.',
        module: 'Chat Composer UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'In Development',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v1.4.3',
        notes: 'Web composer behavior update.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-004',
        name: 'Attachment Selection Reliability',
        description: 'Photo and document uploads should work on the first attempt without duplicate picks.',
        module: 'Attachments',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        notes: 'Investigate file picker and upload confirmation flow.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-005',
        name: 'Message Copy and Text Selection',
        description: 'Users should be able to select message text cleanly and copy messages reliably on web.',
        module: 'Chat Messages UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'In Development',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v1.4.3',
      ),
      FlowFeatureRecord(
        id: 'FLOW-006',
        name: 'Wake-up Notification Governance',
        description: 'Wake-up configuration should default to disabled and only authorized group/channel managers should be able to edit it.',
        module: 'Group and Channel Management',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'In Development',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v1.4.3',
        notes: 'Business rule: skip weekends; role-controlled editing.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-007',
        name: 'Admin Member Management',
        description: 'Admins should be able to add and remove group and channel members.',
        module: 'Group and Channel Management',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'In Development',
        requestedDate: _todayStamp(),
      ),
      FlowFeatureRecord(
        id: 'FLOW-008',
        name: 'Ownership Transfer',
        description: 'Provide a controlled flow for transferring owner privileges to another member.',
        module: 'Group and Channel Management',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'Requested',
        requestedDate: _todayStamp(),
        notes: 'Requires backend support in manage_group API.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-009',
        name: 'Admin Portal',
        description: 'Add an admin portal surface for operational configuration, governance and monitoring.',
        module: 'Admin Portal',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
      ),
      FlowFeatureRecord(
        id: 'FLOW-010',
        name: 'Enterprise Attachment Security',
        description: 'Introduce enterprise-grade access control, auditing and security for attachments and photos.',
        module: 'Attachment Security',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        notes: 'Likely API and storage policy work.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-011',
        name: 'Reply and Mention Highlighting',
        description: 'Tagged and replied messages should be visually differentiated with stronger color treatment.',
        module: 'Chat Messages UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Medium',
        status: 'In Development',
        requestedDate: _todayStamp(),
      ),
      FlowFeatureRecord(
        id: 'FLOW-012',
        name: 'Emoji Glyph Rendering',
        description: 'Show real emoji glyphs in the composer and message tools instead of mojibake text.',
        module: 'Chat Composer UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'In Development',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v1.4.3',
      ),
      FlowFeatureRecord(
        id: 'FLOW-013',
        name: 'Live Composer Send State Sync',
        description: 'The Send button should enable immediately from the current text controller value without waiting for navigation or screen recreation.',
        module: 'Chat Composer UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
        notes: 'Use controller-driven rebuilds and remove stale composer state caching.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-014',
        name: 'Enterprise Selection Toolbar',
        description: 'Replace the default Android selection toolbar with a custom Flow toolbar that supports Copy, Reply, Forward, Bookmark, Create Task, AI Summary, Quote, Translate, Delete, Edit, Pin and Message Info.',
        module: 'Chat Messages UI',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
        notes: 'Needs cross-platform parity for Android, iOS, Windows and Web.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-015',
        name: 'Inline Composer Feedback Cleanup',
        description: 'Remove non-actionable confirmation snackbars and surface inline feedback only where it helps the user recover or proceed.',
        module: 'Chat UI Feedback',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'Medium',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
      ),
      FlowFeatureRecord(
        id: 'FLOW-016',
        name: 'Full Flow Audit Register',
        description: 'Audit the codebase, database, APIs, Flutter app, PHP services, XMPP integration, notifications, attendance, location, channels, users and settings.',
        module: 'Flow Registry / Audit',
        requestedBy: 'Ajith',
        owner: 'AI + Dev Team',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
        notes: 'Track issues by severity with root cause, impact, fix and effort.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-017',
        name: 'FLOW Audit Reports',
        description: 'Generate FLOW_AUDIT_REPORT, FLOW_BUG_REGISTER, FLOW_PERFORMANCE_REPORT, FLOW_BATTERY_REPORT, FLOW_SECURITY_REPORT and FLOW_IMPLEMENTATION_AUDIT outputs.',
        module: 'Flow Registry / Reports',
        requestedBy: 'Ajith',
        owner: 'AI + Dev Team',
        priority: 'Critical',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
        notes: 'Reports should stay in sync with the current audit backlog.',
      ),
      FlowFeatureRecord(
        id: 'FLOW-018',
        name: 'Composer and Selection UX Hardening',
        description: 'Fix composer responsiveness, message selection handling, and selection toolbar behavior across mobile, desktop and web.',
        module: 'Chat UX',
        requestedBy: 'Ajith',
        owner: 'Ajith P',
        priority: 'High',
        status: 'Requested',
        requestedDate: _todayStamp(),
        lastModifiedInVersion: 'v2.0.0',
      ),
    ];
  }

  static const Set<String> _implementedStatuses = <String>{
    'Implemented',
    'AI Audited',
    'UAT Tested',
    'Release Approved',
    'Released',
  };

  static const Set<String> _releaseReadyStatuses = <String>{
    'AI Audited',
    'UAT Tested',
    'Release Approved',
    'Released',
  };
}

String _todayStamp() => DateTime.now().toIso8601String().split('T').first;

class FlowDevelopmentScreen extends StatefulWidget {
  const FlowDevelopmentScreen({
    super.key,
    required this.viewerEmployeeId,
    required this.viewerName,
    required this.viewerDesignation,
  });

  final String viewerEmployeeId;
  final String viewerName;
  final String viewerDesignation;

  @override
  State<FlowDevelopmentScreen> createState() => _FlowDevelopmentScreenState();
}

class _FlowDevelopmentScreenState extends State<FlowDevelopmentScreen> {
  FlowRegistryData _data = const FlowRegistryData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await FlowRegistryStore.instance.load();
    if (!mounted) return;
    setState(() {
      _data = loaded;
      _loading = false;
    });
  }

  Future<void> _persist(FlowRegistryData data, {String? successMessage}) async {
    await FlowRegistryStore.instance.save(data);
    if (!mounted) return;
    setState(() => _data = data);
    if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  Future<void> _saveFeature(FlowFeatureRecord feature) async {
    final features = [..._data.features];
    final index = features.indexWhere((FlowFeatureRecord item) => item.id == feature.id);
    if (index >= 0) {
      features[index] = feature;
    } else {
      features.add(feature);
    }
    await _persist(_data.copyWith(features: features), successMessage: '${feature.id} saved.');
  }

  Future<void> _saveRelease(FlowReleaseRecord release) async {
    final summary = FlowRegistryStore.instance.summarizeRelease(release, _data.features);
    final audited = release.copyWith(
      implementedFeatureIds: summary.implemented.map((FlowFeatureRecord item) => item.id).toList(),
      partiallyImplementedFeatureIds: summary.partiallyImplemented.map((FlowFeatureRecord item) => item.id).toList(),
      deferredFeatureIds: summary.deferred.map((FlowFeatureRecord item) => item.id).toList(),
      missingFeatureIds: summary.missing,
    );
    final releases = [..._data.releases];
    final index = releases.indexWhere((FlowReleaseRecord item) => item.version == release.version);
    if (index >= 0) {
      releases[index] = audited;
    } else {
      releases.add(audited);
    }
    await _persist(_data.copyWith(releases: releases), successMessage: 'Release ${release.version} saved.');
  }
  Future<void> _generateAudit(FlowReleaseRecord release) async {
    final report = FlowRegistryStore.instance.generateAiAudit(
      release,
      _data.features,
      _data.minimumAuditThreshold,
    );
    await _saveRelease(release.copyWith(aiAudit: report));
  }

  Future<void> _updateThreshold(double value) async {
    await _persist(
      _data.copyWith(minimumAuditThreshold: value.round()),
      successMessage: 'Minimum audit threshold updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canAccessFlowDevelopment(
      employeeId: widget.viewerEmployeeId,
      name: widget.viewerName,
      designation: widget.viewerDesignation,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('Development')),
        body: const Center(child: Text('You are not authorized to view Flow development controls.')),
      );
    }
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flow Development'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Feature Registry'),
              Tab(text: 'Release Register'),
              Tab(text: 'Audit Reports'),
              Tab(text: 'Changelog'),
              Tab(text: 'Release Notes'),
              Tab(text: 'Compliance'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildFeatureRegistryTab(),
                  _buildReleaseRegisterTab(),
                  _buildAuditReportsTab(),
                  _buildChangelogTab(),
                  _buildReleaseNotesTab(),
                  _buildComplianceTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildFeatureRegistryTab() {
    return Column(
      children: [
        ListTile(
          title: const Text('FLOW_MASTER_BACKLOG'),
          subtitle: Text('${_data.features.length} features tracked from request to release'),
          trailing: FilledButton.icon(
            onPressed: () => _showFeatureEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New feature'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _data.features.length,
            itemBuilder: (context, index) {
              final feature = _data.features[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: ListTile(
                  title: Text('${feature.id} - ${feature.name}'),
                  subtitle: Text('${feature.module} | ${feature.status} | ${feature.priority}\nOwner: ${feature.owner}'),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(feature.firstReleasedInVersion.ifEmpty('-')),
                      Text('${feature.implementationConfidence.toStringAsFixed(0)}%'),
                    ],
                  ),
                  onTap: () => _showFeatureEditor(feature: feature),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseRegisterTab() {
    return Column(
      children: [
        ListTile(
          title: const Text('FLOW_RELEASE_REGISTER'),
          subtitle: const Text('Plan, implement, defer and audit every release.'),
          trailing: FilledButton.icon(
            onPressed: () => _showReleaseEditor(),
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('New release'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: _data.releases.map((FlowReleaseRecord release) {
              final summary = FlowRegistryStore.instance.summarizeRelease(release, _data.features);
              final canRelease = FlowRegistryStore.instance.canRelease(
                release,
                _data.features,
                _data.minimumAuditThreshold,
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(release.version, style: Theme.of(context).textTheme.titleLarge)),
                          _ScoreChip(label: 'Compliance', value: summary.complianceScore),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricChip(label: 'Planned', value: '${summary.planned.length + summary.missing.length}'),
                          _MetricChip(label: 'Implemented', value: '${summary.implemented.length}'),
                          _MetricChip(label: 'Partial', value: '${summary.partiallyImplemented.length}'),
                          _MetricChip(label: 'Deferred', value: '${summary.deferred.length}'),
                          _MetricChip(label: 'Missing', value: '${summary.missing.length}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(canRelease ? 'Release gate passed.' : 'Release gate blocked until all audits clear the threshold.'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showReleaseEditor(release: release),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _generateAudit(release),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Run AI audit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Widget _buildAuditReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _data.features.map((FlowFeatureRecord feature) {
        return Card(
          child: ListTile(
            title: Text('${feature.id} ${feature.name}'),
            subtitle: Text('Confidence ${feature.implementationConfidence.toStringAsFixed(0)}% | Threshold ${_data.minimumAuditThreshold}%'),
            trailing: OutlinedButton(
              onPressed: () => _showAuditEditor(feature),
              child: const Text('Audit'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChangelogTab() {
    final log = FlowRegistryStore.instance.changelog(_data.features);
    final versions = log.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: versions.map((String version) {
        final entry = log[version]!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(version, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _BulletSection(title: 'Introduced', items: entry['introduced']!.map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}').toList()),
                _BulletSection(title: 'Modified', items: entry['modified']!.map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}').toList()),
                _BulletSection(title: 'Completed', items: entry['completed']!.map((FlowFeatureRecord feature) => '${feature.id} ${feature.name}').toList()),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReleaseNotesTab() {
    final versions = _data.releases.map((FlowReleaseRecord release) => release.version).toSet().toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: versions.map((String version) {
        final notes = FlowRegistryStore.instance.releaseNotesForVersion(version, _data.features);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(version, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _BulletSection(title: 'Release Notes', items: notes),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComplianceTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compliance Dashboard', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Minimum audit threshold: ${_data.minimumAuditThreshold}%'),
                Slider(
                  value: _data.minimumAuditThreshold.toDouble(),
                  min: 70,
                  max: 100,
                  divisions: 6,
                  label: '${_data.minimumAuditThreshold}%',
                  onChanged: _updateThreshold,
                ),
              ],
            ),
          ),
        ),
        ..._data.releases.map((FlowReleaseRecord release) {
          final summary = FlowRegistryStore.instance.summarizeRelease(release, _data.features);
          return Card(
            child: ListTile(
              title: Text(release.version),
              subtitle: Text('Compliance ${summary.complianceScore.toStringAsFixed(0)}% | Planned ${summary.planned.length + summary.missing.length}'),
              trailing: release.aiAudit == null
                  ? const Text('Pending audit')
                  : Text('${release.aiAudit!.confidenceScore.toStringAsFixed(0)}% confidence'),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showFeatureEditor({FlowFeatureRecord? feature}) async {
    final editing = feature != null;
    final nameController = TextEditingController(text: feature?.name ?? '');
    final descriptionController = TextEditingController(text: feature?.description ?? '');
    final moduleController = TextEditingController(text: feature?.module ?? '');
    final requesterController = TextEditingController(text: feature?.requestedBy ?? widget.viewerName);
    final ownerController = TextEditingController(text: feature?.owner ?? widget.viewerName);
    final firstDevController = TextEditingController(text: feature?.firstDevelopedInVersion ?? '');
    final firstReleaseController = TextEditingController(text: feature?.firstReleasedInVersion ?? '');
    final lastModifiedController = TextEditingController(text: feature?.lastModifiedInVersion ?? '');
    final dependenciesController = TextEditingController(text: feature?.dependencies.join(', ') ?? '');
    final notesController = TextEditingController(text: feature?.notes ?? '');
    var status = feature?.status ?? flowStatusWorkflow.first;
    var priority = feature?.priority ?? 'Medium';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(editing ? 'Edit feature' : 'New feature'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogField(controller: nameController, label: 'Feature name'),
                  _DialogField(controller: descriptionController, label: 'Description', maxLines: 3),
                  _DialogField(controller: moduleController, label: 'Module'),
                  _DialogField(controller: requesterController, label: 'Requested by'),
                  _DialogField(controller: ownerController, label: 'Owner'),
                  Row(children: [Expanded(child: _DropdownField(value: priority, items: flowPriorities, label: 'Priority', onChanged: (value) => setState(() => priority = value!))), const SizedBox(width: 12), Expanded(child: _DropdownField(value: status, items: flowStatusWorkflow, label: 'Status', onChanged: (value) => setState(() => status = value!)))]),
                  _DialogField(controller: firstDevController, label: 'First developed in version'),
                  _DialogField(controller: firstReleaseController, label: 'First released in version'),
                  _DialogField(controller: lastModifiedController, label: 'Last modified in version'),
                  _DialogField(controller: dependenciesController, label: 'Dependencies (comma separated)'),
                  _DialogField(controller: notesController, label: 'Notes', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final newFeature = FlowFeatureRecord(
                  id: feature?.id ?? FlowRegistryStore.instance.nextFeatureId(_data.features),
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  module: moduleController.text.trim(),
                  requestedBy: requesterController.text.trim(),
                  owner: ownerController.text.trim(),
                  priority: priority,
                  status: status,
                  requestedDate: feature?.requestedDate ?? _todayStamp(),
                  firstDevelopedInVersion: firstDevController.text.trim(),
                  firstReleasedInVersion: firstReleaseController.text.trim(),
                  lastModifiedInVersion: lastModifiedController.text.trim(),
                  dependencies: dependenciesController.text.split(',').map((String value) => value.trim()).where((String value) => value.isNotEmpty).toList(),
                  notes: notesController.text.trim(),
                  auditEntries: feature?.auditEntries ?? const <FlowAuditEntry>[],
                );
                Navigator.pop(context);
                await _saveFeature(newFeature);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showAuditEditor(FlowFeatureRecord feature) async {
    final scoreMap = <String, TextEditingController>{
      for (final category in flowAuditCategories)
        category: TextEditingController(
          text: '${feature.auditEntries.firstWhere(
            (FlowAuditEntry entry) => entry.category == category,
            orElse: () => FlowAuditEntry(category: category, score: 0),
          ).score}',
        ),
    };
    final commentMap = <String, TextEditingController>{
      for (final category in flowAuditCategories)
        category: TextEditingController(
          text: feature.auditEntries.firstWhere(
            (FlowAuditEntry entry) => entry.category == category,
            orElse: () => FlowAuditEntry(category: category, score: 0),
          ).comments,
        ),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Audit ${feature.id}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: flowAuditCategories.map((String category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _DialogField(controller: scoreMap[category]!, label: 'Score 0-100'),
                      _DialogField(controller: commentMap[category]!, label: 'Comments', maxLines: 2),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final audited = feature.copyWith(
                auditEntries: flowAuditCategories.map((String category) {
                  return FlowAuditEntry(
                    category: category,
                    score: int.tryParse(scoreMap[category]!.text.trim())?.clamp(0, 100) ?? 0,
                    comments: commentMap[category]!.text.trim(),
                  );
                }).toList(),
              );
              Navigator.pop(context);
              await _saveFeature(audited);
            },
            child: const Text('Save audit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReleaseEditor({FlowReleaseRecord? release}) async {
    final versionController = TextEditingController(text: release?.version ?? 'v2.0.0');
    final selected = <String>{...release?.plannedFeatureIds ?? const <String>[]};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(release == null ? 'New release' : 'Edit release'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogField(controller: versionController, label: 'Version number'),
                  const SizedBox(height: 8),
                  Text('Features planned', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._data.features.map((FlowFeatureRecord feature) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(feature.id),
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            selected.add(feature.id);
                          } else {
                            selected.remove(feature.id);
                          }
                        });
                      },
                      title: Text('${feature.id} ${feature.name}'),
                      subtitle: Text('${feature.status} | ${feature.module}'),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _saveRelease(
                  (release ?? FlowReleaseRecord(version: versionController.text.trim())).copyWith(
                    version: versionController.text.trim(),
                    plannedFeatureIds: selected.toList()..sort(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.controller, required this.label, this.maxLines = 1});

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.value, required this.items, required this.label, required this.onChanged});

  final String value;
  final List<String> items;
  final String label;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $value'));
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label ${value.toStringAsFixed(0)}%'));
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('None')
          else
            ...items.map((String item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $item'),
                )),
        ],
      ),
    );
  }
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
