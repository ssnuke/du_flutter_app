import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  String _selectedFilter = 'Weekly';
  DateTimeRange? _weekRange;
  DateTime? _selectedMonth;

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _filteredLeads = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _filteredPlans = [];
  bool _isLoading = true;
  String _error = '';
  String _selectedTab = 'Infos';
  bool _plansLoaded = false;

  int totalCalls = 0;
  double totalTurnover = 0;
  int totalMeetings = 0;

  bool get isOwnDashboard => widget.irId == widget.loggedInIrId;
  bool get canAddLead => widget.userRole == 1 || isOwnDashboard;
  bool get canAddPlan => widget.userRole == 1 || isOwnDashboard;
  bool get canEdit => widget.userRole == 1;

  @override
  void initState() {
    super.initState();
    _setDefaultWeekRange();
    _fetchPlans();
    _fetchLeads();
    _fetchUvCount();
  }



  void _setDefaultWeekRange() {
    final today = DateTime.now();
    final lastFriday = today.subtract(Duration(days: (today.weekday + 1) % 7));
    final nextFriday = lastFriday.add(const Duration(days: 7));
    _weekRange = DateTimeRange(start: lastFriday, end: nextFriday);
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final result = await ApiService.getInfoDetails(widget.irId);

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
        _isLoading = false;
      });
      _calculateAggregatedData();
    } else {
      setState(() {
        _error = result['error'] ?? 'Failed to fetch leads';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPlans() async {
    final result = await ApiService.getPlanDetails(widget.irId);

    if (result['success']) {
      final List<dynamic> data = result['data'] ?? [];
      setState(() {
        _plans = data.map((item) {
          return {
            'id': item['id'],
            'prospect_name': item['plan_name'] ?? 'Unknown',
            'date': DateTime.tryParse(item['plan_date'] ?? '') ?? DateTime.now(),
            'comments': item['comments'] ?? '',
          };
        }).toList();        _plansLoaded = true;      });
      _calculateAggregatedData();
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

  void _calculateAggregatedData() {
    List<Map<String, dynamic>> filteredLeads;
    List<Map<String, dynamic>> filteredPlans;

    if (_selectedFilter == 'Weekly' && _weekRange != null) {
      filteredLeads = _leads.where((entry) {
        final date = entry['date'] as DateTime;
        return date.isAfter(_weekRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_weekRange!.end.add(const Duration(days: 1)));
      }).toList();
      filteredPlans = _plans.where((entry) {
        final date = entry['date'] as DateTime;
        return date.isAfter(_weekRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_weekRange!.end.add(const Duration(days: 1)));
      }).toList();
    } else if (_selectedFilter == 'Monthly' && _selectedMonth != null) {
      filteredLeads = _leads.where((entry) {
        final date = entry['date'] as DateTime;
        return date.year == _selectedMonth!.year && date.month == _selectedMonth!.month;
      }).toList();
      filteredPlans = _plans.where((entry) {
        final date = entry['date'] as DateTime;
        return date.year == _selectedMonth!.year && date.month == _selectedMonth!.month;
      }).toList();
    } else {
      filteredLeads = _leads;
      filteredPlans = _plans;
    }

    setState(() {
      _filteredLeads = filteredLeads;
      _filteredPlans = filteredPlans;
      totalCalls = filteredLeads.length;
      totalMeetings = filteredPlans.length;
    });
  }

  void _pickWeekRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _weekRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _weekRange = picked);
      _calculateAggregatedData();
    }
  }

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _calculateAggregatedData();
    }
  }

  String _formatRange() {
    if (_selectedFilter == 'Weekly' && _weekRange != null) {
      return "${DateFormat('MMM dd').format(_weekRange!.start)} - ${DateFormat('MMM dd').format(_weekRange!.end)}";
    } else if (_selectedFilter == 'Monthly' && _selectedMonth != null) {
      return DateFormat('MMMM yyyy').format(_selectedMonth!);
    }
    return '';
  }

  void _showAddLeadDialog() {
    final nameController = TextEditingController();
    final commentController = TextEditingController();
    String selectedResponse = 'A';
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
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
                            infoDate: DateTime.now(),
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
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
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
                              'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}\nIR ID: ${widget.irId}',
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
                ElevatedButton(
                  onPressed: isSubmitting
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
                            planDate: DateTime.now(),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Add', style: TextStyle(color: Colors.black)),
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
                ElevatedButton(
                  onPressed: isSubmitting
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Save', style: TextStyle(color: Colors.black)),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
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

  @override
  Widget build(BuildContext context) {
    final filterText = _formatRange();

    return Scaffold(
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
                      ElevatedButton(onPressed: _fetchLeads, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter row
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          DropdownButton<String>(
                            value: _selectedFilter,
                            dropdownColor: const Color(0xFF1E1E2E),
                            style: const TextStyle(color: Colors.white),
                            items: ['Weekly', 'Monthly'].map((f) {
                              return DropdownMenuItem(value: f, child: Text(f));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedFilter = value);
                                _calculateAggregatedData();
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: _selectedFilter == 'Weekly' ? _pickWeekRange : _pickMonth,
                            child: Text(filterText.isEmpty ? 'Select Date' : filterText),
                          ),
                        ],
                      ),
                    ),

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
                                            if (canAddLead)
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                                                onPressed: () => _showEditLeadDialog(lead),
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
                                                ],
                                              ),
                                            ),
                                            if (canAddPlan)
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                                onPressed: () => _showEditPlanDialog(plan),
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
                ElevatedButton(
                  onPressed: isSubmitting
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Update', style: TextStyle(color: Colors.black)),
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
}
