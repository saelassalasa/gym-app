import Foundation

// MARK: - Biomechanics Engine
// Maps exercises to weighted muscle activations for heatmap rendering.
// Intensity values: 1.0 = prime mover, 0.6 = major synergist, 0.3 = stabilizer

enum BiomechanicsEngine {

    typealias ActivationMap = [MuscleGroup: Double]

    /// Compute normalized muscle heatmap from a list of completed sets.
    /// Returns [MuscleGroup: 0.0–1.0] where 1.0 = most stimulated muscle.
    static func heatmap(from sets: [WorkoutSet]) -> ActivationMap {
        var raw: ActivationMap = [:]
        for s in sets {
            guard let ex = s.exercise else { continue }
            let volume = Double(s.reps) * s.weight
            let rpeMultiplier = rpeWeight(s.rpe)
            let activations = muscleActivation(for: ex)
            for (muscle, intensity) in activations {
                raw[muscle, default: 0] += volume * intensity * rpeMultiplier
            }
        }
        let peak = raw.values.max() ?? 1.0
        guard peak > 0 else { return [:] }
        return raw.mapValues { $0 / peak }
    }

    /// RPE weighting — harder sets contribute more stimulus
    private static func rpeWeight(_ rpe: Int?) -> Double {
        switch rpe ?? 7 {
        case 10:    return 1.2
        case 9:     return 1.1
        case 8:     return 1.0
        case 7:     return 0.85
        case 6:     return 0.7
        default:    return 0.5
        }
    }

    /// Returns muscle activation pattern for an exercise.
    /// First checks the named exercise registry, then falls back to category-based estimation.
    static func muscleActivation(for exercise: Exercise) -> ActivationMap {
        let key = exercise.name.lowercased().trimmingCharacters(in: .whitespaces)
        if let known = exerciseRegistry[key] { return known }

        // Fuzzy match: longest matching key wins (deterministic)
        let match = exerciseRegistry
            .filter { key.contains($0.key) || $0.key.contains(key) }
            .max(by: { $0.key.count < $1.key.count })
        if let match { return match.value }

        // Fallback: category-based estimation
        return categoryFallback(for: exercise)
    }

    // MARK: - Category Fallback

    private static func categoryFallback(for exercise: Exercise) -> ActivationMap {
        let primary = exercise.resolvedPrimaryMuscle
        let isCompound = exercise.resolvedExerciseType == .compound

        guard isCompound else {
            return [primary: 1.0]
        }

        switch exercise.category {
        case .push:
            return [primary: 1.0]
                .merging([.chest: 0.5, .shoulders: 0.5, .triceps: 0.4]) { max($0, $1) }
        case .pull:
            return [primary: 1.0]
                .merging([.back: 0.5, .biceps: 0.4]) { max($0, $1) }
        case .legs:
            return [primary: 1.0]
                .merging([.quads: 0.4, .hamstrings: 0.35, .glutes: 0.4]) { max($0, $1) }
        default:
            return [primary: 1.0]
        }
    }

    // MARK: - Exercise Registry
    // Comprehensive dictionary: exercise name (lowercased) → [MuscleGroup: intensity]
    // Intensity scale: 1.0 prime mover, 0.6 major synergist, 0.3 stabilizer/minor

