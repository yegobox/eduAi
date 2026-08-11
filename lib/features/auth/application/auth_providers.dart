import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/datasources/firebase_phone_auth_data_source.dart';
import '../data/datasources/offline_credential_store.dart';
import '../data/datasources/supabase_auth_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';

/// Dependency-injection graph for the auth feature. Each edge is a provider so
/// any node can be overridden in a test with a fake.

final _supabaseDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(ref.watch(supabaseClientProvider));
});

final _phoneDataSourceProvider = Provider<FirebasePhoneAuthDataSource>((ref) {
  return FirebasePhoneAuthDataSource(ready: ref.watch(firebaseReadyProvider));
});

final offlineCredentialStoreProvider = Provider<OfflineCredentialStore>((ref) {
  return OfflineCredentialStore(ref.watch(secureStorageProvider));
});

/// The app-wide [AuthRepository]. Disposed with the container.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepositoryImpl(
    supabaseSource: ref.watch(_supabaseDataSourceProvider),
    phoneSource: ref.watch(_phoneDataSourceProvider),
    offlineStore: ref.watch(offlineCredentialStoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of the current session (null when signed out). Used by the
/// router and any screen that needs to react to auth changes.
final authSessionStreamProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Whether this device has an offline PIN configured (drives the "set up
/// offline access" prompt). Re-evaluated whenever the session changes.
final hasOfflinePinProvider = FutureProvider<bool>((ref) async {
  ref.watch(authSessionStreamProvider);
  return ref.watch(authRepositoryProvider).hasOfflinePin();
});
