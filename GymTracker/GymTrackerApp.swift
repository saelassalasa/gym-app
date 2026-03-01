import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutProgram.self,
            WorkoutTemplate.self,
            WorkoutSession.self,
            WorkoutSet.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Set file protection on the store
            if let storeURL = container.configurations.first?.url {
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: storeURL.path()
                )
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .onAppear {
                    seedIfNeeded()
                    cleanOrphanSessions()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutProgram>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // ── PUSH A (High Intensity) ──
        let pushA = WorkoutProgram(name: "PUSH A — HIT", isActive: true)
        let pushTemplate = WorkoutTemplate(name: "PUSH A", dayIndex: 0, exercises: [
            Exercise(name: "Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest,
                     restSeconds: 150, currentWeight: 80, targetReps: 8, targetSets: 2),
            Exercise(name: "Overhead Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders,
                     restSeconds: 150, currentWeight: 50, targetReps: 8, targetSets: 2),
            Exercise(name: "Incline Dumbbell Fly", category: .push, exerciseType: .accessory, primaryMuscle: .chest,
                     restSeconds: 150, currentWeight: 16, targetReps: 8, targetSets: 2),
            Exercise(name: "Lateral Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders,
                     restSeconds: 150, currentWeight: 10, targetReps: 8, targetSets: 2),
            Exercise(name: "Tricep Pushdown", category: .push, exerciseType: .accessory, primaryMuscle: .triceps,
                     restSeconds: 150, currentWeight: 25, targetReps: 8, targetSets: 2),
        ])
        pushTemplate.program = pushA

        // ── PULL B (High Intensity) ──
        let pullB = WorkoutProgram(name: "PULL B — HIT")
        let pullTemplate = WorkoutTemplate(name: "PULL B", dayIndex: 0, exercises: [
            Exercise(name: "Barbell Row", category: .pull, exerciseType: .compound, primaryMuscle: .back,
                     restSeconds: 150, currentWeight: 70, targetReps: 8, targetSets: 2),
            Exercise(name: "Lat Pulldown", category: .pull, exerciseType: .compound, primaryMuscle: .back,
                     restSeconds: 150, currentWeight: 60, targetReps: 8, targetSets: 2),
            Exercise(name: "Face Pull", category: .pull, exerciseType: .accessory, primaryMuscle: .shoulders,
                     restSeconds: 150, currentWeight: 15, targetReps: 8, targetSets: 2),
            Exercise(name: "Barbell Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps,
                     restSeconds: 150, currentWeight: 25, targetReps: 8, targetSets: 2),
            Exercise(name: "Hammer Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps,
                     restSeconds: 150, currentWeight: 14, targetReps: 8, targetSets: 2),
        ])
        pullTemplate.program = pullB

        context.insert(pushA)
        context.insert(pushTemplate)
        context.insert(pullB)
        context.insert(pullTemplate)
        context.saveSafe()
    }

    @MainActor
    private func cleanOrphanSessions() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { !$0.isCompleted }
        )
        guard let orphans = try? context.fetch(descriptor), !orphans.isEmpty else { return }
        for session in orphans {
            session.isCompleted = true
            session.duration = 0
            session.notes = "[RECOVERED]"
        }
        context.saveSafe()
        debugLog("Cleaned \(orphans.count) orphan session(s)")
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN TAB VIEW
// Brutalist tab navigation
// ═══════════════════════════════════════════════════════════════════════════

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("TRAIN")
                }
                .tag(0)
            
            NavigationStack {
                    PlanView()
                }
                .tabItem {
                    Image(systemName: "calendar")
                    Text("GRID")
                }
                .tag(1)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("LOG")
                }
                .tag(2)
            
            NavigationStack {
                    ProgressChartView()
                }
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("STATS")
                }
                .tag(3)
        }
        .tint(Wire.Color.white)
    }
}
