class Team {
  final String name;
  final String id;
  final int weeklyInfoTarget;
  final int weeklyPlanTarget;

  Team({
    required this.name,
    required this.id,
    this.weeklyInfoTarget = 0,
    this.weeklyPlanTarget = 0,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      name: json['name'] ?? 'Unnamed',
      id: (json['id'] ?? '').toString(),
      weeklyInfoTarget: json['weekly_info_target'] ?? 0,
      weeklyPlanTarget: json['weekly_plan_target'] ?? 0,
    );
  }
}
