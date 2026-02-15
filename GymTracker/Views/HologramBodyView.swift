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

        // Camera — centered on body midpoint
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.fieldOfView = 36
        cameraNode.position = SCNVector3(0, 0.45, 2.4)
        cameraNode.look(at: SCNVector3(0, 0.45, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Ambient — subtle blue fill
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0)
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        // Directional — top-down for depth
        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.color = UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0)
        directional.light?.intensity = 600
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(directional)

        // Build body
        let body = buildBody()
        scene.rootNode.addChildNode(body)

        // Apply initial intensities
        updateIntensities(scene: scene, muscleVolumes: muscleVolumes)

        return scene
    }

    // MARK: - Build Primitive Body

    private static func buildBody() -> SCNNode {
        let root = SCNNode()

        // Head
        root.addChildNode(capsule(name: "head", w: 0.12, h: 0.16, pos: v3(0, 1.05, 0)))
        // Neck
        root.addChildNode(cylinder(name: "neck", r: 0.04, h: 0.08, pos: v3(0, 0.93, 0)))

        // Chest
        root.addChildNode(box(name: "chest_L", w: 0.15, h: 0.18, d: 0.1, pos: v3(-0.08, 0.75, 0.02)))
        root.addChildNode(box(name: "chest_R", w: 0.15, h: 0.18, d: 0.1, pos: v3(0.08, 0.75, 0.02)))

        // Core
        root.addChildNode(box(name: "core_front", w: 0.24, h: 0.2, d: 0.08, pos: v3(0, 0.52, 0.02)))

        // Back
        root.addChildNode(box(name: "back_upper", w: 0.28, h: 0.18, d: 0.08, pos: v3(0, 0.75, -0.06)))
        root.addChildNode(box(name: "back_lower", w: 0.24, h: 0.15, d: 0.08, pos: v3(0, 0.52, -0.06)))

        // Shoulders
        root.addChildNode(sphere(name: "shoulder_L", r: 0.07, pos: v3(-0.22, 0.85, 0)))
        root.addChildNode(sphere(name: "shoulder_R", r: 0.07, pos: v3(0.22, 0.85, 0)))

        // Biceps / Triceps
        root.addChildNode(capsule(name: "bicep_L", w: 0.05, h: 0.2, pos: v3(-0.25, 0.68, 0.02)))
        root.addChildNode(capsule(name: "bicep_R", w: 0.05, h: 0.2, pos: v3(0.25, 0.68, 0.02)))
        root.addChildNode(capsule(name: "tricep_L", w: 0.045, h: 0.2, pos: v3(-0.25, 0.68, -0.02)))
        root.addChildNode(capsule(name: "tricep_R", w: 0.045, h: 0.2, pos: v3(0.25, 0.68, -0.02)))

        // Quads / Hamstrings
        root.addChildNode(capsule(name: "quad_L", w: 0.08, h: 0.3, pos: v3(-0.1, 0.22, 0.02)))
        root.addChildNode(capsule(name: "quad_R", w: 0.08, h: 0.3, pos: v3(0.1, 0.22, 0.02)))
        root.addChildNode(capsule(name: "ham_L", w: 0.07, h: 0.28, pos: v3(-0.1, 0.22, -0.02)))
        root.addChildNode(capsule(name: "ham_R", w: 0.07, h: 0.28, pos: v3(0.1, 0.22, -0.02)))

        // Glutes
        root.addChildNode(sphere(name: "glute_L", r: 0.08, pos: v3(-0.09, 0.38, -0.04)))
        root.addChildNode(sphere(name: "glute_R", r: 0.08, pos: v3(0.09, 0.38, -0.04)))

        // Calves
        root.addChildNode(capsule(name: "calf_L", w: 0.05, h: 0.25, pos: v3(-0.1, -0.1, -0.01)))
        root.addChildNode(capsule(name: "calf_R", w: 0.05, h: 0.25, pos: v3(0.1, -0.1, -0.01)))

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
        for name in ["head", "neck"] {
            guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
            node.geometry?.firstMaterial = hologramMaterial(intensity: 0)
        }
    }

    // MARK: - Holographic Material (translucent ghost fill)

    private static func hologramMaterial(intensity: Double) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.isDoubleSided = true
        mat.blendMode = .add // Additive blending for glow-through effect
        mat.writesToDepthBuffer = false // Prevents z-fighting, shows all layers

        // Dim base for non-worked muscles, bright cyan for activated
        let base = 0.08 + intensity * 0.25
        let emGlow = 0.05 + intensity * 0.95

        mat.diffuse.contents = UIColor(red: 0, green: CGFloat(base * 0.8), blue: CGFloat(base), alpha: 1.0)
        mat.metalness.contents = NSNumber(value: 0.8)
        mat.roughness.contents = NSNumber(value: 0.3)
        mat.emission.contents = UIColor(
            red: 0,
            green: CGFloat(emGlow * 0.85),
            blue: CGFloat(emGlow),
            alpha: 1.0
        )
        mat.transparent.contents = UIColor(white: 0, alpha: CGFloat(0.15 + intensity * 0.45))

        return mat
    }

    // MARK: - Geometry Helpers

    private static func v3(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
        SCNVector3(x, y, z)
    }

    private static func capsule(name: String, w: CGFloat, h: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNCapsule(capRadius: w, height: h)
        geo.radialSegmentCount = 24
        geo.heightSegmentCount = 2
        geo.capSegmentCount = 12
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func box(name: String, w: CGFloat, h: CGFloat, d: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNBox(width: w, height: h, length: d, chamferRadius: 0.005)
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
