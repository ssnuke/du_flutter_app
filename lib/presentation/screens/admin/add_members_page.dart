import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadtracker/core/constants/access_levels.dart';
import 'package:leadtracker/data/services/api_service.dart';
import 'package:leadtracker/core/constants/api_constants.dart';
import 'package:leadtracker/main.dart';

class AddMemberSheet extends StatefulWidget {
  final String irId;
  final int userRole;
  final VoidCallback? onDataChanged;
  final BuildContext? parentContext;

  const AddMemberSheet({
    super.key,
    required this.irId,
    required this.userRole,
    this.onDataChanged,
    this.parentContext,
  });

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  bool showCreateTeam = false;
  bool showAddMember = false;
  bool showSetTargets = false;
  bool showDeleteTeam = false;
  bool showRemoveIrFromTeam = false;
  bool showChangeAccessLevel = false;
  bool _isLoading = false;
  bool _isFetchingData = false;
  bool _isFetchingIrTeams = false;

  final _teamNameController = TextEditingController();
  final _weeklyInfoTargetController = TextEditingController();
  final _weeklyPlanTargetController = TextEditingController();
  final _weeklyUvTargetController = TextEditingController();
  final _searchIrController = TextEditingController();
  final _searchRemoveIrController = TextEditingController();
  final _searchAccessLevelIrController = TextEditingController();

  String? _selectedIrId;
  String? _selectedTeamId;
  String? _selectedRole = 'IR'; // Default to IR role
  String? _selectedTargetTeamId;
  String? _selectedDeleteTeamId;
  String? _selectedRemoveIrId;
  String? _selectedRemoveTeamId;
  String? _selectedAccessLevelIrId;
  int? _selectedNewAccessLevel;

  List<Map<String, dynamic>> _allIrs = [];
  List<Map<String, dynamic>> _filteredIrs = [];
  List<Map<String, dynamic>> _filteredRemoveIrs = [];
  List<Map<String, dynamic>> _filteredAccessLevelIrs = [];
  List<Map<String, dynamic>> _managerTeams = [];
  List<Map<String, dynamic>> _irTeams = []; // Teams that selected IR belongs to

  // Role-based permission checks using AccessLevel utility
  bool get hasFullAccess => AccessLevel.hasFullAccess(widget.userRole);
  bool get canCreateTeam => AccessLevel.canCreateTeam(widget.userRole);
  bool get canManageTeams => AccessLevel.canManageTeams(widget.userRole);
  bool get canChangeAccessLevels => AccessLevel.canChangeAccessLevels(widget.userRole);
  bool get canDeleteTeams => AccessLevel.canDeleteTeams(widget.userRole);

