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

    // Cyan-blue hologram base
    private static let baseColor = UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)

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

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.2, 2.8)
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.0, green: 0.15, blue: 0.3, alpha: 1.0)
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.color = UIColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 1.0)
        directional.light?.intensity = 400
        directional.position = SCNVector3(2, 3, 2)
        directional.look(at: SCNVector3Zero)
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
        let head = capsule(name: "head", w: 0.12, h: 0.16, pos: v3(0, 1.05, 0))
        root.addChildNode(head)

        // Neck
        let neck = cylinder(name: "neck", r: 0.04, h: 0.08, pos: v3(0, 0.93, 0))
        root.addChildNode(neck)

        // Torso — chest
        let chestL = box(name: "chest_L", w: 0.15, h: 0.18, d: 0.1, pos: v3(-0.08, 0.75, 0.02))
        let chestR = box(name: "chest_R", w: 0.15, h: 0.18, d: 0.1, pos: v3(0.08, 0.75, 0.02))
        root.addChildNode(chestL)
        root.addChildNode(chestR)

        // Core
        let coreFront = box(name: "core_front", w: 0.24, h: 0.2, d: 0.08, pos: v3(0, 0.52, 0.02))
        root.addChildNode(coreFront)

        // Back
        let backUpper = box(name: "back_upper", w: 0.28, h: 0.18, d: 0.08, pos: v3(0, 0.75, -0.06))
        let backLower = box(name: "back_lower", w: 0.24, h: 0.15, d: 0.08, pos: v3(0, 0.52, -0.06))
        root.addChildNode(backUpper)
        root.addChildNode(backLower)

        // Shoulders
        let shoulderL = sphere(name: "shoulder_L", r: 0.07, pos: v3(-0.22, 0.85, 0))
        let shoulderR = sphere(name: "shoulder_R", r: 0.07, pos: v3(0.22, 0.85, 0))
        root.addChildNode(shoulderL)
        root.addChildNode(shoulderR)

        // Upper arms — biceps/triceps
        let bicepL = capsule(name: "bicep_L", w: 0.05, h: 0.2, pos: v3(-0.25, 0.68, 0.02))
        let bicepR = capsule(name: "bicep_R", w: 0.05, h: 0.2, pos: v3(0.25, 0.68, 0.02))
        let tricepL = capsule(name: "tricep_L", w: 0.045, h: 0.2, pos: v3(-0.25, 0.68, -0.02))
        let tricepR = capsule(name: "tricep_R", w: 0.045, h: 0.2, pos: v3(0.25, 0.68, -0.02))
        root.addChildNode(bicepL)
        root.addChildNode(bicepR)
        root.addChildNode(tricepL)
        root.addChildNode(tricepR)

        // Upper legs
        let quadL = capsule(name: "quad_L", w: 0.08, h: 0.3, pos: v3(-0.1, 0.22, 0.02))
        let quadR = capsule(name: "quad_R", w: 0.08, h: 0.3, pos: v3(0.1, 0.22, 0.02))
        let hamL = capsule(name: "ham_L", w: 0.07, h: 0.28, pos: v3(-0.1, 0.22, -0.02))
        let hamR = capsule(name: "ham_R", w: 0.07, h: 0.28, pos: v3(0.1, 0.22, -0.02))
        root.addChildNode(quadL)
        root.addChildNode(quadR)
        root.addChildNode(hamL)
        root.addChildNode(hamR)

        // Glutes
        let gluteL = sphere(name: "glute_L", r: 0.08, pos: v3(-0.09, 0.38, -0.04))
        let gluteR = sphere(name: "glute_R", r: 0.08, pos: v3(0.09, 0.38, -0.04))
        root.addChildNode(gluteL)
        root.addChildNode(gluteR)

        // Lower legs — calves
        let calfL = capsule(name: "calf_L", w: 0.05, h: 0.25, pos: v3(-0.1, -0.1, -0.01))
        let calfR = capsule(name: "calf_R", w: 0.05, h: 0.25, pos: v3(0.1, -0.1, -0.01))
        root.addChildNode(calfL)
        root.addChildNode(calfR)

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
        // Non-mapped nodes (head, neck) get dim base
        for name in ["head", "neck"] {
            guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
            node.geometry?.firstMaterial = hologramMaterial(intensity: 0)
        }
    }

    // MARK: - Holographic Material

    private static func hologramMaterial(intensity: Double) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.fillMode = .lines
        mat.lightingModel = .constant
        mat.isDoubleSided = true

        let glow = 0.1 + intensity * 0.9
        mat.emission.contents = baseColor.withAlphaComponent(CGFloat(glow))
        mat.diffuse.contents = UIColor.clear

        return mat
    }

    // MARK: - Geometry Helpers

    private static func v3(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
        SCNVector3(x, y, z)
    }

    private static func capsule(name: String, w: CGFloat, h: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNCapsule(capRadius: w, height: h)
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func box(name: String, w: CGFloat, h: CGFloat, d: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func cylinder(name: String, r: CGFloat, h: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNCylinder(radius: r, height: h)
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }

    private static func sphere(name: String, r: CGFloat, pos: SCNVector3) -> SCNNode {
        let geo = SCNSphere(radius: r)
        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        return node
    }
}
