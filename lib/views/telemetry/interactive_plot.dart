import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/plot_configuration.dart';
import '../../core/timeseries_point.dart';

import '../../services/timeseries_data_manager.dart';
import '../../providers/service_providers.dart';
import 'plot_legend.dart';
import 'plot_data_processor.dart';

class InteractivePlot extends ConsumerStatefulWidget {
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
  ConsumerState<InteractivePlot> createState() => _InteractivePlotState();
}

class _InteractivePlotState extends ConsumerState<InteractivePlot> {
  // Access dataManager from Riverpod provider
  late final TimeSeriesDataManager _dataManager;
  Map<String, List<FlSpot>> _signalSpots = {};
  Map<String, Map<double, double>> _originalValues =
      {}; // signal -> x -> original value
  double _minY = 0;
  double _maxY = 100;
  StreamSubscription? _dataSubscription;
  final Map<String, DateTime> _lastDataTimestamps = {};

  // Update throttling - configurable from settings
  Timer? _updateTimer;
  bool _pendingUpdate = false;
  bool _isComputing = false;

  // Zoom and pan state
  double _zoomLevel = 1.0;
  double _timeOffset = 0.0; // Offset from the right edge in milliseconds
  static const double _minZoom = 0.1;
  static const double _maxZoom = 10.0;

  // Absolute time system - use wall clock time for all coordinates
  static final DateTime _absoluteEpoch = DateTime(2020, 1, 1);

  // Layout constants
  static const double _leftTitleWidth = 70.0;
  static const double _bottomTitleHeight = 30.0;
  static const double _borderWidth = 1.0;

  // Pause state tracking - store actual timestamps, not coordinates
  DateTime? _pauseWindowStartTime;

  // Drag selection state
  Offset? _dragStart;
  Offset? _dragEnd;
  bool _isDragging = false;

  // Hover state
  final Map<String, double> _hoveredValues = {};
  List<ShowingTooltipIndicators> _showingTooltipIndicators = [];

  @override
  void initState() {
    super.initState();
    // Get dataManager from Riverpod provider
    _dataManager = ref.read(timeSeriesDataManagerProvider);
    _initializeData();
    _setupDataListener();
  }

