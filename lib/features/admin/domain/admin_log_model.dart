class AdminLog {
  final String id;
  final String action;
  final String targetId;
  final String targetType;
  final String adminId;
  final DateTime createdAt;
  final String? adminName; // Join with utilisateurs

  AdminLog({
    required this.id,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.adminId,
    required this.createdAt,
    this.adminName,
  });

  factory AdminLog.fromJson(Map<String, dynamic> json) {
    return AdminLog(
      id: json['id'] as String,
      action: json['action'] as String,
      targetId: json['target_id'] as String,
      targetType: json['target_type'] as String,
      adminId: json['admin_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      adminName: json['utilisateurs']?['nom'] as String?,
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
