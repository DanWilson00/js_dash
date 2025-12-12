import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connection_status.dart';
import '../models/statustext_entry.dart';
import '../mavlink/mavlink.dart';
import 'service_providers.dart';

/// Maximum number of STATUSTEXT entries to keep in memory.
const int _maxStatusTextEntries = 100;

/// Notifier that manages STATUSTEXT message entries.
/// Migrated from StateNotifier to Notifier for Riverpod 3.x compatibility.
class StatusTextNotifier extends Notifier<List<StatusTextEntry>> {
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  StreamSubscription<MavlinkMessage>? _messageSubscription;
  MavlinkMetadataRegistry? _registry;
  bool _isSubscribedToMessages = false;

  @override
  List<StatusTextEntry> build() {
    _initialize();

    // Register cleanup on dispose
    ref.onDispose(() {
      _statusSubscription?.cancel();
      _messageSubscription?.cancel();
      _statusSubscription = null;
      _messageSubscription = null;
    });

    return [];
  }

  void _initialize() {
    _registry = ref.read(mavlinkRegistryProvider);

    // Subscribe to connection status stream
    final connectionManager = ref.read(connectionManagerProvider);
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

    final connectionManager = ref.read(connectionManagerProvider);
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
}

/// Provider for STATUSTEXT messages.
final statusTextProvider =
    NotifierProvider<StatusTextNotifier, List<StatusTextEntry>>(
  StatusTextNotifier.new,
);
