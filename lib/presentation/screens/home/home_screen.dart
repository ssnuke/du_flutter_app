import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadtracker/core/constants/access_levels.dart';
import 'package:leadtracker/presentation/screens/admin/add_members_page.dart';
import 'package:leadtracker/presentation/screens/dashboard/dashboard_page.dart';
import 'package:leadtracker/presentation/screens/teams/managers_page.dart';
import 'package:leadtracker/presentation/screens/teams/teams_page.dart';
import 'package:leadtracker/presentation/screens/achievements/achievements_page.dart';
import 'package:leadtracker/presentation/screens/settings/settings_page.dart';
import 'package:leadtracker/main.dart';

class HomeScreen extends StatefulWidget {
  final int userRole;
  final String irId;
  const HomeScreen({super.key, required this.userRole, required this.irId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Key _homePageKey = UniqueKey();

  // Role-based access checks using AccessLevel utility
  bool get hasFullAccess => AccessLevel.hasFullAccess(widget.userRole);
  bool get canManageTeams => AccessLevel.canManageTeams(widget.userRole);
  bool get canViewTeams => AccessLevel.canViewTeams(widget.userRole);
  bool get canAccessAdminPanel => AccessLevel.canAccessAdminPanel(widget.userRole);
  bool get isViewOnly => AccessLevel.isViewOnly(widget.userRole);

  String _getRoleName() {
    return AccessLevel.getRoleName(widget.userRole);
  }

  void _refreshHomePage() {
    setState(() {
      _homePageKey = UniqueKey();
    });
  }

  Widget _getHomePage() {
    // ADMIN/CTC: See all managers (ManagersPage)
    // LDC/LS/GC/IR: See teams they belong to (TeamsPage)
    // GC/IR will have restricted access - can only see their own data in team members
    if (hasFullAccess) {
      return ManagersPage(key: _homePageKey, irId: widget.irId, userRole: widget.userRole);
    } else {
      // LDC, LS, GC, IR all see TeamsPage
      // Permissions are handled within TeamsPage and TeamMembersPage
      return TeamsPage(key: _homePageKey, irId: widget.irId, userRole: widget.userRole);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyApp()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build different pages based on role
    final List<Widget> pages = [
      _getHomePage(),
      const AchievementsPage(),
      const FAQPage(),
      SettingsPage(irId: widget.irId, userRole: widget.userRole),
    ];

    // Different bottom nav labels based on role
    final String firstTabLabel = isViewOnly ? 'My Dashboard' : 'Teams';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showLogoutDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF121212),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.cyanAccent,
              radius: 16,
              child: Text(
                widget.irId.isNotEmpty ? widget.irId[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.irId,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _getRoleName(),
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    irId: widget.irId,
                    userRole: widget.userRole,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(isViewOnly ? Icons.dashboard : Icons.group),
            label: firstTabLabel,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Dream Ticks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.question_answer),
            label: 'Coming soon',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Profile Settings',
          ),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
      // Only show FAB for ADMIN, CTC, LDC (canAccessAdminPanel)
      floatingActionButton: canAccessAdminPanel && _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                      content: AddMemberSheet(
                        irId: widget.irId,
                        userRole: widget.userRole,
                        onDataChanged: _refreshHomePage,
                        parentContext: context,
                      ),
                    ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      ),
    );
  }
}

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Something cool will be here soon!"));
  }
}

class ProfilePage extends StatelessWidget {
  final String irId;
  final int userRole;

  const ProfilePage({
    super.key,
    required this.irId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      personName: irId,
      irId: irId,
      userRole: userRole,
      loggedInIrId: irId,
    );
  }
}
