import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:leadtracker/core/constants/api_constants.dart';

class ApiService {
  // ==================== TEAM OPERATIONS ====================

  /// Create a new team
  /// Based on Postman: POST /api/create_team with {"name": "TeamName", "ir_id": "IR123"}
  static Future<Map<String, dynamic>> createTeam(String teamName, String irId) async {
    try {
      final url = Uri.parse('$baseUrl$createTeamEndpoint');
      print('Creating team at: $url');
      print('Team name: "$teamName"');
      print('IR ID: "$irId"');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': teamName,
          'ir_id': irId,
        }),
      );

      print('Create team response: ${response.statusCode}');
      print('Response body: ${response.body}');

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
    String? irId,
    List<String>? irIds,
    required String teamId,
    required String role,
    String? requesterIrId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$addIrToTeamEndpoint');
      print('Adding IR(s) to team at: $url');

      final Map<String, dynamic> payload = {
        'team_id': teamId,
        'role': role,
      };
      
      // Support both single and bulk additions
      if (irIds != null && irIds.isNotEmpty) {
        payload['ir_ids'] = irIds;
        print('Payload: ir_ids=$irIds, team_id=$teamId, role=$role, requester_ir_id=$requesterIrId');
      } else if (irId != null) {
        payload['ir_id'] = irId;
        print('Payload: ir_id=$irId, team_id=$teamId, role=$role, requester_ir_id=$requesterIrId');
      } else {
        return {
          'success': false,
          'error': 'Either irId or irIds must be provided'
        };
      }
      
      if (requesterIrId != null) {
        payload['requester_ir_id'] = requesterIrId;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
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
    String? requesterIrId,
  }) async {
    final url = requesterIrId != null
        ? Uri.parse('$baseUrl$removeIrFromTeamEndpoint/$teamId/$irId?requester_ir_id=$requesterIrId')
        : Uri.parse('$baseUrl$removeIrFromTeamEndpoint/$teamId/$irId');
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

  /// Move IR from one team to another
  /// PUT /api/move_ir_to_team/
  static Future<Map<String, dynamic>> moveIrToTeam({
    required String irId,
    required String currentTeamId,
    required String newTeamId,
    String? newRole,
    String? requesterIrId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$moveIrToTeamEndpoint');
      print('Moving IR to new team at: $url');
      print('Payload: ir_id=$irId, current_team=$currentTeamId, new_team=$newTeamId');

      final Map<String, dynamic> payload = {
        'ir_id': irId,
        'current_team_id': currentTeamId,
        'new_team_id': newTeamId,
      };
      
      if (newRole != null) {
        payload['new_role'] = newRole;
      }
      
      if (requesterIrId != null) {
        payload['requester_ir_id'] = requesterIrId;
      }

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Move IR response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['detail'] ??
                body['message'] ??
                'Failed to move IR to new team (${response.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to move IR to new team (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Move IR to team error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Delete a team
  static Future<Map<String, dynamic>> deleteTeam(String teamId, {String? requesterIrId}) async {
    final url = requesterIrId != null
        ? Uri.parse('$baseUrl$deleteTeamEndpoint/$teamId?requester_ir_id=$requesterIrId')
        : Uri.parse('$baseUrl$deleteTeamEndpoint/$teamId');
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
  static Future<Map<String, dynamic>> getInfoDetails(
    String irId, {
    String? response,
    String? fromDate,
    String? toDate,
    int? week,
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      // Week/year takes precedence over fromDate/toDate
      if (week != null && year != null) {
        queryParams['week'] = week.toString();
        queryParams['year'] = year.toString();
      } else {
        if (fromDate != null) queryParams['from_date'] = fromDate;
        if (toDate != null) queryParams['to_date'] = toDate;
      }
      
      if (response != null && response.isNotEmpty) {
        queryParams['response'] = response;
      }
      
      final url = Uri.parse('$baseUrl$getInfoDetailsEndpoint/$irId').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final httpResponse = await http.get(url);

      if (httpResponse.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(httpResponse.body)};
      } else {
        try {
          final errorBody = jsonDecode(httpResponse.body);
          return {
            'success': false,
            'error': errorBody['detail'] ?? errorBody['message'] ?? 'Failed to fetch leads (${httpResponse.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to fetch leads (${httpResponse.statusCode})'
          };
        }
      }
    } catch (e) {
      debugPrint('getInfoDetails error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Update an info detail
  static Future<Map<String, dynamic>> updateInfoDetail({
    required String ir,
    required int infoId,
    required String infoName,
    required String response,
    required String comments,
    required DateTime infoDate,
    String? requesterIrId,
  }) async {
    final url = Uri.parse('$baseUrl$updateInfoDetailEndpoint/$infoId/');
    final payload = {
      "ir": ir,
      'info_name': infoName,
      'response': response,
      'comments': comments,
      'info_date': infoDate.toIso8601String(),
    };
    if (requesterIrId != null) {
      payload['requester_ir_id'] = requesterIrId;
    }
    final httpResponse = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
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
  static Future<Map<String, dynamic>> deleteInfoDetail(int infoId, {String? requesterIrId}) async {
    final url = requesterIrId != null
        ? Uri.parse('$baseUrl$deleteInfoDetailEndpoint/$infoId?requester_ir_id=$requesterIrId')
        : Uri.parse('$baseUrl$deleteInfoDetailEndpoint/$infoId');
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
  /// requesterIrId: The IR ID of the user making the request (for hierarchy filtering)
  static Future<Map<String, dynamic>> getLdcs({String? requesterIrId}) async {
    final uri = requesterIrId != null
        ? Uri.parse('$baseUrl$getLdcsEndpoint').replace(
            queryParameters: {'requester_ir_id': requesterIrId})
        : Uri.parse('$baseUrl$getLdcsEndpoint');
    final response = await http.get(uri);

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
  /// requesterIrId: The IR ID of the user making the request (for hierarchy filtering)
  static Future<Map<String, dynamic>> getTeamsByLdc(String irId, {String? requesterIrId}) async {
    final uri = requesterIrId != null
        ? Uri.parse('$baseUrl$getTeamsByLdcEndpoint/$irId').replace(
            queryParameters: {'requester_ir_id': requesterIrId})
        : Uri.parse('$baseUrl$getTeamsByLdcEndpoint/$irId');
    final response = await http.get(uri);

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

  /// Get visible teams for an IR (based on role and hierarchy)
  static Future<Map<String, dynamic>> getVisibleTeams(String irId) async {
    final url = Uri.parse('$baseUrl$getVisibleTeamsEndpoint/$irId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {
        'success': false,
        'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch visible teams'
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

  /// Get targets for an IR or team
  static Future<Map<String, dynamic>> getTargets({
    String? irId,
    String? teamId,
    String? requesterIrId,
    int? week,
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (irId != null) queryParams['ir_id'] = irId;
      if (teamId != null) queryParams['team_id'] = teamId;
      if (requesterIrId != null) queryParams['requester_ir_id'] = requesterIrId;
      if (week != null) queryParams['week'] = week.toString();
      if (year != null) queryParams['year'] = year.toString();

      final url = Uri.parse('$baseUrl/api/get_targets').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {'success': true, 'data': body};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['detail'] ?? 'Failed to fetch targets (${response.statusCode})'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to fetch targets (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      print('Get targets error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get targets dashboard for an IR
  static Future<Map<String, dynamic>> getTargetsDashboard(String irId, {int? week, int? year}) async {
    try {
      var url = Uri.parse('$baseUrl/api/targets_dashboard/$irId/');
      if (week != null && year != null) {
        url = url.replace(queryParameters: {
          'week': week.toString(),
          'year': year.toString(),
        });
      }
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': 'Failed to load targets dashboard'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Fetch weekly targets for a specific IR
  static Future<Map<String, dynamic>> getWeeklyTargets({
    required String irId,
    required int week,
    required int year,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/weekly_targets/$irId/').replace(
        queryParameters: {
          'week': week.toString(),
          'year': year.toString(),
        },
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['message'] ?? 'Failed to fetch weekly targets'
        };
      }
    } catch (e) {
      print('Get weekly targets error: $e');
      return {'success': false, 'error': 'Network error: $e'};
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
    String? status,
  }) async {
    final url = Uri.parse('$baseUrl$addPlanDetailEndpoint/$irId/');
    final payload = [
      {
        'ir_id': irId,
        'plan_date': planDate.toIso8601String(),
        'comments': comments,
        'plan_name': planName,
        if (status != null) 'status': status,
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
  static Future<Map<String, dynamic>> getPlanDetails(String irId, {String? status, int? week, int? year}) async {
    try {
      final queryParams = <String, String>{};
      
      if (week != null && year != null) {
        queryParams['week'] = week.toString();
        queryParams['year'] = year.toString();
      }
      
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      
      final url = Uri.parse('$baseUrl$getPlanDetailsEndpoint/$irId').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
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
    String? requesterIrId,
    String? status,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$updatePlanDetailEndpoint/$planId/');
      final payload = {
        'ir': ir,
        'plan_name': planName,
        'comments': comments,
      };
      
      if (requesterIrId != null) {
        payload['requester_ir_id'] = requesterIrId;
      }
      
      if (status != null) {
        payload['status'] = status;
      }

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
  static Future<Map<String, dynamic>> deletePlanDetail(int planId, {String? requesterIrId}) async {
    try {
      final url = requesterIrId != null
          ? Uri.parse('$baseUrl$deletePlanDetailEndpoint/$planId?requester_ir_id=$requesterIrId')
          : Uri.parse('$baseUrl$deletePlanDetailEndpoint/$planId');
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
  static Future<Map<String, dynamic>> getTeamInfoTotal(String teamId, {String? fromDate, String? toDate}) async {
    var uri = Uri.parse('$baseUrl$getTeamInfoTotalEndpoint/$teamId/');
    
    // Add date filters if provided
    if (fromDate != null || toDate != null) {
      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final response = await http.get(uri);

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

  /// Register a new IR
  /// Called by Admin, CTC, or LDC to register a new IR under their hierarchy
  static Future<Map<String, dynamic>> registerNewIR({
    required String parentIrId,
    required String newIrId,
    required String newIrName,
    required String newIrEmail,
    required String password,
    int accessLevel = 6,  // Default to IR level
  }) async {
    try {
      // Step 1: Add IR ID to whitelist
      debugPrint('Adding IR ID to whitelist: $newIrId');
      final addIdResponse = await http.post(
        Uri.parse('$baseUrl$addIrId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ir_id': newIrId}),
      );

      if (addIdResponse.statusCode != 200 && addIdResponse.statusCode != 201) {
        final error = json.decode(addIdResponse.body);
        return {
          'success': false,
          'message': error['detail'] ?? error['message'] ?? 'Could not reserve IR ID',
        };
      }

      // Step 2: Register the IR
      debugPrint('Registering new IR: $newIrId with parent: $parentIrId');
      final response = await http.post(
        Uri.parse('$baseUrl$registerIrId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ir_id': newIrId,
          'ir_name': newIrName,
          'ir_email': newIrEmail,
          'ir_password': password,
          'ir_access_level': accessLevel,
          'parent_ir_id': parentIrId,
        }),
      );

      debugPrint('Register IR response status: ${response.statusCode}');
      debugPrint('Register IR response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'IR registered successfully',
            'ir_id': newIrId,
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'IR registered successfully',
            'ir_id': newIrId,
          };
        }
      } else {
        try {
          final error = json.decode(response.body);
          // Handle errors array format
          if (error['errors'] != null && error['errors'] is List) {
            final errors = error['errors'] as List;
            if (errors.isNotEmpty) {
              return {
                'success': false,
                'message': errors[0]['error'] ?? 'Registration failed',
              };
            }
          }
          return {
            'success': false,
            'message': error['detail'] ?? error['message'] ?? 'Registration failed',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Server error (${response.statusCode})',
          };
        }
      }
    } catch (e) {
      debugPrint('Register IR network error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
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

  /// Change IR Access Level
  /// Based on API: POST /api/change_access_level/
  /// Requires: acting_ir_id, target_ir_id, new_access_level (1-6)
  /// Access levels: 1=Admin, 2=CTC, 3=LDC, 4=LS, 5=GC, 6=IR
  static Future<Map<String, dynamic>> changeAccessLevel({
    required String actingIrId,
    required String targetIrId,
    required int newAccessLevel,
  }) async {
    // NOTE: This endpoint is not yet implemented on the backend    
    try {
      final url = Uri.parse('$baseUrl/api/change_access_level/');
      debugPrint('Changing access level at: $url');
      debugPrint('Acting IR: $actingIrId, Target IR: $targetIrId, New Level: $newAccessLevel');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'acting_ir_id': actingIrId,
          'target_ir_id': targetIrId,
          'new_access_level': newAccessLevel,
        }),
      );

      debugPrint('Change access level response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Access level changed successfully',
            'target_ir_id': data['target_ir_id'],
            'target_ir_name': data['target_ir_name'],
            'old_access_level': data['old_access_level'],
            'new_access_level': data['new_access_level'],
            'changed_by': data['changed_by'],
          };
        } catch (e) {
          debugPrint('JSON decode error on success: $e');
          return {
            'success': true,
            'message': 'Access level changed successfully',
          };
        }
      } else {
        try {
          final error = json.decode(response.body);
          return {
            'success': false,
            'error': error['detail'] ?? 'Failed to change access level',
          };
        } catch (e) {
          debugPrint('JSON decode error on failure: $e');
          return {
            'success': false,
            'error': 'Server error (${response.statusCode}): ${response.body}',
          };
        }
      }
    } catch (e) {
      debugPrint('Change access level network error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
   
  }

  /// Update team name
  static Future<Map<String, dynamic>> updateTeamName({
    required int teamId,
    required String newName,
    String? requesterIrId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/update_team_name/$teamId/');
      final payload = {'name': newName};
      
      if (requesterIrId != null) {
        payload['requester_ir_id'] = requesterIrId;
      }

      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        try {
          final body = jsonDecode(response.body);
          return {
            'success': false,
            'error': body['detail'] ?? body['message'] ?? 'Failed to update team name'
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to update team name (${response.statusCode})'
          };
        }
      }
    } catch (e) {
      debugPrint('Update team name error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

}
