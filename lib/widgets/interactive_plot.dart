import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/plot_configuration.dart';
import '../services/timeseries_data_manager.dart';
import 'plot_legend.dart';

class InteractivePlot extends StatefulWidget {
  final PlotConfiguration configuration;
  final bool isAxisSelected;
  final VoidCallback? onAxisTap;
  final VoidCallback? onClearAxis;
  final VoidCallback? onLegendTap;

  const InteractivePlot({
    super.key,
    required this.configuration,
    this.isAxisSelected = false,
    this.onAxisTap,
    this.onClearAxis,
    this.onLegendTap,
  });

  @override
  State<InteractivePlot> createState() => _InteractivePlotState();
}

class _InteractivePlotState extends State<InteractivePlot> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  Map<String, List<FlSpot>> _signalSpots = {};
  Map<String, double> _currentValues = {};
  double _minY = 0;
  double _maxY = 100;
  StreamSubscription? _dataSubscription;
  final Map<String, int> _lastDataLengths = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupDataListener();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _initializeData() {
    if (widget.configuration.yAxis.hasData) {
      _updatePlotData();
    }
  }

  void _setupDataListener() {
    _dataSubscription = _dataManager.dataStream.listen((_) {
      if (mounted && widget.configuration.yAxis.hasData) {
        _updatePlotData();
      }
    });
  }

  void _updatePlotData() {
    if (!widget.configuration.yAxis.hasVisibleSignals) return;

    final now = DateTime.now();
    final startTime = now.subtract(widget.configuration.timeWindow);
    final cutoff = now.subtract(widget.configuration.timeWindow);
    
    final newSignalSpots = <String, List<FlSpot>>{};
    final newCurrentValues = <String, double>{};
    final allValues = <double>[];
    bool hasNewData = false;

    // Process each visible signal
    for (final signal in widget.configuration.yAxis.visibleSignals) {
      final fieldKey = signal.fieldKey;
      final data = _dataManager.getFieldData(signal.messageType, signal.fieldName);
      
      // Check if we have new data for this signal
      final lastLength = _lastDataLengths[fieldKey] ?? 0;
      if (data.length != lastLength) {
        _lastDataLengths[fieldKey] = data.length;
        hasNewData = true;
      }

      // Filter data by time window
      final filteredData = data
          .where((point) => point.timestamp.isAfter(cutoff))
          .toList();

      if (filteredData.isNotEmpty) {
        // Store current value
        newCurrentValues[fieldKey] = filteredData.last.value;
        
        // Convert to FlSpots with scaling
        List<FlSpot> spots;
        if (widget.configuration.yAxis.scalingMode == ScalingMode.independent) {
          // Normalize to 0-100% range
          final values = filteredData.map((p) => p.value).toList();
          final minVal = values.reduce((a, b) => a < b ? a : b);
          final maxVal = values.reduce((a, b) => a > b ? a : b);
          final range = maxVal - minVal;
          
          spots = filteredData.map((point) {
            final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
            final normalizedY = range > 0 ? ((point.value - minVal) / range) * 100.0 : 50.0;
            return FlSpot(x, normalizedY);
          }).toList();
          
          // Add normalized values for independent scaling
          allValues.addAll(spots.map((s) => s.y));
        } else {
          // Use raw values for unified/auto scaling
          spots = filteredData.map((point) {
            final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
            return FlSpot(x, point.value);
          }).toList();
          
          // Add raw values for scaling calculation
          allValues.addAll(spots.map((s) => s.y));
        }
        
        newSignalSpots[fieldKey] = spots;
      } else {
        newSignalSpots[fieldKey] = [];
      }
    }

    // Only update if we have new data
    if (!hasNewData && _signalSpots.isNotEmpty) return;

    // Calculate Y axis bounds
    double newMinY, newMaxY;
    if (allValues.isNotEmpty) {
      switch (widget.configuration.yAxis.scalingMode) {
        case ScalingMode.autoScale:
          newMinY = allValues.reduce((a, b) => a < b ? a : b);
          newMaxY = allValues.reduce((a, b) => a > b ? a : b);
          
          // Add 10% padding
          final range = newMaxY - newMinY;
          if (range > 0) {
            newMinY -= range * 0.1;
            newMaxY += range * 0.1;
          } else {
            newMinY -= 1;
            newMaxY += 1;
          }
          break;
        case ScalingMode.independent:
          // For independent scaling, use 0-100% range
          newMinY = 0;
          newMaxY = 100;
          break;
        case ScalingMode.unified:
          // Use configured bounds or calculate from data
          newMinY = widget.configuration.yAxis.minY ?? 
                   allValues.reduce((a, b) => a < b ? a : b);
          newMaxY = widget.configuration.yAxis.maxY ?? 
                   allValues.reduce((a, b) => a > b ? a : b);
          break;
      }
    } else {
      newMinY = widget.configuration.yAxis.minY ?? 0;
      newMaxY = widget.configuration.yAxis.maxY ?? 100;
    }

    // Always update for maximum responsiveness
    setState(() {
      _signalSpots = newSignalSpots;
      _currentValues = newCurrentValues;
      _minY = newMinY;
      _maxY = newMaxY;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAxisTap,
      onSecondaryTapUp: widget.onClearAxis != null ? (_) => _showContextMenu() : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isAxisSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: widget.isAxisSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildChart(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.configuration.yAxis.hasData
                ? widget.configuration.yAxis.displayName
                : 'Click to select signals',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.configuration.yAxis.hasData
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.onLegendTap,
          child: widget.configuration.yAxis.hasData
              ? CompactPlotLegend(
                  signals: widget.configuration.yAxis.signals,
                )
              : Container(
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
                        Icons.add,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Signals',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final hasAnyData = _signalSpots.values.any((spots) => spots.isNotEmpty);
    
    if (!hasAnyData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 24,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 4),
            Text(
              widget.configuration.yAxis.hasData ? 'No data' : 'Select signals',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: (_maxY - _minY) / 5,
              verticalInterval: widget.configuration.timeWindow.inMilliseconds / 5,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: widget.configuration.timeWindow.inMilliseconds / 4,
                  getTitlesWidget: (value, meta) => _buildTimeLabel(value),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (_maxY - _minY) / 4,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) => _buildValueLabel(value),
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            minX: 0,
            maxX: widget.configuration.timeWindow.inMilliseconds.toDouble(),
            minY: _minY,
            maxY: _maxY,
            lineBarsData: _buildLineChartBars(),
          ),
          // No animation duration - immediate updates
          duration: Duration.zero,
        ),
        // Legend overlay
        if (widget.configuration.yAxis.visibleSignals.length > 1)
          PlotLegendOverlay(
            signals: widget.configuration.yAxis.signals,
            showValues: true,
            currentValues: _currentValues,
            alignment: Alignment.topRight,
          ),
      ],
    );
  }

  List<LineChartBarData> _buildLineChartBars() {
    final lineBars = <LineChartBarData>[];
    
    for (final signal in widget.configuration.yAxis.visibleSignals) {
      final spots = _signalSpots[signal.fieldKey] ?? [];
      if (spots.isNotEmpty) {
        lineBars.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: signal.color,
            barWidth: signal.lineWidth,
            dotData: FlDotData(show: signal.showDots),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }
    
    return lineBars;
  }

  Widget _buildTimeLabel(double value) {
    final now = DateTime.now();
    final startTime = now.subtract(widget.configuration.timeWindow);
    final time = startTime.add(Duration(milliseconds: value.round()));
    final diff = now.difference(time);
    
    String label;
    if (diff.inMinutes < 1) {
      label = '${diff.inSeconds}s';
    } else if (diff.inHours < 1) {
      label = '${diff.inMinutes}m';
    } else {
      label = '${diff.inHours}h';
    }
    
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildValueLabel(double value) {
    return Text(
      value.toStringAsFixed(1),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  void _showContextMenu() {
    if (widget.onClearAxis == null || !widget.configuration.yAxis.hasData) return;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        PopupMenuItem(
          onTap: widget.onClearAxis,
          child: const Row(
            children: [
              Icon(Icons.clear),
              SizedBox(width: 8),
              Text('Clear'),
            ],
          ),
        ),
      ],
    );
  }
}