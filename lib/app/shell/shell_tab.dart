import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/app_role.dart';

/// One destination in a role's navigation chrome.
@immutable
class ShellTab {
  const ShellTab({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

/// The tab set each role sees. Order matters — it is the branch order of the
/// matching `StatefulShellRoute`.
abstract final class ShellTabs {
  static const student = <ShellTab>[
    ShellTab(label: 'Home', icon: Icons.home_outlined, route: '/'),
    ShellTab(
      label: 'Tutor',
      icon: Icons.auto_awesome_outlined,
      route: '/tutor',
    ),
    ShellTab(label: 'Workbook', icon: Icons.edit_outlined, route: '/workbook'),
    ShellTab(
      label: 'Lessons',
      icon: Icons.menu_book_outlined,
      route: '/lessons',
    ),
    ShellTab(
      label: 'Progress',
      icon: Icons.insights_outlined,
      route: '/progress',
    ),
  ];

  static const parent = <ShellTab>[
    ShellTab(label: 'Overview', icon: Icons.home_outlined, route: '/parent'),
    ShellTab(
      label: 'Reports',
      icon: Icons.insights_outlined,
      route: '/parent/reports',
    ),
    ShellTab(
      label: 'Messages',
      icon: Icons.mail_outline,
      route: '/parent/messages',
    ),
    ShellTab(label: 'Plan', icon: Icons.shield_outlined, route: '/parent/plan'),
  ];

  static const teacher = <ShellTab>[
    ShellTab(label: 'Classes', icon: Icons.groups_outlined, route: '/teacher'),
    ShellTab(
      label: 'Progress',
      icon: Icons.insights_outlined,
      route: '/teacher/progress',
    ),
  ];

  static const schoolAdmin = <ShellTab>[
    ShellTab(label: 'License', icon: Icons.shield_outlined, route: '/admin'),
    // "People" rather than "Seats": the tab lists the students who consume the
    // seats and lets an admin invite their parents. Seats are counted from the
    // roster, not typed in.
    ShellTab(
      label: 'People',
      icon: Icons.groups_outlined,
      route: '/admin/seats',
    ),
    ShellTab(
      label: 'Invoices',
      icon: Icons.description_outlined,
      route: '/admin/invoices',
    ),
    ShellTab(
      label: 'Usage',
      icon: Icons.bar_chart_outlined,
      route: '/admin/usage',
    ),
  ];

  static List<ShellTab> forRole(AppRole role) => switch (role) {
    AppRole.student => student,
    AppRole.parent => parent,
    AppRole.teacher => teacher,
    AppRole.schoolAdmin => schoolAdmin,
  };
}
