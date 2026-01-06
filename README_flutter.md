# Dreamers United - Lead Tracker

A Flutter-based mobile and web application for tracking leads, managing teams, and monitoring performance metrics for the Dreamers United organization.

![Flutter](https://img.shields.io/badge/Flutter-3.6.1+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.6.1+-blue.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20Web%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-green.svg)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Screens & Navigation](#screens--navigation)
- [User Roles & Permissions](#user-roles--permissions)
- [API Integration](#api-integration)
- [Data Models](#data-models)
- [UI/UX & Theming](#uiux--theming)
- [Dependencies](#dependencies)
- [Getting Started](#getting-started)

---

## 🎯 Overview

**Lead Tracker** is a comprehensive lead management and team performance tracking application built for the Dreamers United organization. The app allows users to:

- Track and manage leads (Infos) and plans
- Monitor team performance with weekly targets
- View individual and team statistics
- Manage team hierarchies with role-based access control
- Watch achievement videos for motivation

---

## ✨ Features

### Core Features
- **Lead Management**: Add, edit, delete, and track leads with date-based filtering
- **Plan Tracking**: Manage prospect plans and meetings
- **Team Management**: Create teams, add/remove members, set targets
- **Performance Dashboard**: View calls, UVs (turnover), and plans metrics
- **Weekly/Monthly Filtering**: Filter data by week range or month
- **Role-Based Access**: Different views and permissions based on user role
- **Achievements Gallery**: Video gallery showcasing success stories

### Administrative Features
- Create and manage teams
- Set weekly targets (Info, Plan, UV)
- Add/remove IR members from teams
- Change user access levels
- Password reset functionality

---

## 🏗️ Architecture

The app follows a clean architecture pattern with separation of concerns:

```
lib/
├── main.dart                 # App entry point, theme config, splash screen
├── core/
│   └── constants/
│       └── api_constants.dart    # API endpoints and base URL
├── data/
│   ├── models/
│   │   ├── team_model.dart       # Team data model
│   │   └── team_member_model.dart # Team member data model
│   └── services/
│       └── api_service.dart      # Centralized API service layer
└── presentation/
    ├── screens/                  # All app screens organized by feature
    └── widgets/
        └── info_card.dart        # Reusable info card widget
```

---

## 📁 Project Structure

### Screens Organization

| Directory | Description |
|-----------|-------------|
| `auth/` | Login and signup screens |
| `home/` | Main home screen with bottom navigation |
| `dashboard/` | Individual user dashboard with leads/plans |
| `teams/` | Team listing, team members, managers view |
| `admin/` | Admin panel for team/member management |
| `achievements/` | Video gallery of achievements |
| `settings/` | User profile and password settings |

---

## 📱 Screens & Navigation

### 1. **Splash Screen** (`main.dart`)
- Shows logo and loading indicator
- Checks authentication status via SharedPreferences
- Fetches latest user role from backend
- Routes to Welcome or Home screen

### 2. **Welcome Screen** (`main.dart`)
- Landing page with logo
- Login button navigation

### 3. **Login Screen** (`auth/login_screen.dart`)
- IR ID and password authentication
- Stores session in SharedPreferences
- Routes to HomeScreen on success

### 4. **Home Screen** (`home/home_screen.dart`)
- Main navigation hub with bottom navigation bar
- **Navigation Tabs:**
  - Teams (default) - Shows ManagersPage or TeamsPage based on role
  - Dream Ticks - AchievementsPage
  - Coming Soon - Placeholder for future features
  - Profile Settings - SettingsPage
- AppBar shows user ID, role badge, profile, and logout
- FAB for admin actions (roles ≤ 3)

### 5. **Managers Page** (`teams/managers_page.dart`)
- **Visible to**: Super Admin only
- Lists all LDCs (managers) in the system
- Tapping an LDC navigates to their teams

### 6. **Teams Page** (`teams/teams_page.dart`)
- Lists teams based on user role:
  - Super Admin/LDC: Teams managed by selected LDC
  - LS/IR: Teams the user belongs to
- Shows weekly targets progress (Info/Plan/UV)
- Tapping a team opens team members view

### 7. **Team Members Page** (`teams/team_members_page.dart`)
- Lists all members of a selected team
- Shows individual stats (calls, UVs, plans)
- Role badges (LS, LDC, IR)

### 8. **Dashboard Page** (`dashboard/dashboard_page.dart`)
- Individual performance dashboard
- **Tabs**: Infos | Plans
- **Filtering**: Weekly or Monthly date range picker
- **Statistics Cards**: Total Calls, UVs, Plans
- **CRUD Operations**: Add, edit, delete leads and plans
- Owner and admin-only edit permissions

### 9. **Achievements Page** (`achievements/achievements_page.dart`)
- Video gallery loaded from `assets/data/achievements.json`
- Grid layout with video thumbnails
- Full-screen video player on tap
- Uses `video_player` package

### 10. **Settings Page** (`settings/settings_page.dart`)
- User profile display (IR ID, role)
- Password change form with validation
- Minimum 6 character password requirement

### 11. **Admin Panel** (`admin/add_members_page.dart`)
- **Accessible via**: FAB on Teams tab (roles ≤ 3)
- **Features**:
  - Create new team
  - Add IR to team
  - Remove IR from team
  - Set weekly targets
  - Delete team
  - Change access level (Super Admin only)
- Searchable IR dropdown
- Team selection dropdowns

---

## 👥 User Roles & Permissions

| Role | Level | Permissions |
|------|-------|-------------|
| **Super Admin** | 1 | Full access, manage all teams/users, change access levels |
| **LDC (Manager)** | 2 | Manage own teams, set targets, add/remove members |
| **LS (Team Lead)** | 3 | View team data, limited admin functions |
| **IR (Member)** | 4 | View own data, add leads/plans |

### Role-Based UI Differences

```dart
// Home screen landing page differs by role
if (isSuperAdmin) {
  return ManagersPage(...);  // Shows all LDCs
} else {
  return TeamsPage(...);     // Shows user's teams
}

// FAB visibility
floatingActionButton: widget.userRole <= 3 && _selectedIndex == 0
    ? FloatingActionButton(...) // Only for admin roles
    : null,
```

---

## 🔌 API Integration

### Base URL
```dart
const String baseUrl = "https://du-backend-dj.onrender.com";
```

### API Endpoints

#### Authentication
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/login/` | POST | User login |
| `/api/register_new_ir/` | POST | Register new IR |
| `/api/ir/{ir_id}/` | GET | Get IR details |
| `/api/password_reset/` | POST | Reset password |

#### Teams
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/teams/` | GET | Get all teams |
| `/api/create_team/` | POST | Create new team |
| `/api/update_team_name/{team_id}` | PUT | Update team name |
| `/api/delete_team/{team_id}` | DELETE | Delete team |
| `/api/add_ir_to_team/` | POST | Add member to team |
| `/api/remove_ir_from_team/{team_id}/{ir_id}` | DELETE | Remove member |
| `/api/team_members/{team_id}` | GET | Get team members |
| `/api/teams_by_ldc/{ir_id}` | GET | Get teams by LDC |
| `/api/teams_by_ir/{ir_id}` | GET | Get teams by IR |

#### Leads/Info Data (CRUD)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/add_info_detail/{ir_id}/` | POST | Add new lead |
| `/api/info_details/{ir_id}` | GET | Get all leads for IR |
| `/api/update_info_detail/{info_id}/` | PUT | Update lead |
| `/api/delete_info_detail/{info_id}` | DELETE | Delete lead |

#### Plans
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/add_plan_detail/{ir_id}/` | POST | Add new plan |
| `/api/plan_details/{ir_id}` | GET | Get all plans for IR |
| `/api/update_plan_detail/{plan_id}/` | PUT | Update plan |
| `/api/delete_plan_detail/{plan_id}` | DELETE | Delete plan |

#### Targets & Stats
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/set_targets/` | POST | Set team/IR targets |
| `/api/targets_dashboard/{ir_id}` | GET | Get targets dashboard |
| `/api/add_uv/{ir_id}/` | POST | Add UV count |
| `/api/uv_count/{ir_id}` | GET | Get UV count |
| `/api/team_info_total/{team_id}/` | GET | Get team totals |

### API Service Class

All API calls are centralized in `ApiService` class with static methods:

```dart
class ApiService {
  // Team Operations
  static Future<Map<String, dynamic>> createTeam(String teamName, String irId);
  static Future<Map<String, dynamic>> addIrToTeam({...});
  static Future<Map<String, dynamic>> removeIrFromTeam({...});
  
  // Lead Operations
  static Future<Map<String, dynamic>> addInfoDetail({...});
  static Future<Map<String, dynamic>> getInfoDetails(String irId);
  static Future<Map<String, dynamic>> updateInfoDetail({...});
  static Future<Map<String, dynamic>> deleteInfoDetail(int infoId);
  
  // Plan Operations
  static Future<Map<String, dynamic>> addPlanDetail({...});
  static Future<Map<String, dynamic>> getPlanDetails(String irId);
  static Future<Map<String, dynamic>> updatePlanDetail({...});
  static Future<Map<String, dynamic>> deletePlanDetail(int planId);
  
  // Target Operations
  static Future<Map<String, dynamic>> setTargets({...});
  static Future<Map<String, dynamic>> getTargetsDashboard(String irId);
  
  // UV Operations
  static Future<Map<String, dynamic>> addUvFallen({...});
  static Future<Map<String, dynamic>> getUvCount(String irId);
}
```

---

## 📦 Data Models

### Team Model
```dart
class Team {
  final String name;
  final String id;
  final int weeklyInfoTarget;
  final int weeklyPlanTarget;
  final int weeklyUvTarget;
  final int infoProgress;
  final int planProgress;
  final int uvProgress;
  final int weekNumber;
  final int year;
}
```

### Team Member Model
```dart
class TeamMember {
  final String name;
  final int calls;
  final double turnover;
  final int meetings;
  final bool isLead;
  final bool isManager;
}
```

---

## 🎨 UI/UX & Theming

### Theme Configuration
- **Mode**: Dark theme
- **Primary Color**: Cyan Accent (`Colors.cyanAccent`)
- **Background**: Black (`#000000`)
- **Surface Color**: Dark gray (`#121212`, `#1E1E1E`)
- **Text Color**: White

### Design Elements
- Rounded corners (`BorderRadius.circular(12)`)
- Card-based layouts
- Bottom navigation bar (fixed type)
- Floating action buttons for admin actions
- Role badges with icons (star, premium, group)

### Reusable Widgets

#### InfoCard
A versatile card widget for displaying team/member stats:
```dart
InfoCard(
  managerName: "Team Name",
  totalCalls: 50,
  totalTurnover: 1500.0,
  clientMeetings: 10,
  targetCalls: 100,
  targetMeetings: 20,
  targetUv: 2000,
  isLead: true,
  isManager: false,
  isTeam: false,
)
```

---

## 📚 Dependencies

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  intl:                      # Date formatting
  flutter_month_picker:      # Month picker widget
  video_player: ^2.7.0       # Video playback
  http:                      # HTTP requests
  shared_preferences: ^2.2.2 # Local storage

dev_dependencies:
  flutter_native_splash: ^2.4.4   # Splash screen generation
  flutter_launcher_icons: ^0.13.1 # App icon generation
  flutter_lints: ^5.0.0           # Code linting
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.6.1 or higher
- Dart SDK 3.6.1 or higher

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd leadtracker-main
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # For development
   flutter run
   
   # For specific platform
   flutter run -d chrome      # Web
   flutter run -d macos       # macOS
   flutter run -d ios         # iOS Simulator
   flutter run -d android     # Android Emulator
   ```

4. **Build for production**
   ```bash
   flutter build apk          # Android
   flutter build ios          # iOS
   flutter build web          # Web
   flutter build macos        # macOS
   ```

### Configuration

To change the backend URL, edit `lib/core/constants/api_constants.dart`:
```dart
const String baseUrl = "https://your-backend-url.com";
```

---

## 📝 Assets

- **Logo**: `assets/logo.jpeg`
- **Achievements Data**: `assets/data/achievements.json`

### Achievements JSON Format
```json
[
  {
    "title": "Achievement Title",
    "url": "https://video-url.mp4"
  }
]
```

---

## 🔐 Local Storage (SharedPreferences)

The app stores the following data locally:
- `isLoggedIn` (bool) - Login status
- `irId` (String) - User's IR ID
- `userRole` (int) - User's access level

---

## 📄 License

This project is proprietary software for Dreamers United organization.

---

## 👨‍💻 Contributors

Built with ❤️ by the Dreamers United Development Team