    static let exerciseRegistry: [String: ActivationMap] = {
        var r: [String: ActivationMap] = [:]

        // ═══════════════════════════════════════
        // CHEST — Push
        // ═══════════════════════════════════════

        let benchPress: ActivationMap = [.chest: 1.0, .shoulders: 0.5, .triceps: 0.6]
        r["bench press"] = benchPress
        r["bench"] = benchPress
        r["flat bench"] = benchPress
        r["barbell bench press"] = benchPress
        r["bb bench"] = benchPress

        let inclineBench: ActivationMap = [.chest: 0.9, .shoulders: 0.7, .triceps: 0.5]
        r["incline bench press"] = inclineBench
        r["incline bench"] = inclineBench
        r["incline barbell press"] = inclineBench
        r["incline press"] = inclineBench

        let declineBench: ActivationMap = [.chest: 1.0, .shoulders: 0.3, .triceps: 0.6]
        r["decline bench press"] = declineBench
        r["decline bench"] = declineBench

        let dbBench: ActivationMap = [.chest: 1.0, .shoulders: 0.5, .triceps: 0.4]
        r["dumbbell bench press"] = dbBench
        r["db bench press"] = dbBench
        r["dumbbell press"] = dbBench
        r["db press"] = dbBench
        r["db bench"] = dbBench

        let inclineDB: ActivationMap = [.chest: 0.9, .shoulders: 0.6, .triceps: 0.4]
        r["incline dumbbell press"] = inclineDB
        r["incline db press"] = inclineDB

        let chestFly: ActivationMap = [.chest: 1.0, .shoulders: 0.3]
        r["chest fly"] = chestFly
        r["dumbbell fly"] = chestFly
        r["db fly"] = chestFly
        r["flat fly"] = chestFly
        r["pec fly"] = chestFly
        r["machine fly"] = chestFly
        r["pec deck"] = chestFly

        let inclineFly: ActivationMap = [.chest: 0.9, .shoulders: 0.4]
        r["incline fly"] = inclineFly
        r["incline dumbbell fly"] = inclineFly
        r["incline db fly"] = inclineFly

        let cableCross: ActivationMap = [.chest: 1.0, .shoulders: 0.3, .core: 0.2]
        r["cable crossover"] = cableCross
        r["cable fly"] = cableCross
        r["cable chest fly"] = cableCross

        let dip: ActivationMap = [.chest: 0.8, .triceps: 0.8, .shoulders: 0.4]
        r["dip"] = dip
        r["dips"] = dip
        r["chest dip"] = dip
        r["weighted dip"] = dip
        r["weighted dips"] = dip

        let pushUp: ActivationMap = [.chest: 0.8, .triceps: 0.5, .shoulders: 0.4, .core: 0.3]
        r["push up"] = pushUp
        r["push-up"] = pushUp
        r["pushup"] = pushUp

        // ═══════════════════════════════════════
        // SHOULDERS — Push
        // ═══════════════════════════════════════

        let ohp: ActivationMap = [.shoulders: 1.0, .triceps: 0.6, .chest: 0.3, .core: 0.3]
        r["overhead press"] = ohp
        r["ohp"] = ohp
        r["military press"] = ohp
        r["barbell overhead press"] = ohp
        r["standing press"] = ohp
        r["strict press"] = ohp

        let dbOHP: ActivationMap = [.shoulders: 1.0, .triceps: 0.5, .core: 0.3]
        r["dumbbell overhead press"] = dbOHP
        r["db overhead press"] = dbOHP
        r["seated dumbbell press"] = dbOHP
        r["seated db press"] = dbOHP
        r["arnold press"] = [.shoulders: 1.0, .triceps: 0.4, .chest: 0.3]

        let latRaise: ActivationMap = [.shoulders: 1.0]
        r["lateral raise"] = latRaise
        r["lateral raises"] = latRaise
        r["lat raise"] = latRaise
        r["side raise"] = latRaise
        r["side lateral raise"] = latRaise
        r["db lateral raise"] = latRaise
        r["cable lateral raise"] = latRaise

        let frontRaise: ActivationMap = [.shoulders: 0.9, .chest: 0.3]
        r["front raise"] = frontRaise
        r["front raises"] = frontRaise
        r["front delt raise"] = frontRaise

        let rearDelt: ActivationMap = [.shoulders: 0.9, .back: 0.3]
        r["rear delt fly"] = rearDelt
        r["reverse fly"] = rearDelt
        r["reverse pec deck"] = rearDelt
        r["rear delt raise"] = rearDelt
        r["bent over raise"] = rearDelt
        r["face pull"] = [.shoulders: 0.8, .back: 0.4, .biceps: 0.3]

        let shrug: ActivationMap = [.back: 1.0, .shoulders: 0.3]
        r["shrug"] = shrug
        r["shrugs"] = shrug
        r["barbell shrug"] = shrug
        r["dumbbell shrug"] = shrug
        r["db shrug"] = shrug

        let uprightRow: ActivationMap = [.shoulders: 0.9, .biceps: 0.4, .back: 0.3]
        r["upright row"] = uprightRow
        r["upright rows"] = uprightRow

        // ═══════════════════════════════════════
        // TRICEPS — Push
        // ═══════════════════════════════════════

        let pushdown: ActivationMap = [.triceps: 1.0]
        r["tricep pushdown"] = pushdown
        r["cable pushdown"] = pushdown
        r["rope pushdown"] = pushdown
        r["tricep rope pushdown"] = pushdown
        r["pushdown"] = pushdown
        r["pressdown"] = pushdown

        let skullcrusher: ActivationMap = [.triceps: 1.0, .shoulders: 0.2]
        r["skull crusher"] = skullcrusher
        r["skullcrusher"] = skullcrusher
        r["skull crushers"] = skullcrusher
        r["lying tricep extension"] = skullcrusher
        r["ez bar skull crusher"] = skullcrusher

        let overheadExt: ActivationMap = [.triceps: 1.0, .shoulders: 0.2]
        r["overhead tricep extension"] = overheadExt
        r["overhead extension"] = overheadExt
        r["tricep overhead extension"] = overheadExt
        r["cable overhead extension"] = overheadExt
        r["french press"] = overheadExt

        let tricepDip: ActivationMap = [.triceps: 1.0, .chest: 0.4, .shoulders: 0.3]
        r["tricep dip"] = tricepDip
        r["tricep dips"] = tricepDip
        r["bench dip"] = tricepDip

        let closeGripBench: ActivationMap = [.triceps: 0.9, .chest: 0.6, .shoulders: 0.4]
        r["close grip bench"] = closeGripBench
        r["close grip bench press"] = closeGripBench
        r["cgbp"] = closeGripBench

        let kickback: ActivationMap = [.triceps: 1.0]
        r["tricep kickback"] = kickback
        r["kickback"] = kickback
        r["kickbacks"] = kickback
        r["cable tricep kickback"] = kickback

        // ═══════════════════════════════════════
        // BACK — Pull
        // ═══════════════════════════════════════

        let barbellRow: ActivationMap = [.back: 1.0, .biceps: 0.6, .shoulders: 0.3, .core: 0.3]
        r["barbell row"] = barbellRow
        r["bent over row"] = barbellRow
        r["bb row"] = barbellRow
        r["pendlay row"] = barbellRow

        let dbRow: ActivationMap = [.back: 1.0, .biceps: 0.5, .shoulders: 0.3]
        r["dumbbell row"] = dbRow
        r["db row"] = dbRow
        r["one arm row"] = dbRow
        r["single arm row"] = dbRow

        let cableRow: ActivationMap = [.back: 1.0, .biceps: 0.5, .shoulders: 0.3]
        r["cable row"] = cableRow
        r["seated cable row"] = cableRow
        r["seated row"] = cableRow
        r["low row"] = cableRow

        let latPulldown: ActivationMap = [.back: 1.0, .biceps: 0.6, .shoulders: 0.3]
        r["lat pulldown"] = latPulldown
        r["pulldown"] = latPulldown
        r["lat pull down"] = latPulldown
        r["wide grip pulldown"] = latPulldown
        r["close grip pulldown"] = [.back: 0.9, .biceps: 0.7, .shoulders: 0.3]

        let pullUp: ActivationMap = [.back: 1.0, .biceps: 0.7, .shoulders: 0.3, .core: 0.3]
        r["pull up"] = pullUp
        r["pull-up"] = pullUp
        r["pullup"] = pullUp
        r["chin up"] = [.back: 0.8, .biceps: 0.9, .shoulders: 0.3, .core: 0.3]
        r["chin-up"] = r["chin up"]!
        r["chinup"] = r["chin up"]!
        r["weighted pull up"] = pullUp
        r["weighted chin up"] = r["chin up"]!

        let deadlift: ActivationMap = [.back: 0.8, .hamstrings: 0.7, .glutes: 1.0, .quads: 0.4, .core: 0.6]
        r["deadlift"] = deadlift
        r["conventional deadlift"] = deadlift
        r["barbell deadlift"] = deadlift

        let sumo: ActivationMap = [.glutes: 1.0, .quads: 0.6, .hamstrings: 0.5, .back: 0.6, .core: 0.5]
        r["sumo deadlift"] = sumo

        let rdl: ActivationMap = [.hamstrings: 1.0, .glutes: 0.8, .back: 0.5, .core: 0.4]
        r["romanian deadlift"] = rdl
        r["rdl"] = rdl
        r["stiff leg deadlift"] = rdl
        r["dumbbell rdl"] = rdl
        r["db rdl"] = rdl

        let tBarRow: ActivationMap = [.back: 1.0, .biceps: 0.5, .shoulders: 0.3, .core: 0.3]
        r["t-bar row"] = tBarRow
        r["t bar row"] = tBarRow

        let machineRow: ActivationMap = [.back: 1.0, .biceps: 0.4]
        r["machine row"] = machineRow
        r["chest supported row"] = machineRow

        let straightArmPull: ActivationMap = [.back: 1.0, .core: 0.3]
        r["straight arm pulldown"] = straightArmPull
        r["straight arm pushdown"] = straightArmPull
        r["pullover"] = [.back: 0.8, .chest: 0.5, .core: 0.3]

        // ═══════════════════════════════════════
        // BICEPS — Pull
        // ═══════════════════════════════════════

        let bbCurl: ActivationMap = [.biceps: 1.0]
        r["barbell curl"] = bbCurl
        r["bb curl"] = bbCurl
        r["ez bar curl"] = bbCurl
        r["ez curl"] = bbCurl
        r["standing curl"] = bbCurl
        r["curl"] = bbCurl

        let dbCurl: ActivationMap = [.biceps: 1.0]
        r["dumbbell curl"] = dbCurl
        r["db curl"] = dbCurl
        r["alternating curl"] = dbCurl
        r["alternating dumbbell curl"] = dbCurl

        let hammerCurl: ActivationMap = [.biceps: 0.8]
        r["hammer curl"] = hammerCurl
        r["hammer curls"] = hammerCurl
        r["db hammer curl"] = hammerCurl
        r["rope hammer curl"] = hammerCurl

        let preacherCurl: ActivationMap = [.biceps: 1.0]
        r["preacher curl"] = preacherCurl
        r["preacher curls"] = preacherCurl
        r["ez bar preacher curl"] = preacherCurl
        r["machine preacher curl"] = preacherCurl
        r["scott curl"] = preacherCurl

        let inclineCurl: ActivationMap = [.biceps: 1.0]
        r["incline curl"] = inclineCurl
        r["incline dumbbell curl"] = inclineCurl
        r["incline db curl"] = inclineCurl

        let cableCurl: ActivationMap = [.biceps: 1.0]
        r["cable curl"] = cableCurl
        r["cable bicep curl"] = cableCurl
        r["bayesian curl"] = cableCurl

        let concentrationCurl: ActivationMap = [.biceps: 1.0]
        r["concentration curl"] = concentrationCurl
        r["concentration curls"] = concentrationCurl

        let spiderCurl: ActivationMap = [.biceps: 1.0]
        r["spider curl"] = spiderCurl
        r["spider curls"] = spiderCurl

        let reverseCurl: ActivationMap = [.biceps: 0.7]
        r["reverse curl"] = reverseCurl
        r["reverse barbell curl"] = reverseCurl
        r["reverse ez curl"] = reverseCurl

        // ═══════════════════════════════════════
        // QUADS — Legs
        // ═══════════════════════════════════════

        let squat: ActivationMap = [.quads: 1.0, .glutes: 0.8, .hamstrings: 0.4, .core: 0.5, .back: 0.3]
        r["squat"] = squat
        r["squats"] = squat
        r["back squat"] = squat
        r["barbell squat"] = squat
        r["bb squat"] = squat

        let frontSquat: ActivationMap = [.quads: 1.0, .glutes: 0.6, .core: 0.6, .back: 0.3]
        r["front squat"] = frontSquat

        let legPress: ActivationMap = [.quads: 1.0, .glutes: 0.6, .hamstrings: 0.3]
        r["leg press"] = legPress

        let hackSquat: ActivationMap = [.quads: 1.0, .glutes: 0.5]
        r["hack squat"] = hackSquat
        r["hack squats"] = hackSquat
        r["machine hack squat"] = hackSquat

        let legExtension: ActivationMap = [.quads: 1.0]
        r["leg extension"] = legExtension
        r["leg extensions"] = legExtension
        r["machine leg extension"] = legExtension

        let gobletSquat: ActivationMap = [.quads: 0.9, .glutes: 0.7, .core: 0.4]
        r["goblet squat"] = gobletSquat
        r["goblet squats"] = gobletSquat

        let bulgarianSplit: ActivationMap = [.quads: 0.9, .glutes: 0.8, .hamstrings: 0.3, .core: 0.3]
        r["bulgarian split squat"] = bulgarianSplit
        r["split squat"] = bulgarianSplit

        let lunge: ActivationMap = [.quads: 0.8, .glutes: 0.7, .hamstrings: 0.4, .core: 0.3]
        r["lunge"] = lunge
        r["lunges"] = lunge
        r["walking lunge"] = lunge
        r["walking lunges"] = lunge
        r["reverse lunge"] = lunge
        r["dumbbell lunge"] = lunge

        let stepUp: ActivationMap = [.quads: 0.8, .glutes: 0.7, .core: 0.3]
        r["step up"] = stepUp
        r["step ups"] = stepUp

        let sissy: ActivationMap = [.quads: 1.0]
        r["sissy squat"] = sissy

        // ═══════════════════════════════════════
        // HAMSTRINGS — Legs
        // ═══════════════════════════════════════

        let legCurl: ActivationMap = [.hamstrings: 1.0]
        r["leg curl"] = legCurl
        r["leg curls"] = legCurl
        r["lying leg curl"] = legCurl
        r["seated leg curl"] = legCurl
        r["hamstring curl"] = legCurl
        r["machine leg curl"] = legCurl
        r["nordic curl"] = [.hamstrings: 1.0, .glutes: 0.3]
        r["nordic ham curl"] = r["nordic curl"]!

        let goodMorning: ActivationMap = [.hamstrings: 0.8, .glutes: 0.7, .back: 0.5, .core: 0.4]
        r["good morning"] = goodMorning
        r["good mornings"] = goodMorning

        // ═══════════════════════════════════════
        // GLUTES — Legs
        // ═══════════════════════════════════════

        let hipThrust: ActivationMap = [.glutes: 1.0, .hamstrings: 0.4, .core: 0.3]
        r["hip thrust"] = hipThrust
        r["hip thrusts"] = hipThrust
        r["barbell hip thrust"] = hipThrust
        r["bb hip thrust"] = hipThrust
        r["glute bridge"] = [.glutes: 1.0, .hamstrings: 0.3]

        let cableKickback: ActivationMap = [.glutes: 1.0, .hamstrings: 0.3]
        r["cable glute kickback"] = cableKickback
        r["glute kickback"] = cableKickback
        r["donkey kick"] = cableKickback

        let hipAbduction: ActivationMap = [.glutes: 1.0]
        r["hip abduction"] = hipAbduction
        r["hip abductions"] = hipAbduction
        r["abduction machine"] = hipAbduction
        r["banded hip abduction"] = hipAbduction

        // ═══════════════════════════════════════
        // CALVES — Legs
        // ═══════════════════════════════════════

        let calfRaise: ActivationMap = [.calves: 1.0]
        r["calf raise"] = calfRaise
        r["calf raises"] = calfRaise
        r["standing calf raise"] = calfRaise
        r["seated calf raise"] = calfRaise
        r["machine calf raise"] = calfRaise
        r["smith machine calf raise"] = calfRaise
        r["donkey calf raise"] = calfRaise

        // ═══════════════════════════════════════
        // CORE
        // ═══════════════════════════════════════

        let crunch: ActivationMap = [.core: 1.0]
        r["crunch"] = crunch
        r["crunches"] = crunch
        r["cable crunch"] = crunch
        r["cable crunches"] = crunch
        r["machine crunch"] = crunch
        r["ab crunch"] = crunch

        let plank: ActivationMap = [.core: 1.0, .shoulders: 0.2]
        r["plank"] = plank
        r["side plank"] = plank
        r["weighted plank"] = plank

        let legRaise: ActivationMap = [.core: 1.0]
        r["leg raise"] = legRaise
        r["leg raises"] = legRaise
        r["hanging leg raise"] = legRaise
        r["hanging leg raises"] = legRaise
        r["knee raise"] = legRaise
        r["captain's chair"] = legRaise

        let abWheel: ActivationMap = [.core: 1.0, .shoulders: 0.3, .back: 0.2]
        r["ab wheel"] = abWheel
        r["ab rollout"] = abWheel

        let woodchop: ActivationMap = [.core: 1.0, .shoulders: 0.3]
        r["woodchop"] = woodchop
        r["cable woodchop"] = woodchop
        r["pallof press"] = [.core: 1.0]
        r["russian twist"] = [.core: 1.0]
        r["sit up"] = [.core: 1.0]
        r["sit-up"] = [.core: 1.0]
        r["situp"] = [.core: 1.0]
        r["decline sit up"] = [.core: 1.0]

        return r
    }()
}
