import 'package:flutter/material.dart';
import 'realtime_data_display.dart';
import 'jetshark_dashboard.dart';
import '../services/mavlink_spoof_service.dart';

class MainNavigation extends StatefulWidget {
  final bool autoStartMonitor;
  
  const MainNavigation({super.key, this.autoStartMonitor = true});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final MavlinkSpoofService _spoofService = MavlinkSpoofService();

  @override
  void initState() {
    super.initState();
    if (widget.autoStartMonitor) {
      _spoofService.startSpoofing();
    }
  }

  @override
  void dispose() {
    _spoofService.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RealtimeDataDisplay(autoStartMonitor: widget.autoStartMonitor),
      const JetsharkDashboard(),
    ];

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Allow tapping anywhere on Jetshark dashboard to go back to telemetry
          if (_selectedIndex == 1) {
            _onItemTapped(0);
          }
        },
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: _selectedIndex == 1 ? null : _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00FFFF).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF00FFFF),
        unselectedItemColor: const Color(0xFF666666),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w300,
          letterSpacing: 1.0,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            label: 'TELEMETRY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'JETSHARK',
          ),
        ],
      ),
    );
  }
}