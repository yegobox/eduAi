import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coarse network status. Note: "connected" only means a transport exists,
/// not that the internet is actually reachable — treat online paths as
/// best-effort and always keep the offline fallback.
enum NetworkStatus { online, offline }

class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  static NetworkStatus _map(List<ConnectivityResult> results) {
    final hasTransport = results.any((r) => r != ConnectivityResult.none);
    return hasTransport ? NetworkStatus.online : NetworkStatus.offline;
  }

  Future<NetworkStatus> current() async {
    return _map(await _connectivity.checkConnectivity());
  }

  Future<bool> get isOnline async =>
      (await current()) == NetworkStatus.online;

  Stream<NetworkStatus> watch() {
    return _connectivity.onConnectivityChanged.map(_map).distinct();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});

/// Live network status as a Riverpod stream. Defaults to online until the
/// first reading arrives, so first-launch UX isn't gated on the probe.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.watch();
});
