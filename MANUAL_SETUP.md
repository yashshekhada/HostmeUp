# Manual Setup Guide for Dev Server Manager

Since the automatically generated Xcode project file has issues, here's a step-by-step guide to create the project manually in Xcode.

## Step 1: Create New Xcode Project

1. Open **Xcode**
2. Select **"Create a new Xcode project"**
3. Choose **macOS** → **App**
4. Click **Next**

## Step 2: Configure Project Settings

Fill in the following details:
- **Product Name**: `DevServerManager`
- **Team**: Select your development team
- **Organization Identifier**: `com.devserver.manager`
- **Bundle Identifier**: `com.devserver.manager`
- **Language**: Swift
- **Interface**: SwiftUI
- **Use Core Data**: Unchecked
- **Include Tests**: Unchecked (optional)

Click **Next** and choose a location to save the project.

## Step 3: Delete Default Files

1. In the project navigator, delete the default `ContentView.swift` file
2. Keep `DevServerManagerApp.swift` but we'll replace its content

## Step 4: Create Folder Structure

1. Right-click on the `DevServerManager` folder in the project navigator
2. Select **"New Group"** and name it `Views`
3. Create another group named `Managers`

## Step 5: Add Source Files

### Add DevServerManagerApp.swift
Replace the content of `DevServerManagerApp.swift` with:

```swift
import SwiftUI

@main
struct DevServerManagerApp: App {
    @StateObject private var projectManager = ProjectManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        Settings {
            SettingsView()
                .environmentObject(projectManager)
        }
    }
}

// ... rest of the content from DevServerManagerApp.swift
```

### Add Views
1. Right-click on the `Views` group
2. Select **"New File"** → **Swift File**
3. Name it `ContentView.swift`
4. Copy the content from `DevServerManager/Views/ContentView.swift`

Repeat for:
- `ProjectSettingsView.swift`
- `StatusView.swift`

### Add Managers
1. Right-click on the `Managers` group
2. Select **"New File"** → **Swift File**
3. Add these files:
   - `ProjectManager.swift`
   - `ServerManager.swift`
   - `NetworkManager.swift`
   - `PortForwardingManager.swift`

## Step 6: Configure Entitlements

1. In the project navigator, select the **DevServerManager** project (blue icon)
2. Select the **DevServerManager** target
3. Go to **"Signing & Capabilities"**
4. Click **"+ Capability"**
5. Add:
   - **Network** (for network access)
   - **Outgoing Network Connections** (for external IP detection)
   - **Hardened Runtime** (for security)

### Manual Entitlements File
1. Right-click on the project and select **"New File"**
2. Choose **Property List**
3. Name it `DevServerManager.entitlements`
4. Add the following keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

## Step 7: Configure Info.plist

1. In the project navigator, find `Info.plist`
2. Add these keys:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>This app needs to control system processes to manage development servers.</string>
<key>NSNetworkVolumesUsageDescription</key>
<string>This app needs network access to manage development servers and port forwarding.</string>
<key>NSSystemAdministrationUsageDescription</key>
<string>This app needs administrator privileges to configure network settings and port forwarding.</string>
```

## Step 8: Build Settings

1. Select the project in the navigator
2. Go to **Build Settings**
3. Set **Deployment Target** to `14.0`
4. Set **Swift Language Version** to `Swift 5`

## Step 9: Build and Run

1. Press **⌘+B** to build the project
2. Fix any import or compilation errors
3. Press **⌘+R** to run the application

## Troubleshooting

### Common Issues:

1. **Build Errors**: Make sure all files are added to the target
2. **Permission Errors**: Check entitlements configuration
3. **Network Issues**: Ensure network entitlements are properly set
4. **Code Signing**: Select your development team in project settings

### File Dependencies:

Make sure these files are properly linked:
- All `.swift` files should be added to the target
- `Assets.xcassets` should be in Resources
- `DevServerManager.entitlements` should be referenced in build settings

## Alternative: Using the Setup Script

If you prefer automation, run the setup script on macOS:

```bash
chmod +x create_project.sh
./create_project.sh
```

This will attempt to create the project structure automatically.

## Final Steps

1. **Test the application** by adding a sample project
2. **Configure permissions** when prompted
3. **Test server functionality** with a simple Node.js or Python project
4. **Configure network settings** for external access

The application should now be fully functional with all the features described in the README.md file.