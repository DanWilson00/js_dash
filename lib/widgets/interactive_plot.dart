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
  List<TimeSeriesPoint> _plotData = [];

  @override
  void initState() {
    super.initState();
    _updatePlotData();
    _dataManager.dataStream.listen((_) {
      if (mounted) {
        _updatePlotData();
      }
    });
  }

  void _updatePlotData() {
    if (widget.configuration.yAxis.hasData) {
      final data = _dataManager.getFieldData(
        widget.configuration.yAxis.messageType!,
        widget.configuration.yAxis.fieldName!,
      );
      
      final now = DateTime.now();
      final cutoff = now.subtract(widget.configuration.timeWindow);
      
      setState(() {
        _plotData = data
            .where((point) => point.timestamp.isAfter(cutoff))
            .toList();
      });
    } else {
      setState(() {
        _plotData = [];
      });
    }
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
    if (_plotData.isEmpty) {
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

    final now = DateTime.now();
    final startTime = now.subtract(widget.configuration.timeWindow);
    
    final spots = _plotData.map((point) {
      final x = point.timestamp.difference(startTime).inMilliseconds.toDouble();
      return FlSpot(x, point.value);
    }).toList();

    // Calculate Y axis bounds
    double minY, maxY;
    if (widget.configuration.yAxis.autoScale && spots.isNotEmpty) {
      final values = spots.map((s) => s.y).toList();
      minY = values.reduce((a, b) => a < b ? a : b);
      maxY = values.reduce((a, b) => a > b ? a : b);
      
      // Add 10% padding
      final range = maxY - minY;
      if (range > 0) {
        minY -= range * 0.1;
        maxY += range * 0.1;
      } else {
        minY -= 1;
        maxY += 1;
      }
    } else {
      minY = widget.configuration.yAxis.minY ?? 0;
      maxY = widget.configuration.yAxis.maxY ?? 100;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / 5,
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
              getTitlesWidget: (value, meta) => _buildTimeLabel(value, startTime),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY - minY) / 4,
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
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(double value, DateTime startTime) {
    final time = startTime.add(Duration(milliseconds: value.round()));
    final now = DateTime.now();
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