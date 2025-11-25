import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/mavlink_message_tracker.dart';

import '../../providers/service_providers.dart';

class MavlinkMessageMonitor extends ConsumerStatefulWidget {
  const MavlinkMessageMonitor({
    super.key,
    this.autoStart = true,
    this.onFieldSelected,
    this.plottedFields = const {},
    this.selectedPlotFields = const {},
    this.header,
    this.uiScale = 1.0,
  });

  final bool autoStart;
  final Function(String messageType, String fieldName)? onFieldSelected;
  final Set<String> plottedFields; // All fields plotted across all plots
  final Map<String, Color>
  selectedPlotFields; // Fields in selected plot with their colors
  final Widget? header;
  final double uiScale;

  @override
  ConsumerState<MavlinkMessageMonitor> createState() =>
      _MavlinkMessageMonitorState();
}

class _MavlinkMessageMonitorState extends ConsumerState<MavlinkMessageMonitor> {
  static const double _baseMonitorWidth = 350.0;
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
    // Use centralized message stats stream from TelemetryRepository
    final repository = ref.read(telemetryRepositoryProvider);
    _statsSubscription = repository.messageStatsStream.listen((stats) {
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

  @override
  Widget build(BuildContext context) {
    final sortedMessages = _messageStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      width: _baseMonitorWidth * widget.uiScale,
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
          if (widget.header != null) widget.header!,
          Expanded(
            child: _messageStats.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(sortedMessages),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0 * widget.uiScale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radio,
              size: 48 * widget.uiScale,
              color: Theme.of(context).colorScheme.outline,
            ),
            SizedBox(height: 16 * widget.uiScale),
            Text(
              'No Messages',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize:
                    (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                    widget.uiScale,
              ),
            ),
            SizedBox(height: 8 * widget.uiScale),
            Text(
              'Waiting for MAVLink data...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize:
                    (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                    widget.uiScale,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    List<MapEntry<String, MessageStats>> sortedMessages,
  ) {
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

  Widget _buildMessageTile(
    String messageName,
    MessageStats stats,
    bool isExpanded,
  ) {
    final fields = stats.getMessageFields();

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: 8 * widget.uiScale,
        vertical: 2 * widget.uiScale,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(messageName),
            child: Padding(
              padding: EdgeInsets.all(12.0 * widget.uiScale),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          messageName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.fontSize ??
                                        14) *
                                    widget.uiScale,
                              ),
                        ),
                        SizedBox(height: 4 * widget.uiScale),
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
                    size: 24 * widget.uiScale,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildExpandedContent(messageName, fields),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * widget.uiScale,
        vertical: 2 * widget.uiScale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8 * widget.uiScale),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10 * widget.uiScale,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: 0.8),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
    String messageName,
    Map<String, dynamic> fields,
  ) {
    if (fields.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(12.0 * widget.uiScale),
        child: Text(
          'No field data available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
            fontSize:
                (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) *
                widget.uiScale,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.all(12.0 * widget.uiScale),
      child: Column(
        children: fields.entries.map((field) {
          final fieldKey = '$messageName.${field.key}';
          final isPlotted = widget.plottedFields.contains(fieldKey);
          final isInSelectedPlot = widget.selectedPlotFields.containsKey(
            fieldKey,
          );
          final fieldColor = widget.selectedPlotFields[fieldKey];

          return InkWell(
            onTap: widget.onFieldSelected != null
                ? () => widget.onFieldSelected!(messageName, field.key)
                : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: 2.0 * widget.uiScale,
                horizontal: 4.0 * widget.uiScale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4 * widget.uiScale),
                color: isInSelectedPlot
                    ? fieldColor!.withValues(alpha: 0.1)
                    : (isPlotted
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : Colors.transparent),
                border: isInSelectedPlot
                    ? Border.all(
                        color: fieldColor!.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100 * widget.uiScale,
                    child: Text(
                      field.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize:
                            (Theme.of(context).textTheme.bodySmall?.fontSize ??
                                12) *
                            widget.uiScale,
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * widget.uiScale),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.value.toString(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.fontSize ??
                                          12) *
                                      widget.uiScale,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
