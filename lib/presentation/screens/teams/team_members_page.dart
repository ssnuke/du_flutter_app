import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/presentation/screens/dashboard/dashboard_page.dart';
import 'package:leadtracker/presentation/widgets/info_card.dart';
import 'package:leadtracker/data/services/api_service.dart';
import 'package:leadtracker/core/constants/api_constants.dart';

class TeamMembersPage extends StatefulWidget {
  final String teamName;
  final String teamId;
  final int userRole;
  final String loggedInIrId;
  final int weeklyInfoTarget;
  final int weeklyPlanTarget;
  final int weeklyUvTarget;
  final int infoProgress;
  final int planProgress;
  final int uvProgress;
  final int weekNumber;
  final int year;

  const TeamMembersPage({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.userRole,
    required this.loggedInIrId,
    this.weeklyInfoTarget = 0,
    this.weeklyPlanTarget = 0,
    this.weeklyUvTarget = 0,
    this.infoProgress = 0,
    this.planProgress = 0,
    this.uvProgress = 0,
    this.weekNumber = 0,
    this.year = 0,
  });

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  List<dynamic> members = [];
  Map<String, int> memberLeadCounts = {};
  Map<String, int> memberPlanCounts = {};
  Map<String, int> memberUvCounts = {};
  bool isLoading = true;
  String error = '';

  int currentWeeklyInfoTarget = 0;
  int currentWeeklyPlanTarget = 0;
  int currentWeeklyUvTarget = 0;
  int currentInfoProgress = 0;
  int currentPlanProgress = 0;
  int currentUvProgress = 0;
  int currentWeekNumber = 0;
  int currentYear = 0;
  

  bool get isManager => widget.userRole <= 2;
  bool get isTeamLead => widget.userRole == 3;
  bool get canSetTargets => widget.userRole <= 3;

