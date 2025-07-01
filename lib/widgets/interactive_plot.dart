import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/plot_configuration.dart';
import '../services/timeseries_data_manager.dart';

class InteractivePlot extends StatefulWidget {
  final PlotConfiguration configuration;
  final bool isAxisSelected;
  final VoidCallback? onAxisTap;
  final VoidCallback? onClearAxis;

  const InteractivePlot({
    super.key,
    required this.configuration,
    this.isAxisSelected = false,
    this.onAxisTap,
    this.onClearAxis,
  });

  @override
  State<InteractivePlot> createState() => _InteractivePlotState();
}

class _InteractivePlotState extends State<InteractivePlot> {
  final TimeSeriesDataManager _dataManager = TimeSeriesDataManager();
  List<FlSpot> _spots = [];
  double _minY = 0;
  double _maxY = 100;
  StreamSubscription? _dataSubscription;
  int _lastDataLength = 0;

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
    if (!widget.configuration.yAxis.hasData) return;

    final data = _dataManager.getFieldData(
      widget.configuration.yAxis.messageType!,
      widget.configuration.yAxis.fieldName!,
    );

    // Only proceed if we have new data
    if (data.length == _lastDataLength) return;
    _lastDataLength = data.length;

    if (data.isEmpty) {
      if (_spots.isNotEmpty) {
        setState(() {
          _spots = [];
        });
      }
      return;
    }

    // Filter data by time window
    final now = DateTime.now();
    final cutoff = now.subtract(widget.configuration.timeWindow);
    final filteredData = data
        .where((point) => point.timestamp.isAfter(cutoff))
        .toList();

    if (filteredData.isEmpty) {
      if (_spots.isNotEmpty) {
        setState(() {
          _spots = [];
        });
      }
      return;
    }

    // Calculate time-based X coordinates
    final startTime = now.subtract(widget.configuration.timeWindow);
    final newSpots = filteredData.map((point) {
      final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
      return FlSpot(x, point.value);
    }).toList();

    // Calculate Y axis bounds
    double newMinY, newMaxY;
    if (widget.configuration.yAxis.autoScale && newSpots.isNotEmpty) {
      final values = newSpots.map((s) => s.y).toList();
      newMinY = values.reduce((a, b) => a < b ? a : b);
      newMaxY = values.reduce((a, b) => a > b ? a : b);
      
      // Add 10% padding
      final range = newMaxY - newMinY;
      if (range > 0) {
        newMinY -= range * 0.1;
        newMaxY += range * 0.1;
      } else {
        newMinY -= 1;
        newMaxY += 1;
      }
    } else {
      newMinY = widget.configuration.yAxis.minY ?? 0;
      newMaxY = widget.configuration.yAxis.maxY ?? 100;
    }

    // Always update for maximum responsiveness
    setState(() {
      _spots = newSpots;
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
                : 'Click to select data',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.configuration.yAxis.hasData
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        if (widget.configuration.yAxis.hasData && widget.configuration.yAxis.units != null)
          Text(
            widget.configuration.yAxis.units!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Widget _buildChart() {
    if (_spots.isEmpty) {
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
              widget.configuration.yAxis.hasData ? 'No data' : 'Select data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LineChart(
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
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: false,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: false), // No dots for maximum performance
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      // No animation duration - immediate updates
      duration: Duration.zero,
    );
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