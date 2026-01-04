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
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      name: json['name'] ?? json['team_name'] ?? 'Unnamed',
      id: (json['id'] ?? json['team_id'] ?? '').toString(),
      weeklyInfoTarget: int.tryParse((json['weekly_info_target'] ?? 0).toString()) ?? 0,
      weeklyPlanTarget: int.tryParse((json['weekly_plan_target'] ?? 0).toString()) ?? 0,
      weeklyUvTarget: int.tryParse((json['weekly_uv_target'] ?? json['uv_target'] ?? 0).toString()) ?? 0,
      infoProgress: int.tryParse((json['info_progress'] ?? json['info_count'] ?? 0).toString()) ?? 0,
      planProgress: int.tryParse((json['plan_progress'] ?? json['plan_count'] ?? 0).toString()) ?? 0,
      uvProgress: int.tryParse((json['uv_progress'] ?? json['uv_count'] ?? 0).toString()) ?? 0,
      weekNumber: int.tryParse((json['week_number'] ?? 0).toString()) ?? 0,
      year: int.tryParse((json['year'] ?? 0).toString()) ?? 0,
    );
  }
}
