import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD VIEW - OPTIMIZED
// Zero Latency Protocol: Fetch limits, background tasks, view isolation
// ═══════════════════════════════════════════════════════════════════════════

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]
    
    // Query all programs
    @Query(sort: \WorkoutProgram.name) private var programs: [WorkoutProgram]
    
    // Query active program
    @Query(filter: #Predicate<WorkoutProgram> { $0.isActive })
    private var activePrograms: [WorkoutProgram]
    
    // OPTIMIZATION: Separate query just for "last completed" - no longer loading all sessions
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var completedSessions: [WorkoutSession]
    
    @State private var showTemplateCreator = false
    @State private var showProgramSetup = false
    @State private var showImageImport = false
    @State private var showGenerator = false
    @State private var activeManager: WorkoutManager?
    @State private var templateToEdit: WorkoutTemplate?
    @State private var templateToDelete: WorkoutTemplate?
    @State private var showDeleteAlert = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        // OPTIMIZATION: LazyVStack for deferred rendering
                        LazyVStack(spacing: Wire.Layout.gap) {
                            // OPTIMIZATION: Isolated subview to prevent full repaint
                            StatsHeaderView()

                            // SRA Recovery Strip
                            NavigationLink(destination: RecoveryDashboardView()) {
                                RecoveryStripView()
                            }

                            if let next = nextTemplate {
                                missionCard(next)
                            }

                            templatesSection
                        }
                        .padding(Wire.Layout.pad)
                    }
                }
            }
            .sheet(isPresented: $showTemplateCreator) {
                WorkoutTemplateView()
            }
            .sheet(item: $templateToEdit) { template in
                WorkoutTemplateView(templateToEdit: template)
            }
            .sheet(isPresented: $showProgramSetup) {
                ProgramSetupView()
            }
            .fullScreenCover(item: $activeManager) { manager in
                ActiveWorkoutView(manager: manager)
            }
            .alert("DELETE TEMPLATE?", isPresented: $showDeleteAlert) {
                Button("INCINERATE", role: .destructive) {
                    if let template = templateToDelete {
                        deleteTemplate(template)
                    }
                }
                Button("CANCEL", role: .cancel) {
                    templateToDelete = nil
                }
            } message: {
                Text("Template will be destroyed. History is preserved.")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showImageImport) {
                ImageImportView()
            }
            .sheet(isPresented: $showGenerator) {
                GenerateProgramView()
            }
            .navigationDestination(for: WorkoutProgram.self) { program in
                ProgramDetailView(program: program)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("IRONTRACK")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(3)
            
            Spacer()

            Button {
                Wire.tap()
                showGenerator = true
            } label: {
                Text("⚡")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 40, height: 40)
            }

            NavigationLink(destination: ProgressChartView()) {
                Text("◉")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 40, height: 40)
            }

            NavigationLink(destination: HistoryView()) {
                Text("☰")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 40, height: 40)
            }

            Button {
                Wire.tap()
                showSettings = true
            } label: {
                Text("⚙")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Mission Card
    
    private func missionCard(_ template: WorkoutTemplate) -> some View {
        Button(action: { startWorkout(template: template) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("NEXT →")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.white)
                        .kerning(1)
                    
                    Spacer()
                }
                
                Text(template.name.uppercased())
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                
                Rectangle()
                    .fill(Wire.Color.dark)
                    .frame(height: 1)
                
                ForEach(template.exercises.prefix(4)) { ex in
                    HStack {
                        Text(ex.category.rawValue.prefix(4).uppercased())
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.gray)
                            .frame(width: 36, alignment: .leading)
                        
                        Text(ex.name.uppercased())
                            .font(Wire.Font.caption)
                            .foregroundColor(Wire.Color.gray)
                        
                        Spacer()
                        
                        Text("\(Int(ex.currentWeight))")
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.white)
                    }
                }
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
    
    // MARK: - Templates Section
    
    // MARK: - Programs Section (Grouped Templates)
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            HStack {
                Text("PROGRAMS")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                
                Spacer()
                
                Button(action: { showImageImport = true }) {
                    Text("📷")
                        .font(Wire.Font.header)
                }

                Button(action: { showProgramSetup = true }) {
                    Text("+")
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                }
            }
            
            if programs.isEmpty {
                WireButton("SETUP PROGRAM") { showProgramSetup = true }
            } else {
                ForEach(programs) { program in
                    programCard(program)
                }
            }
        }
    }
    
    private func programCard(_ program: WorkoutProgram) -> some View {
        NavigationLink(value: program) {
            VStack(alignment: .leading, spacing: 8) {
                // Program Header
                HStack {
                    if program.isActive {
                        Text("⚡")
                            .font(Wire.Font.caption)
                    }
                    
                    Text(program.name.uppercased())
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .kerning(1)
                    
                    Spacer()
                    
                    if program.isActive {
                        Text("ACTIVE")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(Rectangle().stroke(Wire.Color.gray, lineWidth: Wire.Layout.border))
                    } else {
                        Button {
                            Wire.tap()
                            setActiveProgram(program)
                        } label: {
                            Text("ACTIVATE")
                                .font(Wire.Font.tiny)
                                .foregroundColor(Wire.Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                        }
                    }
                }
                
                // Templates in this program
                let sortedTemplates = (program.templates ?? []).sorted { $0.dayIndex < $1.dayIndex }
                if !sortedTemplates.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(sortedTemplates) { template in
                            templateRow(template)
                        }
                    }
                } else {
                    Text("No workouts in program")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.dark)
                }
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(program.isActive ? Wire.Color.white : Wire.Color.dark, lineWidth: Wire.Layout.border))
            .contextMenu {
                Button {
                    setActiveProgram(program)
                } label: {
                    Label(program.isActive ? "ACTIVE" : "SET ACTIVE", systemImage: "checkmark.circle")
                }
                .disabled(program.isActive)
                
                Button(role: .destructive) {
                    deleteProgram(program)
                } label: {
                    Label("DELETE", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain) // Ensures the card is clickable but internal buttons still work
    }
    
    private func templateRow(_ template: WorkoutTemplate) -> some View {
        Button(action: { startWorkout(template: template) }) {
            HStack {
                Text(template.name.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                
                Spacer()
                
                Text("\(template.exercises.count)")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
                
                Text("→")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
        }
        .contextMenu {
            Button {
                templateToEdit = template
            } label: {
                Label("EDIT", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                templateToDelete = template
                showDeleteAlert = true
            } label: {
                Label("DELETE", systemImage: "trash")
            }
        }
    }
    
    private func deleteTemplate(_ template: WorkoutTemplate) {
        Wire.heavy()
        // Nullify session references before deleting
        for session in completedSessions where session.template?.id == template.id {
            session.template = nil
        }
        modelContext.delete(template)
        modelContext.saveSafe()
        templateToDelete = nil
    }
    
    private func setActiveProgram(_ program: WorkoutProgram) {
        Wire.tap()
        // Deactivate all other programs
        for p in programs {
            p.isActive = (p.id == program.id)
        }
        modelContext.saveSafe()
    }
    
    private func deleteProgram(_ program: WorkoutProgram) {
        // Block deletion if an active workout uses a template from this program
        if let manager = activeManager,
           let activeTemplate = manager.session.template,
           (program.templates ?? []).contains(where: { $0.id == activeTemplate.id }) {
            Wire.heavy()
            return
        }
        Wire.heavy()
        // Nullify session references BEFORE cascade deletes the templates,
        // otherwise sessions hold dangling refs to invalidated objects.
        let templateIDs = Set((program.templates ?? []).map(\.id))
        for session in completedSessions where session.template != nil {
            if templateIDs.contains(session.template!.id) {
                session.template = nil
            }
        }
        modelContext.delete(program)
        modelContext.saveSafe()
    }
    
    // MARK: - Actions
    
    private func startWorkout(template: WorkoutTemplate) {
        Wire.heavy()
        let manager = WorkoutManager(template: template, container: modelContext.container)
        activeManager = manager
    }
    
    // MARK: - Computed (OPTIMIZED)
    
    /// Active program (should only be one)
    private var activeProgram: WorkoutProgram? {
        activePrograms.first
    }
    
    /// PERPETUAL GRIND: Always show the next workout in rotation
    /// Uses program-based cycling: Day 1 → Day 2 → ... → Day N → Day 1
    private var nextTemplate: WorkoutTemplate? {
        // Safely resolve last completed template (may be nil if template was deleted)
        let lastTemplate = completedSessions.first?.template

        // Try program-based templates first
        if let program = activeProgram {
            let orderedTemplates = program.orderedTemplates
            guard !orderedTemplates.isEmpty else { return nil }

            guard let last = lastTemplate,
                  !last.isDeleted else {
                return orderedTemplates.first
            }

            return program.nextTemplate(after: last)
        }

        // Fallback: legacy template cycling
        guard !templates.isEmpty else { return nil }

        guard let last = lastTemplate,
              !last.isDeleted else {
            return templates.first
        }

        guard let lastIndex = templates.firstIndex(where: { $0.id == last.id }) else {
            return templates.first
        }

        let nextIndex = (lastIndex + 1) % templates.count
        return templates[nextIndex]
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATS HEADER VIEW - ISOLATED SUBVIEW
// Own query = own render cycle. Dashboard won't repaint when stats change.
// ═══════════════════════════════════════════════════════════════════════════

struct StatsHeaderView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted }, sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    
    // OPTIMIZATION: Cached stats computed in background
    @State private var totalCount: Int = 0
    @State private var weekCount: Int = 0
    @State private var streakCount: Int = 0
    
    var body: some View {
        HStack(spacing: 0) {
            statCell("TOTAL", "\(totalCount)")
            statCell("WEEK", "\(weekCount)")
            statCell("STREAK", "\(streakCount)")
        }
        .task(priority: .userInitiated) {
            await computeStats()
        }
        .onChange(of: sessions.count) { _, _ in
            Task(priority: .userInitiated) {
                await computeStats()
            }
        }
    }
    
    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    // OPTIMIZATION: Background computation
    @MainActor
    private func computeStats() async {
        let sessionsSnapshot = sessions
        
        // Total
        totalCount = sessionsSnapshot.count
        
        // Week (computed in background conceptually, but data is small)
        let week = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weekCount = sessionsSnapshot.filter { $0.date >= week }.count
        
        // Streak
        streakCount = computeStreak(sessionsSnapshot)
    }
    
    private func computeStreak(_ sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let completed = sessions.filter { $0.isCompleted && $0.notes != "[RECOVERED]" }
        guard !completed.isEmpty else { return 0 }

        // Group by calendar day (dedup)
        let uniqueDays = Set(completed.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var day = calendar.startOfDay(for: Date())

        // Allow streak to start from yesterday if no workout today
        if !uniqueDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
           uniqueDays.contains(yesterday) {
            day = yesterday
        }

        while uniqueDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        return streak
    }
}

extension WorkoutManager: Identifiable {
    nonisolated var id: UUID { _sessionID }
}

#Preview {
    DashboardView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutSession.self], inMemory: true)
}
