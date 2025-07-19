import SwiftUI

@main
struct DevServerManagerApp: App {
    @StateObject private var projectManager = ProjectManager()
    
    var body: some Scene {
        WindowGroup("DevServer Manager") {
            ContentView()
                .environmentObject(projectManager)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultPosition(.center)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
                .environmentObject(projectManager)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var projectManager: ProjectManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            NetworkSettingsView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
            
            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Default Settings") {
                TextField("Default IP Address", text: .constant("127.0.0.1"))
                TextField("Default Port Range", text: .constant("3000-3300"))
                Toggle("Auto-start servers on launch", isOn: .constant(false))
                Toggle("Show detailed logs", isOn: .constant(true))
            }
        }
        .padding()
    }
}

struct NetworkSettingsView: View {
    var body: some View {
        Form {
            Section("Network Configuration") {
                TextField("External IP Address", text: .constant(""))
                TextField("Port Forwarding Range", text: .constant("3000-3300"))
                Toggle("Enable port forwarding", isOn: .constant(true))
                Toggle("Allow external connections", isOn: .constant(false))
            }
        }
        .padding()
    }
}

struct PermissionsSettingsView: View {
    var body: some View {
        Form {
            Section("macOS Permissions") {
                Button("Request Network Access") {
                    // Request network permissions
                }
                Button("Request File System Access") {
                    // Request file system permissions
                }
                Button("Request Firewall Configuration") {
                    // Request firewall permissions
                }
            }
        }
        .padding()
    }
}