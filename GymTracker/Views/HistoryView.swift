import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// HISTORY VIEW
// Wireframe session log. Dense data. Full CRUD capabilities.
// ═══════════════════════════════════════════════════════════════════════════

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkoutSession> { $0.isCompleted }, sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var sessionToEdit: WorkoutSession?
    @State private var sessionToDelete: WorkoutSession?
    @State private var showDeleteAlert = false
    @State private var cachedGroupedSessions: [(String, [WorkoutSession])] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, dd MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func recomputeGroupedSessions() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }
        cachedGroupedSessions = grouped.sorted { $0.key > $1.key }.map { (key, sessions) in
            (Self.sectionDateFormatter.string(from: key), sessions)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        sessionList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .alert("DELETE RECORD?", isPresented: $showDeleteAlert) {
            Button("INCINERATE", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
            Button("CANCEL", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("Session and all sets will be permanently destroyed.")
        }
        .sheet(item: $sessionToEdit) { session in
            SessionEditorView(session: session)
        }
        .onAppear { recomputeGroupedSessions() }
        .onChange(of: sessions.count) { recomputeGroupedSessions() }
    }
    
    private var header: some View {
        HStack {
            Text("HISTORY")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            
            Spacer()
            
            Text("\(sessions.count)")
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, Wire.Layout.gap)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("NO DATA")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
                .kerning(2)
            Text("Start a workout from the TRAIN tab")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .padding(.top, Wire.Layout.gap)
            Spacer()
        }
    }
    
    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 4, pinnedViews: []) {
                ForEach(cachedGroupedSessions, id: \.0) { (dateString, daySessions) in
                    Section {
                        ForEach(daySessions) { session in
                            sessionRow(session)
                                .contextMenu {
                                    Button {
                                        sessionToEdit = session
                                    } label: {
                                        Label("EDIT", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        sessionToDelete = session
                                        showDeleteAlert = true
                                    } label: {
                                        Label("DELETE", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(dateString.uppercased())
                            .font(Wire.Font.caption)
                            .foregroundColor(Wire.Color.gray)
                            .kerning(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Wire.Layout.gap)
                    }
                }
            }
            .padding(Wire.Layout.pad)
        }
    }
    
    
    private func sessionRow(_ session: WorkoutSession) -> some View {
        NavigationLink(destination: WorkoutDetailView(session: session)) {
            HStack(spacing: Wire.Layout.gap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.template?.name.uppercased() ?? "—")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .kerning(1)
                    
                    Text(formatDate(session.date))
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.gray)
                }
                
                Spacer()
                
                if let sets = session.sets {
                    let completed = sets.filter { $0.isCompleted && !$0.isSkipped }.count
                    let skipped = sets.filter { $0.isSkipped }.count
                    
                    Text("\(completed)")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                    
                    if skipped > 0 {
                        Text("(\(skipped)⊘)")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.dark)
                    }
                }
                
                if session.isCompleted {
                    Text("✓")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                }
                
                // Navigation arrow
                Text("›")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.gray)
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func deleteSession(_ session: WorkoutSession) {
        Wire.heavy()
        modelContext.delete(session)
        modelContext.saveSafe()
        sessionToDelete = nil
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// SESSION EDITOR VIEW
// Edit historical workout data
// ═══════════════════════════════════════════════════════════════════════════

struct SessionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        sessionInfo
                        setsEditor
                    }
                    .padding(Wire.Layout.pad)
                }
                
                saveButton
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("EDIT SESSION")
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            
            Spacer()
            
            Button("×") { dismiss() }
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    private var sessionInfo: some View {
        WireCell(highlight: true) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.template?.name.uppercased() ?? "WORKOUT")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                
                Text(formatDate(session.date))
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
            }
        }
    }
    
    private var setsEditor: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            Text("SETS [\(session.sets?.count ?? 0)]")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            if let sets = session.sets?.sorted(by: { $0.timestamp < $1.timestamp }) {
                ForEach(sets, id: \.id) { set in
                    SetEditorRow(set: set, onDelete: {
                        deleteSet(set)
                    })
                }
            }
        }
    }
    
    private var saveButton: some View {
        WireButton("SAVE", inverted: true) {
            save()
        }
        .padding(Wire.Layout.pad)
    }
    
    private func save() {
        Wire.heavy()
        modelContext.saveSafe()
        dismiss()
    }
    
    private func deleteSet(_ set: WorkoutSet) {
        Wire.tap()
        modelContext.delete(set)
    }
    
    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// SET EDITOR ROW
// Editable row for modifying weight/reps/rpe
// ═══════════════════════════════════════════════════════════════════════════

struct SetEditorRow: View {
    @Bindable var set: WorkoutSet
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: Wire.Layout.gap) {
            Text("\(set.setNumber)")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.gray)
                .frame(width: 24)
            
            // Weight
            TextField("", value: $set.weight, format: .number)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .padding(Wire.Layout.gap)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
                .onChange(of: set.weight) { _, new in
                    if !new.isFinite || new < 0 { set.weight = 0 }
                    if new > 1000 { set.weight = 1000 }
                }

            Text("×")
                .foregroundColor(Wire.Color.gray)

            // Reps
            TextField("", value: $set.reps, format: .number)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .keyboardType(.numberPad)
                .frame(width: 40)
                .padding(Wire.Layout.gap)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
                .onChange(of: set.reps) { _, new in
                    if new < 0 { set.reps = 0 }
                    if new > 100 { set.reps = 100 }
                }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Text("×")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.danger)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(Wire.Layout.gap)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
}
