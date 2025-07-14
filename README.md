# Dev Server Manager

A comprehensive macOS application for managing development servers with GUI-based self-hosting capabilities, built with SwiftUI and designed for developers who need to manage multiple projects running on different ports.

## Features

### 🚀 **Server Management**
- Start/Stop/Restart development servers with a single click
- Support for multiple project types (Node.js, React, Vue.js, Angular, .NET, Python, Ruby, PHP, Go, Rust, Java, and more)
- Real-time server status monitoring
- Process ID tracking and management
- Custom start commands for each project

### 🌐 **Network & Port Management**
- Automatic port allocation (3000-3300 range)
- Port forwarding configuration
- External IP address detection
- Network interface monitoring
- Port usage visualization
- Real-time network status updates

### 🔧 **Project Management**
- Add/Edit/Delete projects with different technologies
- Browse and select project directories
- Project-specific settings and configurations
- Prerequisites checking for each project type
- Project path validation

### 📊 **Real-time Monitoring**
- Live server status dashboard
- Network interface monitoring
- Port usage charts
- Running server overview
- System resource monitoring

### 🔐 **Security & Permissions**
- macOS firewall integration
- Network access permissions
- File system access management
- Admin privileges handling
- UPnP port forwarding support

### 🔌 **External Access**
- Port forwarding setup
- External URL generation
- DDNS configuration support
- Network sharing capabilities
- IP-based access control

## Supported Project Types

| Technology | Default Port | Start Command | Prerequisites |
|------------|--------------|---------------|---------------|
| Node.js | 3000 | `node index.js` | Node.js, npm |
| React | 3000 | `npm start` | Node.js, npm |
| Vue.js | 8080 | `npm run serve` | Node.js, npm |
| Angular | 4200 | `ng serve` | Node.js, npm |
| Next.js | 3000 | `npm run dev` | Node.js, npm |
| .NET | 5000 | `dotnet run` | .NET SDK |
| Python | 5000 | `python app.py` | Python 3.x, pip |
| Django | 8000 | `python manage.py runserver` | Python 3.x, pip |
| Ruby on Rails | 3000 | `rails server` | Ruby, gem |
| PHP | 8000 | `php -S localhost:8000` | PHP |
| Go | 8080 | `go run main.go` | Go |
| Rust | 8000 | `cargo run` | Rust, Cargo |
| Java Spring | 8080 | `mvn spring-boot:run` | Java JDK, Maven |

## Installation

### Requirements
- macOS 14.0 or later
- Xcode 15.0 or later
- Administrator privileges (for network configuration)

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/DevServerManager.git
cd DevServerManager
```

2. Open the project in Xcode:
```bash
open DevServerManager.xcodeproj
```

3. Build and run the project:
   - Select your target device/simulator
   - Press `Cmd+R` to build and run

### Permissions Setup

The application requires several permissions to function properly:

1. **Network Access**: For port forwarding and external connectivity
2. **File System Access**: To browse and manage project directories
3. **Administrator Privileges**: For firewall configuration
4. **Full Disk Access**: For accessing project files across the system

## Usage

### Adding a Project

1. Click the "+" button in the sidebar
2. Enter project details:
   - **Name**: Display name for your project
   - **Path**: Directory where your project is located
   - **Type**: Select the appropriate technology
   - **Port**: Port number (auto-assigned if not specified)
   - **Start Command**: Command to start the server

### Managing Servers

- **Start Server**: Click the "Start Server" button in the project detail view
- **Stop Server**: Click the "Stop Server" button when running
- **Restart Server**: Use the "Restart" button for quick restarts
- **View Logs**: Click "Logs" to see server output

### Network Configuration

1. Open **Settings** → **Network**
2. Configure:
   - External IP address
   - Port forwarding range
   - Enable/disable external connections
   - DDNS settings

### Port Forwarding

The application automatically configures port forwarding for:
- Local network access
- External internet access (with proper router configuration)
- UPnP automatic port mapping
- Manual firewall rules

## Network Architecture

```
Internet → Router → macOS Firewall → Dev Server Manager → Local Servers
    ↓          ↓            ↓                   ↓              ↓
External IP → NAT → Local IP → Port Forward → localhost:port
```

## Security Considerations

- **Firewall Rules**: Automatically configured but can be manually adjusted
- **Port Access**: Limited to specified range (3000-3300)
- **External Access**: Disabled by default, requires explicit enabling
- **Process Isolation**: Each server runs in its own process
- **Permission Model**: Follows macOS security guidelines

## Advanced Features

### DDNS Integration
Support for dynamic DNS providers:
- DuckDNS
- No-IP
- Cloudflare

### Network Monitoring
- Real-time network interface status
- Port scanning capabilities
- Network speed testing
- Ping utilities
- DNS resolution

### Process Management
- Graceful server shutdown
- Process monitoring
- Resource usage tracking
- Log aggregation

## Configuration Files

The application stores configuration in:
- **Projects**: `~/Library/Preferences/com.devserver.manager.plist`
- **Network Settings**: User defaults
- **Logs**: `~/Library/Logs/DevServerManager/`

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   - Check if another application is using the port
   - Use the built-in port scanner to find available ports

2. **Permission Denied**
   - Ensure the application has necessary permissions
   - Run with administrator privileges for network configuration

3. **Server Won't Start**
   - Verify project path exists
   - Check if prerequisites are installed
   - Review server logs for error messages

4. **External Access Issues**
   - Verify router port forwarding configuration
   - Check firewall settings
   - Ensure external IP is correctly detected

### Debug Mode

Enable debug logging by setting the environment variable:
```bash
DEBUG=1 /path/to/DevServerManager.app/Contents/MacOS/DevServerManager
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please:
1. Check the [Issues](https://github.com/yourusername/DevServerManager/issues) page
2. Create a new issue with detailed information
3. Include system information and logs

## Roadmap

- [ ] Docker container support
- [ ] Custom domain configuration
- [ ] SSL/TLS certificate management
- [ ] Database server integration
- [ ] Cloud deployment integration
- [ ] Team collaboration features
- [ ] Plugin system for custom project types

## Acknowledgments

- Built with SwiftUI and modern macOS APIs
- Inspired by various developer tools and server management solutions
- Thanks to the open-source community for inspiration and resources
