import Foundation
import Observation
import EventKit

// ═══════════════════════════════════════════════════════════════════════════
// CALENDAR MANAGER - EVENTKIT INTEGRATION
// Handles iOS Calendar synchronization for workout scheduling
// ═══════════════════════════════════════════════════════════════════════════

@MainActor
@Observable
final class CalendarManager {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    private let eventPrefix = "[IRON]"

    private(set) var hasAccess = false
    private(set) var scheduledDates: Set<Date> = []
    
    private init() {}
    
    // ═══════════════════════════════════════════════════════════════════════
    // REQUEST ACCESS
    // ═══════════════════════════════════════════════════════════════════════
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                hasAccess = try await eventStore.requestFullAccessToEvents()
            } else {
                hasAccess = try await eventStore.requestAccess(to: .event)
            }
            print("📅 Calendar access: \(hasAccess ? "GRANTED" : "DENIED")")
            return hasAccess
        } catch {
            print("❌ Calendar access error: \(error)")
            hasAccess = false
            return false
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // SCHEDULE WORKOUT
    // ═══════════════════════════════════════════════════════════════════════
    
    func scheduleWorkout(templateName: String, date: Date, durationMinutes: Int = 90) async -> Bool {
        // Ensure we have access
        if !hasAccess {
            let granted = await requestAccess()
            if !granted {
                print("❌ Cannot schedule: No calendar access")
                return false
            }
        }
        
        // Get a writable calendar
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            print("❌ No default calendar available")
            return false
        }
        
        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(eventPrefix) \(templateName.uppercased())"
        event.startDate = date
        event.endDate = date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.calendar = calendar
        event.notes = "Workout scheduled via GymTracker"
        
        // Add reminder 30 minutes before
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
        
        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("✅ Event saved: \(event.title ?? "Unknown") at \(date)")
            
            // Update local cache
            let dayStart = Calendar.current.startOfDay(for: date)
            scheduledDates.insert(dayStart)
            
            return true
        } catch {
            print("❌ Failed to save event: \(error)")
            return false
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // FETCH SCHEDULED DATES
    // ═══════════════════════════════════════════════════════════════════════
    
    func fetchScheduledDates(for month: Date) async {
        if !hasAccess {
            _ = await requestAccess()
        }
        
        guard hasAccess else {
            print("⚠️ Cannot fetch: No calendar access")
            return
        }
        
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return
        }
        
        // Buffer: ±1 month
        let start = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) ?? monthInterval.start
        let end = calendar.date(byAdding: .month, value: 1, to: monthInterval.end) ?? monthInterval.end
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var scheduled: Set<Date> = []
        for event in events {
            if event.title?.hasPrefix(eventPrefix) == true {
                let dayStart = calendar.startOfDay(for: event.startDate)
                scheduled.insert(dayStart)
            }
        }
        
        scheduledDates = scheduled
        print("📅 Fetched \(scheduled.count) scheduled workouts")
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DELETE SCHEDULED WORKOUT
    // ═══════════════════════════════════════════════════════════════════════
    
    func deleteScheduledWorkout(on date: Date) async -> Bool {
        guard hasAccess else { return false }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        let predicate = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var deletedSomething = false
        for event in events where event.title?.hasPrefix(eventPrefix) == true {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: true)
                print("🗑️ Deleted event: \(event.title ?? "Unknown")")
                deletedSomething = true
            } catch {
                print("❌ Failed to delete: \(error)")
            }
        }
        
        if deletedSomething {
            scheduledDates.remove(dayStart)
        }
        
        return deletedSomething
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // AUTOPILOT: DEPLOY ROUTINE (Bulk Schedule)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// Deploy a routine pattern for the next N weeks
    /// Pattern: Array of template names (nil = rest day)
    /// Example: ["Push", "Pull", "Push", "Pull", nil, "Legs", nil] for 7 days
    func deployRoutine(
        pattern: [String?],
        templateNames: [String],
        startDate: Date = Date(),
        weeks: Int = 4,
        defaultHour: Int = 9
    ) async -> Int {
        guard !pattern.isEmpty else { return 0 }
        
        if !hasAccess {
            _ = await requestAccess()
        }
        guard hasAccess else {
            print("❌ Cannot deploy routine: No calendar access")
            return 0
        }
        
        let calendar = Calendar.current
        var scheduledCount = 0
        let totalDays = weeks * 7
        
        // Start from tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate)) else {
            return 0
        }
        
        for dayOffset in 0..<totalDays {
            let patternIndex = dayOffset % pattern.count
            
            // Skip rest days (nil in pattern)
            guard let templateName = pattern[patternIndex] else {
                print("📅 Day \(dayOffset + 1): REST")
                continue
            }
            
            // Calculate target date
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: tomorrow) else {
                continue
            }
            
            let dayStart = calendar.startOfDay(for: targetDate)
            
            // Skip if already scheduled (no double booking)
            if scheduledDates.contains(dayStart) {
                print("⏭️ Day \(dayOffset + 1): Already scheduled, skipping")
                continue
            }
            
            // Create workout at default hour
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = defaultHour
            components.minute = 0
            let scheduledTime = calendar.date(from: components) ?? targetDate
            
            // Schedule the workout
            let success = await scheduleWorkout(
                templateName: templateName,
                date: scheduledTime
            )
            
            if success {
                scheduledCount += 1
                print("✅ Day \(dayOffset + 1): Scheduled \(templateName)")
            }
        }
        
        print("🎯 AUTOPILOT COMPLETE: Scheduled \(scheduledCount) workouts")
        return scheduledCount
    }
    
    /// Deploy a workout program across selected weekdays
    /// Cycles through templates in order and maps them to selected weekdays
    /// - Parameters:
    ///   - templates: Array of templates (ordered by dayIndex)
    ///   - weekdays: Selected weekday numbers (1=Sunday, 2=Monday, etc)
    ///   - startDate: When to start scheduling
    ///   - weeks: How many weeks to schedule ahead
    /// - Returns: Number of workouts scheduled
    func deployProgram(
        templates: [WorkoutTemplate],
        weekdays: [Int] = [2, 3, 4, 5, 6], // Default: Mon-Fri
        startDate: Date = Date(),
        weeks: Int = 4,
        defaultHour: Int = 9
    ) async -> Int {
        guard !templates.isEmpty, !weekdays.isEmpty else { return 0 }
        
        if !hasAccess {
            _ = await requestAccess()
        }
        guard hasAccess else {
            print("❌ Cannot deploy program: No calendar access")
            return 0
        }
        
        let calendar = Calendar.current
        let sortedTemplates = templates.sorted { $0.dayIndex < $1.dayIndex }
        var scheduledCount = 0
        
        // Start from tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate)) else {
            return 0
        }
        
        var currentTemplateIndex = 0
        var currentDate = tomorrow
        let endDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: tomorrow) ?? tomorrow
        
        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            // Check if this weekday is selected for training
            if weekdays.contains(weekday) {
                let dayStart = calendar.startOfDay(for: currentDate)
                
                // Skip if already scheduled
                if !scheduledDates.contains(dayStart) {
                    let template = sortedTemplates[currentTemplateIndex % sortedTemplates.count]
                    
                    // Create workout at default hour
                    var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                    components.hour = defaultHour
                    components.minute = 0
                    let scheduledTime = calendar.date(from: components) ?? currentDate
                    
                    let success = await scheduleWorkout(
                        templateName: template.name,
                        date: scheduledTime
                    )
                    
                    if success {
                        scheduledCount += 1
                        currentTemplateIndex += 1
                        print("✅ Scheduled \\(template.name) on \\(currentDate)")
                    }
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        print("🎯 AUTOPILOT COMPLETE: Scheduled \\(scheduledCount) workouts from \\(sortedTemplates.count)-day program")
        return scheduledCount
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PURGE FUTURE EVENTS
    // ═══════════════════════════════════════════════════════════════════════
    
    func purgeFutureEvents() async -> Int {
        guard hasAccess else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let farFuture = calendar.date(byAdding: .month, value: 12, to: tomorrow) ?? tomorrow
        
        let predicate = eventStore.predicateForEvents(withStart: tomorrow, end: farFuture, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var deletedCount = 0
        for event in events where event.title?.hasPrefix(eventPrefix) == true {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: true)
                deletedCount += 1
            } catch {
                print("❌ Failed to purge event: \(error)")
            }
        }
        
        // Refresh local cache (crude but effective)
        await fetchScheduledDates(for: now)
        
        print("☢️ PURGED \(deletedCount) future events from calendar")
        return deletedCount
    }
}
