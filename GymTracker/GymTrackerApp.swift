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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
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
            
            PlanView()
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
            
            ProgressView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("STATS")
                }
                .tag(3)
        }
        .tint(Wire.Color.white)
    }
}