  @override
  void dispose() {
    _teamNameController.dispose();
    _weeklyInfoTargetController.dispose();
    _weeklyPlanTargetController.dispose();
    _weeklyUvTargetController.dispose();
    _searchIrController.dispose();
    _searchRemoveIrController.dispose();
    _searchAccessLevelIrController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(widget.parentContext ?? context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchAllIrs() async {
    if (!mounted) return;
    setState(() => _isFetchingData = true);

    try {
      final irsUrl = Uri.parse('$baseUrl/api/irs');
      print('Fetching IRs from: $irsUrl');
      final irsResponse = await http.get(irsUrl);
      print('IRs response status: ${irsResponse.statusCode}');
      print('IRs response body: ${irsResponse.body}');

      if (irsResponse.statusCode == 200) {
        final dynamic responseBody = json.decode(irsResponse.body);
        // Handle both {"data": [...]} and direct [...] formats
        final List<dynamic> irsData = responseBody is List
            ? responseBody
            : (responseBody['data'] as List<dynamic>? ?? []);
        print('Parsed ${irsData.length} IRs');
        if (!mounted) return;
        setState(() {
          _allIrs = irsData
              .where((ir) => 
                ir['ir_id'] != null && 
                ir['ir_id'].toString().isNotEmpty &&
                ir['ir_access_level'] != 1) // Filter out SuperAdmin
              .map<Map<String, dynamic>>((ir) => {
                'ir_id': ir['ir_id'].toString(),
                'ir_name': (ir['ir_name'] ?? ir['ir_id']).toString(),
                'ir_access_level': ir['ir_access_level'] ?? 5,
              }).toList();
          _filteredIrs = List.from(_allIrs);
          _filteredRemoveIrs = List.from(_allIrs);
          _filteredAccessLevelIrs = List.from(_allIrs);
        });
        print('All IRs loaded: ${_allIrs.length} items (SuperAdmin filtered out)');
        if (_allIrs.isEmpty) {
          _showSnackBar('No IRs found in the system', isError: true);
        }
      } else {
        _showSnackBar('Failed to load IRs (${irsResponse.statusCode})', isError: true);
      }
    } catch (e) {
      print('Error fetching IRs: $e');
      _showSnackBar('Error fetching IRs: $e', isError: true);
    }

    if (!mounted) return;
    setState(() => _isFetchingData = false);
  }

  Future<void> _fetchManagerTeams() async {
    if (!mounted) return;
    setState(() => _isFetchingData = true);

    try {
      // ADMIN/CTC can see all teams, LDC sees only their teams
      final String endpoint = hasFullAccess
          ? getTeamsEndpoint
          : '$getTeamsByLdcEndpoint/${widget.irId}';
      final teamsUrl = Uri.parse('$baseUrl$endpoint');
      final teamsResponse = await http.get(teamsUrl);

      if (teamsResponse.statusCode == 200) {
        final List<dynamic> teamsData = json.decode(teamsResponse.body);
        if (!mounted) return;
        setState(() {
          _managerTeams = teamsData.map<Map<String, dynamic>>((team) => {
            'id': (team['id'] ?? '').toString(),
            'name': (team['name'] ?? 'Unnamed Team').toString(),
            'weekly_info_target': team['weekly_info_target'] ?? 0,
            'weekly_plan_target': team['weekly_plan_target'] ?? 0,
            'weekly_uv_target': team['weekly_uv_target'] ?? team['uv_target'] ?? 0,
          }).toList();
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching teams: $e', isError: true);
    }

    if (!mounted) return;
    setState(() => _isFetchingData = false);
  }

  void _onTeamSelectedForTargets(String? teamId) {
    setState(() {
      _selectedTargetTeamId = teamId;
      if (teamId != null) {
        final team = _managerTeams.firstWhere(
          (t) => t['id'] == teamId,
          orElse: () => {'weekly_info_target': 0, 'weekly_plan_target': 0, 'weekly_uv_target': 0},
        );
        _weeklyInfoTargetController.text = (team['weekly_info_target'] ?? 0).toString();
        _weeklyPlanTargetController.text = (team['weekly_plan_target'] ?? 0).toString();
        _weeklyUvTargetController.text = (team['weekly_uv_target'] ?? 0).toString();
      }
    });
  }

  Future<void> _setTargets() async {
    if (_selectedTargetTeamId == null) {
      _showSnackBar('Please select a team', isError: true);
      return;
    }

    final infoTarget = int.tryParse(_weeklyInfoTargetController.text) ?? 0;
    final planTarget = int.tryParse(_weeklyPlanTargetController.text) ?? 0;
    final uvTarget = int.tryParse(_weeklyUvTargetController.text) ?? 0;

    if (infoTarget < 0 || planTarget < 0 || uvTarget < 0) {
      _showSnackBar('Targets must be positive numbers', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await ApiService.setTargets(
      teamId: _selectedTargetTeamId!,
      teamWeeklyInfoTarget: infoTarget,
      teamWeeklyPlanTarget: planTarget,
      teamWeeklyUvTarget: uvTarget,
      actingIrId: widget.irId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      final callback = widget.onDataChanged;

      setState(() {
        _selectedTargetTeamId = null;
        _weeklyInfoTargetController.clear();
        _weeklyPlanTargetController.clear();
        _weeklyUvTargetController.clear();
        showSetTargets = false;
      });
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Targets set successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to set targets', isError: true);
    }
  }

  Future<void> _deleteTeam() async {
    if (_selectedDeleteTeamId == null) {
      _showSnackBar('Please select a team to delete', isError: true);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: const Text('Are you sure you want to delete this team? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await ApiService.deleteTeam(_selectedDeleteTeamId!);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      final callback = widget.onDataChanged;

      if (!mounted) return;
      setState(() {
        _selectedDeleteTeamId = null;
        showDeleteTeam = false;
      });
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Team deleted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to delete team', isError: true);
    }
  }

  Future<void> _fetchTeamsForIr(String irId) async {
    if (!mounted) return;
    setState(() {
      _isFetchingIrTeams = true;
      _irTeams = [];
      _selectedRemoveTeamId = null;
    });

    try {
      final url = Uri.parse('$baseUrl/api/teams_by_ir/$irId');
      print('Fetching teams for IR: $url');
      final response = await http.get(url);
      print('Teams for IR response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseBody = json.decode(response.body);
        final List<dynamic> teamsData = responseBody is List
            ? responseBody
            : (responseBody['data'] as List<dynamic>? ?? []);

        if (!mounted) return;
        setState(() {
          _irTeams = teamsData.map<Map<String, dynamic>>((team) => {
            'id': (team['id'] ?? team['team_id'] ?? '').toString(),
            'name': (team['name'] ?? team['team_name'] ?? 'Unnamed Team').toString(),
          }).toList();
        });

        if (_irTeams.isEmpty) {
          _showSnackBar('This IR is not part of any team', isError: true);
        }
      } else {
        _showSnackBar('Failed to fetch teams for this IR', isError: true);
      }
    } catch (e) {
      print('Error fetching IR teams: $e');
      _showSnackBar('Error fetching teams: $e', isError: true);
    }

    if (!mounted) return;
    setState(() => _isFetchingIrTeams = false);
  }

  Future<void> _removeIrFromTeam() async {
    if (_selectedRemoveIrId == null) {
      _showSnackBar('Please select an IR', isError: true);
      return;
    }
    if (_selectedRemoveTeamId == null) {
      _showSnackBar('Please select a team', isError: true);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove IR from Team'),
        content: const Text('Are you sure you want to remove this IR from the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await ApiService.removeIrFromTeam(
      teamId: _selectedRemoveTeamId!,
      irId: _selectedRemoveIrId!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      final callback = widget.onDataChanged;

      if (!mounted) return;
      setState(() {
        _selectedRemoveIrId = null;
        _selectedRemoveTeamId = null;
        _irTeams = [];
        showRemoveIrFromTeam = false;
      });
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('IR removed from team successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to remove IR from team', isError: true);
    }
  }

  Future<void> _createTeam() async {
    if (_teamNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a team name', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final teamName = _teamNameController.text.trim();
    print('Creating team with name: "$teamName"');
    
    final result = await ApiService.createTeam(
      teamName,
      widget.irId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final callback = widget.onDataChanged;

      _teamNameController.clear();
      if (!mounted) return;
      setState(() => showCreateTeam = false);
      
      // Refresh the teams list so newly created team appears in dropdowns
      await _fetchManagerTeams();
      
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Team created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to create team', isError: true);
    }
  }

  Future<void> _addMemberToTeam() async {
    if (_selectedIrId == null) {
      _showSnackBar('Please select an IR', isError: true);
      return;
    }
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team', isError: true);
      return;
    }
    if (_selectedRole == null) {
      _showSnackBar('Please select a role', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await ApiService.addIrToTeam(
      irId: _selectedIrId!,
      teamId: _selectedTeamId!,
      role: _selectedRole!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final callback = widget.onDataChanged;

      if (!mounted) return;
      setState(() {
        _selectedIrId = null;
        _selectedTeamId = null;
        _selectedRole = null;
        showAddMember = false;
      });
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Member added to team successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to add member', isError: true);
    }
  }

  void _filterIrsForAddMember(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredIrs = List.from(_allIrs);
      } else {
        _filteredIrs = _allIrs.where((ir) {
          final irId = ir['ir_id'].toString().toLowerCase();
          final irName = ir['ir_name'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return irId.contains(searchLower) || irName.contains(searchLower);
        }).toList();
      }
    });
  }

  void _filterIrsForRemove(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRemoveIrs = List.from(_allIrs);
      } else {
        _filteredRemoveIrs = _allIrs.where((ir) {
          final irId = ir['ir_id'].toString().toLowerCase();
          final irName = ir['ir_name'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return irId.contains(searchLower) || irName.contains(searchLower);
        }).toList();
      }
    });
  }

  void _filterIrsForAccessLevel(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAccessLevelIrs = List.from(_allIrs);
      } else {
        _filteredAccessLevelIrs = _allIrs.where((ir) {
          final irId = ir['ir_id'].toString().toLowerCase();
          final irName = ir['ir_name'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return irId.contains(searchLower) || irName.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _changeAccessLevel() async {
    if (_selectedAccessLevelIrId == null) {
      _showSnackBar('Please select an IR', isError: true);
      return;
    }
    if (_selectedNewAccessLevel == null) {
      _showSnackBar('Please select a new access level', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await ApiService.changeAccessLevel(
      actingIrId: widget.irId,
      targetIrId: _selectedAccessLevelIrId!,
      newAccessLevel: _selectedNewAccessLevel!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final callback = widget.onDataChanged;
      final targetIrId = result['target_ir_id'] as String?;
      final newAccessLevel = result['new_access_level'] as int?;

      // Check if the modified user is the currently logged-in user
      // If so, update SharedPreferences and force app restart
      bool isOwnAccount = targetIrId == widget.irId;
      
      if (isOwnAccount && newAccessLevel != null) {
        // Update SharedPreferences with new access level
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userRole', newAccessLevel);
        print('✅ Updated own access level in SharedPreferences: ${widget.userRole} -> $newAccessLevel');
      }

      if (!mounted) return;
      setState(() {
        _selectedAccessLevelIrId = null;
        _selectedNewAccessLevel = null;
        showChangeAccessLevel = false;
      });
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Access level changed successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // If user changed their own account, force app restart
      if (isOwnAccount) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showRestartDialog();
          }
        });
      } else {
        // Show info for other users
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note: The affected user will see their new role badge when they restart the app.'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 5),
              ),
            );
          }
        });
      }

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to change access level', isError: true);
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Access Level Changed'),
        content: const Text(
          'Your access level has been changed. The app needs to restart for the changes to take effect.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to splash screen which will reload with new role
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MyApp()),
                (route) => false,
              );
            },
            child: const Text('Restart Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

          // Create Team
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () => setState(() => showCreateTeam = true),
              child: Card(
                child: const ListTile(
                  title: Text("Create Team"),
                  trailing: Icon(Icons.group_add),
                  textColor: Colors.cyan,
                ),
              ),
            ),

          // Add Member to Team
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () {
                setState(() => showAddMember = true);
                _fetchAllIrs();
                _fetchManagerTeams();
              },
              child: Card(
                child: const ListTile(
                  title: Text("Add Member to Team"),
                  trailing: Icon(Icons.person_add),
                ),
              ),
            ),

          // Remove IR from Team (ADMIN, CTC, LDC only)
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () {
                setState(() => showRemoveIrFromTeam = true);
                _fetchAllIrs();
              },
              child: Card(
                child: const ListTile(
                  title: Text("Remove IR from Team"),
                  trailing: Icon(Icons.person_remove, color: Colors.orange),
                ),
              ),
            ),

          // Promote/Demote IR (ADMIN, CTC only - not LDC)
          if (canChangeAccessLevels && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () {
                setState(() => showChangeAccessLevel = true);
                _fetchAllIrs();
              },
              child: Card(
                child: const ListTile(
                  title: Text("Promote / Demote IR"),
                  trailing: Icon(Icons.admin_panel_settings, color: Colors.purple),
                ),
              ),
            ),

          // Set Targets (ADMIN, CTC, LDC)
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () {
                setState(() => showSetTargets = true);
                _fetchManagerTeams();
              },
              child: Card(
                child: const ListTile(
                  title: Text("Set Targets"),
                  trailing: Icon(Icons.track_changes),
                ),
              ),
            ),

          // Delete Team (ADMIN, CTC, LDC)
          if (canDeleteTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam && !showChangeAccessLevel)
            GestureDetector(
              onTap: () {
                setState(() => showDeleteTeam = true);
                _fetchManagerTeams();
              },
              child: Card(
                child: const ListTile(
                  title: Text("Delete Team"),
                  trailing: Icon(Icons.delete, color: Colors.red),
                ),
              ),
            ),

          // Create Team Form
          if (showCreateTeam)
            Column(
              children: [
                TextField(
                  controller: _teamNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => showCreateTeam = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _isLoading ? null : _createTeam,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(
                          color: _isLoading ? Colors.grey : Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          // Add Member Form
          if (showAddMember)
            _isFetchingData
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                : Column(
                    children: [
                      // Search field for IRs
                      TextField(
                        controller: _searchIrController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Search IR',
                          hintText: 'Search by ID or Name',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _searchIrController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchIrController.clear();
                                    _filterIrsForAddMember('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _filterIrsForAddMember,
                      ),
                      const SizedBox(height: 16),

                      _filteredIrs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _allIrs.isEmpty 
                                        ? 'No IRs available. Check API connection.' 
                                        : 'No IRs match your search.',
                                    ),
                                  ),
                                  if (_allIrs.isEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      onPressed: _fetchAllIrs,
                                    ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedIrId,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF1E1E1E),
                              decoration: const InputDecoration(
                                labelText: 'Select IR',
                                border: OutlineInputBorder(),
                                hintText: 'Choose an IR',
                              ),
                              isExpanded: true,
                              items: _filteredIrs.map((ir) {
                                return DropdownMenuItem<String>(
                                  value: ir['ir_id'] as String,
                                  child: Text('${ir['ir_name']} (${ir['ir_id']})'),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedIrId = value),
                            ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        style: const TextStyle(color: Colors.white),
                        dropdownColor: const Color(0xFF1E1E1E),
                        decoration: const InputDecoration(labelText: 'Select Team', border: OutlineInputBorder()),
                        items: _managerTeams.map((team) {
                          return DropdownMenuItem<String>(value: team['id'] as String, child: Text(team['name'] as String));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedTeamId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        style: const TextStyle(color: Colors.white),
                        dropdownColor: const Color(0xFF1E1E1E),
                        decoration: const InputDecoration(labelText: 'Select Role', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'LDC', child: Text('LDC (Manager)')),
                          DropdownMenuItem(value: 'LS', child: Text('LS (Team Lead)')),
                          DropdownMenuItem(value: 'IR', child: Text('IR (Member)')),
                        ],
                        onChanged: (value) => setState(() => _selectedRole = value),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => showAddMember = false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _addMemberToTeam,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Add to Team'),
                          ),
                        ],
                      ),
                    ],
                  ),

          // Set Targets Form
          if (showSetTargets)
            _isFetchingData
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedTargetTeamId,
                        style: const TextStyle(color: Colors.white),
                        dropdownColor: const Color(0xFF1E1E1E),
                        decoration: const InputDecoration(labelText: 'Select Team', border: OutlineInputBorder()),
                        items: _managerTeams.map((team) {
                          return DropdownMenuItem<String>(value: team['id'] as String, child: Text(team['name'] as String));
                        }).toList(),
                        onChanged: _onTeamSelectedForTargets,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _weeklyInfoTargetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Weekly Info Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _weeklyPlanTargetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Weekly Plan Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _weeklyUvTargetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Weekly UV Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => showSetTargets = false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _setTargets,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Set Targets'),
                          ),
                        ],
                      ),
                    ],
                  ),

          // Delete Team Form
          if (showDeleteTeam)
            _isFetchingData
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _managerTeams.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('No teams available to delete.')),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedDeleteTeamId,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF1E1E1E),
                              decoration: const InputDecoration(
                                labelText: 'Select Team to Delete',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: _managerTeams.map((team) {
                                return DropdownMenuItem<String>(
                                  value: team['id'] as String,
                                  child: Text(team['name'] as String),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedDeleteTeamId = value),
                            ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              showDeleteTeam = false;
                              _selectedDeleteTeamId = null;
                            }),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading || _selectedDeleteTeamId == null ? null : _deleteTeam,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Delete Team'),
                          ),
                        ],
                      ),
                    ],
                  ),

          // Remove IR from Team Form
          if (showRemoveIrFromTeam)
            _isFetchingData
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                : Column(
                    children: [
                      // Search field for IRs
                      TextField(
                        controller: _searchRemoveIrController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Search IR',
                          hintText: 'Search by ID or Name',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _searchRemoveIrController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchRemoveIrController.clear();
                                    _filterIrsForRemove('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _filterIrsForRemove,
                      ),
                      const SizedBox(height: 16),

                      // Step 1: Select IR
                      _filteredRemoveIrs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _allIrs.isEmpty 
                                        ? 'No IRs available.' 
                                        : 'No IRs match your search.',
                                    ),
                                  ),
                                  if (_allIrs.isEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      onPressed: _fetchAllIrs,
                                    ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedRemoveIrId,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF1E1E1E),
                              decoration: const InputDecoration(
                                labelText: 'Select IR to Remove',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: _filteredRemoveIrs.map((ir) {
                                return DropdownMenuItem<String>(
                                  value: ir['ir_id'] as String,
                                  child: Text('${ir['ir_name']} (${ir['ir_id']})'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRemoveIrId = value;
                                  _selectedRemoveTeamId = null;
                                  _irTeams = [];
                                });
                                if (value != null) {
                                  _fetchTeamsForIr(value);
                                }
                              },
                            ),
                      const SizedBox(height: 16),

                      // Step 2: Select Team (only shown after IR is selected)
                      if (_selectedRemoveIrId != null)
                        _isFetchingIrTeams
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              )
                            : _irTeams.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.orange),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning_amber, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('This IR is not part of any team.')),
                                      ],
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedRemoveTeamId,
                                    style: const TextStyle(color: Colors.white),
                                    dropdownColor: const Color(0xFF1E1E1E),
                                    decoration: const InputDecoration(
                                      labelText: 'Select Team',
                                      border: OutlineInputBorder(),
                                    ),
                                    isExpanded: true,
                                    items: _irTeams.map((team) {
                                      return DropdownMenuItem<String>(
                                        value: team['id'] as String,
                                        child: Text(team['name'] as String),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _selectedRemoveTeamId = value),
                                  ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              showRemoveIrFromTeam = false;
                              _selectedRemoveIrId = null;
                              _selectedRemoveTeamId = null;
                              _irTeams = [];
                            }),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isLoading || _selectedRemoveIrId == null || _selectedRemoveTeamId == null
                                  ? null
                                  : _removeIrFromTeam,
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Remove'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

          // Change Access Level Form
          if (showChangeAccessLevel)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Promote / Demote IR",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (_isFetchingData)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ))
                else ...[
                  // Search field for IRs
                  TextField(
                    controller: _searchAccessLevelIrController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Search IR',
                      hintText: 'Search by ID or Name',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchAccessLevelIrController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchAccessLevelIrController.clear();
                                _filterIrsForAccessLevel('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _filterIrsForAccessLevel,
                  ),
                  const SizedBox(height: 16),

                  if (_filteredAccessLevelIrs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _allIrs.isEmpty 
                                ? 'No IRs available' 
                                : 'No IRs match your search.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          if (_allIrs.isEmpty)
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _fetchAllIrs,
                            ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedAccessLevelIrId,
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF1E1E1E),
                      decoration: const InputDecoration(
                        labelText: 'Select IR',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: _filteredAccessLevelIrs.map((ir) {
                        return DropdownMenuItem<String>(
                          value: ir['ir_id'] as String,
                          child: Text('${ir['ir_name']} (${ir['ir_id']})'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedAccessLevelIrId = value),
                    ),
                ],

                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _selectedNewAccessLevel,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E1E1E),
                  decoration: const InputDecoration(
                    labelText: 'New Access Level',
                    border: OutlineInputBorder(),
                    helperText: '1=Admin, 2=CTC, 3=LDC, 4=LS, 5=GC, 6=IR',
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Level 1 - Admin')),
                    DropdownMenuItem(value: 2, child: Text('Level 2 - CTC')),
                    DropdownMenuItem(value: 3, child: Text('Level 3 - LDC')),
                    DropdownMenuItem(value: 4, child: Text('Level 4 - LS')),
                    DropdownMenuItem(value: 5, child: Text('Level 5 - GC')),
                    DropdownMenuItem(value: 6, child: Text('Level 6 - IR')),
                  ],
                  onChanged: (value) => setState(() => _selectedNewAccessLevel = value),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        showChangeAccessLevel = false;
                        _selectedAccessLevelIrId = null;
                        _selectedNewAccessLevel = null;
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoading || _selectedAccessLevelIrId == null || _selectedNewAccessLevel == null
                            ? null
                            : _changeAccessLevel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLoading || _selectedAccessLevelIrId == null || _selectedNewAccessLevel == null
                                ? Colors.grey
                                : Colors.purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Change Access Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
