// Set your actual backend base URL here
// const String baseUrl = "https://du-backend-t437.onrender.com";
const String baseUrl = "https://du-backend-dj.onrender.com";

// API Endpoints - Authentication
const String createIrEndpoint = "/api/add_ir_id/";
const String registerIrEndpoint = "/api/register_new_ir/";
const String loginIrEndpoint = "/api/login/";

// API Endpoints - Teams
const String getTeamsEndpoint = "/api/teams/";
const String createTeamEndpoint = "/api/create_team/";
const String updateTeamNameEndpoint = "/api/update_team_name"; // + /{team_id}
const String deleteTeamEndpoint = "/api/delete_team"; // + /{team_id}
const String addIrToTeamEndpoint = "/api/add_ir_to_team/";
const String removeIrFromTeamEndpoint = "/api/remove_ir_from_team"; // + /{team_id}/{ir_id}
const String getTeamMembersEndpoint = "/api/team_members"; // + /{team_id}

// API Endpoints - Lead/Info Data (CRUD)
const String addInfoDetailEndpoint = "/api/add_info_detail"; // + /{ir_id}
const String getInfoDetailsEndpoint = "/api/info_details"; // + /{ir_id}
const String updateInfoDetailEndpoint = "/api/update_info_detail"; // + /{info_id}
const String deleteInfoDetailEndpoint = "/api/delete_info_detail"; // + /{info_id}

// API Endpoints - Plan Data
const String addPlanDetailEndpoint = "/api/add_plan_detail"; // + /{ir_id}
const String getPlanDetailsEndpoint = "/api/plan_details"; // + /{ir_id}
const String updatePlanDetailEndpoint = "/api/update_plan_detail"; // POST array payload
const String deletePlanDetailEndpoint = "/api/delete_plan_detail"; // + /{plan_id}
const String getTeamInfoTotalEndpoint = "/api/team_info_total"; // + /{team_id}/

// API Endpoints - LDCs/Managers
const String getLdcsEndpoint = "/api/ldcs/";
const String getTeamsByLdcEndpoint = "/api/teams_by_ldc"; // + /{ir_id}
const String getTeamsByIrEndpoint = "/api/teams_by_ir"; // + /{ir_id}
const String getAllIrsEndpoint = "/api/irs/"; // Get all registered IRs

// API Endpoints - Targets
const String setTargetsEndpoint = "/api/set_targets/";
const String getTargetsEndpoint = "/api/get_targets/";
const String getTargetsDashboardEndpoint = "/api/targets_dashboard"; // + /{ir_id}