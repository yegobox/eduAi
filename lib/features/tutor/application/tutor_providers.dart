import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/network/http_client_provider.dart';
import '../data/datasources/tutor_remote_data_source.dart';
import '../data/repositories/tutor_repository_impl.dart';
import '../domain/repositories/tutor_repository.dart';

final _tutorRemoteProvider = Provider<TutorRemoteDataSource>((ref) {
  return TutorRemoteDataSource(
    ref.watch(httpClientProvider),
    ref.watch(appConfigProvider).dataConnectorUrl,
  );
});

final tutorRepositoryProvider = Provider<TutorRepository>((ref) {
  return TutorRepositoryImpl(remoteSource: ref.watch(_tutorRemoteProvider));
});
