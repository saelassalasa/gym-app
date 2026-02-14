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
