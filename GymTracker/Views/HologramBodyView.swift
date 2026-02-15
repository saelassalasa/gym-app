import SwiftUI
import SceneKit

// MARK: - Hologram Body View

struct HologramBodyView: UIViewRepresentable {
    let muscleVolumes: [MuscleGroup: Double]

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.scene = HologramBodyBuilder.buildScene(muscleVolumes: muscleVolumes)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let scene = scnView.scene else { return }
        HologramBodyBuilder.updateIntensities(scene: scene, muscleVolumes: muscleVolumes)
    }
}

// MARK: - Hologram Body Builder

enum HologramBodyBuilder {

    // Node name → MuscleGroup mapping
    static let nodeMapping: [MuscleGroup: [String]] = [
        .chest:      ["chest_L", "chest_R"],
        .back:       ["back_upper", "back_lower"],
        .shoulders:  ["shoulder_L", "shoulder_R"],
        .biceps:     ["bicep_L", "bicep_R"],
        .triceps:    ["tricep_L", "tricep_R"],
        .quads:      ["quad_L", "quad_R"],
        .hamstrings: ["ham_L", "ham_R"],
        .glutes:     ["glute_L", "glute_R"],
        .calves:     ["calf_L", "calf_R"],
        .core:       ["core_front"],
    ]

    // MARK: - Build Scene

    static func buildScene(muscleVolumes: [MuscleGroup: Double]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Camera — centered on body midpoint
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 36
        // Bloom approximation via HDR + bloom threshold
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.8
        cameraNode.camera?.bloomThreshold = 0.4
        cameraNode.camera?.bloomBlurRadius = 12.0
        cameraNode.position = SCNVector3(0, 0.45, 2.4)
        cameraNode.look(at: SCNVector3(0, 0.45, 0))
        scene.rootNode.addChildNode(cameraNode)

        // No scene lights needed — constant lighting uses emission only

        // Build body
        let body = buildBody()
        scene.rootNode.addChildNode(body)

        updateIntensities(scene: scene, muscleVolumes: muscleVolumes)
        return scene
    }

    // MARK: - Build Primitive Body

    private static func buildBody() -> SCNNode {
        let root = SCNNode()

        // Head
        root.addChildNode(capsule(name: "head", w: 0.11, h: 0.15, pos: v3(0, 1.05, 0)))
        // Neck
        root.addChildNode(cylinder(name: "neck", r: 0.035, h: 0.08, pos: v3(0, 0.93, 0)))

        // Chest
        root.addChildNode(box(name: "chest_L", w: 0.14, h: 0.17, d: 0.09, pos: v3(-0.075, 0.75, 0.02)))
        root.addChildNode(box(name: "chest_R", w: 0.14, h: 0.17, d: 0.09, pos: v3(0.075, 0.75, 0.02)))

        // Core
        root.addChildNode(box(name: "core_front", w: 0.22, h: 0.18, d: 0.07, pos: v3(0, 0.53, 0.02)))

        // Back
        root.addChildNode(box(name: "back_upper", w: 0.26, h: 0.17, d: 0.07, pos: v3(0, 0.75, -0.05)))
        root.addChildNode(box(name: "back_lower", w: 0.22, h: 0.14, d: 0.07, pos: v3(0, 0.53, -0.05)))

        // Shoulders
        root.addChildNode(sphere(name: "shoulder_L", r: 0.065, pos: v3(-0.21, 0.86, 0)))
        root.addChildNode(sphere(name: "shoulder_R", r: 0.065, pos: v3(0.21, 0.86, 0)))

        // Biceps / Triceps
        root.addChildNode(capsule(name: "bicep_L", w: 0.04, h: 0.18, pos: v3(-0.24, 0.68, 0.015)))
        root.addChildNode(capsule(name: "bicep_R", w: 0.04, h: 0.18, pos: v3(0.24, 0.68, 0.015)))
        root.addChildNode(capsule(name: "tricep_L", w: 0.038, h: 0.18, pos: v3(-0.24, 0.68, -0.015)))
        root.addChildNode(capsule(name: "tricep_R", w: 0.038, h: 0.18, pos: v3(0.24, 0.68, -0.015)))

        // Forearms (visual only, mapped to biceps for simplicity)
        root.addChildNode(capsule(name: "forearm_L", w: 0.03, h: 0.16, pos: v3(-0.24, 0.50, 0)))
        root.addChildNode(capsule(name: "forearm_R", w: 0.03, h: 0.16, pos: v3(0.24, 0.50, 0)))

        // Quads / Hamstrings
        root.addChildNode(capsule(name: "quad_L", w: 0.07, h: 0.28, pos: v3(-0.09, 0.22, 0.015)))
        root.addChildNode(capsule(name: "quad_R", w: 0.07, h: 0.28, pos: v3(0.09, 0.22, 0.015)))
        root.addChildNode(capsule(name: "ham_L", w: 0.065, h: 0.26, pos: v3(-0.09, 0.22, -0.015)))
        root.addChildNode(capsule(name: "ham_R", w: 0.065, h: 0.26, pos: v3(0.09, 0.22, -0.015)))

        // Glutes
        root.addChildNode(sphere(name: "glute_L", r: 0.075, pos: v3(-0.085, 0.38, -0.035)))
        root.addChildNode(sphere(name: "glute_R", r: 0.075, pos: v3(0.085, 0.38, -0.035)))

        // Calves
        root.addChildNode(capsule(name: "calf_L", w: 0.04, h: 0.22, pos: v3(-0.09, -0.08, 0)))
        root.addChildNode(capsule(name: "calf_R", w: 0.04, h: 0.22, pos: v3(0.09, -0.08, 0)))

        return root
    }

