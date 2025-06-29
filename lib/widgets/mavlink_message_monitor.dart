import 'dart:async';
import 'package:flutter/material.dart';
import '../services/mavlink_message_tracker.dart';

class MavlinkMessageMonitor extends StatefulWidget {
  const MavlinkMessageMonitor({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  State<MavlinkMessageMonitor> createState() => _MavlinkMessageMonitorState();
}

class _MavlinkMessageMonitorState extends State<MavlinkMessageMonitor> {
  final MavlinkMessageTracker _tracker = MavlinkMessageTracker();
  Map<String, MessageStats> _messageStats = {};
  StreamSubscription? _statsSubscription;
  final Set<String> _expandedMessages = {};

  @override
  void initState() {
    super.initState();
    _initializeTracker();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }

  void _initializeTracker() {
    if (widget.autoStart) {
      _tracker.startTracking();
    }
    _statsSubscription = _tracker.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _messageStats = stats;
        });
      }
    });
  }

  void _toggleExpanded(String messageName) {
    setState(() {
      if (_expandedMessages.contains(messageName)) {
        _expandedMessages.remove(messageName);
      } else {
        _expandedMessages.add(messageName);
      }
    });
  }

  void _clearStats() {
    _tracker.clearStats();
  }

  @override
  Widget build(BuildContext context) {
    final sortedMessages = _messageStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messageStats.isEmpty 
                ? _buildEmptyState() 
                : _buildMessageList(sortedMessages),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monitor,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MAVLink Monitor',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 20),
            onPressed: _clearStats,
            tooltip: 'Clear Statistics',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Messages',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for MAVLink data...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<MapEntry<String, MessageStats>> sortedMessages) {
    return ListView.builder(
      itemCount: sortedMessages.length,
      itemBuilder: (context, index) {
        final entry = sortedMessages[index];
        final messageName = entry.key;
        final stats = entry.value;
        final isExpanded = _expandedMessages.contains(messageName);

        return _buildMessageTile(messageName, stats, isExpanded);
      },
    );
  }

  Widget _buildMessageTile(String messageName, MessageStats stats, bool isExpanded) {
    final fields = stats.getMessageFields();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(messageName),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          messageName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatChip(
                          '${stats.frequency.toStringAsFixed(1)} Hz',
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildExpandedContent(fields),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: 0.8),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Map<String, dynamic> fields) {
    if (fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          'No field data available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: fields.entries.map((field) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    field.key,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.value.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}