  int get totalTeamCalls => memberLeadCounts.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    currentWeeklyInfoTarget = widget.weeklyInfoTarget;
    currentWeeklyPlanTarget = widget.weeklyPlanTarget;
    currentWeeklyUvTarget = widget.weeklyUvTarget;
    currentInfoProgress = widget.infoProgress;
    currentPlanProgress = widget.planProgress;
    currentUvProgress = widget.uvProgress;
    currentWeekNumber = widget.weekNumber;
    currentYear = widget.year;
    fetchTeamMembers();
  }

  Future<void> fetchTeamMembers() async {
    final url = Uri.parse('$baseUrl/api/team_members/${widget.teamId}');

    try {
      setState(() {
        isLoading = true;
        error = '';
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          members = data;
        });

        await _fetchTeamMetrics();

        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Failed to load members. (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTeamMetrics() async {
    final result = await ApiService.getTeamInfoTotal(widget.teamId);
    if (!mounted) return;

    if (result['success'] == true) {
      final dynamic data = result['data'];
      if (data is Map<String, dynamic>) {
        final membersData = (data['members'] as List<dynamic>? ?? []);

        final updatedLeadCounts = <String, int>{};
        final updatedPlanCounts = <String, int>{};
        final updatedUvCounts = <String, int>{};

        for (final entry in membersData) {
          if (entry is Map<String, dynamic>) {
            final memberId = (entry['ir_id'] ?? '').toString();
            if (memberId.isEmpty) continue;

            updatedLeadCounts[memberId] = _parseInt(entry['info_total']);
            updatedPlanCounts[memberId] = _parseInt(entry['plan_total']);
            updatedUvCounts[memberId] = _parseInt(entry['uv_count']);
          }
        }

        int infoTotal = _parseInt(data['members_info_total'] ?? data['running_weekly_info_done']);
        int planTotal = _parseInt(data['members_plan_total'] ?? data['running_weekly_plan_done']);
        int uvTotal = _parseInt(data['members_uv_total'] ?? data['running_weekly_uv_done']);

        if (infoTotal == 0 && updatedLeadCounts.isNotEmpty) {
          infoTotal = updatedLeadCounts.values.fold(0, (sum, value) => sum + value);
        }
        if (planTotal == 0 && updatedPlanCounts.isNotEmpty) {
          planTotal = updatedPlanCounts.values.fold(0, (sum, value) => sum + value);
        }
        if (uvTotal == 0 && updatedUvCounts.isNotEmpty) {
          uvTotal = updatedUvCounts.values.fold(0, (sum, value) => sum + value);
        }

        final int weekNumber = _parseInt(data['week_number'] ?? currentWeekNumber);
        final int year = _parseInt(data['year'] ?? currentYear);

        setState(() {
          memberLeadCounts = updatedLeadCounts;
          memberPlanCounts = updatedPlanCounts;
          memberUvCounts = updatedUvCounts;
          currentInfoProgress = infoTotal;
          currentPlanProgress = planTotal;
          currentUvProgress = uvTotal;
          currentWeekNumber = weekNumber;
          currentYear = year;
        });
      }
    } else {
      debugPrint('Failed to fetch team metrics: ${result['error']}');
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _showSetTargetsDialog() {
    final infoTargetController = TextEditingController(text: currentWeeklyInfoTarget.toString());
    final planTargetController = TextEditingController(text: currentWeeklyPlanTarget.toString());
    final uvTargetController = TextEditingController(text: currentWeeklyUvTarget.toString());
    bool isSubmitting = false;
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Set Targets', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: infoTargetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Weekly Info Target',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: planTargetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Weekly Plan Target',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: uvTargetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Weekly UV Target',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final infoTarget = int.tryParse(infoTargetController.text) ?? 0;
                          final planTarget = int.tryParse(planTargetController.text) ?? 0;
                          final uvTarget = int.tryParse(uvTargetController.text) ?? 0;

                          if (infoTarget < 0 || planTarget < 0 || uvTarget < 0) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Targets must be positive numbers')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.setTargets(
                            teamId: widget.teamId,
                            teamWeeklyInfoTarget: infoTarget,
                            teamWeeklyPlanTarget: planTarget,
                            teamWeeklyUvTarget: uvTarget,
                            actingIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isSubmitting = false);
                          debugPrint('Set targets result: ${result['success']}');
                          if (result['success']) {
                            Navigator.pop(dialogContext);
                            setState(() {
                              currentWeeklyInfoTarget = infoTarget;
                              currentWeeklyPlanTarget = planTarget;
                              currentWeeklyUvTarget = uvTarget;
                            });
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Targets updated successfully!')),
                            );
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text(result['error'] ?? 'Failed to update targets')),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSubmitting ? Colors.grey : Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onMemberTap(String irId) {
    final bool canViewOthers = widget.userRole <= 3;

    if (canViewOthers || irId == widget.loggedInIrId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            personName: irId,
            irId: irId,
            userRole: widget.userRole,
            loggedInIrId: widget.loggedInIrId,
          ),
        ),
      ).then((_) {
        _fetchTeamMetrics();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only view your own dashboard')),
      );
    }
  }

  Widget _buildTargetsHeader() {
    final hasWeekInfo = currentWeekNumber > 0;
    final weekLabel = hasWeekInfo
      ? 'Team Targets for week $currentWeekNumber'
      : 'Team Targets';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            weekLabel,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTargetItem('Info Target', currentInfoProgress, currentWeeklyInfoTarget, Colors.cyanAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTargetItem('Plan Target', currentPlanProgress, currentWeeklyPlanTarget, Colors.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTargetItem('UV Target', currentUvProgress, currentWeeklyUvTarget, Colors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetItem(String label, int current, int target, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            '$current / $target',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF121212),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.teamName),
            Text(
              '${members.length} members',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      ),
      floatingActionButton: canSetTargets
          ? FloatingActionButton(
              onPressed: _showSetTargetsDialog,
              backgroundColor: Colors.cyanAccent,
              child: const Icon(Icons.track_changes, color: Colors.black),
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error, style: const TextStyle(color: Colors.white70)))
              : Column(
                  children: [
                    if (widget.userRole <= 3) _buildTargetsHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final String memberId = (member['ir_id'] ?? member['ir'] ?? '').toString();
                          final String displayName = (member['ir_name'] ?? member['ir'] ?? memberId).toString();
                          final int roleNum = member['role_num'] ?? 5;
                          final bool isOwnProfile = memberId.isNotEmpty && memberId == widget.loggedInIrId;

                          final int leadCount = memberLeadCounts[memberId] ?? 0;
                          final int planCount = memberPlanCounts[memberId] ?? 0;
                          final int uvCount = memberUvCounts[memberId] ?? 0;

                          final bool canTap = widget.userRole <= 3 || isOwnProfile;
                          final bool shouldHideStats = widget.userRole == 4 && !isOwnProfile;

                          return Opacity(
                            opacity: canTap ? 1.0 : 0.5,
                            child: InfoCard(
                              managerName: isOwnProfile ? '$displayName (You)' : displayName,
                              totalCalls: leadCount,
                              targetCalls: 0,
                              totalTurnover: uvCount.toDouble(),
                              clientMeetings: planCount,
                              targetMeetings: 0,
                              isManager: roleNum == 2,
                              isLead: roleNum == 3,
                              onTap: canTap ? () => _onMemberTap(memberId) : () {},
                              hideStats: shouldHideStats,
                              showMemberFormat: true,
                              // no trailing action here; dashboard FAB is shown on the member's DashboardPage
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
