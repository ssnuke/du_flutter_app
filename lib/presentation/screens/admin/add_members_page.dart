import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:leadtracker/data/services/api_service.dart';
import 'package:leadtracker/core/constants/api_constants.dart';

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
  bool _isLoading = false;
  bool _isFetchingData = false;
  bool _isFetchingIrTeams = false;

  final _teamNameController = TextEditingController();
  final _weeklyInfoTargetController = TextEditingController();
  final _weeklyPlanTargetController = TextEditingController();
  final _weeklyUvTargetController = TextEditingController();

  String? _selectedIrId;
  String? _selectedTeamId;
  String? _selectedRole;
  String? _selectedTargetTeamId;
  String? _selectedDeleteTeamId;
  String? _selectedRemoveIrId;
  String? _selectedRemoveTeamId;

  List<Map<String, dynamic>> _allIrs = [];
  List<Map<String, dynamic>> _managerTeams = [];
  List<Map<String, dynamic>> _irTeams = []; // Teams that selected IR belongs to

  bool get isSuperAdmin => widget.userRole == 1;
  bool get isManager => widget.userRole <= 2;
  bool get canManageTeams => widget.userRole <= 3; // Super Admin, Manager, Team Lead

  @override
  void dispose() {
    _teamNameController.dispose();
    _weeklyInfoTargetController.dispose();
    _weeklyPlanTargetController.dispose();
    _weeklyUvTargetController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(widget.parentContext ?? context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchAllIrs() async {
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
        setState(() {
          _allIrs = irsData
              .where((ir) => ir['ir_id'] != null && ir['ir_id'].toString().isNotEmpty)
              .map<Map<String, dynamic>>((ir) => {
                'ir_id': ir['ir_id'].toString(),
                'ir_name': (ir['ir_name'] ?? ir['ir_id']).toString(),
              }).toList();
        });
        print('All IRs loaded: ${_allIrs.length} items');
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

    setState(() => _isFetchingData = false);
  }

  Future<void> _fetchManagerTeams() async {
    setState(() => _isFetchingData = true);

    try {
      final String endpoint = isSuperAdmin
          ? getTeamsEndpoint
          : '$getTeamsByLdcEndpoint/${widget.irId}';
      final teamsUrl = Uri.parse('$baseUrl$endpoint');
      final teamsResponse = await http.get(teamsUrl);

      if (teamsResponse.statusCode == 200) {
        final List<dynamic> teamsData = json.decode(teamsResponse.body);
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

    setState(() => _isLoading = true);

    final result = await ApiService.setTargets(
      teamId: _selectedTargetTeamId!,
      teamWeeklyInfoTarget: infoTarget,
      teamWeeklyPlanTarget: planTarget,
      teamWeeklyUvTarget: uvTarget,
      actingIrId: widget.irId,
    );

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
          behavior: SnackBarBehavior.floating,
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

    setState(() => _isLoading = true);

    final result = await ApiService.deleteTeam(_selectedDeleteTeamId!);

    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      final callback = widget.onDataChanged;

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

    setState(() => _isLoading = true);

    final result = await ApiService.removeIrFromTeam(
      teamId: _selectedRemoveTeamId!,
      irId: _selectedRemoveIrId!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      final callback = widget.onDataChanged;

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

    setState(() => _isLoading = true);

    final result = await ApiService.createTeam(_teamNameController.text.trim());

    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final callback = widget.onDataChanged;

      _teamNameController.clear();
      setState(() => showCreateTeam = false);
      Navigator.pop(context);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Team created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
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

    setState(() => _isLoading = true);

    final result = await ApiService.addIrToTeam(
      irId: _selectedIrId!,
      teamId: _selectedTeamId!,
      role: _selectedRole!,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final callback = widget.onDataChanged;

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
          behavior: SnackBarBehavior.floating,
        ),
      );

      callback?.call();
    } else {
      _showSnackBar(result['error'] ?? 'Failed to add member', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Create Team
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam)
            GestureDetector(
              onTap: () => setState(() => showCreateTeam = true),
              child: Card(
                child: const ListTile(
                  title: Text("Create Team"),
                  trailing: Icon(Icons.group_add),
                ),
              ),
            ),

          // Add Member to Team
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam)
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

          // Remove IR from Team (Super Admin, Manager only)
          if (isManager && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam)
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

          // Set Targets (Super Admin, Manager, Team Lead)
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam)
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

          // Delete Team (Super Admin, Manager, Team Lead)
          if (canManageTeams && !showAddMember && !showCreateTeam && !showSetTargets && !showDeleteTeam && !showRemoveIrFromTeam)
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
                      _allIrs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('No IRs available. Check API connection.')),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _fetchAllIrs,
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedIrId,
                              decoration: const InputDecoration(
                                labelText: 'Select IR',
                                border: OutlineInputBorder(),
                                hintText: 'Choose an IR',
                              ),
                              isExpanded: true,
                              items: _allIrs.map((ir) {
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
                        decoration: const InputDecoration(labelText: 'Select Team', border: OutlineInputBorder()),
                        items: _managerTeams.map((team) {
                          return DropdownMenuItem<String>(value: team['id'] as String, child: Text(team['name'] as String));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedTeamId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(labelText: 'Select Role', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'LDC', child: Text('LDC (Manager)')),
                          DropdownMenuItem(value: 'LS', child: Text('LS (Team Lead)')),
                          DropdownMenuItem(value: 'GC', child: Text('GC (Member)')),
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
                        decoration: const InputDecoration(
                          labelText: 'Weekly Info Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _weeklyPlanTargetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Weekly Plan Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _weeklyUvTargetController,
                        keyboardType: TextInputType.number,
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
                      // Step 1: Select IR
                      _allIrs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('No IRs available.')),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _fetchAllIrs,
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedRemoveIrId,
                              decoration: const InputDecoration(
                                labelText: 'Select IR to Remove',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: _allIrs.map((ir) {
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
        ],
      ),
    );
  }
}
