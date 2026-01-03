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
    debugPrint('_fetchTeams: starting for ir ${widget.irId}');
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
            return Team(name: t.name, id: t.id, weeklyInfoTarget: info, weeklyPlanTarget: plan);
          }
          return t;
        }).toList();

        debugPrint('_fetchTeams: response OK, received ${data.length} teams');
        setState(() {
          teamData = merged;
          isLoading = false;
        });
        // Fetch per-team targets (if stored separately) and then compute totals.
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
    debugPrint('_fetchTargetsForTeams: starting');
    try {
      final result = await ApiService.getTargetsDashboard(widget.irId);
      if (result['success']) {
        final data = result['data'];
        debugPrint('Fetched targets data: $data');
        // Build a mapping of teamId -> targets
        final Map<String, Map<String, int>> mapping = {};

        if (data is List) {
          for (final item in data) {
            final teamId = (item['team_id'] ?? item['id'] ?? '').toString();
            if (teamId.isEmpty) continue;
            final infoT = int.tryParse((item['team_weekly_info_target'] ?? item['weekly_info_target'] ?? 0).toString()) ?? 0;
            final planT = int.tryParse((item['team_weekly_plan_target'] ?? item['weekly_plan_target'] ?? 0).toString()) ?? 0;
            mapping[teamId] = {'info': infoT, 'plan': planT};
          }
        } else if (data is Map) {
          // If backend returns a map keyed by team id or single object
          if (data.containsKey('teams') && data['teams'] is List) {
            for (final item in data['teams']) {
              final teamId = (item['team_id'] ?? item['id'] ?? '').toString();
              if (teamId.isEmpty) continue;
              final infoT = int.tryParse((item['team_weekly_info_target'] ?? item['weekly_info_target'] ?? 0).toString()) ?? 0;
              final planT = int.tryParse((item['team_weekly_plan_target'] ?? item['weekly_plan_target'] ?? 0).toString()) ?? 0;
              mapping[teamId] = {'info': infoT, 'plan': planT};
            }
          } else {
            // maybe single team object
            final teamId = (data['team_id'] ?? data['id'] ?? '').toString();
            if (teamId.isNotEmpty) {
              final infoT = int.tryParse((data['team_weekly_info_target'] ?? data['weekly_info_target'] ?? 0).toString()) ?? 0;
              final planT = int.tryParse((data['team_weekly_plan_target'] ?? data['weekly_plan_target'] ?? 0).toString()) ?? 0;
              mapping[teamId] = {'info': infoT, 'plan': planT};
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
                    ElevatedButton(
                      onPressed: _fetchTeams,
                      child: const Text('Retry'),
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
                        final int actualCalls = teamTotalCalls[team.id] ?? 0;
                        return InfoCard(
                          managerName: team.name,
                          totalCalls: actualCalls,
                          targetCalls: team.weeklyInfoTarget,
                          totalTurnover: 0.0,
                          clientMeetings: 0,
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
                                ),
                              ),
                            ).then((_) {
                              // Re-fetch full team list (including weekly targets)
                              _fetchTeams();
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
