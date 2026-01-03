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

  const TeamMembersPage({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.userRole,
    required this.loggedInIrId,
    this.weeklyInfoTarget = 0,
    this.weeklyPlanTarget = 0,
  });

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  List<dynamic> members = [];
  Map<String, int> memberLeadCounts = {};
  bool isLoading = true;
  String error = '';

  late int currentWeeklyInfoTarget;
  late int currentWeeklyPlanTarget;

  bool get isManager => widget.userRole <= 2;
  bool get isTeamLead => widget.userRole == 3;
  bool get canSetTargets => widget.userRole <= 3;

  int get totalTeamCalls => memberLeadCounts.values.fold(0, (sum, count) => sum + count);

  @override
  void initState() {
    super.initState();
    currentWeeklyInfoTarget = widget.weeklyInfoTarget;
    currentWeeklyPlanTarget = widget.weeklyPlanTarget;
    fetchTeamMembers();
  }

  Future<void> fetchTeamMembers() async {
    final url = Uri.parse('$baseUrl/api/team_members/${widget.teamId}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          members = data;
          isLoading = false;
        });

        _fetchLeadCounts();
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

  Future<void> _fetchLeadCounts() async {
    for (final member in members) {
      final String irId = member['ir_id'] ?? '';
      if (irId.isEmpty) continue;

      final result = await ApiService.getInfoDetails(irId);
      if (result['success']) {
        final List<dynamic> leads = result['data'] ?? [];
        if (mounted) {
          setState(() {
            memberLeadCounts[irId] = leads.length;
          });
        }
      }
    }
  }

  void _showSetTargetsDialog() {
    final infoTargetController = TextEditingController(text: currentWeeklyInfoTarget.toString());
    final planTargetController = TextEditingController(text: currentWeeklyPlanTarget.toString());
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final infoTarget = int.tryParse(infoTargetController.text) ?? 0;
                          final planTarget = int.tryParse(planTargetController.text) ?? 0;


                          if (infoTarget < 0 || planTarget < 0) {
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
                            actingIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (result['success']) {
                            Navigator.pop(dialogContext);
                            setState(() {
                              currentWeeklyInfoTarget = infoTarget;
                              currentWeeklyPlanTarget = planTarget;
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
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
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
        _fetchLeadCounts();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only view your own dashboard')),
      );
    }
  }

  Widget _buildTargetsHeader() {
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
          const Text(
            'Team Targets',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTargetItem('Info Target', totalTeamCalls, currentWeeklyInfoTarget, Colors.cyanAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTargetItem('Plan Target', 0, currentWeeklyPlanTarget, Colors.amber),
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

                          final bool canTap = widget.userRole <= 3 || isOwnProfile;
                          final bool shouldHideStats = widget.userRole == 4 && !isOwnProfile;

                          return Opacity(
                            opacity: canTap ? 1.0 : 0.5,
                            child: InfoCard(
                              managerName: isOwnProfile ? '$displayName (You)' : displayName,
                              totalCalls: leadCount,
                              targetCalls: 0,
                              totalTurnover: 0.0,
                              clientMeetings: 0,
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
