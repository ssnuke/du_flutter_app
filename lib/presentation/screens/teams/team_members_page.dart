import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/core/constants/access_levels.dart';
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
  final int? selectedWeekNumber;  // Week filter passed from teams page
  final int? selectedYear;  // Year filter passed from teams page

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
    this.selectedWeekNumber,
    this.selectedYear,
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
  bool hasTargetsSet = false; // Track if targets are already set for this week
  bool isEditingTeamName = false;
  final TextEditingController _teamNameController = TextEditingController();
  
  // Week filter state
  int? selectedWeekNumber;
  int? selectedYear;
  List<Map<String, dynamic>> availableWeeks = [];
  bool isLoadingWeeks = false;
  
  // Role-based permission checks using AccessLevel utility
  bool get hasFullAccess => AccessLevel.hasFullAccess(widget.userRole);
  bool get canManageTeams => AccessLevel.canManageTeams(widget.userRole);
  bool get canSetTargets => AccessLevel.canManageTeams(widget.userRole) && !hasTargetsSet;
  bool get canAddDataForOthers => AccessLevel.canAddDataForOthers(widget.userRole);

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
    
    // Initialize selected week from widget or use current
    selectedWeekNumber = widget.selectedWeekNumber ?? widget.weekNumber;
    selectedYear = widget.selectedYear ?? widget.year;
    
    _fetchAvailableWeeks();
    fetchTeamMembers();
    _fetchTargetStatus();
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
          // Update current week info if not set
          if (currentWeekNumber == 0) {
            currentWeekNumber = responseData['current_week'];
            currentYear = responseData['current_year'];
          }
          // Set selected to current week initially if not already set
          if (selectedWeekNumber == null || selectedWeekNumber == 0) {
            selectedWeekNumber = currentWeekNumber;
            selectedYear = currentYear;
          }
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

  Future<void> fetchTeamMembers() async {
    var url = Uri.parse('$baseUrl/api/team_members/${widget.teamId}');
    
    // Add week filter if selected
    if (selectedWeekNumber != null && selectedYear != null && (selectedYear ?? 0) > 0) {
      url = Uri.parse('$baseUrl/api/team_members/${widget.teamId}?week=$selectedWeekNumber&year=$selectedYear');
    }

    try {
      setState(() {
        isLoading = true;
        error = '';
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Aggregate team totals from member data
        int teamInfoTotal = 0;
        int teamPlanTotal = 0;
        int teamUvTotal = 0;
        
        for (final member in data) {
          teamInfoTotal += _parseInt(member['info_count'] ?? 0);
          teamPlanTotal += _parseInt(member['plan_count'] ?? 0);
          teamUvTotal += _parseInt(member['uv_count'] ?? 0);
        }

        // Store the original current week before updating
        final originalCurrentWeek = currentWeekNumber;
        
        setState(() {
          members = data;
          // Update team progress with aggregated values
          currentInfoProgress = teamInfoTotal;
          currentPlanProgress = teamPlanTotal;
          currentUvProgress = teamUvTotal;
          // Update week number to reflect selected week
          currentWeekNumber = selectedWeekNumber ?? currentWeekNumber;
          currentYear = selectedYear ?? currentYear;
        });

        // Fetch targets for the selected week
        await _fetchWeekTargets();

        // Only fetch additional metrics if viewing current week (using original week number)
        // _fetchTeamMetrics doesn't support week filtering, so skip it for historical weeks
        final isViewingCurrentWeek = selectedWeekNumber == null || 
                                      (originalCurrentWeek > 0 && selectedWeekNumber == originalCurrentWeek);
        if (isViewingCurrentWeek) {
          // Don't overwrite the aggregated progress values - only update member maps
          await _fetchTeamMetrics();
        }

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
          // Don't overwrite currentInfoProgress, currentPlanProgress, currentUvProgress
          // because they were already set from aggregated member data in fetchTeamMembers()
          // Only update them if the aggregated values are higher
          if (infoTotal > currentInfoProgress) currentInfoProgress = infoTotal;
          if (planTotal > currentPlanProgress) currentPlanProgress = planTotal;
          if (uvTotal > currentUvProgress) currentUvProgress = uvTotal;
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

  Future<void> _fetchTargetStatus() async {
    try {
      final result = await ApiService.getTargets(teamId: widget.teamId);
      if (!mounted) return;
      
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic> && data.containsKey('team')) {
          final teamData = data['team'];
          final bool targetsSet = teamData['has_weekly_targets_set'] ?? false;
          
          setState(() {
            hasTargetsSet = targetsSet;
          });
          
          debugPrint('Target status for team ${widget.teamId}: hasTargetsSet=$hasTargetsSet');
        }
      }
    } catch (e) {
      debugPrint('Error fetching target status: $e');
      // Don't update state on error - keep default behavior
    }
  }

  Future<void> _fetchWeekTargets() async {
    try {
      final result = await ApiService.getTargets(
        teamId: widget.teamId,
        week: selectedWeekNumber,
        year: selectedYear,
      );
      if (!mounted) return;
      
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic> && data.containsKey('team')) {
          final teamData = data['team'];
          
          setState(() {
            currentWeeklyInfoTarget = _parseInt(teamData['weekly_info_target']);
            currentWeeklyPlanTarget = _parseInt(teamData['weekly_plan_target']);
            currentWeeklyUvTarget = _parseInt(teamData['weekly_uv_target']);
          });
          
          debugPrint('Loaded targets for week $selectedWeekNumber: Info=$currentWeeklyInfoTarget, Plan=$currentWeeklyPlanTarget, UV=$currentWeeklyUvTarget');
        }
      }
    } catch (e) {
      debugPrint('Error fetching week targets: $e');
    }
  }

  Future<void> _saveTeamName() async {
    final newName = _teamNameController.text.trim();
    
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (newName == widget.teamName) {
      setState(() {
        isEditingTeamName = false;
      });
      return;
    }
    
    setState(() {
      isEditingTeamName = false;
    });
    
    final result = await ApiService.updateTeamName(
      teamId: int.parse(widget.teamId),
      newName: newName,
      requesterIrId: widget.loggedInIrId,
    );
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team name updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to update team name'),
          backgroundColor: Colors.red,
        ),
      );
      // Revert the name if update failed
      _teamNameController.text = widget.teamName;
    }
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
                              hasTargetsSet = true; // Mark targets as set
                            });
                            _fetchTargetStatus(); // Refresh status from backend
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
    // LS (level 4) and above can view team members' dashboards
    final bool canViewOthers = widget.userRole <= 4;

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

  void _showMoveIrDialog(String irId, String irName) async {
    // Fetch all available teams
    List<dynamic> availableTeams = [];
    bool loadingTeams = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? selectedTeamId;
        bool isMoving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load teams when dialog opens
            if (loadingTeams) {
              () async {
                try {
                  final result = await ApiService.getVisibleTeams(widget.loggedInIrId);
                  if (result['success']) {
                    final teams = result['data'] as List<dynamic>;
                    setDialogState(() {
                      // Exclude current team from the list
                      availableTeams = teams.where((t) => t['team_id'].toString() != widget.teamId).toList();
                      loadingTeams = false;
                    });
                  } else {
                    setDialogState(() {
                      loadingTeams = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load teams: ${result['error']}')),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    loadingTeams = false;
                  });
                }
              }();
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: Text(
                'Move $irName to Another Team',
                style: const TextStyle(color: Colors.white),
              ),
              content: loadingTeams
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : availableTeams.isEmpty
                      ? const Text(
                          'No other teams available',
                          style: TextStyle(color: Colors.white70),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select destination team:',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A3E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedTeamId,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A3E),
                                  hint: const Text(
                                    'Choose a team',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  items: availableTeams.map((team) {
                                    return DropdownMenuItem<String>(
                                      value: team['team_id'].toString(),
                                      child: Text(
                                        team['team_name'] ?? 'Team ${team['team_id']}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isMoving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            selectedTeamId = value;
                                          });
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
              actions: [
                TextButton(
                  onPressed: isMoving ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
                GestureDetector(
                  onTap: isMoving || selectedTeamId == null
                      ? null
                      : () async {
                          setDialogState(() => isMoving = true);

                          final result = await ApiService.moveIrToTeam(
                            irId: irId,
                            currentTeamId: widget.teamId,
                            newTeamId: selectedTeamId!,
                            requesterIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isMoving = false);

                          Navigator.pop(dialogContext);

                          if (result['success']) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$irName moved successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Refresh the members list
                            fetchTeamMembers();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to move IR'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isMoving || selectedTeamId == null
                          ? Colors.grey
                          : Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isMoving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Move',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _changeAccessLevel(
    String irId,
    String irName,
    int currentLevel,
    int newLevel,
    {required bool isPromotion}
  ) async {
    final action = isPromotion ? 'Promote' : 'Demote';
    final currentRoleName = AccessLevel.getRoleName(currentLevel);
    final newRoleName = AccessLevel.getRoleName(newLevel);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          '$action $irName?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Change access level from $currentRoleName (Level $currentLevel) to $newRoleName (Level $newLevel)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPromotion ? Colors.green : Colors.orange,
            ),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('${action}ing $irName...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    final result = await ApiService.changeAccessLevel(
      actingIrId: widget.loggedInIrId,
      targetIrId: irId,
      newAccessLevel: newLevel,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$irName ${isPromotion ? 'promoted' : 'demoted'} to $newRoleName successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      fetchTeamMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to change access level'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmRemoveIr(String irId, String irName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Remove Member?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove $irName from ${widget.teamName}?\n\nThis will remove them from this team only. Their data and account will remain intact.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Removing $irName...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    final result = await ApiService.removeIrFromTeam(
      teamId: widget.teamId,
      irId: irId,
      requesterIrId: widget.loggedInIrId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$irName removed from team successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      fetchTeamMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to remove member'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTargetsHeader() {
    final displayWeekNumber = selectedWeekNumber ?? currentWeekNumber;
    final hasWeekInfo = displayWeekNumber > 0;
    final weekLabel = hasWeekInfo
      ? 'Team Targets for week $displayWeekNumber'
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
                        // Ensure value is one of the items; else set to null to avoid crash
                        value: (selectedWeekNumber != null && availableWeeks.any((w) => _parseInt(w['week_number']) == selectedWeekNumber))
                            ? selectedWeekNumber
                            : null,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                        items: availableWeeks.map((week) {
                          final weekNum = _parseInt(week['week_number']);
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
                          if (value != null) {
                            setState(() {
                              selectedWeekNumber = value;
                              // Ensure a year is set; default to currentYear if unset
                              if (selectedYear == null || selectedYear == 0) {
                                selectedYear = currentYear > 0 ? currentYear : selectedYear;
                              }
                            });
                            fetchTeamMembers();
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF121212),
        title: isEditingTeamName
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _teamNameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter team name',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                      onSubmitted: (value) => _saveTeamName(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: _saveTeamName,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        isEditingTeamName = false;
                        _teamNameController.text = widget.teamName;
                      });
                    },
                  ),
                ],
              )
            : GestureDetector(
                onTap: canManageTeams ? () {
                  setState(() {
                    isEditingTeamName = true;
                    _teamNameController.text = widget.teamName;
                  });
                } : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.teamName),
                        if (canManageTeams) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, size: 16, color: Colors.white54),
                        ],
                      ],
                    ),
                    Text(
                      '${members.length} members',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
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
                    // Week filter dropdown
                    _buildWeekFilter(),
                    if (widget.userRole <= 3) _buildTargetsHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final String memberId = (member['ir_id'] ?? member['ir'] ?? '').toString();
                          final String displayName = (member['ir_name'] ?? member['ir'] ?? memberId).toString();
                          // Use ir_access_level (actual access level) if available, fallback to role_num
                          final int memberAccessLevel = member['ir_access_level'] ?? member['role_num'] ?? 6;
                          final bool isOwnProfile = memberId.isNotEmpty && memberId == widget.loggedInIrId;

                          // Use data from API response (which includes week-filtered counts)
                          // Fall back to memberLeadCounts/memberPlanCounts for current week
                          final int leadCount = member['info_count'] ?? memberLeadCounts[memberId] ?? 0;
                          final int planCount = member['plan_count'] ?? memberPlanCounts[memberId] ?? 0;
                          final int uvCount = member['uv_count'] ?? memberUvCounts[memberId] ?? 0;

                          // LS (level 4) and above can tap on team members
                          // GC/IR (level 5-6) can only tap on their own profile
                          final bool canTap = widget.userRole <= 4 || isOwnProfile;
                          // GC/IR (level 5-6) can only see stats for own profile
                          final bool shouldHideStats = widget.userRole >= 5 && !isOwnProfile;
                          // Only LDC (level 3) and above can move members
                          final bool canMoveMembers = widget.userRole <= 3 && !isOwnProfile;
                          // Only ADMIN/CTC (level 1-2) can promote/demote
                          final bool canPromoteDemote = widget.userRole <= 2 && !isOwnProfile;

                          return Opacity(
                            opacity: canTap ? 1.0 : 0.5,
                            child: InkWell(
                              onLongPress: (canMoveMembers || canPromoteDemote)
                                  ? () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: const Color(0xFF1E1E2E),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (context) {
                                          return Container(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Access Level ${AccessLevel.getRoleName(memberAccessLevel)}',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                if (canPromoteDemote) ...[
                                                  ListTile(
                                                    leading: const Icon(Icons.arrow_upward, color: Colors.green),
                                                    title: const Text(
                                                      'Promote',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    subtitle: Text(
                                                      'Increase access level',
                                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                                    ),
                                                    enabled: memberAccessLevel > 1,
                                                    onTap: memberAccessLevel > 1
                                                        ? () {
                                                            Navigator.pop(context);
                                                            _changeAccessLevel(
                                                              memberId,
                                                              displayName,
                                                              memberAccessLevel,
                                                              memberAccessLevel - 1,
                                                              isPromotion: true,
                                                            );
                                                          }
                                                        : null,
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons.arrow_downward, color: Colors.orange),
                                                    title: const Text(
                                                      'Demote',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    subtitle: Text(
                                                      'Decrease access level',
                                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                                    ),
                                                    enabled: memberAccessLevel < 6,
                                                    onTap: memberAccessLevel < 6
                                                        ? () {
                                                            Navigator.pop(context);
                                                            _changeAccessLevel(
                                                              memberId,
                                                              displayName,
                                                              memberAccessLevel,
                                                              memberAccessLevel + 1,
                                                              isPromotion: false,
                                                            );
                                                          }
                                                        : null,
                                                  ),
                                                ],
                                                if (canMoveMembers)
                                                  ListTile(
                                                    leading: const Icon(Icons.swap_horiz, color: Colors.cyanAccent),
                                                    title: const Text(
                                                      'Move to Another Team',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    subtitle: Text(
                                                      'Transfer to different team',
                                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _showMoveIrDialog(memberId, displayName);
                                                    },
                                                  ),
                                                if (canMoveMembers)
                                                  ListTile(
                                                    leading: const Icon(Icons.person_remove, color: Colors.red),
                                                    title: const Text(
                                                      'Remove from Team',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                    subtitle: Text(
                                                      'Remove member from this team',
                                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _confirmRemoveIr(memberId, displayName);
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  : null,
                              child: InfoCard(
                                managerName: isOwnProfile ? '$displayName (You)' : displayName,
                                totalCalls: leadCount,
                                targetCalls: 0,
                                totalTurnover: uvCount.toDouble(),
                                clientMeetings: planCount,
                                targetMeetings: 0,
                                accessLevel: memberAccessLevel,  // Use actual access level for proper badge display
                                onTap: canTap ? () => _onMemberTap(memberId) : null,  // No action for GC/IR on others
                                hideStats: shouldHideStats,
                                showMemberFormat: true,
                                // no trailing action here; dashboard FAB is shown on the member's DashboardPage
                              ),
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
