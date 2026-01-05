import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool get isSuperAdmin => widget.userRole == 1;
  bool get isManager => widget.userRole <= 2;

  String _getRoleName() {
    switch (widget.userRole) {
      case 1:
        return 'Super Admin';
      case 2:
        return 'LDC';
      case 3:
        return 'LS';
      case 4:
        return 'IR';
      default:
        return 'User';
    }
  }

  void _refreshHomePage() {
    setState(() {
      _homePageKey = UniqueKey();
    });
  }

  Widget _getHomePage() {
    if (isSuperAdmin) {
      return ManagersPage(key: _homePageKey, irId: widget.irId, userRole: widget.userRole);
    } else {
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
    final List<Widget> pages = [
      _getHomePage(),
      const AchievementsPage(),
      const FAQPage(),
      SettingsPage(irId: widget.irId, userRole: widget.userRole),
    ];

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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Teams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Dream Ticks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.question_answer),
            label: 'Coming soon',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Profile Settings',
          ),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
      floatingActionButton: widget.userRole <= 3 && _selectedIndex == 0
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
