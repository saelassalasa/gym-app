import SwiftUI
import SwiftData
import EventKit

// ═══════════════════════════════════════════════════════════════════════════
// PLAN VIEW MODEL - BACKGROUND AGGREGATOR
// ALL I/O happens off the main thread. UI receives pre-computed state.
// ═══════════════════════════════════════════════════════════════════════════

@MainActor
@Observable
final class PlanViewModel {
    
    // MARK: - Published State (UI reads this)
    private(set) var dayStates: [Date: DayState] = [:]
    private(set) var isLoading = false
    private(set) var displayedMonth = Date()
    private(set) var lastUpdate = UUID() // Force render trigger
    
    // MARK: - Dependencies
    private let eventStore = EKEventStore()
    private var hasCalendarAccess = false
    private let eventPrefix = "[IRON]"
    
    // MARK: - Day State (Pre-computed)
    enum DayState: Hashable {
        case empty
        case completed(initial: String)
        case scheduled
    }
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Calendar Access
    
    func requestCalendarAccess() async {
        do {
            if #available(iOS 17.0, *) {
                hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
            } else {
                hasCalendarAccess = try await eventStore.requestAccess(to: .event)
            }
        } catch {
            hasCalendarAccess = false
        }
    }
    
    // MARK: - Month Navigation
    
    func shiftMonth(_ offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
    
    // MARK: - Background Data Aggregation
    
    func loadMonthData(sessions: [WorkoutSession]) async {
        isLoading = true
        
        // Capture values for background work
        let month = displayedMonth
        let calendar = Calendar.current
        
        // Get month bounds
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            isLoading = false
            return
        }
        
        // Buffer: include ±1 month for edge days
        let start = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) ?? monthInterval.start
        let end = calendar.date(byAdding: .month, value: 1, to: monthInterval.end) ?? monthInterval.end
        
        // BATCH 1: Process SwiftData sessions (already on main thread via @Query)
        var states: [Date: DayState] = [:]
        
        for session in sessions where session.isCompleted {
            let dayStart = calendar.startOfDay(for: session.date)
            if dayStart >= start && dayStart <= end {
                let initial = session.template?.name.prefix(1).uppercased() ?? "✓"
                states[dayStart] = .completed(initial: String(initial))
            }
        }
        
        // BATCH 2: Fetch EventKit events (background-safe call)
        if hasCalendarAccess {
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            let events = eventStore.events(matching: predicate)
            
            for event in events {
                guard event.title?.hasPrefix(eventPrefix) == true else { continue }
                let dayStart = calendar.startOfDay(for: event.startDate)
                // Don't overwrite completed with scheduled
                if states[dayStart] == nil {
                    states[dayStart] = .scheduled
                }
            }
        }
        
        // Update UI state (already on MainActor)
        self.dayStates = states
        self.lastUpdate = UUID() // Force grid re-render
        self.isLoading = false
    }
    
    // MARK: - Schedule Workout
    
    func scheduleWorkout(templateName: String, date: Date, sessions: [WorkoutSession]) async -> Bool {
        if !hasCalendarAccess {
            await requestCalendarAccess()
            if !hasCalendarAccess { return false }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(eventPrefix) \(templateName.uppercased())"
        event.startDate = date
        event.endDate = date.addingTimeInterval(90 * 60) // 90 minutes
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            // Reload month data
            await loadMonthData(sessions: sessions)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Generate Month Days
    
    func generateMonthDays() -> [Date?] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        // Adjust for Monday start (iOS uses Sunday = 1)
        let leadingEmpty = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? monthInterval.end
        }
        
        // Pad to complete final week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    // MARK: - Month String
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM YYYY"
        return formatter.string(from: displayedMonth).uppercased()
    }
}
