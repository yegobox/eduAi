import '../../features/auth/domain/entities/app_role.dart';

/// Centralised route paths + names. Keep string literals out of widgets.
abstract final class AppRoutes {
  // ---- gates -------------------------------------------------------------
  static const splash = '/splash';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const phone = '/phone';
  static const unlock = '/unlock';
  static const setPin = '/set-pin';

  // ---- student tabs ------------------------------------------------------
  static const home = '/';
  static const tutor = '/tutor';
  static const workbook = '/workbook';
  static const lessons = '/lessons';
  static const progress = '/progress';

  // ---- parent tabs -------------------------------------------------------
  static const parentOverview = '/parent';
  static const parentReports = '/parent/reports';
  static const parentMessages = '/parent/messages';
  static const parentPlan = '/parent/plan';

  // ---- school-admin tabs -------------------------------------------------
  static const adminLicense = '/admin';
  static const adminSeats = '/admin/seats';
  static const adminInvoices = '/admin/invoices';
  static const adminUsage = '/admin/usage';

  // ---- pushed detail pages (full screen, over the shell) -----------------
  static const schools = '/schools';

  /// Parent ↔ student links: invite a child, or redeem a code. Reachable from
  /// the parent shell and from the student shell, which is why it is a pushed
  /// page rather than a tab in either.
  static const family = '/family';

  /// A single school's classroom detail page.
  static String schoolDetail(String id) => '/school/$id';

  /// A single lesson's reader page.
  static String lessonReader(String id) => '/lesson/$id';

  /// Routes reachable while signed out.
  static const unauthenticated = {login, signUp, phone};

  /// Where an authenticated identity lands, by role.
  static String homeFor(AppRole role) => switch (role) {
    AppRole.student => home,
    AppRole.parent => parentOverview,
    AppRole.schoolAdmin => adminLicense,
  };

  /// The tab roots that belong to [role] — used to bounce an identity that
  /// deep-links into another role's shell back to its own home.
  static Set<String> shellRootsFor(AppRole role) => switch (role) {
    AppRole.student => const {home, tutor, workbook, lessons, progress},
    AppRole.parent => const {
      parentOverview,
      parentReports,
      parentMessages,
      parentPlan,
    },
    AppRole.schoolAdmin => const {
      adminLicense,
      adminSeats,
      adminInvoices,
      adminUsage,
    },
  };

  /// True when [location] belongs to a *different* role's shell.
  static bool isForeignShell(String location, AppRole role) {
    final mine = shellRootsFor(role);
    if (mine.contains(location)) return false;
    for (final other in AppRole.values) {
      if (other == role) continue;
      if (shellRootsFor(other).contains(location)) return true;
    }
    return false;
  }
}
