class MigrationIssue {
  const MigrationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  Map<String, dynamic> toJson() => {
        'path': path,
        'code': code,
        'message': message,
      };
}

class MigrationDuplicate {
  const MigrationDuplicate({
    required this.entityType,
    required this.betaId,
    required this.count,
  });

  final String entityType;
  final String betaId;
  final int count;

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'beta_id': betaId,
        'count': count,
      };
}

class MigrationPreview {
  const MigrationPreview({
    required this.checksum,
    required this.betaVersion,
    required this.synthetic,
    required this.idMap,
    required this.counts,
    required this.duplicates,
    required this.issues,
  });

  final String checksum;
  final int betaVersion;
  final bool synthetic;
  final Map<String, String> idMap;
  final Map<String, int> counts;
  final List<MigrationDuplicate> duplicates;
  final List<MigrationIssue> issues;

  bool get isValid => issues.isEmpty;

  Map<String, dynamic> toJson() => {
        'checksum': checksum,
        'beta_version': betaVersion,
        'synthetic': synthetic,
        'id_map': idMap,
        'counts': counts,
        'duplicates':
            duplicates.map((duplicate) => duplicate.toJson()).toList(),
        'issues': issues.map((issue) => issue.toJson()).toList(),
      };
}

class ReconciliationReport {
  const ReconciliationReport({
    required this.preview,
    required this.imported,
    required this.skippedExisting,
    required this.reconciliation,
  });

  final MigrationPreview preview;
  final Map<String, int> imported;
  final Map<String, int> skippedExisting;
  final Map<String, int> reconciliation;

  Map<String, dynamic> toJson() => {
        'checksum': preview.checksum,
        'imported': imported,
        'skipped_existing': skippedExisting,
        'reconciliation': reconciliation,
        'preview_counts': preview.counts,
      };
}
