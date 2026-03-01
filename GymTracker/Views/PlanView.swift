import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// PLAN VIEW - SIMPLE CALENDAR 2.0 + DATA SYNC
// ═══════════════════════════════════════════════════════════════════════════

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var templates: [WorkoutTemplate]
    
    // Calendar Manager - Singleton
    @State private var calendarManager = CalendarManager.shared
    
    // SINGLE STATE TRIGGER - If non-nil, sheet is open
    @State private var selectedDate: Date?
    
    // Display state
    @State private var displayedMonth = Date()
    @State private var isLoading = false
    
    // Pre-computed data
    @State private var weeks: [[Date?]] = []
    @State private var completedDays: Set<Date> = []
    @State private var refreshTrigger = UUID()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM YYYY"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let commandDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    // Command menu state
    @State private var dateToAdjust: Date?
    @State private var showAdjustmentDialog = false
    
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    
    // ═══════════════════════════════════════════════════════════════════════
    // BODY - Sheet attached at ROOT level
    // ═══════════════════════════════════════════════════════════════════════
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            mainContent
        }
        // SHEET AT ROOT - Outside everything else
        .sheet(item: $selectedDate) { date in
            SchedulerSheet(date: date, templates: templates) { name, time in
                Task {
                    await scheduleWorkout(templateName: name, date: time)
                }
            }
        }
        .onAppear {
            debugLog("📱 PlanView appeared")
            regenerateWeeks()
            Task {
                await loadAllData()
            }
        }
        .onChange(of: displayedMonth) { _, _ in
            regenerateWeeks()
            Task {
                await loadAllData()
            }
        }
        .onChange(of: sessions.count) { _, _ in
            loadCompletedDays()
        }
        .confirmationDialog(
            "COMMAND: \(dateToAdjust != nil ? formatDateForCommand(dateToAdjust!) : "")",
            isPresented: $showAdjustmentDialog,
            titleVisibility: .visible
        ) {
            Button("[ CHANGE MISSION ]") {
                if let date = dateToAdjust {
                    Wire.tap()
                    selectedDate = date
                }
            }
            
            Button("[ ABORT MISSION ]", role: .destructive) {
                if let date = dateToAdjust {
                    Task {
                        Wire.heavy()
                        let _ = await calendarManager.deleteScheduledWorkout(on: date)
                        await loadAllData()
                    }
                }
            }
            
            Button("CANCEL", role: .cancel) {
                dateToAdjust = nil
            }
        } message: {
            Text("Modify or terminate the current objective.")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MAIN CONTENT
    // ═══════════════════════════════════════════════════════════════════════
    
    private var mainContent: some View {
        GeometryReader { geo in
            let cellWidth = (geo.size.width - 32 - 12) / 7
            
            VStack(spacing: 0) {
                header
                monthNavigation
                weekdayRow(cellWidth: cellWidth)
                
                ScrollView(.vertical, showsIndicators: false) {
                    calendarGrid(cellWidth: cellWidth)
                        .id(refreshTrigger) // Force refresh when data changes
                }
                
                legend
                Spacer(minLength: 0)
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════════════════
    
    private var header: some View {
        HStack {
            Text("DISCIPLINE GRID")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
            
            if isLoading {
                Text("...")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
            }
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, Wire.Layout.gap)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MONTH NAVIGATION
    // ═══════════════════════════════════════════════════════════════════════
    
    private var monthNavigation: some View {
        HStack {
            Button("◀") {
                Wire.tap()
                if let m = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
                    displayedMonth = m
                }
            }
            .font(Wire.Font.header)
            .foregroundColor(Wire.Color.white)
            .frame(width: 44, height: 44)
            
            Spacer()
            
            Text(monthString)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            
            Spacer()
            
            Button("▶") {
                Wire.tap()
                if let m = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
                    displayedMonth = m
                }
            }
            .font(Wire.Font.header)
            .foregroundColor(Wire.Color.white)
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, Wire.Layout.gap)
    }
    
    private var monthString: String {
        Self.monthFormatter.string(from: displayedMonth).uppercased()
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // WEEKDAY ROW
    // ═══════════════════════════════════════════════════════════════════════
    
    private func weekdayRow(cellWidth: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .frame(width: cellWidth, height: 24)
            }
        }
        .padding(.horizontal, Wire.Layout.pad)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // CALENDAR GRID
    // ═══════════════════════════════════════════════════════════════════════
    
    private func calendarGrid(cellWidth: CGFloat) -> some View {
        VStack(spacing: 2) {
            ForEach(0..<weeks.count, id: \.self) { weekIdx in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { dayIdx in
                        let date = weeks[safe: weekIdx]?[safe: dayIdx] ?? nil
                        dayCell(date: date, width: cellWidth)
                    }
                }
            }
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, Wire.Layout.gap)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DAY CELL - Shows completed/scheduled/missed/empty state
    // SHAME PROTOCOL: Past scheduled days with no completion = MISSED
    // ═══════════════════════════════════════════════════════════════════════
    
    private func dayCell(date: Date?, width: CGFloat) -> some View {
        Group {
            if let date = date {
                let cal = Calendar.current
                let dayNum = cal.component(.day, from: date)
                let isToday = cal.isDateInToday(date)
                let dayStart = cal.startOfDay(for: date)
                let todayStart = cal.startOfDay(for: Date())
                let isPast = dayStart < todayStart
                let canSchedule = dayStart >= todayStart
                let isCompleted = completedDays.contains(dayStart)
                let isScheduled = calendarManager.scheduledDates.contains(dayStart)
                
                // SHAME PROTOCOL: Detect missed workouts
                let isMissed = isPast && isScheduled && !isCompleted
                
                // Determine cell appearance based on state
                let fillColor: Color = {
                    if isCompleted { return Wire.Color.white }
                    return Wire.Color.black
                }()
                
                let strokeColor: Color = {
                    if isMissed { return Wire.Color.danger } // RED for shame
                    if isToday { return Wire.Color.white }
                    if isScheduled { return Wire.Color.white }
                    return Wire.Color.dark
                }()
                
                let strokeWidth: CGFloat = {
                    if isMissed { return 2 }
                    if isToday { return 2 }
                    return 1
                }()
                
                let textColor: Color = {
                    if isCompleted { return Wire.Color.black }
                    if isMissed { return Wire.Color.danger }
                    return Wire.Color.white
                }()
                
                // Cell indicator
                let indicator: String? = {
                    if isCompleted {
                        if let session = sessions.first(where: { cal.startOfDay(for: $0.date) == dayStart && $0.isCompleted }) {
                            return String(session.template?.name.prefix(1).uppercased() ?? "✓")
                        }
                        return "✓"
                    } else if isMissed {
                        return "✗" // SHAME: X for missed
                    } else if isScheduled {
                        return "○"
                    }
                    return nil
                }()
                
                ZStack {
                    Rectangle()
                        .fill(fillColor)
                    
                    Rectangle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                    
                    // Diagonal strike-through for missed
                    if isMissed {
                        Path { path in
                            path.move(to: CGPoint(x: 4, y: 4))
                            path.addLine(to: CGPoint(x: width - 4, y: width - 4))
                        }
                        .stroke(Wire.Color.danger.opacity(0.4), lineWidth: 1)
                    }
                    
                    VStack(spacing: 0) {
                        Text("\(dayNum)")
                            .font(Wire.Font.caption)
                            .foregroundColor(textColor)
                        
                        if let indicator = indicator {
                            Text(indicator)
                                .font(Wire.Font.tiny)
                                .foregroundColor(isMissed ? Wire.Color.danger : (isCompleted ? Wire.Color.dark : Wire.Color.gray))
                        }
                    }
                }
                .frame(width: width, height: width)
                .contentShape(Rectangle())
                .onTapGesture {
                    debugLog("👆 Tap detected on \(date)")
                    
                    if isCompleted {
                        debugLog("✅ Already completed, ignoring")
                        return
                    }
                    
                    if isScheduled || isMissed {
                        debugLog("⚖️ Planned/Missed detected, opening command menu")
                        Wire.tap()
                        dateToAdjust = date
                        showAdjustmentDialog = true
                    } else if canSchedule {
                        debugLog("✅ Opening sheet for \(date)")
                        Wire.tap()
                        selectedDate = date
                    } else {
                        debugLog("❌ Past date, ignoring")
                    }
                }
            } else {
                Rectangle()
                    .fill(Wire.Color.black)
                    .frame(width: width, height: width)
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // LEGEND
    // ═══════════════════════════════════════════════════════════════════════
    
    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Rectangle().fill(Wire.Color.white).frame(width: 14, height: 14)
                Text("DONE").font(Wire.Font.tiny).foregroundColor(Wire.Color.gray)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Wire.Color.black).frame(width: 14, height: 14)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
                Text("PLAN").font(Wire.Font.tiny).foregroundColor(Wire.Color.gray)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Wire.Color.black).frame(width: 14, height: 14)
                    .overlay(Rectangle().stroke(Wire.Color.danger, lineWidth: 1))
                Text("MISS").font(Wire.Font.tiny).foregroundColor(Wire.Color.danger)
            }
        }
        .padding(Wire.Layout.pad)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DATA LOADING
    // ═══════════════════════════════════════════════════════════════════════
    
    private func loadAllData() async {
        isLoading = true
        
        // Request calendar access and fetch scheduled dates
        await calendarManager.fetchScheduledDates(for: displayedMonth)
        
        // Load completed days from SwiftData
        loadCompletedDays()
        
        isLoading = false
        refreshTrigger = UUID() // Force UI refresh
        debugLog("🔄 Data loaded, triggering refresh")
    }
    
    private func regenerateWeeks() {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday else {
            weeks = []
            return
        }
        
        let leadingEmpty = (firstWeekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        
        var current = interval.start
        while current < interval.end {
            days.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current) ?? interval.end
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        var result: [[Date?]] = []
        for i in stride(from: 0, to: days.count, by: 7) {
            result.append(Array(days[i..<min(i+7, days.count)]))
        }
        
        weeks = result
        debugLog("📆 Regenerated \(result.count) weeks for \(monthString)")
    }
    
    private func loadCompletedDays() {
        let cal = Calendar.current
        var completed: Set<Date> = []
        
        for session in sessions where session.isCompleted {
            let dayStart = cal.startOfDay(for: session.date)
            completed.insert(dayStart)
        }
        
        completedDays = completed
        debugLog("✅ Loaded \(completed.count) completed days")
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCHEDULE WORKOUT (EventKit + Grid Refresh)
    // ═══════════════════════════════════════════════════════════════════════
    
    private func scheduleWorkout(templateName: String, date: Date) async {
        debugLog("📅 Scheduling: \(templateName) at \(date)")
        
        // Ensure no double booking (cleanup old plan if exists)
        let _ = await calendarManager.deleteScheduledWorkout(on: date)
        
        let success = await calendarManager.scheduleWorkout(
            templateName: templateName,
            date: date
        )
        
        if success {
            debugLog("✅ Workout scheduled successfully")
            Wire.success()
            
            // Refresh the grid to show the new scheduled date
            await MainActor.run {
                refreshTrigger = UUID()
            }
        } else {
            debugLog("❌ Failed to schedule workout")
        }
    }
    
    private func formatDateForCommand(_ d: Date) -> String {
        Self.commandDateFormatter.string(from: d).uppercased()
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// SAFE ARRAY ACCESS
// ═══════════════════════════════════════════════════════════════════════════

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATE EXTENSION FOR SHEET ITEM
// ═══════════════════════════════════════════════════════════════════════════

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULER SHEET
// ═══════════════════════════════════════════════════════════════════════════

struct SchedulerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calendarManager = CalendarManager.shared

    let date: Date
    let templates: [WorkoutTemplate]
    let onSchedule: (String, Date) -> Void
    
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var hour: Int = 9
    @State private var minute: Int = 0
    
    // Autopilot state
    @State private var isDeploying = false
    @State private var deployedCount = 0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        dateSection
                        timeSection
                        templateSection
                        
                        // Divider
                        Rectangle()
                            .fill(Wire.Color.dark)
                            .frame(height: 2)
                            .padding(.vertical, Wire.Layout.gap)
                        
                        // Autopilot Section
                        autopilotSection
                    }
                    .padding(Wire.Layout.pad)
                    .padding(.bottom, 100)
                }
                
                deployButton
            }
        }
        .onAppear {
            debugLog("📋 SchedulerSheet appeared for \(date)")
        }
    }
    
    private var header: some View {
        HStack {
            Text("SCHEDULE OP")
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
            Button("×") { dismiss() }
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
    }
    
    private var dateSection: some View {
        HStack {
            Text("DATE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
            Spacer()
            Text(formatDate(date))
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
        }
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIME")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
            
            HStack(spacing: 16) {
                // Hour stepper
                HStack(spacing: 0) {
                    Button("-") { if hour > 0 { hour -= 1 } }
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 40, height: 40)
                    
                    Text(String(format: "%02d", hour))
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 50)
                    
                    Button("+") { if hour < 23 { hour += 1 } }
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 40, height: 40)
                }
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
                
                Text(":")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.gray)
                
                // Minute stepper
                HStack(spacing: 0) {
                    Button("-") { minute = max(0, minute - 15) }
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 40, height: 40)
                    
                    Text(String(format: "%02d", minute))
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 50)
                    
                    Button("+") { minute = min(45, minute + 15) }
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 40, height: 40)
                }
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
                
                Spacer()
            }
        }
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
    }
    
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEMPLATE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
            
            ForEach(templates) { t in
                Button {
                    Wire.tap()
                    selectedTemplate = t
                } label: {
                    HStack {
                        Text(t.name.uppercased())
                            .font(Wire.Font.body)
                            .foregroundColor(selectedTemplate?.id == t.id ? Wire.Color.black : Wire.Color.white)
                        Spacer()
                        Text("\(t.exercises.count)")
                            .font(Wire.Font.body)
                            .foregroundColor(selectedTemplate?.id == t.id ? Wire.Color.black : Wire.Color.gray)
                    }
                    .padding(Wire.Layout.pad)
                    .background(selectedTemplate?.id == t.id ? Wire.Color.white : Wire.Color.black)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
                }
            }
        }
        .padding(Wire.Layout.pad)
    }
    
    private var deployButton: some View {
        Button {
            guard let t = selectedTemplate else { return }
            
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            let finalDate = Calendar.current.date(from: components) ?? date
            
            debugLog("🚀 Deploying: \(t.name) at \(finalDate)")
            Wire.heavy()
            onSchedule(t.name, finalDate)
            dismiss()
        } label: {
            Text("DEPLOY")
                .font(Wire.Font.body)
                .kerning(2)
                .foregroundColor(selectedTemplate != nil ? Wire.Color.black : Wire.Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Wire.Layout.pad)
                .background(selectedTemplate != nil ? Wire.Color.white : Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
        }
        .disabled(selectedTemplate == nil)
        .padding(Wire.Layout.pad)
    }
    
    private func formatDate(_ d: Date) -> String {
        Self.dateFormatter.string(from: d).uppercased()
    }
    
    // MARK: - Autopilot Section (N-Day Program Support)
    
    private var autopilotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⚡ AUTOPILOT")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                
                Spacer()
                
                Text("4 WEEKS")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
            
            if templates.isEmpty {
                Text("No templates available")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
            } else {
                Text("Deploy all \(templates.count) templates across weekdays")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                
                // Show templates that will be cycled
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRAM ROTATION:")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                    
                    let sortedTemplates = templates.sorted { $0.dayIndex < $1.dayIndex }
                    ForEach(Array(sortedTemplates.enumerated()), id: \.offset) { index, template in
                        HStack {
                            Text("\(index + 1).")
                                .font(Wire.Font.tiny)
                                .foregroundColor(Wire.Color.dark)
                                .frame(width: 20, alignment: .leading)
                            Text(template.name.uppercased())
                                .font(Wire.Font.caption)
                                .foregroundColor(Wire.Color.white)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(Wire.Layout.gap)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: 1))
                
                // Deploy Button
                Button {
                    isDeploying = true
                    
                    Task {
                        let sortedTemplates = templates.sorted { $0.dayIndex < $1.dayIndex }
                        // Default: Mon-Fri (weekday numbers: 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri)
                        let count = await calendarManager.deployProgram(
                            templates: sortedTemplates,
                            weekdays: [2, 3, 4, 5, 6],
                            weeks: 4
                        )
                        deployedCount = count
                        isDeploying = false
                        Wire.success()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if isDeploying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Wire.Color.black))
                            Text("DEPLOYING...")
                        } else if deployedCount > 0 {
                            Text("✓ \(deployedCount) SCHEDULED")
                        } else {
                            Text("[ DEPLOY MON-FRI ]")
                        }
                    }
                    .font(Wire.Font.body)
                    .kerning(1)
                    .foregroundColor(!templates.isEmpty ? Wire.Color.black : Wire.Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Wire.Layout.pad)
                    .background(!templates.isEmpty ? Wire.Color.white : Wire.Color.black)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
                }
                .disabled(templates.isEmpty || isDeploying)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
    }
}
