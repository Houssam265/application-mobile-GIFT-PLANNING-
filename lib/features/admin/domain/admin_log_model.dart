class AdminLog {
  final String id;
  final String action;
  final String targetId;
  final String targetType;
  final String adminId;
  final DateTime createdAt;
  final String? adminName;   // admin's name (join utilisateurs via admin_id)
  final String? targetEmail; // email of the target user OR list owner
  final String? targetName;  // name of the target user OR title of the list

  AdminLog({
    required this.id,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.adminId,
    required this.createdAt,
    this.adminName,
    this.targetEmail,
    this.targetName,
  });

  factory AdminLog.fromJson(Map<String, dynamic> json) {
    return AdminLog(
      id: json['id'] as String,
      action: json['action'] as String,
      targetId: json['target_id'] as String,
      targetType: json['target_type'] as String,
      adminId: json['admin_id'] as String,
      // Parse UTC timestamp and convert to device local time
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      adminName: json['utilisateurs']?['nom'] as String?,
      // targetEmail / targetName are enriched after the initial query
      targetEmail: json['target_email'] as String?,
      targetName: json['target_name'] as String?,
    );
  }

  /// Returns a copy with enriched target details filled in.
  AdminLog copyWithTarget({String? targetName, String? targetEmail}) {
    return AdminLog(
      id: id,
      action: action,
      targetId: targetId,
      targetType: targetType,
      adminId: adminId,
      createdAt: createdAt,
      adminName: adminName,
      targetName: targetName ?? this.targetName,
      targetEmail: targetEmail ?? this.targetEmail,
    );
  }

  String get actionLabel {
    switch (action) {
      case 'SUSPEND_USER':
        return 'Suspension utilisateur';
      case 'REACTIVATE_USER':
        return 'Réactivation utilisateur';
      case 'DELETE_USER':
        return 'Suppression utilisateur';
      case 'ARCHIVE_LIST':
        return 'Archivage forcé liste';
      case 'REACTIVATE_LIST':
        return 'Réactivation liste';
      case 'DELETE_LIST':
        return 'Suppression liste';
      default:
        return action;
    }
  }
}
