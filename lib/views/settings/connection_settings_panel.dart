import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settings_manager.dart';

class ConnectionSettingsPanel extends StatefulWidget {
  final SettingsManager settingsManager;

  const ConnectionSettingsPanel({
    super.key,
    required this.settingsManager,
  });

  @override
  State<ConnectionSettingsPanel> createState() => _ConnectionSettingsPanelState();
}

class _ConnectionSettingsPanelState extends State<ConnectionSettingsPanel> {
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final connection = widget.settingsManager.connection;
    _hostController = TextEditingController(text: connection.mavlinkHost);
    _portController = TextEditingController(text: connection.mavlinkPort.toString());
    
    widget.settingsManager.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        final connection = widget.settingsManager.connection;
        _hostController.text = connection.mavlinkHost;
        _portController.text = connection.mavlinkPort.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.settingsManager.connection;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'MAVLink Connection',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Use spoof mode'),
                  subtitle: const Text('Generate test data instead of connecting to real MAVLink'),
                  value: connection.useSpoofMode,
                  onChanged: (value) {
                    widget.settingsManager.updateConnectionMode(value);
                  },
                ),
                const Divider(),
                ListTile(
                  dense: true,
                  enabled: !connection.useSpoofMode,
                  title: const Text('MAVLink host'),
                  subtitle: const Text('IP address or hostname of MAVLink source'),
                  trailing: SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _hostController,
                      enabled: !connection.useSpoofMode,
                      style: Theme.of(context).textTheme.bodySmall,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          widget.settingsManager.updateMavlinkConnection(
                            value,
                            connection.mavlinkPort,
                          );
                        }
                      },
                    ),
                  ),
                ),
                ListTile(
                  dense: true,
                  enabled: !connection.useSpoofMode,
                  title: const Text('MAVLink port'),
                  subtitle: const Text('UDP port number for MAVLink communication'),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _portController,
                      enabled: !connection.useSpoofMode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Theme.of(context).textTheme.bodySmall,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (value) {
                        final port = int.tryParse(value);
                        if (port != null && port > 0 && port <= 65535) {
                          widget.settingsManager.updateMavlinkConnection(
                            connection.mavlinkHost,
                            port,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Startup Behavior',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Auto-start monitoring'),
                  subtitle: const Text('Begin monitoring MAVLink messages on startup'),
                  value: connection.autoStartMonitor,
                  onChanged: (value) {
                    widget.settingsManager.updateAutoStartMonitor(value);
                  },
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Start paused'),
                  subtitle: const Text('Begin with data collection paused'),
                  value: connection.isPaused,
                  onChanged: (value) {
                    widget.settingsManager.updatePauseState(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}