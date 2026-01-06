/// Access level constants mapped to user roles.
/// This mirrors the backend AccessLevel class in models.py
class AccessLevel {
  static const int admin = 1;
  static const int ctc = 2;
  static const int ldc = 3;
  static const int ls = 4;
  static const int gc = 5;
  static const int ir = 6;

  /// Get the role name for display
  static String getRoleName(int level) {
    switch (level) {
      case admin:
        return 'Admin';
      case ctc:
        return 'CTC';
      case ldc:
        return 'LDC';
      case ls:
        return 'LS';
      case gc:
        return 'GC';
      case ir:
        return 'IR';
      default:
        return 'User';
    }
  }

  /// Get role badge color
  static int getRoleBadgeColor(int level) {
    switch (level) {
      case admin:
        return 0xFFFFD700; // Gold
      case ctc:
        return 0xFFFFA500; // Orange
      case ldc:
        return 0xFF00CED1; // Dark Cyan
      case ls:
        return 0xFF9370DB; // Medium Purple
      case gc:
        return 0xFF20B2AA; // Light Sea Green
      case ir:
        return 0xFF87CEEB; // Sky Blue
      default:
        return 0xFF808080; // Grey
    }
  }

  /// Check if user has full access (ADMIN or CTC)
  static bool hasFullAccess(int level) {
    return level == admin || level == ctc;
  }

  /// Check if user can promote/demote others (only ADMIN, CTC)
  static bool canPromoteDemote(int level) {
    return level == admin || level == ctc;
  }

  /// Check if user can create teams (ADMIN, CTC, LDC)
  static bool canCreateTeam(int level) {
    return level <= ldc;
  }

  /// Check if user can manage teams (add/remove members, set targets)
  /// ADMIN, CTC, LDC can manage teams
  static bool canManageTeams(int level) {
    return level <= ldc;
  }

  /// Check if user can view teams list
  /// - ADMIN/CTC: Can view all teams
  /// - LDC: Can view teams they manage
  /// - LS: Can view teams they belong to
  /// - GC/IR: Can view teams they belong to (but with restricted data access)
  static bool canViewTeams(int level) {
    return level <= ir;  // All users can view teams list
  }

  /// Check if user can add data for others
  /// - ADMIN/CTC: Can add for everyone
  /// - LDC: Can add for members of teams they created
  /// - LS: Can add for team members (in teams they belong to)
  /// - GC/IR: Can add only for self
  static bool canAddDataForOthers(int level) {
    return level <= ls;
  }

  /// Check if user can view other users' data
  /// - ADMIN/CTC: Can view everyone
  /// - LDC: Can view their team members
  /// - LS: Can view team members
  /// - GC/IR: Can view only self
  static bool canViewOthersData(int level) {
    return level <= ls;
  }

  /// Check if the actor can view the target user's data
  static bool canViewUser({
    required int actorLevel,
    required String actorId,
    required String targetId,
  }) {
    // Can always view own data
    if (actorId == targetId) return true;
    
    // ADMIN/CTC can view everyone
    if (hasFullAccess(actorLevel)) return true;
    
    // LDC and LS can view others (will be filtered by team membership on backend)
    if (actorLevel <= ls) return true;
    
    // GC/IR can only view themselves
    return false;
  }

  /// Check if the actor can edit the target user's data
  static bool canEditUser({
    required int actorLevel,
    required String actorId,
    required String targetId,
  }) {
    // Can always edit own data
    if (actorId == targetId) return true;
    
    // ADMIN/CTC can edit everyone
    if (hasFullAccess(actorLevel)) return true;
    
    // LDC can edit members of teams they created
    if (actorLevel == ldc) return true;
    
    // LS can add data for team members
    if (actorLevel == ls) return true;
    
    // GC/IR can only edit themselves
    return false;
  }

  /// Check if the actor can add leads/plans for the target user
  static bool canAddDataFor({
    required int actorLevel,
    required String actorId,
    required String targetId,
  }) {
    // Can always add for self
    if (actorId == targetId) return true;
    
    // ADMIN/CTC can add for everyone
    if (hasFullAccess(actorLevel)) return true;
    
    // LDC can add for members of their teams
    if (actorLevel == ldc) return true;
    
    // LS can add for team members
    if (actorLevel == ls) return true;
    
    // GC/IR can only add for themselves
    return false;
  }

  /// Check if user should see Admin Panel FAB
  static bool canAccessAdminPanel(int level) {
    return level <= ldc; // ADMIN, CTC, LDC only
  }

  /// Check if user can change access levels
  static bool canChangeAccessLevels(int level) {
    return level == admin || level == ctc;
  }

  /// Check if user can delete teams
  static bool canDeleteTeams(int level) {
    return level <= ldc;
  }

  /// Check if user is view-only (GC/IR)
  static bool isViewOnly(int level) {
    return level >= gc;
  }
}
