# Modular Dashboard

The Dashboard has been refactored into modular, configurable components while maintaining **identical** look, feel, and functionality.

## File Structure

```
lib/views/dashboard/
├── dashboard_config.dart         # Single configuration point
├── main_dashboard.dart           # Main dashboard assembly
├── ambient_lighting.dart         # Background lighting effects
├── dashboard_branding.dart       # Top branding component
├── rpm_gauge.dart               # Central RPM gauge with speed
├── wing_indicator.dart          # Wing position indicators
├── hud_display.dart            # Alternative HUD display
```

## Configuration

All dashboard configuration is centralized in `dashboard_config.dart`:

### Layout Configuration
- **Flex values**: Control relative sizes of left wing (2), center gauge (4), right wing (2)
- **Gauge sizing**: Responsive sizing based on screen dimensions
- **Branding**: Height, font size, letter spacing calculations

### Visual Configuration
- **Colors**: Background, gradients, accent colors
- **Animation durations**: RPM (800ms), startup (1500ms), pulse (3000ms)
- **Update settings**: 50ms intervals, 8% smoothing factor

### Data Configuration
- **Speed conversion**: m/s to knots (1.94384 factor)
- **RPM range**: 0-7000 with animation threshold of 5 RPM
- **Wing angles**: ±20 degrees with normalization

## Component Structure

### Main Dashboard (`main_dashboard.dart`)
- Assembles all components
- Manages data updates and animations
- Maintains exact original functionality

### Individual Components
1. **AmbientLighting**: Subtle background pulse effects
2. **DashboardBranding**: Top branding text with responsive sizing
3. **RPMGauge**: Central circular gauge with speed display
4. **WingIndicator**: Left/right wing position with curved track

## Key Benefits

1. **Single Configuration Point**: All settings in `dashboard_config.dart`
2. **Modular Components**: Each widget is self-contained and reusable
3. **Maintained Functionality**: Identical animations, data handling, and appearance
4. **Easy Customization**: Modify colors, sizes, timing from config file
5. **Clean Architecture**: Separation of concerns with clear component boundaries

## Usage

To modify the dashboard:

1. **Layout changes**: Adjust flex values in `DashboardConfig`
2. **Visual changes**: Update colors and dimensions in config
3. **Animation tweaks**: Modify duration constants
4. **Component swapping**: Replace individual components while maintaining interface

The dashboard maintains exactly the same visual appearance and behavior as the original while being much more maintainable and configurable.
