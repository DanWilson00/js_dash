import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/app_settings.dart';
import '../../providers/action_providers.dart';
import '../../providers/service_providers.dart';
import '../../core/connection_config.dart';
import '../../services/dialect_discovery.dart';
import '../../services/platform/platform_capabilities.dart';
import '../../services/serial/serial_service.dart';
import '../../services/storage/user_dialect_manager.dart';

class ConnectionSettingsPanel extends ConsumerStatefulWidget {
  const ConnectionSettingsPanel({super.key});

  @override
  ConsumerState<ConnectionSettingsPanel> createState() => _ConnectionSettingsPanelState();
}

class _ConnectionSettingsPanelState extends ConsumerState<ConnectionSettingsPanel> {
  late TextEditingController _spoofSystemIdController;
  late TextEditingController _spoofComponentIdController;
  List<SerialPortInfo> _availablePorts = [];
  SerialPortInfo? _webSerialPort;
  final _platform = PlatformCapabilities.instance;
  final _userDialectManager = UserDialectManager();

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
    final settingsManager = ref.read(settingsManagerProvider);
    final connection = settingsManager.connection;
    _spoofSystemIdController = TextEditingController(text: connection.spoofSystemId.toString());
    _spoofComponentIdController = TextEditingController(text: connection.spoofComponentId.toString());
    _refreshPorts();
  }

  void _refreshPorts() {
    setState(() {
      _availablePorts = getAvailableSerialPorts();
    });
  }

  Future<void> _requestWebSerialPort() async {
    try {
      final portInfo = await requestSerialPort();
      if (portInfo != null) {
        setState(() {
          _webSerialPort = portInfo;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Serial port selected successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request serial port: $e')),
        );
      }
    }
  }

  Future<void> _connectWebSerial() async {
    if (_webSerialPort == null) {
      // Request port first
      await _requestWebSerialPort();
      if (_webSerialPort == null) return;
    }

    final settingsManager = ref.read(settingsManagerProvider);
    final connection = settingsManager.connection;

    try {
      final connectionActions = ref.read(connectionActionsProvider);
      await connectionActions.connectWith(WebSerialConnectionConfig(
        baudRate: connection.serialBaudRate,
        vendorId: _webSerialPort?.vendorId,
        productId: _webSerialPort?.productId,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  void _showRestartRequiredDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _importXmlDialect() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
        dialogTitle: 'Select MAVLink XML Dialect',
      );

      if (result != null && result.files.single.path != null) {
        final xmlPath = result.files.single.path!;
        final connectionActions = ref.read(connectionActionsProvider);

        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importing XML dialect...')),
          );
        }

        final dialectName = await connectionActions.importXmlDialect(xmlPath);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          // Force rebuild to refresh dialect list
          setState(() {});
          _showRestartRequiredDialog(
            'Dialect "$dialectName" imported successfully.\n\n'
            'Please restart the app to use the new dialect.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import dialect: $e')),
        );
      }
    }
  }

  Future<void> _reloadDialect(String dialectName) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reloading dialect from XML...')),
        );
      }

      final connectionActions = ref.read(connectionActionsProvider);
      await connectionActions.reloadUserDialect(dialectName);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Force rebuild
        setState(() {});
        _showRestartRequiredDialog(
          'Dialect "$dialectName" reloaded from XML.\n\n'
          'Please restart the app for changes to take effect.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reload dialect: $e')),
        );
      }
    }
  }

  void _changeDialect(String newDialect) {
    final connectionActions = ref.read(connectionActionsProvider);
    final changed = connectionActions.changeDialect(newDialect);
    if (changed) {
      _showRestartRequiredDialog(
        'Dialect changed to "$newDialect".\n\n'
        'Please restart the app for changes to take effect.',
      );
    }
  }

  @override
  void dispose() {
    _spoofSystemIdController.dispose();
    _spoofComponentIdController.dispose();
    super.dispose();
  }

  void _syncControllersIfNeeded(ConnectionSettings connection) {
    // Only update if different to avoid cursor jumping during user input
    if (_spoofSystemIdController.text != connection.spoofSystemId.toString()) {
      _spoofSystemIdController.text = connection.spoofSystemId.toString();
    }
    if (_spoofComponentIdController.text != connection.spoofComponentId.toString()) {
      _spoofComponentIdController.text = connection.spoofComponentId.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsManager = ref.watch(settingsManagerProvider);
    final connection = settingsManager.connection;

    // Sync controllers with settings (replaces listener pattern)
    _syncControllersIfNeeded(connection);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MAVLink Dialect Selection
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.code, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'MAVLink Protocol',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<List<DialectInfo>>(
                  future: DialectDiscovery.getAvailableDialectsInfo(),
                  builder: (context, snapshot) {
                    final dialects = snapshot.data ?? [const DialectInfo(name: 'common', isUserDialect: false)];
                    final currentDialect = connection.mavlinkDialect;
                    final currentInfo = dialects.firstWhere(
                      (d) => d.name == currentDialect,
                      orElse: () => dialects.first,
                    );

                    return ListTile(
                      dense: true,
                      title: const Text('Dialect'),
                      subtitle: const Text('MAVLink message definitions to use'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: dialects.any((d) => d.name == currentDialect) ? currentDialect : dialects.first.name,
                            items: dialects.map((info) => DropdownMenuItem(
                              value: info.name,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(info.name),
                                  if (info.isUserDialect) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.person, size: 14, color: Theme.of(context).colorScheme.primary),
                                  ],
                                ],
                              ),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null && value != currentDialect) {
                                _changeDialect(value);
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          // Reload button for user dialects
                          if (currentInfo.isUserDialect && currentInfo.xmlSourcePath != null)
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: 'Reload from XML source',
                              onPressed: () => _reloadDialect(currentDialect),
                            ),
                          // Import XML button (desktop only)
                          if (_userDialectManager.isSupported)
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              tooltip: 'Import XML dialect',
                              onPressed: _importXmlDialect,
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.add, size: 20, color: Colors.grey.withValues(alpha: 0.5)),
                              tooltip: 'XML import not available on web',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('XML dialect import is not available on web. Use bundled dialects.'),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
                    settingsManager.updateConnectionMode(value);

                    // Auto-start connection based on new mode
                    if (value) {
                      // Spoofing enabled - connect to spoof
                      try {
                        final connectionActions = ref.read(connectionActionsProvider);
                        final conn = settingsManager.connection;
                        await connectionActions.connectWith(SpoofConnectionConfig(
                          systemId: conn.spoofSystemId,
                          componentId: conn.spoofComponentId,
                          baudRate: conn.spoofBaudRate,
                        ));
                      } catch (e) {
                        // Silently handle auto-start failures
                      }
                    } else {
                      // Spoofing disabled - connect to serial if port selected and exists
                      try {
                        final conn = settingsManager.connection;
                        final portExists = _availablePorts.any((p) => p.portName == conn.serialPort);
                        if (conn.serialPort.isNotEmpty && portExists) {
                          final connectionActions = ref.read(connectionActionsProvider);
                          await connectionActions.connectWith(SerialConnectionConfig(
                            port: conn.serialPort,
                            baudRate: conn.serialBaudRate,
                          ));
                        }
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

          // Serial Connection Settings (only when spoofing is disabled)
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
                          'Serial Connection',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_platform.isWeb) ...[
                          const Spacer(),
                          Chip(
                            label: Text(
                              _platform.supportsWebSerial ? 'Web Serial' : 'Not Supported',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: _platform.supportsWebSerial
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Web Serial UI (Chrome/Edge)
                  if (_platform.isWeb && _platform.supportsWebSerial) ...[
                    ListTile(
                      dense: true,
                      title: const Text('Serial port'),
                      subtitle: Text(_webSerialPort != null
                          ? 'Port selected (VID: ${_webSerialPort!.vendorId ?? "N/A"})'
                          : 'Click to request serial port access'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _requestWebSerialPort,
                            icon: const Icon(Icons.usb, size: 18),
                            label: Text(_webSerialPort == null ? 'Select Port' : 'Change Port'),
                          ),
                          if (_webSerialPort != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _connectWebSerial,
                              child: const Text('Connect'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]
                  // Web without Serial support (Firefox/Safari)
                  else if (_platform.isWeb && !_platform.supportsWebSerial) ...[
                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text('Serial not available'),
                      subtitle: Text(
                        'Web Serial API is not supported in this browser. '
                        'Use Chrome or Edge for serial connection, or enable spoofing for demo mode.',
                      ),
                    ),
                  ]
                  // Desktop Serial UI
                  else ...[
                    ListTile(
                      dense: true,
                      title: const Text('Serial port'),
                      subtitle: Text(_availablePorts.isEmpty
                          ? 'No serial ports found'
                          : 'Select serial port device'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 150,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _availablePorts.any((p) => p.portName == connection.serialPort)
                                  ? connection.serialPort
                                  : null,
                              hint: const Text('Select port'),
                              items: _availablePorts.map((portInfo) => DropdownMenuItem(
                                value: portInfo.portName,
                                child: Text(portInfo.description ?? portInfo.portName),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  settingsManager.updateSerialConnection(
                                    value,
                                    connection.serialBaudRate,
                                  );
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh ports',
                            onPressed: _refreshPorts,
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Baud rate (shown for both desktop and web serial)
                  if (!_platform.isWeb || _platform.supportsWebSerial)
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
                            settingsManager.updateSerialConnection(
                              connection.serialPort,
                              value,
                            );
                          }
                        },
                      ),
                    ),
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
                            settingsManager.updateSpoofingConfig(spoofSystemId: systemId);
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
                            settingsManager.updateSpoofingConfig(spoofComponentId: componentId);
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
                          settingsManager.updateSpoofingConfig(spoofBaudRate: value);
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
                    settingsManager.updateAutoStartMonitor(value);
                  },
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Start paused'),
                  subtitle: const Text('Begin with data collection paused'),
                  value: connection.isPaused,
                  onChanged: (value) {
                    settingsManager.updatePauseState(value);
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
