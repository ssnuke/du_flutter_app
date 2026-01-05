import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/presentation/screens/teams/team_members_page.dart';
import 'package:leadtracker/presentation/widgets/info_card.dart';
import 'package:leadtracker/data/models/team_model.dart';
import 'package:leadtracker/data/services/api_service.dart';
import 'package:leadtracker/core/constants/api_constants.dart';

class TeamsPage extends StatefulWidget {
  final String? managerName;
  final String irId;
  final int userRole;
  final String? loggedInIrId;

  const TeamsPage({
    super.key,
    this.managerName,
    required this.irId,
    required this.userRole,
    this.loggedInIrId,
  });

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  List<Team> teamData = [];
  Map<String, int> teamTotalCalls = {};
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final endpoint = widget.userRole >= 3
        ? '$getTeamsByIrEndpoint/${widget.irId}'
        : '$getTeamsByLdcEndpoint/${widget.irId}';

    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // preserve previous non-zero target values to avoid overwriting with 0
        final previousTargets = {for (var t in teamData) t.id: t};

        final List<Team> fetched = data.map((item) => Team.fromJson(item)).toList();

        final merged = fetched.map((t) {
          final prev = previousTargets[t.id];
          if (prev != null) {
            final info = (t.weeklyInfoTarget == 0 && prev.weeklyInfoTarget != 0) ? prev.weeklyInfoTarget : t.weeklyInfoTarget;
            final plan = (t.weeklyPlanTarget == 0 && prev.weeklyPlanTarget != 0) ? prev.weeklyPlanTarget : t.weeklyPlanTarget;
            final uv = (t.weeklyUvTarget == 0 && prev.weeklyUvTarget != 0) ? prev.weeklyUvTarget : t.weeklyUvTarget;
            final infoProgress = (t.infoProgress == 0 && prev.infoProgress != 0) ? prev.infoProgress : t.infoProgress;
            final planProgress = (t.planProgress == 0 && prev.planProgress != 0) ? prev.planProgress : t.planProgress;
            final uvProgress = (t.uvProgress == 0 && prev.uvProgress != 0) ? prev.uvProgress : t.uvProgress;
            final weekNumber = t.weekNumber != 0 ? t.weekNumber : prev.weekNumber;
            final year = t.year != 0 ? t.year : prev.year;
            return Team(
              name: t.name,
              id: t.id,
              weeklyInfoTarget: info,
              weeklyPlanTarget: plan,
              weeklyUvTarget: uv,
              infoProgress: infoProgress,
              planProgress: planProgress,
              uvProgress: uvProgress,
              weekNumber: weekNumber,
              year: year,
            );
          }
          return t;
        }).toList();

