/// Which product surface an identity signs in to.
///
/// This is not a runtime toggle in the shipped app: a parent account, a
/// student account and a school-admin account are three different identities.
/// The router redirects to the matching shell the same way it redirects
/// signed-out users to `/login`.
enum AppRole {
  student,
  parent,
  schoolAdmin;

  String get label => switch (this) {
    AppRole.student => 'Student',
    AppRole.parent => 'Parent',
    AppRole.schoolAdmin => 'School admin',
  };

  /// Wire value stored on the identity record / offline credential.
  String get wireName => switch (this) {
    AppRole.student => 'student',
    AppRole.parent => 'parent',
    AppRole.schoolAdmin => 'school_admin',
  };

  /// Parses a server/cache value, defaulting to [AppRole.student] for
  /// anything unknown — an unrecognised role must never lock a learner out.
  static AppRole fromWire(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'parent' => AppRole.parent,
      'school_admin' || 'schooladmin' || 'admin' => AppRole.schoolAdmin,
      _ => AppRole.student,
    };
  }
}
