#!/bin/bash

# Dev Server Manager Build Script
# This script builds the macOS application and optionally creates a DMG for distribution

set -e

PROJECT_NAME="DevServerManager"
SCHEME="DevServerManager"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
DMG_PATH="$BUILD_DIR/$PROJECT_NAME.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if Xcode is installed
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or xcodebuild is not in PATH"
        exit 1
    fi
    print_success "Xcode found"
}

# Function to clean build directory
clean_build() {
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    print_success "Build directory cleaned"
}

# Function to build the project
build_project() {
    print_status "Building $PROJECT_NAME..."
    
    cd "$PROJECT_NAME"
    
    xcodebuild -scheme "$SCHEME" \
               -configuration "$CONFIGURATION" \
               -derivedDataPath "../$BUILD_DIR/DerivedData" \
               -archivePath "../$ARCHIVE_PATH" \
               archive
    
    print_success "Project built successfully"
    cd ..
}

# Function to export the app
export_app() {
    print_status "Exporting application..."
    
    # Create export options plist
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
               -archivePath "$ARCHIVE_PATH" \
               -exportPath "$BUILD_DIR" \
               -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"
    
    print_success "Application exported to $BUILD_DIR"
}

# Function to create DMG
create_dmg() {
    print_status "Creating DMG..."
    
    if [ -f "$DMG_PATH" ]; then
        rm "$DMG_PATH"
    fi
    
    # Create temporary DMG directory
    DMG_DIR="$BUILD_DIR/dmg"
    mkdir -p "$DMG_DIR"
    
    # Copy app to DMG directory
    cp -R "$APP_PATH" "$DMG_DIR/"
    
    # Create Applications symlink
    ln -sf /Applications "$DMG_DIR/Applications"
    
    # Create DMG
    hdiutil create -size 100m \
                   -fs HFS+ \
                   -volname "$PROJECT_NAME" \
                   -srcfolder "$DMG_DIR" \
                   "$DMG_PATH"
    
    # Clean up temporary directory
    rm -rf "$DMG_DIR"
    
    print_success "DMG created at $DMG_PATH"
}

# Function to notarize the app (requires Apple Developer account)
notarize_app() {
    print_warning "Notarization requires Apple Developer account and credentials"
    print_warning "Skipping notarization step"
    
    # Uncomment and configure the following lines if you have notarization set up:
    # xcrun altool --notarize-app \
    #              --primary-bundle-id "com.devserver.manager" \
    #              --username "your-apple-id@example.com" \
    #              --password "@keychain:AC_PASSWORD" \
    #              --file "$DMG_PATH"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --clean     Clean build directory before building"
    echo "  -d, --dmg       Create DMG after building"
    echo "  -n, --notarize  Notarize the application (requires Apple Developer account)"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Build the application"
    echo "  $0 --clean --dmg   # Clean, build, and create DMG"
    echo "  $0 -cdn           # Clean, build, create DMG, and notarize"
}

# Parse command line arguments
CLEAN=false
CREATE_DMG=false
NOTARIZE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -d|--dmg)
            CREATE_DMG=true
            shift
            ;;
        -n|--notarize)
            NOTARIZE=true
            shift
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

# Main build process
print_status "Starting build process for $PROJECT_NAME"

# Check prerequisites
check_xcode

# Clean if requested
if [ "$CLEAN" = true ]; then
    clean_build
fi

# Build the project
build_project

# Export the app
export_app

# Create DMG if requested
if [ "$CREATE_DMG" = true ]; then
    create_dmg
fi

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    notarize_app
fi

print_success "Build process completed successfully!"
print_status "Built files are available in: $BUILD_DIR"

# Show final status
if [ -f "$APP_PATH" ]; then
    print_success "Application: $APP_PATH"
fi

if [ -f "$DMG_PATH" ]; then
    print_success "DMG: $DMG_PATH"
fi

print_status "You can now run the application or distribute the DMG file"