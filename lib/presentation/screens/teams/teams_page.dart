import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/core/constants/access_levels.dart';
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
  int? currentWeekNumber;
  int? currentYear;
  
  // Week filter state
  int? selectedWeekNumber;
  int? selectedYear;
  List<Map<String, dynamic>> availableWeeks = [];
  bool isLoadingWeeks = false;

  // Role-based checks
  bool get hasFullAccess => AccessLevel.hasFullAccess(widget.userRole);
  bool get canManageTeams => AccessLevel.canManageTeams(widget.userRole);

  @override
  void initState() {
    super.initState();
    _fetchAvailableWeeks();
    _fetchVisibleTeams();
  }
  
  /// Fetches available weeks from the backend
  Future<void> _fetchAvailableWeeks() async {
    setState(() {
      isLoadingWeeks = true;
    });

    try {
      final url = Uri.parse('$baseUrl/api/available_weeks/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> weeks = responseData['weeks'] ?? [];
        
        setState(() {
          availableWeeks = weeks.cast<Map<String, dynamic>>();
          currentWeekNumber = responseData['current_week'];
          currentYear = responseData['current_year'];
          // Set selected to current week initially
          selectedWeekNumber = currentWeekNumber;
          selectedYear = currentYear;
          isLoadingWeeks = false;
        });
      } else {
        setState(() {
          isLoadingWeeks = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching available weeks: $e');
      setState(() {
        isLoadingWeeks = false;
      });
    }
  }

  /// Fetches all visible teams using the hierarchy-based visible_teams API
  /// Teams created by the logged-in user appear first, followed by other teams in their subtree
  Future<void> _fetchVisibleTeams() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    // Build URL with week filter if selected
    var url = Uri.parse('$baseUrl$getVisibleTeamsEndpoint/${widget.irId}');
    if (selectedWeekNumber != null && selectedYear != null) {
      url = Uri.parse('$baseUrl$getVisibleTeamsEndpoint/${widget.irId}?week=$selectedWeekNumber&year=$selectedYear');
    }

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> teamsJson = responseData['teams'] ?? [];
        
        // Store week info from response
        currentWeekNumber = responseData['week_number'];
        currentYear = responseData['year'];

        // Only preserve previous values if we're fetching the same week
        // This prevents historical week data from being overwritten with current week data
        final isSameWeekAsBefore = teamData.isNotEmpty && 
                                    teamData.first.weekNumber == currentWeekNumber &&
                                    teamData.first.year == currentYear;
        final previousTargets = isSameWeekAsBefore ? {for (var t in teamData) t.id: t} : <String, Team>{};

        final List<Team> fetched = teamsJson.map((item) => Team.fromJson(item)).toList();

        // Sort teams: Teams created by logged-in user first, then others
        fetched.sort((a, b) {
          final aIsOwn = a.createdById == widget.irId;
          final bIsOwn = b.createdById == widget.irId;
          
          // Own teams first
          if (aIsOwn && !bIsOwn) return -1;
          if (!aIsOwn && bIsOwn) return 1;
          
          // Within same category, sort by name
          return a.name.compareTo(b.name);
        });

        final merged = fetched.map((t) {
          final prev = previousTargets[t.id];
          if (prev != null && isSameWeekAsBefore) {
            // Only merge with previous non-zero values if it's the same week
            return t.copyWith(
              weeklyInfoTarget: (t.weeklyInfoTarget == 0 && prev.weeklyInfoTarget != 0) ? prev.weeklyInfoTarget : t.weeklyInfoTarget,
              weeklyPlanTarget: (t.weeklyPlanTarget == 0 && prev.weeklyPlanTarget != 0) ? prev.weeklyPlanTarget : t.weeklyPlanTarget,
              weeklyUvTarget: (t.weeklyUvTarget == 0 && prev.weeklyUvTarget != 0) ? prev.weeklyUvTarget : t.weeklyUvTarget,
              infoProgress: (t.infoProgress == 0 && prev.infoProgress != 0) ? prev.infoProgress : t.infoProgress,
              planProgress: (t.planProgress == 0 && prev.planProgress != 0) ? prev.planProgress : t.planProgress,
              uvProgress: (t.uvProgress == 0 && prev.uvProgress != 0) ? prev.uvProgress : t.uvProgress,
              weekNumber: t.weekNumber != 0 ? t.weekNumber : prev.weekNumber,
              year: t.year != 0 ? t.year : prev.year,
            );
          }
          return t;
        }).toList();

        setState(() {
          teamData = merged;
          isLoading = false;
        });
        
        debugPrint('Visible teams fetched: ${teamData.length} items');

        // Always fetch targets and calls for the currently displayed teams
        // await _fetchTargetsForTeams();
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
    if (selectedWeekNumber == null || availableWeeks.isEmpty) return;

    final selectedWeekData = availableWeeks.firstWhere(
      (w) => w['week_number'] == selectedWeekNumber,
      orElse: () => {},
    );

    if (selectedWeekData.isEmpty) return;

    final fromDate = selectedWeekData['week_start']?.split('T')[0];
    final toDate = selectedWeekData['week_end']?.split('T')[0];

    if (fromDate == null || toDate == null) return;

    debugPrint('_fetchTeamTotalCalls: starting for week $selectedWeekNumber ($fromDate to $toDate)');
    
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

            final result = await ApiService.getInfoDetails(irId, fromDate: fromDate, toDate: toDate);
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
    if (teamData.isEmpty || selectedWeekNumber == null) return;
    try {
      // Pass week and year to get targets for the selected week
      final result = await ApiService.getTargetsDashboard(
        widget.irId,
        week: selectedWeekNumber,
        year: selectedYear,
      );
      if (result['success']) {
        final data = result['data'];
        // debugPrint("Fetched targets data: $data");
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

  Widget _buildWeekFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Week: ',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: isLoadingWeeks
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedWeekNumber,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                        items: availableWeeks.map((week) {
                          final weekNum = week['week_number'] as int;
                          final isCurrent = week['is_current'] as bool? ?? false;
                          return DropdownMenuItem<int>(
                            value: weekNum,
                            child: Row(
                              children: [
                                Text(
                                  'Week $weekNum',
                                  style: TextStyle(
                                    color: isCurrent ? Colors.cyanAccent : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (isCurrent)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text(
                                      '(Current)',
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null && value != selectedWeekNumber) {
                            setState(() {
                              selectedWeekNumber = value;
                              // Year should stay the same for now
                            });
                            _fetchVisibleTeams();
                          }
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // When navigated from ManagersPage, show with Scaffold and back button
    final bool showAsSubPage = widget.managerName != null;

    final content = Column(
      children: [
        // Week filter dropdown
        _buildWeekFilter(),
        // Main content
        Expanded(
          child: isLoading
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
                            onTap: _fetchVisibleTeams,
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
                                'Contact your LDC to be added to a team',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchVisibleTeams,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: teamData.length,
                            itemBuilder: (context, index) {
                              final team = teamData[index];
                              final int actualCalls = team.infoProgress != 0
                                  ? team.infoProgress
                                  : (teamTotalCalls[team.id] ?? 0);
                              
                              // Check if this team was created by the logged-in user
                              final isOwnTeam = team.createdById == widget.irId;
                              
                              return InfoCard(
                                managerName: team.name,
                                totalCalls: actualCalls,
                                targetCalls: team.weeklyInfoTarget,
                                totalTurnover: team.uvProgress.toDouble(),
                                targetUv: team.weeklyUvTarget,
                                clientMeetings: team.planProgress,
                                targetMeetings: team.weeklyPlanTarget,
                                isTeam: true,
                                isOwnTeam: isOwnTeam,
                                createdByName: team.createdByName,
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
                                        selectedWeekNumber: selectedWeekNumber,
                                        selectedYear: selectedYear,
                                      ),
                                    ),
                                  ).then((_) {
                                    // Re-fetch team list with current week filter
                                    _fetchVisibleTeams();
                                  });
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );

    if (showAsSubPage) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
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
