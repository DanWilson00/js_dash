import 'package:flutter/material.dart';
import 'dashboard_container.dart';
import 'configs/jetshark_config.dart';
import 'data/data_provider.dart';
import 'data/mavlink_data_provider.dart' as dashboard_mavlink;
import 'widgets/widget_factory.dart';
import '../../services/mavlink_spoof_service.dart';

/// Refactored Jetshark Dashboard using modular architecture
class JetsharkDashboardV2 extends StatefulWidget {
  const JetsharkDashboardV2({Key? key}) : super(key: key);
  
  @override
  State<JetsharkDashboardV2> createState() => _JetsharkDashboardV2State();
}

class _JetsharkDashboardV2State extends State<JetsharkDashboardV2>
    with SingleTickerProviderStateMixin {
  late final MavlinkSpoofService _spoofService;
  late final DataProvider _dataProvider;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize widgets
    initializeStandardWidgets();
    
    // Setup services
    _spoofService = MavlinkSpoofService();
    _dataProvider = dashboard_mavlink.MavlinkDataProvider(_spoofService);
    
    // Start data spoofing
    if (!_spoofService.isRunning) {
      _spoofService.startSpoofing(interval: const Duration(milliseconds: 50));
    }
    
    // Setup animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _dataProvider.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0a0a0a),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          
          // Dashboard content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  child: const Text(
                    'JETSHARK',
                    style: TextStyle(
                      color: Color(0xFF4a90e2),
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                
                // Dashboard
                Expanded(
                  child: DashboardContainer(
                    config: JetsharkDashboardConfig.main,
                    dataProvider: _dataProvider,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}