    // MARK: - Update Intensities

    static func updateIntensities(scene: SCNScene, muscleVolumes: [MuscleGroup: Double]) {
        for (muscle, nodeNames) in nodeMapping {
            let intensity = muscleVolumes[muscle] ?? 0
            for name in nodeNames {
                guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
                node.geometry?.firstMaterial = hologramMaterial(intensity: intensity)
            }
        }
        // Non-mapped structural nodes
        for name in ["head", "neck", "forearm_L", "forearm_R"] {
            guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
            node.geometry?.firstMaterial = hologramMaterial(intensity: 0)
        }
    }

    // MARK: - Holographic Material (phantom projection)

    private static func hologramMaterial(intensity: Double) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .constant   // Emission only — no scene lights
        mat.isDoubleSided = true
        mat.blendMode = .add            // Additive = glow through overlapping parts
        mat.writesToDepthBuffer = false  // All layers visible (X-ray effect)

        if intensity > 0.01 {
            // ACTIVE: Neon cyan glow, intensity drives brightness
            let g = CGFloat(0.3 + intensity * 0.7)
            mat.emission.contents = UIColor(
                red: 0,
                green: g * 0.9,
                blue: g,
                alpha: 1.0
            )
            // Slight transparency so overlapping parts compound
            mat.transparent.contents = UIColor(white: 1.0, alpha: CGFloat(0.25 + intensity * 0.55))
        } else {
            // INACTIVE: Dark ghost outline — barely visible
            mat.emission.contents = UIColor(
                red: 0,
                green: 0.08,
                blue: 0.15,
                alpha: 1.0
            )
            mat.transparent.contents = UIColor(white: 1.0, alpha: 0.12)
        }

        return mat
    }

    // MARK: - Geometry Helpers

    private static func v3(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
        SCNVector3(x, y, z)
    }

    private static func capsule(name: String, w: CGFloat, h: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNCapsule(capRadius: w, height: h)
        geo.radialSegmentCount = 24
        geo.heightSegmentCount = 1
        geo.capSegmentCount = 12
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func box(name: String, w: CGFloat, h: CGFloat, d: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNBox(width: w, height: h, length: d, chamferRadius: 0.008)
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func cylinder(name: String, r: CGFloat, h: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNCylinder(radius: r, height: h)
        geo.radialSegmentCount = 24
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func sphere(name: String, r: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNSphere(radius: r)
        geo.segmentCount = 24
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }
}
