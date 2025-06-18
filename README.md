# PortList - macOS Port Monitor

PortList is a macOS menu bar application that displays running network ports, the processes using them, and allows you to manage those processes directly from the menu bar.

## Features

- **Menu Bar Integration**: Lives in your macOS menu bar for quick access
- **Port Monitoring**: Shows all active network ports and listening services
- **Process Information**: Displays process names, icons, and detailed information
- **Process Management**: Kill or force-kill processes directly from the interface
- **Detailed Tooltips**: Hover for additional process information (parent process, command line, memory, CPU usage)
- **Pause/Resume**: Temporarily pause monitoring to reduce system load
- **Clean UI**: Native macOS design with smooth animations

## Installation

### Option 1: Download Pre-built App (Recommended)
1. Download the latest `PortList.app.zip` from the releases page
2. Unzip the file
3. Drag `PortList.app` to your `/Applications` folder
4. Right-click the app and select "Open" (required for first launch due to macOS security)
5. Grant necessary permissions when prompted

### Option 2: Build from Source
1. Clone this repository
2. Open Terminal and navigate to the project directory
3. Run the build script: `./build.sh`
4. The built app will be in the `build` directory

## Usage

1. **Launch**: Open PortList from Applications or Spotlight
2. **Access**: Click the network icon in your menu bar
3. **View Ports**: See all active ports with their associated processes
4. **Get Details**: Hover over any port entry for detailed information
5. **Manage Processes**: 
   - Click the red stop button to terminate a process gracefully
   - Click the crossbones button to force-kill a process
6. **Control**: Use the pause button to temporarily stop monitoring, or exit to quit

## Permissions

PortList requires the following permissions:
- **Network Access**: To scan for active ports
- **Process Information**: To read process details and memory usage
- **App Control**: To terminate processes (with user confirmation)

## Building from Source

### Prerequisites
- macOS 11.0 or later
- Xcode 13.0 or later
- Command Line Tools for Xcode

### Build Steps
```bash
# Clone the repository
git clone <repository-url>
cd portlist

# Make build script executable
chmod +x build.sh

# Build the application
./build.sh

# The app will be created in build/PortList.app
```

## Packaging for Distribution

### Create a Distributable Package
```bash
# Create a compressed archive
./package.sh

# This creates PortList.app.zip ready for distribution
```

### Code Signing (for distribution)
1. Obtain an Apple Developer Certificate
2. Sign the application:
```bash
codesign --force --sign "Developer ID Application: Your Name" --options runtime build/PortList.app
```

### Notarization (for distribution outside App Store)
1. Create an app-specific password in Apple ID settings
2. Notarize the app:
```bash
xcrun altool --notarize-app --primary-bundle-id "com.yourname.portlist" --username "your@email.com" --password "app-specific-password" --file PortList.app.zip
```

## Uninstallation

1. Quit PortList (right-click menu bar icon → Exit)
2. Delete `/Applications/PortList.app`
3. Remove preferences (optional): `~/Library/Preferences/com.yourname.portlist.plist`

## Troubleshooting

### Common Issues

**App won't open**: Right-click and select "Open" for first launch
**No ports showing**: Check that you've granted network access permissions
**Permission denied**: Run with administrator privileges if needed
**High CPU usage**: Use the pause button to temporarily stop monitoring

### Debug Mode
Run from Terminal to see debug output:
```bash
/Applications/PortList.app/Contents/MacOS/PortList
```

## Development

### Project Structure
```
portlist/
├── Sources/
│   ├── AppDelegate.swift          # Main application delegate
│   ├── StatusBarController.swift  # Menu bar management
│   ├── PortMonitor.swift          # Port scanning logic
│   ├── ProcessInfo.swift          # Process information gathering
│   └── PortListView.swift         # UI components
├── Resources/
│   ├── Info.plist                 # App configuration
│   └── Assets/                    # Icons and images
├── build.sh                       # Build script
├── package.sh                     # Packaging script
└── README.md                      # This file
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on multiple macOS versions
5. Submit a pull request

## License

See LICENSE file for details.

## Next Steps to Consider

After installing and using PortList, you might want to consider:

1. **Security Review**: Review which processes have network access
2. **Performance Optimization**: Use the pause feature for resource-intensive monitoring
3. **Automation**: Consider automating the monitoring of specific ports or processes
4. **Integration**: Explore integrating with other development tools or monitoring systems
5. **Customization**: Request features like custom port filters or notification settings

## Support

For issues, feature requests, or questions, please open an issue on the GitHub repository.