import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

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

// MARK: - Builder

enum HologramBodyBuilder {

    // OBJ group name → MuscleGroup
    static let groupMapping: [String: MuscleGroup] = [
        "chest": .chest, "core": .core,
        "shoulder_L": .shoulders, "shoulder_R": .shoulders,
        "bicep_L": .biceps, "bicep_R": .biceps,
        "tricep_L": .triceps, "tricep_R": .triceps,
        "quad_L": .quads, "quad_R": .quads,
        "ham_L": .hamstrings, "ham_R": .hamstrings,
        "glute_L": .glutes, "glute_R": .glutes,
        "calf_L": .calves, "calf_R": .calves,
    ]

    // Wireframe shader
    private static let wireframeShader = """
    #pragma body
    float2 uv = _surface.diffuseTexcoord;
    float density = 14.0;
    float lineW = 0.06;
    float gx = abs(fract(uv.x * density + 0.5) - 0.5);
    float gy = abs(fract(uv.y * density + 0.5) - 0.5);
    float lx = 1.0 - smoothstep(lineW * 0.3, lineW, gx);
    float ly = 1.0 - smoothstep(lineW * 0.3, lineW, gy);
    float grid = max(lx, ly);
    float2 cell = fract(uv * density);
    float d = length(cell - 0.5);
    float vertexDot = 1.0 - smoothstep(0.03, 0.13, d);
    grid = clamp(max(grid, vertexDot * 1.3), 0.0, 1.0);
    float3 viewDir = normalize(_surface.view);
    float3 norm = normalize(_surface.normal);
    float fresnel = pow(1.0 - abs(dot(viewDir, norm)), 2.5);
    grid = clamp(grid + fresnel * 0.35, 0.0, 1.0);
    _surface.emission *= float4(float3(grid), 1.0);
    _surface.transparent = float4(float3(1.0), mix(0.003, 0.8, grid));
    """

    // MARK: - Build Scene

    static func buildScene(muscleVolumes: [MuscleGroup: Double]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Camera
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 32
        cam.camera?.wantsHDR = true
        cam.camera?.bloomIntensity = 0.6
        cam.camera?.bloomThreshold = 0.5
        cam.camera?.bloomBlurRadius = 10.0
        cam.position = SCNVector3(0, 1.1, 3.0)
        cam.look(at: SCNVector3(0, 1.0, 0))
        scene.rootNode.addChildNode(cam)

        // Load OBJ
        if let url = Bundle.main.url(forResource: "body", withExtension: "obj", subdirectory: "Models") {
            let asset = MDLAsset(url: url)
            let objScene = SCNScene(mdlAsset: asset)
            for child in objScene.rootNode.childNodes {
                scene.rootNode.addChildNode(child)
            }
        } else {
            // Fallback: build primitive body if OBJ missing
            scene.rootNode.addChildNode(buildFallbackBody())
        }

        updateIntensities(scene: scene, muscleVolumes: muscleVolumes)
        return scene
    }

    // MARK: - Update Intensities

    static func updateIntensities(scene: SCNScene, muscleVolumes: [MuscleGroup: Double]) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, node.geometry != nil else { return }
            let muscle = groupMapping[name]
            let intensity = muscle.flatMap { muscleVolumes[$0] } ?? 0
            node.geometry?.firstMaterial = hologramMaterial(intensity: intensity)
        }
    }

    // MARK: - Material

    private static func hologramMaterial(intensity: Double) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.blendMode = .add
        mat.writesToDepthBuffer = false

        if intensity > 0.01 {
            let g = CGFloat(0.45 + intensity * 0.55)
            mat.emission.contents = UIColor(red: 0, green: g * 0.9, blue: g, alpha: 1.0)
        } else {
            mat.emission.contents = UIColor(red: 0, green: 0.08, blue: 0.18, alpha: 1.0)
        }

        mat.transparent.contents = UIColor.white
        mat.shaderModifiers = [.surface: wireframeShader]
        return mat
    }

    // MARK: - Fallback primitive body (in case OBJ not bundled)

    private static func buildFallbackBody() -> SCNNode {
        let root = SCNNode()
        let parts: [(String, SCNGeometry, SCNVector3)] = [
            ("head", SCNCapsule(capRadius: 0.09, height: 0.15), SCNVector3(0, 1.68, 0)),
            ("chest", SCNBox(width: 0.3, height: 0.2, length: 0.16, chamferRadius: 0.01), SCNVector3(0, 1.38, 0)),
            ("core", SCNBox(width: 0.26, height: 0.18, length: 0.14, chamferRadius: 0.01), SCNVector3(0, 1.15, 0)),
        ]
        for (name, geo, pos) in parts {
            let n = SCNNode(geometry: geo)
            n.name = name
            n.position = pos
            root.addChildNode(n)
        }
        return root
    }
}
