import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:leadtracker/presentation/screens/teams/teams_page.dart';
import 'package:leadtracker/presentation/widgets/info_card.dart';
import 'package:leadtracker/core/constants/api_constants.dart';

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
                      ElevatedButton(
                        onPressed: _fetchLdcs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _ldcs.isEmpty
                  ? const Center(
                      child: Text(
                        'No managers found',
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

                          return InfoCard(
                            managerName: irName,
                            totalCalls: 0,
                            totalTurnover: 0.0,
                            clientMeetings: 0,
                            isManager: true,
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
