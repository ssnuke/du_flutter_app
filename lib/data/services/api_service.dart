import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:leadtracker/core/constants/api_constants.dart';

class ApiService {
  // ==================== TEAM OPERATIONS ====================

  /// Create a new team
  /// Based on Postman: POST /api/create_team with {"name": "TeamName"}
  static Future<Map<String, dynamic>> createTeam(String teamName) async {
    try {
      final url = Uri.parse('$baseUrl$createTeamEndpoint');
      print('Creating team at: $url with name: $teamName');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': teamName}),
      );

      print('Create team response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['message'] ??
                body['detail'] ??
                'Failed to create team (${response.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to create team (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Create team error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Add IR to a team
  /// Based on Postman: POST /api/add_ir_to_team with {"ir_id": "IM1579", "team_id": "1", "role": "LDC"}
  static Future<Map<String, dynamic>> addIrToTeam({
    required String irId,
    required String teamId,
    required String role,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$addIrToTeamEndpoint');
      print('Adding IR to team at: $url');
      print('Payload: ir_id=$irId, team_id=$teamId, role=$role');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ir_id': irId,
          'team_id': teamId,
          'role': role,
        }),
      );

      print(
          'Add IR to team response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['message'] ??
                body['detail'] ??
                'Failed to add member to team (${response.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to add member to team (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Add IR to team error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Remove IR from a team
  static Future<Map<String, dynamic>> removeIrFromTeam({
    required String teamId,
    required String irId,
  }) async {
    final url = Uri.parse('$baseUrl$removeIrFromTeamEndpoint/$teamId/$irId');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ??
            'Failed to remove member from team'
      };
    }
  }

