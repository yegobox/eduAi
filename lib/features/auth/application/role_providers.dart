import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_role.dart';
import 'auth_controller.dart';

/// Debug-only role override, driven by the "View as" item in the More menu.
///
/// In release the menu item is not built, so this stays null and the role
/// always comes from the signed-in identity. Widget tests override it to pump
/// the parent / admin shells without minting three fake sessions.
final roleOverrideProvider = StateProvider<AppRole?>((ref) => null);

/// The role whose shell is currently on screen.
final activeRoleProvider = Provider<AppRole>((ref) {
  final override = ref.watch(roleOverrideProvider);
  if (override != null) return override;
  return ref.watch(
    authControllerProvider.select(
      (s) => s.session?.user.role ?? AppRole.student,
    ),
  );
});
