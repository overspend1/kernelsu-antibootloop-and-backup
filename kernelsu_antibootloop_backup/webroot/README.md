# KernelSU Anti-Bootloop & Backup WebUI

A modern, KernelSU-Next compatible web interface for the Anti-Bootloop & Backup module.

## Features

### 🛡️ System Protection
- Real-time bootloop monitoring
- Intelligent system health analysis
- Automated backup creation
- Emergency recovery mode

### 📊 Dashboard
- Live system status indicators
- Protection status monitoring
- Backup availability tracking
- Storage usage information
- System health scoring

### 🔧 Management Tools
- One-click backup creation
- Backup listing and management
- System optimization tools
- Emergency mode activation
- Real-time log viewing

### 🎨 Modern Interface
- Responsive design for all screen sizes
- Dark mode support
- Accessibility features
- Smooth animations and transitions
- Touch-friendly controls

## KernelSU-Next Integration

This WebUI is specifically designed for KernelSU-Next and utilizes:

- **ksu.exec()** - Execute shell commands and scripts
- **ksu.toast()** - Display user notifications
- **ksu.moduleInfo()** - Access module metadata
- **ksu.getModuleProp()** - Read module properties

## File Structure

```
webroot/
├── index.html          # Main HTML structure
├── styles.css          # Styling and responsive design
├── app.js             # JavaScript functionality and KernelSU integration
├── manifest.json      # WebUI metadata and configuration
└── README.md          # This documentation
```

## Installation

1. Ensure KernelSU-Next is installed and running
2. Place the module in `/data/adb/modules/kernelsu_antibootloop_backup/`
3. The WebUI will be automatically available through KernelSU-Next's module interface

## Usage

### Accessing the WebUI
- Open KernelSU-Next app
- Navigate to Modules section
- Find "KernelSU Anti-Bootloop & Backup"
- Tap to open the WebUI

### Main Functions

#### Backup Management
- **Create Backup**: Creates a full system backup
- **List Backups**: Shows all available backups with timestamps
- **Restore**: Restore from selected backup (via emergency mode)

#### System Monitoring
- **System Scan**: Performs comprehensive system health check
- **View Logs**: Display real-time system and module logs
- **Optimize System**: Run system optimization routines

#### Emergency Features
- **Emergency Mode**: Activates safe mode with emergency backup
- **Recovery Tools**: Access to bootloop recovery functions

### Status Indicators

- **Protection Status**: Shows if bootloop protection is active
- **Backup Status**: Displays last backup information
- **System Health**: Overall system health score (0-100)
- **Storage Status**: Available storage space

## Configuration

The WebUI automatically detects module configuration from:
- `/data/adb/modules/kernelsu_antibootloop_backup/module.prop`
- System properties and module settings

## Compatibility

- **Required**: KernelSU-Next v0.7.0+
- **Android**: 7.0+ (API 24+)
- **Architecture**: ARM64, ARM32
- **Root**: KernelSU required

## Development

### Technologies Used
- Vanilla HTML5, CSS3, JavaScript (ES2020)
- CSS Grid and Flexbox for responsive layout
- CSS Custom Properties for theming
- Modern Web APIs for enhanced functionality

### Browser Support
- Chrome/Chromium 80+
- Firefox 75+
- Safari 13+
- Edge 80+

## Security

- All commands executed through KernelSU's secure API
- No direct shell access from web interface
- Input validation and sanitization
- Secure communication with module scripts

## Troubleshooting

### WebUI Not Loading
1. Check KernelSU-Next version compatibility
2. Verify module installation in correct directory
3. Ensure module is enabled in KernelSU-Next
4. Check system logs for errors

### Functions Not Working
1. Verify script permissions in `/scripts/` directory
2. Check if required scripts exist:
   - `backup-engine.sh`
   - `intelligent-monitor.sh`
   - `safe-mode.sh`
3. Review logs for error messages

### Performance Issues
1. Clear browser cache
2. Restart KernelSU-Next app
3. Check available storage space
4. Review system resource usage

## Contributing

Contributions are welcome! Please:
1. Follow existing code style
2. Test on multiple devices
3. Ensure KernelSU-Next compatibility
4. Update documentation as needed

## License

This project is licensed under the MIT License - see the module's main LICENSE file for details.

## Support

For support and bug reports:
- GitHub Issues: [Module Repository]
- KernelSU Community: [Official Channels]
- Documentation: [Wiki/Docs]

---

**Note**: This WebUI requires KernelSU-Next and is not compatible with standard web browsers when accessing KernelSU-specific functions. For development and testing, mock functions are provided.