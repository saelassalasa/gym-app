#!/bin/bash

# ==============================================================================
# BRUTALIST GYM TRACKER - XCODE PROJECT SETUP
# ==============================================================================
# This script creates a complete Xcode project structure using xcodegen.
# If xcodegen is not installed, it will provide manual instructions.
# ==============================================================================

set -e

PROJECT_DIR="/Users/deniznebiler/vibecoding/GymTracker"
PROJECT_NAME="GymTracker"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              BRUTALIST GYM TRACKER - PROJECT SETUP                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if xcodegen is available
if command -v xcodegen &> /dev/null; then
    echo "[✓] xcodegen found. Generating Xcode project..."
    
    # Create project.yml for xcodegen
    cat > "$PROJECT_DIR/project.yml" << 'XCODEGEN_EOF'
name: GymTracker
options:
  bundleIdPrefix: com.brutalist
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

settings:
  base:
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic

targets:
  GymTracker:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes:
          - "*.sh"
          - "*.yml"
          - "*.md"
    settings:
      base:
        INFOPLIST_GENERATION_MODE: GeneratedFile
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone: "UIInterfaceOrientationPortrait"
        INFOPLIST_KEY_CFBundleDisplayName: "GymTracker"
        PRODUCT_BUNDLE_IDENTIFIER: "com.brutalist.gymtracker"
XCODEGEN_EOF

    # Run xcodegen
    cd "$PROJECT_DIR"
    xcodegen generate
    
    echo ""
    echo "[✓] Xcode project generated successfully!"
    echo ""
    echo "To open the project:"
    echo "  open $PROJECT_DIR/$PROJECT_NAME.xcodeproj"
    
else
    echo "[!] xcodegen not found."
    echo ""
    echo "OPTION 1: Install xcodegen (recommended)"
    echo "  brew install xcodegen"
    echo "  Then run this script again."
    echo ""
    echo "OPTION 2: Use the Swift Package Manager approach"
    echo "  Creating Package.swift for command-line build verification..."
    
    # Create a Package.swift for syntax verification (won't run as iOS app)
    cat > "$PROJECT_DIR/Package.swift" << 'PACKAGE_EOF'
// swift-tools-version:5.9
// NOTE: This package is for SYNTAX VERIFICATION ONLY.
// To run the actual iOS app, create an Xcode project manually.

import PackageDescription

let package = Package(
    name: "GymTracker",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GymTracker", targets: ["GymTracker"])
    ],
    targets: [
        .target(
            name: "GymTracker",
            path: ".",
            exclude: ["Package.swift", "setup.sh", "project.yml"],
            sources: [
                "Models/GymModels.swift",
                "Views/IndustrialTheme.swift",
                "Views/ActiveWorkoutView.swift",
                "Views/DashboardView.swift",
                "Views/HistoryView.swift",
                "Views/WorkoutTemplateView.swift",
                "Views/ProgramSetupView.swift",
                "Views/ProgressView.swift",
                "ViewModels/ActiveWorkoutViewModel.swift",
                "ViewModels/DashboardViewModel.swift",
                "ViewModels/ProgressionManager.swift",
                "Utilities/Theme.swift",
                "GymTrackerApp.swift"
            ]
        )
    ]
)
PACKAGE_EOF

    echo ""
    echo "[✓] Package.swift created for syntax verification."
    echo ""
    echo "OPTION 3: Manual Xcode Project Creation"
    echo "========================================="
    echo ""
    echo "1. Open Xcode"
    echo "2. File > New > Project"
    echo "3. Choose: iOS > App"
    echo "4. Settings:"
    echo "   - Product Name: GymTracker"
    echo "   - Interface: SwiftUI"
    echo "   - Storage: SwiftData"
    echo "   - Language: Swift"
    echo "5. Save to: /Users/deniznebiler/vibecoding/"
    echo "6. Delete the auto-generated files (ContentView.swift, Item.swift)"
    echo "7. Right-click on GymTracker folder > Add Files to 'GymTracker'..."
    echo "8. Select all folders from the existing GymTracker directory:"
    echo "   - Models/"
    echo "   - Views/"
    echo "   - ViewModels/"
    echo "   - Utilities/"
    echo "   - GymTrackerApp.swift"
    echo "9. Build and run!"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                           SETUP COMPLETE                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
