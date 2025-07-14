#!/bin/bash

# Dev Server Manager - Project Creation Script
# This script creates a proper Xcode project structure on macOS

set -e

PROJECT_NAME="DevServerManager"
BUNDLE_ID="com.devserver.manager"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script must be run on macOS"
        exit 1
    fi
    print_success "macOS detected"
}

# Check if Xcode is installed
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or xcodebuild is not in PATH"
        print_error "Please install Xcode from the Mac App Store"
        exit 1
    fi
    print_success "Xcode found"
}

# Create directory structure
create_directories() {
    print_status "Creating directory structure..."
    
    # Remove existing broken project if it exists
    if [ -d "$PROJECT_NAME" ]; then
        rm -rf "$PROJECT_NAME"
    fi
    
    # Create project structure
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME"
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Views"
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Managers"
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Assets.xcassets/AppIcon.appiconset"
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Assets.xcassets/AccentColor.colorset"
    mkdir -p "$PROJECT_NAME/$PROJECT_NAME/Preview Content/Preview Assets.xcassets"
    
    print_success "Directory structure created"
}

# Create a new Xcode project using command line
create_xcode_project() {
    print_status "Creating Xcode project..."
    
    cd "$PROJECT_NAME"
    
    # Create a basic Swift package first, then convert to app
    cat > Package.swift << 'EOF'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DevServerManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevServerManager", targets: ["DevServerManager"])
    ],
    targets: [
        .executableTarget(name: "DevServerManager", path: "DevServerManager")
    ]
)
EOF
    
    # Create main.swift temporarily to make it a valid Swift package
    echo 'print("Hello, World!")' > "$PROJECT_NAME/main.swift"
    
    # Now create the proper Xcode project
    swift package generate-xcodeproj
    
    # Remove the temporary files
    rm Package.swift
    rm "$PROJECT_NAME/main.swift"
    
    print_success "Basic Xcode project created"
}

# Alternative: Use Xcode's project template
create_with_xcode_template() {
    print_status "Creating project with Xcode template..."
    
    # This approach uses Xcode's built-in project templates
    # We'll create a temporary script that can be run to create the project
    
    cat > setup_xcode_project.applescript << 'EOF'
tell application "Xcode"
    activate
    delay 2
    
    -- Create new project
    keystroke "n" using {command down, shift down}
    delay 2
    
    -- Select macOS tab
    click button "macOS" of tab group 1 of window "Choose a template for your new project:"
    delay 1
    
    -- Select App template
    click button "App" of scroll area 1 of tab group 1 of window "Choose a template for your new project:"
    delay 1
    
    -- Click Next
    click button "Next" of window "Choose a template for your new project:"
    delay 2
    
    -- Fill in project details
    set value of text field "Product Name:" to "DevServerManager"
    set value of text field "Bundle Identifier:" to "com.devserver.manager"
    
    -- Select SwiftUI
    click popup button "Interface:" of window "Choose options for your new project:"
    click menu item "SwiftUI" of menu 1 of popup button "Interface:" of window "Choose options for your new project:"
    
    -- Click Next
    click button "Next" of window "Choose options for your new project:"
    delay 2
    
    -- Choose location and create
    click button "Create" of window "Choose a location for your new project:"
end tell
EOF
    
    print_warning "An AppleScript has been created to help you create the project in Xcode"
    print_warning "Run: osascript setup_xcode_project.applescript"
}

# Copy source files to the correct locations
copy_source_files() {
    print_status "Copying source files..."
    
    # Copy files from the current directory structure
    if [ -f "../DevServerManager/DevServerManagerApp.swift" ]; then
        cp "../DevServerManager/DevServerManagerApp.swift" "$PROJECT_NAME/"
    fi
    
    if [ -d "../DevServerManager/Views" ]; then
        cp -r "../DevServerManager/Views/"* "$PROJECT_NAME/Views/"
    fi
    
    if [ -d "../DevServerManager/Managers" ]; then
        cp -r "../DevServerManager/Managers/"* "$PROJECT_NAME/Managers/"
    fi
    
    if [ -f "../DevServerManager/DevServerManager.entitlements" ]; then
        cp "../DevServerManager/DevServerManager.entitlements" "$PROJECT_NAME/"
    fi
    
    if [ -f "../DevServerManager/Info.plist" ]; then
        cp "../DevServerManager/Info.plist" "$PROJECT_NAME/"
    fi
    
    print_success "Source files copied"
}

# Main setup process
main() {
    print_status "Starting Dev Server Manager project setup..."
    
    check_macos
    check_xcode
    create_directories
    
    # Try the Swift package approach first
    if create_xcode_project; then
        copy_source_files
        print_success "Project created successfully!"
        print_status "You can now open $PROJECT_NAME.xcodeproj in Xcode"
    else
        print_warning "Swift package approach failed, creating AppleScript helper..."
        create_with_xcode_template
        print_status "Use the AppleScript to create the project, then manually add the source files"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  --applescript   Create AppleScript helper for Xcode"
    echo ""
    echo "This script creates a proper Xcode project for Dev Server Manager."
    echo "It must be run on macOS with Xcode installed."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --applescript)
            create_with_xcode_template
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run main setup
main