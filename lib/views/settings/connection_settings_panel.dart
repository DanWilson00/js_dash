import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/action_providers.dart';
import '../../services/settings_manager.dart';
import '../../core/connection_config.dart';

class ConnectionSettingsPanel extends ConsumerStatefulWidget {
  final SettingsManager settingsManager;

  const ConnectionSettingsPanel({
    super.key,
    required this.settingsManager,
  });

  @override
  ConsumerState<ConnectionSettingsPanel> createState() => _ConnectionSettingsPanelState();
}

class _ConnectionSettingsPanelState extends ConsumerState<ConnectionSettingsPanel> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _serialPortController;
  late TextEditingController _spoofSystemIdController;
  late TextEditingController _spoofComponentIdController;
  
  // Common baud rates for MAVLink and serial communication
  static const List<int> _baudRates = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    500000,
    576000,
    921600,
    1000000,
  ];

  @override
  void initState() {
    super.initState();
    final connection = widget.settingsManager.connection;
    _hostController = TextEditingController(text: connection.mavlinkHost);
    _portController = TextEditingController(text: connection.mavlinkPort.toString());
    _serialPortController = TextEditingController(text: connection.serialPort);
    _spoofSystemIdController = TextEditingController(text: connection.spoofSystemId.toString());
    _spoofComponentIdController = TextEditingController(text: connection.spoofComponentId.toString());
    
    widget.settingsManager.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settingsManager.removeListener(_onSettingsChanged);
    _hostController.dispose();
    _portController.dispose();
    _serialPortController.dispose();
    _spoofSystemIdController.dispose();
    _spoofComponentIdController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {
        final connection = widget.settingsManager.connection;
        _hostController.text = connection.mavlinkHost;
        _portController.text = connection.mavlinkPort.toString();
        _serialPortController.text = connection.serialPort;
        _spoofSystemIdController.text = connection.spoofSystemId.toString();
        _spoofComponentIdController.text = connection.spoofComponentId.toString();
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
          // Spoofing Enable/Disable
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.bug_report, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Data Source',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Enable spoofing'),
                  subtitle: const Text('Use test data instead of real MAVLink connection'),
                  value: connection.enableSpoofing,
                  onChanged: (value) async {
                    // Disconnect current connection before changing mode
                    try {
                      final connectionActions = ref.read(connectionActionsProvider);
                      await connectionActions.disconnect();
                      
                      // Clear any existing data to prevent showing stale "connected" status
                      final dataActions = ref.read(dataActionsProvider);
                      dataActions.clearAllData();
                    } catch (e) {
                      // Continue with settings update even if disconnect fails
                    }
                    
                    // Update the setting
                    widget.settingsManager.updateConnectionMode(value);
                    
                    // Auto-start spoofing if enabled
                    if (value) {
                      try {
                        final connectionActions = ref.read(connectionActionsProvider);
                        final connection = widget.settingsManager.connection;
                        await connectionActions.connectWith(SpoofConnectionConfig(
                          systemId: connection.spoofSystemId,
                          componentId: connection.spoofComponentId,
                          baudRate: connection.spoofBaudRate,
                        ));
                      } catch (e) {
                        // Silently handle auto-start failures
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Real MAVLink Connection Settings (only when spoofing is disabled)
          if (!connection.enableSpoofing) ...[
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_input_antenna, size: 20),
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
                  ListTile(
                    dense: true,
                    title: const Text('Connection type'),
                    subtitle: const Text('How to connect to MAVLink source'),
                    trailing: DropdownButton<String>(
                      value: connection.connectionType,
                      items: const [
                        DropdownMenuItem(
                          value: 'udp',
                          child: Text('UDP'),
                        ),
                        DropdownMenuItem(
                          value: 'serial',
                          child: Text('Serial'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.settingsManager.updateConnectionType(value);
                        }
                      },
                    ),
                  ),
                  
                  const Divider(),
                  
                  // UDP Settings
                  if (connection.connectionType == 'udp') ...[
                    ListTile(
                      dense: true,
                      title: const Text('UDP host'),
                      subtitle: const Text('IP address or hostname of MAVLink source'),
                      trailing: SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _hostController,
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
                      title: const Text('UDP port'),
                      subtitle: const Text('UDP port number for MAVLink communication'),
                      trailing: SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _portController,
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
                  
                  // Serial Settings
                  if (connection.connectionType == 'serial') ...[
                    ListTile(
                      dense: true,
                      title: const Text('Serial port'),
                      subtitle: const Text('Serial port device path (e.g., /dev/ttyUSB0)'),
                      trailing: SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _serialPortController,
                          style: Theme.of(context).textTheme.bodySmall,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              widget.settingsManager.updateSerialConnection(
                                value,
                                connection.serialBaudRate,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('Baud rate'),
                      subtitle: const Text('Serial communication speed'),
                      trailing: DropdownButton<int>(
                        value: _baudRates.contains(connection.serialBaudRate) 
                            ? connection.serialBaudRate 
                            : _baudRates.first,
                        items: _baudRates.map((baudRate) => DropdownMenuItem(
                          value: baudRate,
                          child: Text('$baudRate bps'),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            widget.settingsManager.updateSerialConnection(
                              connection.serialPort,
                              value,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Spoofing Settings (only when spoofing is enabled)
          if (connection.enableSpoofing) ...[
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.science, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Spoofing Configuration',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Removed spoof mode selection - only USB Serial spoofing available
                  
                  const Divider(),
                  
                  ListTile(
                    dense: true,
                    title: const Text('System ID'),
                    subtitle: const Text('MAVLink system identifier'),
                    trailing: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _spoofSystemIdController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: Theme.of(context).textTheme.bodySmall,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final systemId = int.tryParse(value);
                          if (systemId != null && systemId > 0 && systemId <= 255) {
                            widget.settingsManager.updateSpoofingConfig(spoofSystemId: systemId);
                          }
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('Component ID'),
                    subtitle: const Text('MAVLink component identifier'),
                    trailing: SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _spoofComponentIdController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: Theme.of(context).textTheme.bodySmall,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final componentId = int.tryParse(value);
                          if (componentId != null && componentId > 0 && componentId <= 255) {
                            widget.settingsManager.updateSpoofingConfig(spoofComponentId: componentId);
                          }
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('Spoof baud rate'),
                    subtitle: const Text('Simulated serial communication speed'),
                    trailing: DropdownButton<int>(
                      value: _baudRates.contains(connection.spoofBaudRate) 
                          ? connection.spoofBaudRate 
                          : _baudRates.first,
                      items: _baudRates.map((baudRate) => DropdownMenuItem(
                        value: baudRate,
                        child: Text('$baudRate bps'),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          widget.settingsManager.updateSpoofingConfig(spoofBaudRate: value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // General Settings
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