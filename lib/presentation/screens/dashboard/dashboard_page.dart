import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:leadtracker/core/constants/access_levels.dart';
import 'package:leadtracker/core/constants/api_constants.dart';
import 'package:leadtracker/data/services/api_service.dart';

class DashboardPage extends StatefulWidget {
  final String personName;
  final String irId;
  final int userRole;
  final String loggedInIrId;

  const DashboardPage({
    super.key,
    required this.personName,
    required this.irId,
    required this.userRole,
    required this.loggedInIrId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _filteredLeads = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _filteredPlans = [];
  bool _isLoading = true;
  String _error = '';
  String _selectedTab = 'Infos';
  bool _plansLoaded = false;
  String? _selectedPlanStatusFilter; // null means 'All'
  String? _selectedInfoResponseFilter; // null means 'All'
  
  // Week filter state
  int? selectedWeekNumber;
  int? selectedYear;
  List<Map<String, dynamic>> availableWeeks = [];
  bool isLoadingWeeks = false;
  int? currentWeekNumber;
  int? currentYear;

  int totalCalls = 0;
  double totalTurnover = 0;
  int totalMeetings = 0;

  // Role-based permission checks
  bool get isOwnDashboard => widget.irId == widget.loggedInIrId;
  
  /// Can add leads/plans:
  /// - ADMIN/CTC: Can add for anyone
  /// - LDC: Can add for members of teams they manage
  /// - LS: Can add for team members
  /// - GC/IR: Can add only for themselves
  bool get canAddLead => AccessLevel.canAddDataFor(
    actorLevel: widget.userRole,
    actorId: widget.loggedInIrId,
    targetId: widget.irId,
  );
  
  bool get canAddPlan => AccessLevel.canAddDataFor(
    actorLevel: widget.userRole,
    actorId: widget.loggedInIrId,
    targetId: widget.irId,
  );
  
  /// Can edit existing leads/plans:
  /// - ADMIN/CTC: Can edit anyone's data
  /// - LDC: Can edit team members' data
  /// - LS: Can edit team members' data
  /// - GC/IR: Can only edit own data
  bool get canEdit => AccessLevel.canEditUser(
    actorLevel: widget.userRole,
    actorId: widget.loggedInIrId,
    targetId: widget.irId,
  );
  
  /// Can delete leads/plans:
  /// - ADMIN/CTC: Can delete anyone's data
  /// - LDC: Can delete team members' data
  /// - LS: Can delete team members' data
  /// - GC/IR: Can only delete own data
  bool get canDelete => AccessLevel.canEditUser(
    actorLevel: widget.userRole,
    actorId: widget.loggedInIrId,
    targetId: widget.irId,
  );
  
  /// GC/IR viewing their own dashboard - view only mode
  bool get isViewOnlyMode => AccessLevel.isViewOnly(widget.userRole) && !isOwnDashboard;

  @override
  void initState() {
    super.initState();
    _fetchAvailableWeeks();
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
        
        // Fetch data after weeks are loaded
        await _fetchLeads();
        await _fetchPlans();
        await _fetchUvCount();
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

  Future<void> _fetchLeads() async {
    if (selectedWeekNumber == null || selectedYear == null) {
      debugPrint('Cannot fetch leads: week or year not set');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final result = await ApiService.getInfoDetails(
        widget.irId,
        response: _selectedInfoResponseFilter,
        week: selectedWeekNumber,
        year: selectedYear,
      );

      if (result['success']) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _leads = data.map((item) {
            return {
              'id': item['id'],
              'name': item['info_name'] ?? 'Unknown',
              'date': DateTime.tryParse(item['info_date'] ?? '') ?? DateTime.now(),
              'status': item['response'] ?? 'N/A',
              'comments': item['comments'] ?? '',
            };
          }).toList();
          _filteredLeads = _leads; // When using week filter, all leads are already filtered
          _isLoading = false;
          totalCalls = _leads.length;
        });
      } else {
        debugPrint('Failed to fetch leads: ${result['error']}');
        setState(() {
          _error = result['error'] ?? 'Failed to fetch leads';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchLeads: $e');
      setState(() {
        _error = 'Error fetching leads: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPlans() async {
    if (selectedWeekNumber == null || selectedYear == null) {
      debugPrint('Cannot fetch plans: week or year not set');
      return;
    }
    
    try {
      final result = await ApiService.getPlanDetails(
        widget.irId,
        status: _selectedPlanStatusFilter,
        week: selectedWeekNumber,
        year: selectedYear,
      );

      if (result['success']) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _plans = data.map((item) {
            return {
              'id': item['id'],
              'prospect_name': item['plan_name'] ?? 'Unknown',
              'date': DateTime.tryParse(item['plan_date'] ?? '') ?? DateTime.now(),
              'comments': item['comments'] ?? '',
              'status': item['status'] ?? 'closing_pending',
            };
          }).toList();
          _filteredPlans = _plans; // When using week filter, all plans are already filtered
          _plansLoaded = true;
          totalMeetings = _plans.length;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchPlans: $e');
    }
  }

  Future<void> _fetchUvCount() async {
    final result = await ApiService.getUvCount(widget.irId);

    if (result['success']) {
      final data = result['data'];

      double? parseToDouble(dynamic value) {
        if (value is num) {
          return value.toDouble();
        }
        if (value is String) {
          return double.tryParse(value);
        }
        return null;
      }

      double? parsedValue;
      if (data is Map<String, dynamic>) {
        const candidateKeys = ['uv_count', 'uvCount', 'total', 'value'];
        for (final key in candidateKeys) {
          if (data.containsKey(key)) {
            parsedValue = parseToDouble(data[key]);
            if (parsedValue != null) {
              break;
            }
          }
        }
      } else {
        parsedValue = parseToDouble(data);
      }

      if (parsedValue != null) {
        final double newValue = parsedValue;
        if (!mounted) return;
        setState(() {
          totalTurnover = newValue;
        });
      } else {
        debugPrint('Unable to parse UV count from response: $data');
      }
    } else {
      debugPrint('Failed to fetch UV count: ${result['error']}');
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
                            });
                            _fetchLeads();
                            _fetchPlans();
                            _fetchUvCount();
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

  void _showAddLeadDialog() {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    String selectedResponse = 'A';
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    final parentContext = context;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Add Lead', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedResponse,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Response',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                      ),
                      items: ['A', 'B', 'C'].map((r) {
                        return DropdownMenuItem(value: r, child: Text('Response $r'));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedResponse = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comments',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.cyanAccent,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E2E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(selectedDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                            if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Please enter a name')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.addInfoDetail(
                            irId: widget.irId,
                            infoName: nameController.text.trim(),
                            response: selectedResponse,
                            comments: commentController.text.trim(),
                            infoDate: selectedDate,
                          );

                          setDialogState(() => isSubmitting = false);

                            if (result['success']) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Lead added successfully!')),
                            );
                            _fetchLeads();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text(result['error'] ?? 'Failed to add lead')),
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
                        : const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPlanDialog() {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'closing_pending';
    bool isSubmitting = false;
    final parentContext = context;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Add Plan', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Prospect Name',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comments',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.amber,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E2E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.amber, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(selectedDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'closing_pending', child: Text('Closing Pending')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        DropdownMenuItem(value: 'uvs_on_counter', child: Text("UV's on Counter")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'IR ID: ${widget.irId}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Please enter prospect name')),
                            );
                            return;
                          }

                          if (commentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Please enter comments')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.addPlanDetail(
                            irId: widget.irId,
                            planName: nameController.text.trim(),
                            response: '', // Not used for plans
                            comments: commentController.text.trim(),
                            planDate: selectedDate,
                            status: selectedStatus,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          if (result['success']) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Plan added successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchPlans();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to add plan'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSubmitting ? Colors.grey : Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddUvFallenDialog() {
    final uvController = TextEditingController();
    final parentContext = context;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text("Add UV's Fallen", style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: uvController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'UV Count',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orangeAccent),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final rawValue = uvController.text.trim();
                          if (rawValue.isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Please enter the UV count')),
                            );
                            return;
                          }

                          final parsedValue = double.tryParse(rawValue);
                          if (parsedValue == null) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Enter a valid number')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.addUvFallen(
                            irId: widget.irId,
                            uvCount: parsedValue,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (!mounted) return;

                          if (result['success']) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text("UV's fallen recorded"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _fetchUvCount();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to add UV count'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSubmitting ? Colors.grey : Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
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

  void _showDeleteLeadDialog(Map<String, dynamic> lead) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;
        final parentContext = context;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Delete Lead', style: TextStyle(color: Colors.white)),
              content: Text(
                'Are you sure you want to delete "${lead['name']}"?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);

                          final result = await ApiService.deleteInfoDetail(
                            lead['id'],
                            requesterIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isDeleting = false);

                          if (!mounted) return;
                          Navigator.pop(dialogContext);

                          if (result['success']) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Lead deleted successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchLeads();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to delete lead'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isDeleting ? Colors.grey : Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeletePlanDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;
        final parentContext = context;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Delete Plan', style: TextStyle(color: Colors.white)),
              content: Text(
                'Are you sure you want to delete plan for "${plan['prospect_name']}"?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);

                          final result = await ApiService.deletePlanDetail(
                            plan['id'],
                            requesterIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isDeleting = false);

                          if (!mounted) return;
                          Navigator.pop(dialogContext);

                          if (result['success']) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Plan deleted successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchPlans();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to delete plan'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isDeleting ? Colors.grey : Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditLeadDialog(Map<String, dynamic> lead) {
    final nameController = TextEditingController(text: lead['name']);
    final commentController = TextEditingController(text: lead['comments'] ?? '');
    String selectedResponse = lead['status'] ?? 'A';
    DateTime selectedDate = lead['date'] ?? DateTime.now();
    bool isSubmitting = false;
    final parentContext = context;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Edit Lead', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(153)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedResponse,
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Response',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(153)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                      ),
                      items: ['A', 'B', 'C'].map((r) {
                        return DropdownMenuItem(value: r, child: Text('Response $r'));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedResponse = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Comments',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(153)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.cyanAccent,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E2E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withAlpha(77)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(selectedDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Please enter a name')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.updateInfoDetail(
                            ir: widget.irId,
                            infoId: lead['id'],
                            infoName: nameController.text.trim(),
                            response: selectedResponse,
                            comments: commentController.text.trim(),
                            infoDate: selectedDate,
                            requesterIrId: widget.loggedInIrId,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (result['success']) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('Lead updated successfully!')),
                            );
                            _fetchLeads();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(content: Text(result['error'] ?? 'Failed to update lead')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF121212),
        title: Text(widget.personName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeads,
          ),
        ],
      ),
      floatingActionButton: (canAddLead || canAddPlan)
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1E1E2E),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Choose Action',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (canAddLead)
                          ListTile(
                            leading: const Icon(Icons.info_outline, color: Colors.cyanAccent),
                            title: const Text('Add Infos', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddLeadDialog();
                            },
                          ),
                        if (canAddPlan)
                          ListTile(
                            leading: const Icon(Icons.event, color: Colors.amber),
                            title: const Text('Add Plan', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddPlanDialog();
                            },
                          ),
                        if (canAddPlan)
                          ListTile(
                            leading: const Icon(Icons.trending_down, color: Colors.orangeAccent),
                            title: const Text("Add UV's Fallen", style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddUvFallenDialog();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
              backgroundColor: Colors.cyanAccent,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _fetchLeads,
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
              : Column(
                  children: [
                    // Week filter dropdown
                    _buildWeekFilter(),

                    // Summary card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem('Calls', totalCalls.toString()),
                          _buildSummaryItem('UVs', totalTurnover.toStringAsFixed(1)),
                          _buildSummaryItem('Plans', totalMeetings.toString()),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tab bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 'Infos'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 'Infos' ? Colors.cyanAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Infos',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedTab == 'Infos' ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedTab = 'Plans');
                                if (!_plansLoaded) {
                                  _fetchPlans();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 'Plans' ? Colors.amber : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Plans',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedTab == 'Plans' ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info response filter (only show when Infos tab is selected)
                    if (_selectedTab == 'Infos')
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedInfoResponseFilter,
                                  dropdownColor: const Color(0xFF1E1E2E),
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  hint: const Text('All Infos', style: TextStyle(color: Colors.white)),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('All Infos')),
                                    DropdownMenuItem(value: 'A', child: Text('A')),
                                    DropdownMenuItem(value: 'B', child: Text('B')),
                                    DropdownMenuItem(value: 'C', child: Text('C')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedInfoResponseFilter = value;
                                      _fetchLeads();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_selectedTab == 'Infos') const SizedBox(height: 16),

                    // Plan status filter (only show when Plans tab is selected)
                    if (_selectedTab == 'Plans')
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list, color: Colors.amber, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedPlanStatusFilter,
                                  dropdownColor: const Color(0xFF1E1E2E),
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  hint: const Text('All Plans', style: TextStyle(color: Colors.white)),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('All Plans')),
                                    DropdownMenuItem(value: 'closing_pending', child: Text('Closing Pending')),
                                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                                    DropdownMenuItem(value: 'uvs_on_counter', child: Text("UV's on Counter")),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPlanStatusFilter = value;
                                      _fetchPlans();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_selectedTab == 'Plans') const SizedBox(height: 16),

                    // Tabbed content
                    Expanded(
                      child: _selectedTab == 'Infos'
                          ? (_filteredLeads.isEmpty
                              ? Center(
                                  child: Text(
                                    canAddLead ? 'No leads. Tap + to add.' : 'No leads for this period.',
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                )
                              : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredLeads.length,
                              itemBuilder: (context, index) {
                                final lead = _filteredLeads[index];
                                final String comments = lead['comments'] ?? '';
                                return Card(
                                  color: const Color(0xFF1E1E2E),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: _getResponseColor(lead['status']),
                                              child: Text(lead['status'], style: const TextStyle(color: Colors.white)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(lead['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    DateFormat('MMM dd, yyyy').format(lead['date']),
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (canEdit)
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                                                onPressed: () => _showEditLeadDialog(lead),
                                              ),
                                            if (canDelete)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                                onPressed: () => _showDeleteLeadDialog(lead),
                                              ),
                                          ],
                                        ),
                                        if (comments.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(13),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.comment, color: Colors.white.withAlpha(128), size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    comments,
                                                    style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                          ))
                          : (_filteredPlans.isEmpty
                              ? Center(
                                  child: Text(
                                    canAddPlan ? 'No plans. Tap + to add.' : 'No plans for this period.',
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                )
                              : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredPlans.length,
                              itemBuilder: (context, index) {
                                final plan = _filteredPlans[index];
                                final String comments = plan['comments'] ?? '';
                                return Card(
                                  color: const Color(0xFF1E1E2E),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.amber,
                                              child: const Icon(Icons.calendar_today, color: Colors.black, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(plan['prospect_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    DateFormat('MMM dd, yyyy').format(plan['date']),
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getPlanStatusColor(plan['status'] ?? 'closing_pending'),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      _getPlanStatusLabel(plan['status'] ?? 'closing_pending'),
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (canEdit)
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                                onPressed: () => _showEditPlanDialog(plan),
                                              ),
                                            if (canDelete)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                                onPressed: () => _showDeletePlanDialog(plan),
                                              ),
                                          ],
                                        ),
                                        if (comments.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(13),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.comment, color: Colors.white.withAlpha(128), size: 16),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    comments,
                                                    style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                          )),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }

  void _showEditPlanDialog(Map<String, dynamic> plan) {
    final commentController = TextEditingController(text: plan['comments'] ?? '');
    String selectedStatus = plan['status'] ?? 'closing_pending';
    bool isSubmitting = false;
    final parentContext = context;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              title: const Text('Edit Plan', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Prospect: ${plan['prospect_name']}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Date: ${DateFormat('MMM dd, yyyy').format(plan['date'])}',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                      dropdownColor: const Color(0xFF1E1E2E),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'closing_pending', child: Text('Closing Pending')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        DropdownMenuItem(value: 'uvs_on_counter', child: Text("UV's on Counter")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Comments',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                GestureDetector(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          if (commentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Comments cannot be empty'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final result = await ApiService.updatePlanDetail(
                            ir: widget.irId,
                            planId: plan['id'],
                            planName: plan['prospect_name'],
                            comments: commentController.text.trim(),
                            requesterIrId: widget.loggedInIrId,
                            status: selectedStatus,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          if (result['success']) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Plan updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _fetchPlans();
                          } else {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to update plan'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSubmitting ? Colors.grey : Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Update', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getResponseColor(String response) {
    switch (response) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.purple;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPlanStatusColor(String status) {
    switch (status) {
      case 'closed':
        return Colors.green;
      case 'closing_pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'uvs_on_counter':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getPlanStatusLabel(String status) {
    switch (status) {
      case 'closed':
        return 'Closed';
      case 'closing_pending':
        return 'Closing Pending';
      case 'rejected':
        return 'Rejected';
      case 'uvs_on_counter':
        return "UV's on Counter";
      default:
        return 'Unknown';
    }
  }
}