  /// Delete a team
  static Future<Map<String, dynamic>> deleteTeam(String teamId) async {
    final url = Uri.parse('$baseUrl$deleteTeamEndpoint/$teamId');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to delete team'
      };
    }
  }

  // ==================== LEAD/INFO OPERATIONS (CRUD) ====================

  /// Add a new lead/info detail
  static Future<Map<String, dynamic>> addInfoDetail({
    required String irId,
    required String infoName,
    required String response,
    required String comments,
    required DateTime infoDate,
  }) async {
    final url = Uri.parse('$baseUrl$addInfoDetailEndpoint/$irId/');
    final payload = [
      {
        'ir_id': irId,
        'info_date': infoDate.toIso8601String(),
        'response': response,
        'comments': comments,
        'info_name': infoName,
      }
    ];

    final httpResponse = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(httpResponse.body)};
    } else {
      return {
        'success': false,
        'error':
            jsonDecode(httpResponse.body)['message'] ?? 'Failed to add lead'
      };
    }
  }

  /// Get all info details for an IR
  static Future<Map<String, dynamic>> getInfoDetails(String irId) async {
    final url = Uri.parse('$baseUrl$getInfoDetailsEndpoint/$irId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch leads'
      };
    }
  }

  /// Update an info detail
  static Future<Map<String, dynamic>> updateInfoDetail({
    required String ir,
    required int infoId,
    required String infoName,
    required String response,
    required String comments,
  }) async {
    final url = Uri.parse('$baseUrl$updateInfoDetailEndpoint/$infoId/');
    final httpResponse = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "ir": ir,
        'info_name': infoName,
        'response': response,
        'comments': comments,
      }),
    );

    if (httpResponse.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(httpResponse.body)};
    } else {
      debugPrint('Update Info Detail Error: ${httpResponse.body}');
      return {
        'success': false,
        'error':
            jsonDecode(httpResponse.body)['message'] ?? 'Failed to update lead'
      };
    }
  }

  /// Delete an info detail
  static Future<Map<String, dynamic>> deleteInfoDetail(int infoId) async {
    final url = Uri.parse('$baseUrl$deleteInfoDetailEndpoint/$infoId');
    final response = await http.delete(url);

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to delete lead'
      };
    }
  }

  // ==================== LDC/MANAGER OPERATIONS ====================

  /// Get all LDCs/Managers
  static Future<Map<String, dynamic>> getLdcs() async {
    final url = Uri.parse('$baseUrl$getLdcsEndpoint');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch LDCs'
      };
    }
  }

  /// Get teams managed by an LDC
  static Future<Map<String, dynamic>> getTeamsByLdc(String irId) async {
    final url = Uri.parse('$baseUrl$getTeamsByLdcEndpoint/$irId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch teams'
      };
    }
  }

  /// Get teams by IR
  static Future<Map<String, dynamic>> getTeamsByIr(String irId) async {
    final url = Uri.parse('$baseUrl$getTeamsByIrEndpoint/$irId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch teams'
      };
    }
  }

  // ==================== TARGET OPERATIONS ====================

  /// Set targets for a team
  /// Based on Postman: POST /api/set_targets with nested payload
  static Future<Map<String, dynamic>> setTargets({
    required String teamId,
    required int teamWeeklyInfoTarget,
    required int teamWeeklyPlanTarget,
    required int teamWeeklyUvTarget,
    required String actingIrId,
    String? irId,
    int? weeklyInfoTarget,
    int? weeklyPlanTarget,
    int? weeklyUvTarget,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$setTargetsEndpoint');

      final payload = <String, String>{
        'team_id': teamId,
        'team_weekly_info_target': teamWeeklyInfoTarget.toString(),
        'team_weekly_plan_target': teamWeeklyPlanTarget.toString(),
        'team_weekly_uv_target': teamWeeklyUvTarget.toString(),
      };

      // Add individual IR targets if provided
      if (irId != null) {
        payload['ir_id'] = irId;
        payload['weekly_info_target'] = (weeklyInfoTarget ?? 0).toString();
        payload['weekly_plan_target'] = (weeklyPlanTarget ?? 0).toString();
        payload['weekly_uv_target'] = (weeklyUvTarget ?? 0).toString();
      }

      final requestBody = {
        'payload': payload,
        'acting_ir_id': actingIrId,
      };

      print('Setting targets at: $url');
      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Set targets response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['message'] ??
                body['detail'] ??
                'Failed to set targets (${response.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to set targets (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Set targets error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get targets dashboard for an IR
  static Future<Map<String, dynamic>> getTargetsDashboard(String irId) async {
    final url = Uri.parse('$baseUrl$getTargetsDashboardEndpoint/$irId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // print("dashboard targets: ${response.body}");
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error':
            jsonDecode(response.body)['message'] ?? 'Failed to fetch targets'
      };
    }
  }

  // ==================== PLAN OPERATIONS ====================

  /// Add a new plan detail
  static Future<Map<String, dynamic>> addPlanDetail({
    required String irId,
    required String planName,
    required String response,
    required String comments,
    required DateTime planDate,
  }) async {
    final url = Uri.parse('$baseUrl$addPlanDetailEndpoint/$irId/');
    final payload = [
      {
        'ir_id': irId,
        'plan_date': planDate.toIso8601String(),
        'comments': comments,
        'plan_name': planName,
      }
    ];

    final httpResponse = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
      try {
        return {'success': true, 'data': jsonDecode(httpResponse.body)};
      } catch (e) {
        return {
          'success': false,
          'error': 'Invalid response format from server'
        };
      }
    } else {
      String errorMessage = 'Failed to add plan';
      try {
        final contentType = httpResponse.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final errorData = jsonDecode(httpResponse.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } else {
          errorMessage = 'Server error (${httpResponse.statusCode})';
        }
      } catch (e) {
        errorMessage = 'Server error (${httpResponse.statusCode})';
      }
      return {'success': false, 'error': errorMessage};
    }
  }

  /// Get all plan details for an IR
  static Future<Map<String, dynamic>> getPlanDetails(String irId) async {
    try {
      final url = Uri.parse('$baseUrl$getPlanDetailsEndpoint/$irId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error':
                body['message'] ?? body['detail'] ?? 'Failed to fetch plans'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to fetch plans (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      debugPrint('Get plan details error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Update a plan detail
  static Future<Map<String, dynamic>> updatePlanDetail({
    required String ir,
    required int planId,
    required String planName,
    required String comments,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$updatePlanDetailEndpoint/$planId/');
      final payload = {
        'ir': ir,
        'plan_name': planName,
        'comments': comments,
      };

      // print('Updating plan at: $url');
      // print('Payload: ${jsonEncode(payload)}');

      final httpResponse = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // debugPrint('Update plan response: ${httpResponse.statusCode}');
      // debugPrint('Response body: ${httpResponse.body}');

      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(httpResponse.body)};
      } else {
        try {
          final body = jsonDecode(httpResponse.body);
          return {
            'success': false,
            'error':
                body['message'] ?? body['detail'] ?? 'Failed to update plan'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to update plan (${httpResponse.statusCode})'
          };
        }
      }
    } catch (e) {
      debugPrint('Update plan detail error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Delete a plan detail
  static Future<Map<String, dynamic>> deletePlanDetail(int planId) async {
    try {
      final url = Uri.parse('$baseUrl$deletePlanDetailEndpoint/$planId');
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error':
                body['message'] ?? body['detail'] ?? 'Failed to delete plan'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to delete plan (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      debugPrint('Delete plan detail error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ==================== UV OPERATIONS ====================

  /// Add UV count for an IR
  static Future<Map<String, dynamic>> addUvFallen({
    required String irId,
    required double uvCount,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$addUvEndpoint/$irId/');
      final payload = {
        'ir_id': irId,
        'uv_count': uvCount,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return {'success': true, 'data': jsonDecode(response.body)};
        } catch (_) {
          return {
            'success': true,
            'data': {'uv_count': uvCount}
          };
        }
      }

      try {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error':
              body['message'] ?? body['detail'] ?? 'Failed to add UV count',
        };
      } catch (_) {
        return {
          'success': false,
          'error': 'Failed to add UV count (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Add UV error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Retrieve UV count for an IR
  static Future<Map<String, dynamic>> getUvCount(String irId) async {
    try {
      final url = Uri.parse('$baseUrl$getUvEndpoint/$irId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        try {
          return {'success': true, 'data': jsonDecode(response.body)};
        } catch (_) {
          final parsed = double.tryParse(response.body.trim());
          if (parsed != null) {
            return {
              'success': true,
              'data': {'uv_count': parsed}
            };
          }
          return {
            'success': true,
            'data': {'raw': response.body},
          };
        }
      }

      try {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error':
              body['message'] ?? body['detail'] ?? 'Failed to fetch UV count',
        };
      } catch (_) {
        return {
          'success': false,
          'error': 'Failed to fetch UV count (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Get UV count error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get team info total (members_info_total and members_plan_total)
  static Future<Map<String, dynamic>> getTeamInfoTotal(String teamId) async {
    final url = Uri.parse('$baseUrl$getTeamInfoTotalEndpoint/$teamId/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ??
            'Failed to fetch team info totals'
      };
    }
  }

  // In lib/data/services/api_service.dart
  static Future<Map<String, dynamic>> resetPassword({
  required String irId,
  required String newPassword,
}) async {
  try {
    debugPrint('Resetting password for IR: $irId');
    final response = await http.post(
      Uri.parse('$baseUrl$passwordResetEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ir_id': irId,
        'new_password': newPassword,
      }),
    );

    debugPrint('Password reset response status: ${response.statusCode}');
    debugPrint('Password reset response body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successfully',
        };
      } catch (e) {
        debugPrint('JSON decode error on success: $e');
        return {
          'success': true,
          'message': 'Password reset successfully',
        };
      }
    } else {
      try {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Failed to reset password',
        };
      } catch (e) {
        debugPrint('JSON decode error on failure: $e');
        return {
          'success': false,
          'message': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    }
  } catch (e) {
    debugPrint('Reset password network error: $e');
    return {
      'success': false,
      'message': 'Network error: $e',
    };
  }
}
}
