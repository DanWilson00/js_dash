import 'package:flutter/material.dart';
import '../../services/settings_manager.dart';
import 'performance_settings_panel.dart';
import 'connection_settings_panel.dart';
import 'display_settings_panel.dart';
import 'advanced_settings_panel.dart';

class SettingsDialog extends StatefulWidget {
  final SettingsManager settingsManager;

  const SettingsDialog({
    super.key,
    required this.settingsManager,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  PerformanceSettingsPanel(settingsManager: widget.settingsManager),
                  ConnectionSettingsPanel(settingsManager: widget.settingsManager),
                  DisplaySettingsPanel(settingsManager: widget.settingsManager),
                  AdvancedSettingsPanel(settingsManager: widget.settingsManager),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.settings,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(
            icon: Icon(Icons.speed),
            text: 'Performance',
          ),
          Tab(
            icon: Icon(Icons.wifi),
            text: 'Connection',
          ),
          Tab(
            icon: Icon(Icons.monitor),
            text: 'Display',
          ),
          Tab(
            icon: Icon(Icons.build),
            text: 'Advanced',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Changes apply immediately and are saved automatically',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}