import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

typedef NetworkRetryCallback = Future<void> Function();

class NetworkController extends GetxController with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  final RxBool isOffline = false.obs;
  final RxBool isRetrying = false.obs;

  final List<_RetryEntry> _retryEntries = [];
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;
  Timer? _resumeTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    unawaited(refresh(autoRetry: false));
  }

  void registerRetryCallback(Object owner, NetworkRetryCallback callback) {
    unregisterRetryCallback(owner);
    _retryEntries.add(_RetryEntry(owner, callback));
  }

  void unregisterRetryCallback(Object owner) {
    _retryEntries.removeWhere((entry) => identical(entry.owner, owner));
  }

  Future<bool> hasNetwork() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh({bool autoRetry = true}) async {
    final wasOffline = isOffline.value;
    isOffline.value = !await hasNetwork();
    if (autoRetry && wasOffline && !isOffline.value) {
      await retry(checkConnection: false);
    }
  }

  Future<void> retry({bool checkConnection = true}) async {
    if (isRetrying.value) return;
    isRetrying.value = true;
    try {
      if (checkConnection) await refresh(autoRetry: false);
      if (isOffline.value || _retryEntries.isEmpty) return;
      await _retryEntries.last.callback();
    } finally {
      isRetrying.value = false;
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(refresh()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(refresh()),
    );
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _resumeTimer?.cancel();
    _subscription?.cancel();
    super.onClose();
  }
}

class _RetryEntry {
  const _RetryEntry(this.owner, this.callback);
  final Object owner;
  final NetworkRetryCallback callback;
}

class NetworkBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NetworkController(), permanent: true);
  }
}