  @override
  void didUpdateWidget(InteractivePlot oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset timestamp tracking if signals have changed
    if (_hasSignalsChanged(oldWidget.configuration, widget.configuration)) {
      _lastDataTimestamps.clear();
      _initializeData();
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  bool _hasSignalsChanged(
    PlotConfiguration oldConfig,
    PlotConfiguration newConfig,
  ) {
    final oldSignals = oldConfig.yAxis.signals.map((s) => s.fieldKey).toList();
    final newSignals = newConfig.yAxis.signals.map((s) => s.fieldKey).toList();

    if (oldSignals.length != newSignals.length) return true;

    final oldSet = oldSignals.toSet();
    final newSet = newSignals.toSet();
    return oldSet.length != newSet.length || !oldSet.containsAll(newSet);
  }

  void _initializeData() {
    // If we start paused, immediately capture pause window
    if (_dataManager.isPaused && _pauseWindowStartTime == null) {
      final now = DateTime.now();
      _pauseWindowStartTime = now.subtract(widget.configuration.timeWindow);
    }

    if (widget.configuration.yAxis.hasData) {
      _updatePlotData();
    }
  }

  void _setupDataListener() {
    bool wasPaused = _dataManager.isPaused;

    _dataSubscription = _dataManager.dataStream.listen(
      (_) {
        if (mounted && widget.configuration.yAxis.hasData) {
          final isPaused = _dataManager.isPaused;

          // Handle pause state changes
          if (wasPaused != isPaused) {
            if (isPaused) {
              // Just paused - capture FRESH window immediately
              final now = DateTime.now();
              setState(() {
                _pauseWindowStartTime = now.subtract(
                  widget.configuration.timeWindow,
                );
              });
            } else {
              // Resumed - don't clear pause state yet, wait for data
              // Force immediate update to jump to current time
              _scheduleUpdate();
            }
          }
          wasPaused = isPaused;

          _scheduleUpdate();
        }
      },
      onError: (error) {
        // Retry subscription after error
        _retrySubscription();
      },
      onDone: () {
        // Stream closed, retry subscription
        _retrySubscription();
      },
      cancelOnError: false, // Keep listening even after errors
    );
  }

  void _retrySubscription() {
    // Cancel existing subscription
    _dataSubscription?.cancel();
    _dataSubscription = null;

    // Retry after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _setupDataListener();
      }
    });
  }

  void _scheduleUpdate() {
    _pendingUpdate = true;
    final performance = ref.read(settingsManagerProvider).performance;

    if (_updateTimer == null || !_updateTimer!.isActive) {
      final updateInterval = Duration(milliseconds: performance.updateInterval);
      _updateTimer = Timer(updateInterval, () {
        if (mounted && _pendingUpdate) {
          _pendingUpdate = false;

          // Use addPostFrameCallback to ensure smooth rendering
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updatePlotData();
            }
          });
        }
      });
    }
  }

  Future<void> _updatePlotData() async {
    if (!widget.configuration.yAxis.hasVisibleSignals || _isComputing) return;

    final timeWindow = _calculateTimeWindow();

    // Prepare input for isolate
    final input = ComputeInput(
      visibleSignals: widget.configuration.yAxis.visibleSignals,
      allData: _getAllDataForSignals(widget.configuration.yAxis.visibleSignals),
      timeWindow: timeWindow,
      scalingMode: widget.configuration.yAxis.scalingMode,
      performance: ref.read(settingsManagerProvider).performance,
      absoluteEpoch: _absoluteEpoch,
      lastDataTimestamps: Map.from(_lastDataTimestamps),
    );

    _isComputing = true;

    try {
      final result = await compute(processDataInIsolate, input);

      if (!mounted) return;

      if (!result.hasNewData && _signalSpots.isNotEmpty) {
        return;
      }

      // Update timestamps for new data detection
      _lastDataTimestamps.addAll(result.latestTimestamps);

      setState(() {
        _signalSpots = result.signalSpots;
        _originalValues = result.originalValues;

        // If we were paused and now have new data (resuming), clear pause state
        if (!_dataManager.isPaused && _pauseWindowStartTime != null) {
          _zoomLevel = 1.0;
          _timeOffset = 0.0;
          _pauseWindowStartTime = null;
        }
      });

      _recalculateYBounds();
    } finally {
      if (mounted) {
        _isComputing = false;
        // If another update was requested while we were computing, schedule it now
        if (_pendingUpdate) {
          _scheduleUpdate();
        }
      }
    }
  }

  Map<String, List<TimeSeriesPoint>> _getAllDataForSignals(
    List<PlotSignalConfiguration> signals,
  ) {
    final data = <String, List<TimeSeriesPoint>>{};
    for (final signal in signals) {
      data[signal.fieldKey] = _dataManager.getFieldData(
        signal.messageType,
        signal.fieldName,
      );
    }
    return data;
  }

  TimeWindow _calculateTimeWindow() {
    final now = DateTime.now();

    // Data filtering cutoff - how far back to include data
    final cutoff = now.subtract(widget.configuration.timeWindow);

    // Use absolute epoch for all coordinate calculations
    return TimeWindow(startTime: _absoluteEpoch, cutoff: cutoff);
  }

  YAxisBounds _calculateYAxisBounds(List<double> allValues) {
    if (allValues.isEmpty) {
      return YAxisBounds(
        minY: widget.configuration.yAxis.minY ?? 0,
        maxY: widget.configuration.yAxis.maxY ?? 100,
      );
    }

    switch (widget.configuration.yAxis.scalingMode) {
      case ScalingMode.autoScale:
        return _calculateAutoScaleBounds(allValues);
      case ScalingMode.independent:
        return YAxisBounds(minY: 0, maxY: 100);
      case ScalingMode.unified:
        return _calculateUnifiedBounds(allValues);
    }
  }

  YAxisBounds _calculateAutoScaleBounds(List<double> values) {
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);

    final range = maxY - minY;
    if (range > 0) {
      minY -= range * 0.1;
      maxY += range * 0.1;
    } else {
      minY -= 1;
      maxY += 1;
    }

    return YAxisBounds(minY: minY, maxY: maxY);
  }

  YAxisBounds _calculateUnifiedBounds(List<double> values) {
    final minY =
        widget.configuration.yAxis.minY ??
        values.reduce((a, b) => a < b ? a : b);
    final maxY =
        widget.configuration.yAxis.maxY ??
        values.reduce((a, b) => a > b ? a : b);
    return YAxisBounds(minY: minY, maxY: maxY);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAxisTap,
      onSecondaryTap: () {
        if (_dataManager.isPaused && _zoomLevel > 1.0) {
          setState(() {
            _zoomLevel = 1.0;
            _timeOffset = 0.0;
          });
          _recalculateYBounds();
        }
      },
      onSecondaryTapUp: widget.onClearAxis != null
          ? (_) => _showContextMenu()
          : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isAxisSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: widget.isAxisSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 4),
                Expanded(child: _buildChart()),
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
            widget.configuration.yAxis.hasData ? '' : 'Click to select signals',
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
              ? CompactPlotLegend(signals: widget.configuration.yAxis.signals)
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.5),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return Stack(
          children: [
            Listener(
              onPointerDown: (event) {
                if (_dataManager.isPaused) {
                  final localX = event.localPosition.dx;
                  // Clamp to chart area (inside border)
                  final clampedX = localX.clamp(
                    _leftTitleWidth + _borderWidth,
                    maxWidth - _borderWidth,
                  );

                  setState(() {
                    _dragStart = Offset(clampedX, event.localPosition.dy);
                    _dragEnd = Offset(clampedX, event.localPosition.dy);
                    _isDragging = true;
                  });
                }
              },
              onPointerMove: (event) {
                if (_isDragging) {
                  final localX = event.localPosition.dx;
                  final clampedX = localX.clamp(
                    _leftTitleWidth + _borderWidth,
                    maxWidth - _borderWidth,
                  );

                  setState(() {
                    _dragEnd = Offset(clampedX, event.localPosition.dy);
                  });
                }
              },
              onPointerUp: (event) {
                if (_isDragging) {
                  _handleDragZoom(maxWidth);
                }
              },
              child: LineChart(
                LineChartData(
                  clipData: FlClipData.all(),
                  lineTouchData: LineTouchData(
                    enabled:
                        _dataManager.isPaused &&
                        !_isDragging, // Disable when dragging
                    handleBuiltInTouches:
                        !_isDragging, // Don't handle built-in touches when dragging
                    touchSpotThreshold:
                        50, // Increase threshold for sticky feel
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      if (!mounted) return;

                      if (event is FlPointerHoverEvent) {
                        if (response?.lineBarSpots != null &&
                            response!.lineBarSpots!.isNotEmpty) {
                          setState(() {
                            _hoveredValues.clear();

                            // Collect values from all signals at this X position
                            for (final spot in response.lineBarSpots!) {
                              final barIndex = spot.barIndex;
                              if (barIndex <
                                  widget
                                      .configuration
                                      .yAxis
                                      .visibleSignals
                                      .length) {
                                final signal = widget
                                    .configuration
                                    .yAxis
                                    .visibleSignals[barIndex];
                                _hoveredValues[signal.fieldKey] = spot.y;
                              }
                            }

                            // Update showing tooltip indicators
                            _showingTooltipIndicators = response.lineBarSpots!
                                .map((spot) {
                                  return ShowingTooltipIndicators([
                                    LineBarSpot(spot.bar, spot.barIndex, spot),
                                  ]);
                                })
                                .toList();
                          });
                        }
                      } else if (event is FlPointerExitEvent) {
                        // Don't clear hovered values or indicators to make it "sticky"
                        // Only clear if we start dragging or explicitly clear
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.95),
                      tooltipBorder: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      maxContentWidth: 300,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot spot) {
                          final barIndex = spot.barIndex;
                          if (barIndex >=
                              widget
                                  .configuration
                                  .yAxis
                                  .visibleSignals
                                  .length) {
                            return null;
                          }

                          final signal = widget
                              .configuration
                              .yAxis
                              .visibleSignals[barIndex];

                          // Get original value from stored map
                          final originalValue =
                              _originalValues[signal.fieldKey]?[spot.x];
                          final displayValue =
                              originalValue?.toStringAsFixed(2) ??
                              spot.y.toStringAsFixed(2);

                          final fontSize =
                              14.0 * ref.read(settingsManagerProvider).appearance.uiScale;

                          return LineTooltipItem(
                            '${signal.effectiveDisplayName}: $displayValue',
                            TextStyle(
                              color: signal.color,
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              fontFamily:
                                  'RobotoMono', // Use monospaced font for numbers
                            ),
                          );
                        }).toList();
                      },
                    ),
                    getTouchedSpotIndicator:
                        (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    strokeWidth: 2,
                                    strokeColor: barData.color!,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (_maxY - _minY) / 5,
                    verticalInterval:
                        (widget.configuration.timeWindow.inMilliseconds /
                            _zoomLevel) /
                        5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                        reservedSize: 0,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                        reservedSize: 0,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _bottomTitleHeight,
                        interval:
                            widget.configuration.timeWindow.inMilliseconds / 4,
                        getTitlesWidget: (value, meta) =>
                            _buildTimeLabel(value),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (_maxY - _minY) / 4,
                        reservedSize: _leftTitleWidth,
                        getTitlesWidget: (value, meta) =>
                            _buildValueLabel(value),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      width: _borderWidth,
                    ),
                  ),
                  minX: _calculateMinX(),
                  maxX: _calculateMaxX(),
                  minY: _minY,
                  maxY: _maxY,
                  lineBarsData: _buildLineChartBars(),
                  showingTooltipIndicators: _showingTooltipIndicators,
                ),
                // Animations disabled for performance
                duration: Duration.zero,
              ),
            ),
            // Legend overlay
            if (widget.configuration.yAxis.visibleSignals.isNotEmpty)
              PlotLegendOverlay(
                signals: widget.configuration.yAxis.signals,
                showValues: false,
                currentValues: const {},
                alignment: Alignment.topRight,
              ),
            // Drag selection rectangle
            if (_isDragging && _dragStart != null && _dragEnd != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: SelectionRectanglePainter(
                    start: _dragStart!,
                    end: _dragEnd!,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
          ],
        );
      },
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
            isCurved: true,
            curveSmoothness: 0.1,
            color: signal.color,
            barWidth: signal.lineWidth,
            dotData: FlDotData(show: signal.showDots),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  signal.color.withValues(alpha: 0.2),
                  signal.color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        );
      }
    }

    return lineBars;
  }

  Widget _buildTimeLabel(double value) {
    // Convert absolute X coordinate back to actual timestamp
    final timestamp = _absoluteEpoch.add(Duration(milliseconds: value.round()));

    // Show actual wall clock time when data was received
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';

    return Text(timeStr, style: Theme.of(context).textTheme.bodySmall);
  }

  Widget _buildValueLabel(double value) {
    return Text(
      value.toStringAsFixed(1),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  void _showContextMenu() {
    if (widget.onClearAxis == null || !widget.configuration.yAxis.hasData) {
      return;
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        PopupMenuItem(
          onTap: widget.onClearAxis,
          child: const Row(
            children: [Icon(Icons.clear), SizedBox(width: 8), Text('Clear')],
          ),
        ),
      ],
    );
  }

  double _calculateMinX() {
    if (_dataManager.isPaused && _pauseWindowStartTime != null) {
      // When paused, use frozen timestamps (NO DateTime.now() calls)
      final pauseStartX = _pauseWindowStartTime!
          .difference(_absoluteEpoch)
          .inMilliseconds
          .toDouble();
      return pauseStartX + _timeOffset;
    }

    // When not paused, show sliding window ending at current time
    final now = DateTime.now();
    final currentX = now.difference(_absoluteEpoch).inMilliseconds.toDouble();
    return currentX - widget.configuration.timeWindow.inMilliseconds.toDouble();
  }

  double _calculateMaxX() {
    if (_dataManager.isPaused && _pauseWindowStartTime != null) {
      // When paused, use frozen timestamps (NO DateTime.now() calls)
      final visibleDuration =
          widget.configuration.timeWindow.inMilliseconds.toDouble() /
          _zoomLevel;
      final pauseStartX = _pauseWindowStartTime!
          .difference(_absoluteEpoch)
          .inMilliseconds
          .toDouble();
      return pauseStartX + _timeOffset + visibleDuration;
    }

    // When not paused, right edge tracks current time
    final now = DateTime.now();
    return now.difference(_absoluteEpoch).inMilliseconds.toDouble();
  }

  void _handleDragZoom(double maxWidth) {
    if (_dragStart == null || _dragEnd == null || !_isDragging) return;

    // Chart width excludes titles and borders
    final chartWidth = maxWidth - _leftTitleWidth - (_borderWidth * 2);
    if (chartWidth <= 0) return;

    // Calculate pixel range relative to chart area (start after left border)
    final startPixel = _dragStart!.dx - (_leftTitleWidth + _borderWidth);
    final endPixel = _dragEnd!.dx - (_leftTitleWidth + _borderWidth);

    // Ensure we have a meaningful selection (e.g. > 10 pixels)
    if ((endPixel - startPixel).abs() < 10) {
      setState(() {
        _isDragging = false;
        _dragStart = null;
        _dragEnd = null;
      });
      return;
    }

    // Calculate fractions of the current view
    final startFraction = (math.min(startPixel, endPixel) / chartWidth).clamp(
      0.0,
      1.0,
    );
    final endFraction = (math.max(startPixel, endPixel) / chartWidth).clamp(
      0.0,
      1.0,
    );

    // Calculate current visible duration and range
    final currentVisibleDuration =
        widget.configuration.timeWindow.inMilliseconds.toDouble() / _zoomLevel;
    final currentMinX = _calculateMinX();

    // Calculate new time range
    final newMinX = currentMinX + startFraction * currentVisibleDuration;
    final newMaxX = currentMinX + endFraction * currentVisibleDuration;
    final newVisibleDuration = newMaxX - newMinX;

    // Calculate new zoom level
    final totalDuration = widget.configuration.timeWindow.inMilliseconds
        .toDouble();
    final newZoomLevel = (totalDuration / newVisibleDuration).clamp(
      _minZoom,
      _maxZoom,
    );

    // Calculate new offset
    // newMinX = pauseStartX + newTimeOffset
    // newTimeOffset = newMinX - pauseStartX
    final pauseStartX = _pauseWindowStartTime!
        .difference(_absoluteEpoch)
        .inMilliseconds
        .toDouble();
    final newOffset = newMinX - pauseStartX;

    setState(() {
      _zoomLevel = newZoomLevel;
      _timeOffset = newOffset.clamp(0.0, totalDuration - newVisibleDuration);
      _isDragging = false;
      _dragStart = null;
      _dragEnd = null;
    });

    _recalculateYBounds();
  }

  void _recalculateYBounds() {
    if (_signalSpots.isEmpty) return;

    final minX = _calculateMinX();
    final maxX = _calculateMaxX();
    final visibleValues = <double>[];

    for (final spots in _signalSpots.values) {
      for (final spot in spots) {
        if (spot.x >= minX && spot.x <= maxX) {
          visibleValues.add(spot.y);
        }
      }
    }

    // If no points visible (e.g. zoomed into empty space), use all values or keep current
    if (visibleValues.isEmpty) return;

    final yAxisBounds = _calculateYAxisBounds(visibleValues);
    setState(() {
      _minY = yAxisBounds.minY;
      _maxY = yAxisBounds.maxY;
    });
  }
}

class SelectionRectanglePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  SelectionRectanglePainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(
      Offset(start.dx, 0),
      Offset(end.dx, size.height),
    );

    // Draw premium gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.05),
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.05),
      ],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Draw vertical border lines with gradient fade
    final borderGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.0),
      ],
    );

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(rect.topLeft, rect.bottomLeft, borderPaint);
    canvas.drawLine(rect.topRight, rect.bottomRight, borderPaint);
  }

  @override
  bool shouldRepaint(SelectionRectanglePainter oldDelegate) {
    return start != oldDelegate.start || end != oldDelegate.end;
  }
}
