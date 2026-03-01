import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var calendarManager = CalendarManager.shared
    
    // Query ALL sessions - this is what History tab shows
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var allPrograms: [WorkoutProgram]
    
    // Future count comes from CalendarManager's EventKit data
    private var futurePlanCount: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return calendarManager.scheduledDates.filter { $0 > todayStart }.count
    }
    
    // Safety state
    @State private var showFuturePurgeAlert = false
    @State private var showHistoryWipeAlert = false
    @State private var showFinalConfirmation = false
    @State private var wipeErrorMessage: String?
    
    // API Key state
    @State private var apiKeyInput: String = GeminiService.apiKey ?? ""
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        apiKeySection
                        futureOperationsSection
                        dangerZoneSection
                        
                        Text("V1.0.0 COMMAND PROTOCOL")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.dark)
                            .padding(.top, 40)
                    }
                    .padding(Wire.Layout.pad)
                }
            }
        }
        .task {
            await calendarManager.fetchScheduledDates(for: Date())
        }
        // Alert 1: Future Purge
        .alert("PURGE FUTURE?", isPresented: $showFuturePurgeAlert) {
            Button("ABORT MISSIONS", role: .destructive) {
                purgeFuture()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This will delete \(futurePlanCount) planned workouts from your iOS Calendar.")
        }
        // Alert 2: History Wipe - First Confirmation
        .alert("WIPE ALL HISTORY?", isPresented: $showHistoryWipeAlert) {
            Button("PROCEED TO FINAL CHECK", role: .destructive) {
                showFinalConfirmation = true
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(allSessions.count) logged sessions. All stats will be lost.")
        }
        // Alert 3: History Wipe - FINAL Confirmation
        .alert("⚠️ FINAL CONFIRMATION", isPresented: $showFinalConfirmation) {
            Button("CONFIRM WIPE", role: .destructive) {
                wipeHistory()
            }
            Button("ABORT", role: .cancel) {}
        } message: {
            Text("LAST CHANCE. \(allSessions.count) records will be permanently destroyed.")
        }
        // Alert 4: Wipe Error
        .alert("WIPE FAILED", isPresented: Binding(
            get: { wipeErrorMessage != nil },
            set: { if !$0 { wipeErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(wipeErrorMessage ?? "Unknown error")
        }
    }
    
    private var header: some View {
        HStack {
            Text("COMMAND CENTER")
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
    
    // MARK: - Sections
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GEMINI API")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.white)
                .kerning(1)
            
            Text("Required for image parsing feature.")
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
            
            HStack {
                SecureField("API KEY", text: $apiKeyInput)
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Button {
                    Wire.tap()
                    GeminiService.apiKey = apiKeyInput
                } label: {
                    Text(GeminiService.hasAPIKey() ? "✓" : "SAVE")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Wire.Color.white)
                }
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: 1))
        }
    }
    
    private var futureOperationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FUTURE OPERATIONS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.white)
                .kerning(1)
            
            Text("Manage planned missions in your iOS Calendar.")
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
            
            Button {
                Wire.tap()
                showFuturePurgeAlert = true
            } label: {
                HStack {
                    Text("[ ABORT ALL FUTURE MISSIONS ]")
                    Spacer()
                    Text("\(futurePlanCount)")
                }
                .font(Wire.Font.body)
                .foregroundColor(futurePlanCount == 0 ? Wire.Color.gray : Wire.Color.white)
                .padding(Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(futurePlanCount == 0 ? Wire.Color.dark : Wire.Color.white, lineWidth: 1))
            }
            .disabled(futurePlanCount == 0)
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DANGER ZONE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.danger)
                .kerning(1)
            
            Text("Irreversible data destruction protocols.")
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
            
            Button {
                Wire.heavy()
                showHistoryWipeAlert = true
            } label: {
                HStack {
                    Text("[ WIPE LOG HISTORY ]")
                    Spacer()
                    Text("\(allSessions.count)")
                }
                .font(Wire.Font.body)
                .foregroundColor(allSessions.isEmpty ? Wire.Color.gray : Wire.Color.danger)
                .padding(Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(allSessions.isEmpty ? Wire.Color.dark : Wire.Color.danger, lineWidth: 1))
            }
            .disabled(allSessions.isEmpty)
        }
    }
    
    // MARK: - Actions
    
    private func purgeFuture() {
        Task {
            Wire.heavy()
            let count = await calendarManager.purgeFutureEvents()
            debugLog("☢️ Purged \(count) events from calendar")
            dismiss()
        }
    }
    
    private func wipeHistory() {
        debugLog("🧹 WIPE HISTORY: Starting deletion of \(allSessions.count) sessions...")
        Wire.heavy()

        // Delete all sessions
        for session in allSessions {
            modelContext.delete(session)
        }

        // Reset exercise weights on all templates to defaults
        for program in allPrograms {
            for template in program.orderedTemplates {
                for exercise in template.exercises {
                    exercise.currentWeight = 20.0
                }
            }
        }

        // Force save
        do {
            try modelContext.save()
            debugLog("✅ WIPE COMPLETE: All sessions deleted, weights reset")
            Wire.success()
            dismiss()
        } catch {
            debugLog("❌ WIPE FAILED: \(error)")
            wipeErrorMessage = "Wipe failed: \(error.localizedDescription)"
        }
    }
}
