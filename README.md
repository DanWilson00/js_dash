# MAVLink Dashboard

A cross-platform Flutter application for real-time MAVLink telemetry visualization. Connect to ArduPilot, PX4, or any MAVLink-compatible autopilot to monitor vehicle telemetry.

## Features

- **Real-time Telemetry** - View live data from your vehicle with configurable plots and gauges
- **Interactive Map** - Track vehicle position with satellite imagery
- **Multi-dialect Support** - Load custom MAVLink XML dialects or use built-in definitions
- **Cross-platform** - Runs on Web (Chrome/Edge), Windows, and Linux
- **Web Serial** - Connect directly to serial devices from the browser (Chrome/Edge)
- **Spoof Mode** - Test the dashboard without hardware using simulated telemetry

## Quick Start

### Web (Hosted)
Visit the [live demo](https://danwilson00.github.io/js_dash/) - no installation required.

### Run Locally
```bash
# Clone the repository
git clone https://github.com/DanWilson00/js_dash.git
cd js_dash

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Or run on desktop
flutter run -d windows  # or linux
```

## Connecting to a Vehicle

1. **Serial Connection** (Desktop or Chrome/Edge with Web Serial)
   - Select your serial port and baud rate in Settings
   - Click Connect

2. **Spoof Mode** (Testing)
   - Enable "Spoofing" in Settings
   - Simulated MAVLink data will stream automatically

## Platform Support

| Platform | Serial | Web Serial | Status |
|----------|--------|------------|--------|
| Chrome/Edge | - | Yes | Full support |
| Firefox/Safari | - | No | Spoof mode only |
| Windows | Yes | - | Full support |
| Linux | Yes | - | Full support |

## Custom Dialects

Import your own MAVLink XML dialect files:
- **Desktop**: Click the + button and select your XML file
- **Web**: Select your main XML and any included files (e.g., common.xml)

## Development

```bash
flutter test      # Run tests
flutter analyze   # Static analysis
flutter build web # Build for web
```

## License

MIT
