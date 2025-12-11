import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/statustext_entry.dart';
import '../../providers/statustext_provider.dart';

/// A collapsible bottom panel that displays STATUSTEXT messages.
class StatusTextLogPanel extends ConsumerStatefulWidget {
  const StatusTextLogPanel({
    super.key,
    this.expandedHeight = 180.0,
    this.collapsedHeight = 36.0,
    this.uiScale = 1.0,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final double uiScale;

  @override
  ConsumerState<StatusTextLogPanel> createState() => _StatusTextLogPanelState();
}

class _StatusTextLogPanelState extends ConsumerState<StatusTextLogPanel> {
  bool _isExpanded = false;
  int _lastSeenCount = 0;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(statusTextProvider);
    final highestSeverity = _getHighestSeverity(entries);
    final hasUnread = !_isExpanded && entries.length > _lastSeenCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isExpanded
          ? widget.expandedHeight * widget.uiScale
          : widget.collapsedHeight * widget.uiScale,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, entries.length, highestSeverity, hasUnread),
          if (_isExpanded)
            Expanded(
              child: _buildMessageList(context, entries),
            ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        // Mark all as seen when expanding
        _lastSeenCount = ref.read(statusTextProvider).length;
      }
    });
  }

  Widget _buildHeader(BuildContext context, int count, int? highestSeverity, bool hasUnread) {
    final scale = widget.uiScale;

    return InkWell(
      onTap: _toggleExpanded,
      child: Container(
        height: widget.collapsedHeight * scale,
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.expand_more : Icons.expand_less,
              size: 18 * scale,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 4 * scale),
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13 * scale,
                  ),
            ),
            SizedBox(width: 6 * scale),
            if (count > 0) ...[
              _buildCountBadge(context, count, highestSeverity),
              if (hasUnread) ...[
                SizedBox(width: 4 * scale),
                _buildNewBadge(context),
              ],
              SizedBox(width: 6 * scale),
              if (highestSeverity != null && highestSeverity <= 4)
                _buildSeverityIndicator(context, highestSeverity),
            ],
            const Spacer(),
            if (count > 0)
              InkWell(
                onTap: () {
                  ref.read(statusTextProvider.notifier).clear();
                  setState(() {
                    _lastSeenCount = 0;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, size: 14 * scale),
                      SizedBox(width: 2 * scale),
                      Text('Clear', style: TextStyle(fontSize: 11 * scale)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count, int? severity) {
    final scale = widget.uiScale;
    final color = severity != null ? _getSeverityColor(severity) : Colors.grey;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 1 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNewBadge(BuildContext context) {
    final scale = widget.uiScale;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(3 * scale),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          fontSize: 8 * scale,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSeverityIndicator(BuildContext context, int severity) {
    final scale = widget.uiScale;
    final color = _getSeverityColor(severity);
    final label = _getSeverityShortLabel(severity);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3 * scale),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9 * scale,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, List<StatusTextEntry> entries) {
    final scale = widget.uiScale;

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No status messages',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontStyle: FontStyle.italic,
                fontSize: 11 * scale,
              ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildMessageRow(context, entries[index]);
      },
    );
  }

  Widget _buildMessageRow(BuildContext context, StatusTextEntry entry) {
    final scale = widget.uiScale;
    final color = _getSeverityColor(entry.severity);
    final isCritical = entry.severity <= 2;
    final isError = entry.severity <= 4;

    return Container(
      margin: EdgeInsets.only(bottom: 1 * scale),
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: isCritical ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(3 * scale),
        border: isCritical
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 55 * scale,
            child: Text(
              entry.formattedTime,
              style: TextStyle(
                fontSize: 10 * scale,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Severity label
          SizedBox(
            width: 55 * scale,
            child: Text(
              entry.severityLabel,
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                fontStyle: entry.severity == 7 ? FontStyle.italic : FontStyle.normal,
                color: color,
              ),
            ),
          ),
          // Message text
          Expanded(
            child: Text(
              entry.text,
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
                fontStyle: entry.severity == 7 ? FontStyle.italic : FontStyle.normal,
                color: entry.severity == 7
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get the highest (most severe) severity from the entries.
  /// Lower numbers are more severe.
  int? _getHighestSeverity(List<StatusTextEntry> entries) {
    if (entries.isEmpty) return null;
    return entries.map((e) => e.severity).reduce((a, b) => a < b ? a : b);
  }

  /// Get color for severity level.
  Color _getSeverityColor(int severity) {
    return switch (severity) {
      0 || 1 || 2 => Colors.red,        // EMERGENCY, ALERT, CRITICAL
      3 => Colors.orange,               // ERROR
      4 => Colors.amber,                // WARNING
      5 => Colors.blue,                 // NOTICE
      6 => Colors.blueGrey,             // INFO
      7 => Colors.grey,                 // DEBUG
      _ => Colors.grey,
    };
  }

  /// Get short label for severity indicator.
  String _getSeverityShortLabel(int severity) {
    return switch (severity) {
      0 => 'EMERG',
      1 => 'ALERT',
      2 => 'CRIT',
      3 => 'ERROR',
      4 => 'WARN',
      _ => '',
    };
  }
}