        setState(() {
          teamData = merged;
          isLoading = false;
        });
        // Fetch per-team targets (if stored separately) and then compute totals.
        debugPrint('Teams fetched: ${teamData.length} items');
        await _fetchTargetsForTeams();
        await _fetchTeamTotalCalls();
      } else {
        setState(() {
          errorMessage = 'Failed to load teams (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching teams: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTeamTotalCalls() async {
    debugPrint('_fetchTeamTotalCalls: starting for ${teamData.length} teams');
    for (final team in teamData) {
      try {
        final url = Uri.parse('$baseUrl/api/team_members/${team.id}');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final List<dynamic> members = json.decode(response.body);
          int totalCalls = 0;

          for (final member in members) {
            final String irId = member['ir_id'] ?? '';
            if (irId.isEmpty) continue;

            final result = await ApiService.getInfoDetails(irId);
            if (result['success']) {
              final List<dynamic> leads = result['data'] ?? [];
              totalCalls += leads.length;
            }
          }

          if (mounted) {
            setState(() {
              teamTotalCalls[team.id] = totalCalls;
            });
          }
        }
      } catch (e) {
        debugPrint('Error in _fetchTeamTotalCalls for team ${team.id}: $e');
      }
    }
  }

  /// Some backends store team targets separately (e.g., targets dashboard).
  /// Try to fetch targets for the current user and merge them into the `teamData`.
  Future<void> _fetchTargetsForTeams() async {
    if (teamData.isEmpty) return;
    try {
      final result = await ApiService.getTargetsDashboard(widget.irId);
      if (result['success']) {
        final data = result['data'];
        debugPrint("Fetched targets data: $data");
        // Build a mapping of teamId -> targets
        final Map<String, Map<String, int>> mapping = {};

        if (data is List) {
          for (final item in data) {
            final teamId = (item['team_id'] ?? item['id'] ?? '').toString();
            if (teamId.isEmpty) continue;
            final infoT = int.tryParse((item['team_weekly_info_target'] ?? item['weekly_info_target'] ?? 0).toString()) ?? 0;
            final planT = int.tryParse((item['team_weekly_plan_target'] ?? item['weekly_plan_target'] ?? 0).toString()) ?? 0;
            final uvT = int.tryParse((item['team_weekly_uv_target'] ?? item['weekly_uv_target'] ?? item['uv_target'] ?? 0).toString()) ?? 0;
            final infoProgress = int.tryParse((item['info_progress'] ?? item['info_count'] ?? 0).toString()) ?? 0;
            final planProgress = int.tryParse((item['plan_progress'] ?? item['plan_count'] ?? 0).toString()) ?? 0;
            final uvProgress = int.tryParse((item['uv_progress'] ?? item['uv_count'] ?? 0).toString()) ?? 0;
            final weekNumber = int.tryParse((item['week_number'] ?? 0).toString()) ?? 0;
            final year = int.tryParse((item['year'] ?? 0).toString()) ?? 0;
            mapping[teamId] = {
              'info': infoT,
              'plan': planT,
              'uv': uvT,
              'infoProgress': infoProgress,
              'planProgress': planProgress,
              'uvProgress': uvProgress,
              'weekNumber': weekNumber,
              'year': year,
            };
          }
        } else if (data is Map) {
          // If backend returns a map keyed by team id or single object
          if (data.containsKey('teams') && data['teams'] is List) {
            for (final item in data['teams']) {
              final teamId = (item['team_id'] ?? item['id'] ?? '').toString();
              if (teamId.isEmpty) continue;
              final infoT = int.tryParse((item['team_weekly_info_target'] ?? item['weekly_info_target'] ?? 0).toString()) ?? 0;
              final planT = int.tryParse((item['team_weekly_plan_target'] ?? item['weekly_plan_target'] ?? 0).toString()) ?? 0;
              final uvT = int.tryParse((item['team_weekly_uv_target'] ?? item['weekly_uv_target'] ?? item['uv_target'] ?? 0).toString()) ?? 0;
              final infoProgress = int.tryParse((item['info_progress'] ?? item['info_count'] ?? 0).toString()) ?? 0;
              final planProgress = int.tryParse((item['plan_progress'] ?? item['plan_count'] ?? 0).toString()) ?? 0;
              final uvProgress = int.tryParse((item['uv_progress'] ?? item['uv_count'] ?? 0).toString()) ?? 0;
              final weekNumber = int.tryParse((item['week_number'] ?? 0).toString()) ?? 0;
              final year = int.tryParse((item['year'] ?? 0).toString()) ?? 0;
              mapping[teamId] = {
                'info': infoT,
                'plan': planT,
                'uv': uvT,
                'infoProgress': infoProgress,
                'planProgress': planProgress,
                'uvProgress': uvProgress,
                'weekNumber': weekNumber,
                'year': year,
              };
            }
          } else {
            // maybe single team object
            final teamId = (data['team_id'] ?? data['id'] ?? '').toString();
            if (teamId.isNotEmpty) {
              final infoT = int.tryParse((data['team_weekly_info_target'] ?? data['weekly_info_target'] ?? 0).toString()) ?? 0;
              final planT = int.tryParse((data['team_weekly_plan_target'] ?? data['weekly_plan_target'] ?? 0).toString()) ?? 0;
              final uvT = int.tryParse((data['team_weekly_uv_target'] ?? data['weekly_uv_target'] ?? data['uv_target'] ?? 0).toString()) ?? 0;
              final infoProgress = int.tryParse((data['info_progress'] ?? data['info_count'] ?? 0).toString()) ?? 0;
              final planProgress = int.tryParse((data['plan_progress'] ?? data['plan_count'] ?? 0).toString()) ?? 0;
              final uvProgress = int.tryParse((data['uv_progress'] ?? data['uv_count'] ?? 0).toString()) ?? 0;
              final weekNumber = int.tryParse((data['week_number'] ?? 0).toString()) ?? 0;
              final year = int.tryParse((data['year'] ?? 0).toString()) ?? 0;
              mapping[teamId] = {
                'info': infoT,
                'plan': planT,
                'uv': uvT,
                'infoProgress': infoProgress,
                'planProgress': planProgress,
                'uvProgress': uvProgress,
                'weekNumber': weekNumber,
                'year': year,
              };
            }
          }
        }

        if (mapping.isNotEmpty) {
          setState(() {
            teamData = teamData.map((t) {
              final m = mapping[t.id];
              if (m != null) {
                return Team(
                  name: t.name,
                  id: t.id,
                  weeklyInfoTarget: m['info'] ?? t.weeklyInfoTarget,
                  weeklyPlanTarget: m['plan'] ?? t.weeklyPlanTarget,
                  weeklyUvTarget: m['uv'] ?? t.weeklyUvTarget,
                  infoProgress: m['infoProgress'] ?? t.infoProgress,
                  planProgress: m['planProgress'] ?? t.planProgress,
                  uvProgress: m['uvProgress'] ?? t.uvProgress,
                  weekNumber: m['weekNumber'] ?? t.weekNumber,
                  year: m['year'] ?? t.year,
                );
              }
              return t;
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching team targets: $e");
      // ignore errors silently
    }
  }

  @override
  Widget build(BuildContext context) {
    // When navigated from ManagersPage, show with Scaffold and back button
    final bool showAsSubPage = widget.managerName != null;

    final content = isLoading
        ? const Center(child: CircularProgressIndicator())
        : errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _fetchTeams,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : teamData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        const Text(
                          'Not assigned to any team',
                          style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Contact your manager to be added to a team',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchTeams,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: teamData.length,
                      itemBuilder: (context, index) {
                        final team = teamData[index];
                        final int actualCalls = team.infoProgress != 0
                            ? team.infoProgress
                            : (teamTotalCalls[team.id] ?? 0);
                        return InfoCard(
                          managerName: team.name,
                          totalCalls: actualCalls,
                          targetCalls: team.weeklyInfoTarget,
                          totalTurnover: team.uvProgress.toDouble(),
                          targetUv: team.weeklyUvTarget,
                          clientMeetings: team.planProgress,
                          targetMeetings: team.weeklyPlanTarget,
                          isTeam: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamMembersPage(
                                  teamName: team.name,
                                  teamId: team.id,
                                  userRole: widget.userRole,
                                  loggedInIrId: widget.loggedInIrId ?? widget.irId,
                                  weeklyInfoTarget: team.weeklyInfoTarget,
                                  weeklyPlanTarget: team.weeklyPlanTarget,
                                  weeklyUvTarget: team.weeklyUvTarget,
                                  infoProgress: team.infoProgress,
                                  planProgress: team.planProgress,
                                  uvProgress: team.uvProgress,
                                  weekNumber: team.weekNumber,
                                  year: team.year,
                                ),
                              ),
                            ).then((_) {
                              // Re-fetch full team list (including weekly targets)
                              _fetchTeams();
                              _fetchTeamTotalCalls();
                            });
                          },
                        );
                      },
                    ),
                  );

    if (showAsSubPage) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          title: Text("${widget.managerName}'s Teams"),
        ),
        body: content,
      );
    }

    return content;
  }
}
