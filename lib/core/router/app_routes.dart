/// Centralised route paths + names. Keep string literals out of widgets.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const phone = '/phone';
  static const unlock = '/unlock';
  static const setPin = '/set-pin';
  static const home = '/';
  static const schools = '/schools';
  static const tutor = '/tutor';
  static const progress = '/progress';

  /// Path for a single school's detail page.
  static String schoolDetail(String id) => '/schools/$id';

  /// Routes reachable while signed out.
  static const unauthenticated = {login, signUp, phone};
}
