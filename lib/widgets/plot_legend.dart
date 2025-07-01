import 'package:flutter/material.dart';
import '../models/plot_configuration.dart';

class PlotLegend extends StatelessWidget {
  final List<PlotSignalConfiguration> signals;
  final Function(PlotSignalConfiguration)? onSignalTap;
  final bool showValues;
  final Map<String, double>? currentValues;

  const PlotLegend({
    super.key,
    required this.signals,
    this.onSignalTap,
    this.showValues = false,
    this.currentValues,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSignals = signals.where((s) => s.visible).toList();
    
    if (visibleSignals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: visibleSignals.map((signal) => _buildLegendItem(context, signal)).toList(),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, PlotSignalConfiguration signal) {
    final currentValue = currentValues?[signal.fieldKey];
    
    return GestureDetector(
      onTap: onSignalTap != null ? () => onSignalTap!(signal) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: signal.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            signal.effectiveDisplayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showValues && currentValue != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${currentValue.toStringAsFixed(1)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CompactPlotLegend extends StatelessWidget {
  final List<PlotSignalConfiguration> signals;
  final Function(PlotSignalConfiguration)? onSignalTap;

  const CompactPlotLegend({
    super.key,
    required this.signals,
    this.onSignalTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSignals = signals.where((s) => s.visible).toList();
    
    if (visibleSignals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tune,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          ...visibleSignals.take(3).map((signal) => 
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: signal.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
          if (visibleSignals.length > 3) ...[
            const SizedBox(width: 2),
            Text(
              '+${visibleSignals.length - 3}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlotLegendOverlay extends StatelessWidget {
  final List<PlotSignalConfiguration> signals;
  final Function(PlotSignalConfiguration)? onSignalTap;
  final bool showValues;
  final Map<String, double>? currentValues;
  final Alignment alignment;

  const PlotLegendOverlay({
    super.key,
    required this.signals,
    this.onSignalTap,
    this.showValues = false,
    this.currentValues,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSignals = signals.where((s) => s.visible).toList();
    
    if (visibleSignals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: visibleSignals.map((signal) => 
              _buildOverlayLegendItem(context, signal)
            ).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayLegendItem(BuildContext context, PlotSignalConfiguration signal) {
    final currentValue = currentValues?[signal.fieldKey];
    
    return GestureDetector(
      onTap: onSignalTap != null ? () => onSignalTap!(signal) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: signal.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _getShortName(signal.effectiveDisplayName),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showValues && currentValue != null) ...[
              const SizedBox(width: 4),
              Text(
                currentValue.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getShortName(String fullName) {
    // Abbreviate long names to fit in overlay
    if (fullName.length <= 12) return fullName;
    
    final parts = fullName.split('.');
    if (parts.length >= 2) {
      return '${parts[0].substring(0, 3)}...${parts[1]}';
    }
    
    return '${fullName.substring(0, 9)}...';
  }
}