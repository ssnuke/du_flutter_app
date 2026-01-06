class Team {
  final String name;
  final String id;
  final int weeklyInfoTarget;
  final int weeklyPlanTarget;
  final int weeklyUvTarget;
  final int infoProgress;
  final int planProgress;
  final int uvProgress;
  final int weekNumber;
  final int year;
  // New fields for hierarchy-based visible teams
  final String? createdById;
  final String? createdByName;
  final int memberCount;
  final bool isMember;
  final bool canEdit;

  Team({
    required this.name,
    required this.id,
    this.weeklyInfoTarget = 0,
    this.weeklyPlanTarget = 0,
    this.weeklyUvTarget = 0,
    this.infoProgress = 0,
    this.planProgress = 0,
    this.uvProgress = 0,
    this.weekNumber = 0,
    this.year = 0,
    this.createdById,
    this.createdByName,
    this.memberCount = 0,
    this.isMember = false,
    this.canEdit = false,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    // Handle both old format and new visible_teams format
    final targets = json['targets'] as Map<String, dynamic>?;
    final achieved = json['achieved'] as Map<String, dynamic>?;
    
    return Team(
      name: json['name'] ?? json['team_name'] ?? 'Unnamed',
      id: (json['id'] ?? json['team_id'] ?? '').toString(),
      // Support both old flat format and new nested format
      weeklyInfoTarget: int.tryParse((targets?['info_target'] ?? json['weekly_info_target'] ?? 0).toString()) ?? 0,
      weeklyPlanTarget: int.tryParse((targets?['plan_target'] ?? json['weekly_plan_target'] ?? 0).toString()) ?? 0,
      weeklyUvTarget: int.tryParse((targets?['uv_target'] ?? json['weekly_uv_target'] ?? json['uv_target'] ?? 0).toString()) ?? 0,
      infoProgress: int.tryParse((achieved?['info_achieved'] ?? json['info_progress'] ?? json['info_count'] ?? 0).toString()) ?? 0,
      planProgress: int.tryParse((achieved?['plan_achieved'] ?? json['plan_progress'] ?? json['plan_count'] ?? 0).toString()) ?? 0,
      uvProgress: int.tryParse((achieved?['uv_achieved'] ?? json['uv_progress'] ?? json['uv_count'] ?? 0).toString()) ?? 0,
      weekNumber: int.tryParse((json['week_number'] ?? 0).toString()) ?? 0,
      year: int.tryParse((json['year'] ?? 0).toString()) ?? 0,
      // New fields
      createdById: json['created_by_id']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      memberCount: int.tryParse((json['member_count'] ?? 0).toString()) ?? 0,
      isMember: json['is_member'] == true,
      canEdit: json['can_edit'] == true,
    );
  }

  /// Create a copy with updated values (for merging with previous data)
  Team copyWith({
    String? name,
    String? id,
    int? weeklyInfoTarget,
    int? weeklyPlanTarget,
    int? weeklyUvTarget,
    int? infoProgress,
    int? planProgress,
    int? uvProgress,
    int? weekNumber,
    int? year,
    String? createdById,
    String? createdByName,
    int? memberCount,
    bool? isMember,
    bool? canEdit,
  }) {
    return Team(
      name: name ?? this.name,
      id: id ?? this.id,
      weeklyInfoTarget: weeklyInfoTarget ?? this.weeklyInfoTarget,
      weeklyPlanTarget: weeklyPlanTarget ?? this.weeklyPlanTarget,
      weeklyUvTarget: weeklyUvTarget ?? this.weeklyUvTarget,
      infoProgress: infoProgress ?? this.infoProgress,
      planProgress: planProgress ?? this.planProgress,
      uvProgress: uvProgress ?? this.uvProgress,
      weekNumber: weekNumber ?? this.weekNumber,
      year: year ?? this.year,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      canEdit: canEdit ?? this.canEdit,
    );
  }
}
