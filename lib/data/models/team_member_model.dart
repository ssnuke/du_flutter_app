class TeamMember {
  final String name;
  final int calls;
  final double turnover;
  final int meetings;
  final bool isLead;
  final bool isManager;

  TeamMember({
    required this.name,
    required this.calls,
    required this.turnover,
    required this.meetings,
    this.isLead = false,
    this.isManager = false,
  });
}