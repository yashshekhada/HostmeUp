# Dev Server Manager - Setup Guide

This guide will help you set up the Dev Server Manager on your macOS system.

## Prerequisites

### System Requirements
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 2GB free space

### Development Tools
- **Swift**: 5.9 or later (included with Xcode)
- **Git**: For version control
- **Command Line Tools**: `xcode-select --install`

## Quick Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/DevServerManager.git
cd DevServerManager
```

### 2. Open in Xcode

```bash
open DevServerManager.xcodeproj
```

### 3. Configure Signing

1. Select the project in Xcode
2. Go to the "Signing & Capabilities" tab
3. Select your development team
4. Ensure "Automatically manage signing" is checked

### 4. Build and Run

Press `Cmd+R` or click the "Run" button in Xcode.

## Manual Build

### Using the Build Script

```bash
# Make the script executable
chmod +x build.sh

# Build the application
./build.sh

# Build with DMG creation
./build.sh --clean --dmg
```

### Using Xcode Command Line

```bash
# Build for release
xcodebuild -scheme DevServerManager -configuration Release

# Clean and build
xcodebuild clean -scheme DevServerManager
xcodebuild -scheme DevServerManager -configuration Release
```

## First Launch Setup

### 1. Grant Permissions

When you first launch the application, you'll need to grant several permissions:

#### Network Access
- The app will request network access for port forwarding
- Click "Allow" when prompted

#### File System Access
- Grant access to project directories
- You can add more directories later in System Preferences

#### Administrator Privileges
- Required for firewall configuration
- Enter your password when prompted

### 2. Configure Network Settings

1. Open **Settings** → **Network**
2. Configure your network preferences:
   - **External IP Address**: Auto-detected or manually set
   - **Port Range**: Default is 3000-3300
   - **Enable External Access**: Toggle based on your needs

### 3. Add Your First Project

1. Click the "+" button in the sidebar
2. Fill in the project details:
   - **Name**: Your project name
   - **Path**: Browse to your project directory
   - **Type**: Select the appropriate technology
   - **Port**: Will be auto-assigned
   - **Start Command**: Pre-filled based on project type

## Common Project Types Setup

### Node.js Projects

```bash
# Navigate to your project
cd /path/to/your/nodejs/project

# Install dependencies
npm install

# Add to Dev Server Manager
# Name: My Node App
# Path: /path/to/your/nodejs/project
# Type: Node.js
# Command: npm start
```

### React Projects

```bash
# Create a new React app
npx create-react-app my-react-app
cd my-react-app

# Add to Dev Server Manager
# Name: My React App
# Path: /path/to/my-react-app
# Type: React
# Command: npm start
```

### Python Projects

```bash
# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask  # or your preferred framework

# Add to Dev Server Manager
# Name: My Python App
# Path: /path/to/your/python/project
# Type: Python
# Command: python app.py
```

### .NET Projects

```bash
# Create a new .NET project
dotnet new web -n MyDotNetApp
cd MyDotNetApp

# Add to Dev Server Manager
# Name: My .NET App
# Path: /path/to/MyDotNetApp
# Type: .NET
# Command: dotnet run
```

## Troubleshooting

### Permission Issues

If you encounter permission errors:

1. **System Preferences** → **Security & Privacy** → **Privacy**
2. Add Dev Server Manager to:
   - **Full Disk Access**
   - **Files and Folders**
   - **Network** (if available)

### Port Conflicts

If you get "Port already in use" errors:

1. Check running processes: `lsof -i :3000`
2. Stop conflicting services
3. Or change the port in project settings

### Network Issues

If external access doesn't work:

1. Check your router's port forwarding settings
2. Verify firewall configuration
3. Ensure your ISP doesn't block incoming connections

### Build Errors

If you encounter build errors:

1. Clean the build folder: `Cmd+Shift+K`
2. Reset package caches: `File` → `Packages` → `Reset Package Caches`
3. Restart Xcode
4. Check that all dependencies are available

## Advanced Configuration

### Custom Project Types

You can add custom project types by modifying the `ProjectType` enum in `ProjectManager.swift`:

```swift
case myCustomType = "My Custom Type"

var defaultCommand: String {
    switch self {
    case .myCustomType:
        return "my-custom-command"
    // ... other cases
    }
}
```

### Network Security

For production use, consider:

1. **Firewall Rules**: Configure specific IP ranges
2. **SSL/TLS**: Use HTTPS for external access
3. **Authentication**: Implement user authentication
4. **Rate Limiting**: Prevent abuse

### Performance Optimization

For better performance:

1. **Resource Monitoring**: Enable in settings
2. **Log Rotation**: Configure log file sizes
3. **Process Limits**: Set maximum concurrent servers

## Getting Help

If you need help:

1. Check the [README](README.md) for detailed documentation
2. Review the [Issues](https://github.com/yourusername/DevServerManager/issues) page
3. Create a new issue with:
   - System information
   - Error logs
   - Steps to reproduce

## Contributing

To contribute to the project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Next Steps

Once you have the application running:

1. **Explore Features**: Try different project types
2. **Network Configuration**: Set up external access
3. **Automation**: Use the command-line interface
4. **Integration**: Connect with your existing workflow

Happy coding! 🚀