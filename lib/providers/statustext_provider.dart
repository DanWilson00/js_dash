import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_status.dart';
import '../models/statustext_entry.dart';
import '../mavlink/mavlink.dart';
import 'service_providers.dart';

/// Maximum number of STATUSTEXT entries to keep in memory.
const int _maxStatusTextEntries = 100;

/// Provider for STATUSTEXT messages.
final statusTextProvider =
    StateNotifierProvider<StatusTextNotifier, List<StatusTextEntry>>((ref) {
  final notifier = StatusTextNotifier(ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// StateNotifier that manages STATUSTEXT message entries.
class StatusTextNotifier extends StateNotifier<List<StatusTextEntry>> {
  StatusTextNotifier(this._ref) : super([]) {
    _initialize();
  }

  final Ref _ref;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<MavlinkMessage>? _messageSubscription;
  MavlinkMetadataRegistry? _registry;
  bool _isSubscribedToMessages = false;

  void _initialize() {
    _registry = _ref.read(mavlinkRegistryProvider);

    // Subscribe to connection status stream
    final connectionManager = _ref.read(connectionManagerProvider);
    _statusSubscription = connectionManager.statusStream.listen((status) {
      if (status.state == ConnectionState.connected) {
        _subscribeToStatusText();
      } else {
        _unsubscribeFromStatusText();
      }
    });

    // Also check current status immediately (might already be connected)
    if (connectionManager.isConnected) {
      _subscribeToStatusText();
    }
  }

  void _subscribeToStatusText() {
    if (_isSubscribedToMessages) return;

    final connectionManager = _ref.read(connectionManagerProvider);
    final dataSource = connectionManager.currentDataSource;

    if (dataSource != null) {
      _isSubscribedToMessages = true;
      _messageSubscription = dataSource.streamByName('STATUSTEXT').listen(
        _handleStatusText,
        onError: (e) {
          // Silently handle stream errors
          _isSubscribedToMessages = false;
        },
        onDone: () {
          _isSubscribedToMessages = false;
        },
      );
    }
  }

  void _unsubscribeFromStatusText() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _isSubscribedToMessages = false;
  }

  void _handleStatusText(MavlinkMessage message) {
    final severity = message.values['severity'] as int? ?? 6;
    final text = message.values['text'] as String? ?? '';

    // Resolve severity enum name
    String severityName = 'INFO';
    if (_registry != null) {
      severityName =
          _registry!.resolveEnumValue('MAV_SEVERITY', severity) ?? 'INFO';
    }

    final entry = StatusTextEntry(
      timestamp: DateTime.now(),
      severity: severity,
      severityName: severityName,
      text: text.trim(),
    );

    // Add new entry at the beginning (newest first)
    final newState = [entry, ...state];

    // Trim to max entries
    if (newState.length > _maxStatusTextEntries) {
      state = newState.sublist(0, _maxStatusTextEntries);
    } else {
      state = newState;
    }
  }

  /// Clear all status text entries.
  void clear() {
    state = [];
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    _statusSubscription = null;
    _messageSubscription = null;
    super.dispose();
  }
}
