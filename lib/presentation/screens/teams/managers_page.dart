import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/core/constants/access_levels.dart';
import 'package:leadtracker/presentation/screens/teams/teams_page.dart';
import 'package:leadtracker/presentation/widgets/info_card.dart';
import 'package:leadtracker/core/constants/api_constants.dart';

/// ManagersPage - Shows list of all LDCs (managers)
/// Only accessible by ADMIN and CTC (users with full access)
class ManagersPage extends StatefulWidget {
  final int userRole;
  final String irId;

  const ManagersPage({super.key, required this.userRole, required this.irId});

  @override
  State<ManagersPage> createState() => _ManagersPageState();
}

class _ManagersPageState extends State<ManagersPage> {
  List<dynamic> _ldcs = [];
  bool _isLoading = true;
  String _error = '';

  // Verify user has access to this page
  bool get hasFullAccess => AccessLevel.hasFullAccess(widget.userRole);

  @override
  void initState() {
    super.initState();
    _fetchLdcs();
  }

  Future<void> _fetchLdcs() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final url = Uri.parse('$baseUrl$getLdcsEndpoint');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _ldcs = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load managers (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _fetchLdcs,
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
              : _ldcs.isEmpty
                  ? const Center(
                      child: Text(
                        'No LDC Teams found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchLdcs,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _ldcs.length,
                        itemBuilder: (context, index) {
                          final ldc = _ldcs[index];
                          final String irId = ldc['ir_id'] ?? 'Unknown';
                          final String irName = ldc['ir_name'] ?? irId;
                          final int ldcAccessLevel = ldc['ir_access_level'] ?? AccessLevel.ldc;

                          return InfoCard(
                            managerName: irName,
                            totalCalls: 0,
                            totalTurnover: 0.0,
                            clientMeetings: 0,
                            accessLevel: ldcAccessLevel,  // Use actual access level from API
                            hideStats: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeamsPage(
                                    irId: irId,
                                    userRole: widget.userRole,
                                    loggedInIrId: widget.irId,
                                    managerName: irName,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
  }
}
