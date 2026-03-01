import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Hologram Body View

struct HologramBodyView: UIViewRepresentable {
    let muscleVolumes: [MuscleGroup: Double]

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastVolumes: [MuscleGroup: Double] = [:]
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.scene = HologramBodyBuilder.buildScene(muscleVolumes: muscleVolumes)
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        guard let scene = scnView.scene else { return }
        // Skip update if volumes haven't changed
        guard muscleVolumes != context.coordinator.lastVolumes else { return }
        context.coordinator.lastVolumes = muscleVolumes
        HologramBodyBuilder.updateIntensities(scene: scene, muscleVolumes: muscleVolumes)
    }
}

// MARK: - Builder

enum HologramBodyBuilder {

    // MakeHuman base mesh (CC0) — coordinates in decimeters
    // Y: -8.17 (feet) to +8.49 (head), X: ±4.96, Z: -1.02 to +3.21
    // Z > ~1.0 = front face, Z < ~1.0 = back face

    // Geometry entry point: encode position into texcoords for surface shader
    private static let geometryShader = """
    #pragma body
    float nx = _geometry.position.x / 10.0 + 0.5;
    float ny = (_geometry.position.y + 8.2) / 16.7;
    float isFront = step(1.0, _geometry.position.z);
    _geometry.texcoords[0] = float2(nx, ny + isFront * 10.0);
    """

    // Surface entry point: zone detection + wireframe + glow
    private static let surfaceShader = """
    #pragma arguments
    float u_chest;
    float u_back;
    float u_shoulders;
    float u_biceps;
    float u_triceps;
    float u_quads;
    float u_hamstrings;
    float u_glutes;
    float u_calves;
    float u_core;

    #pragma body
    float rawY = _surface.diffuseTexcoord.y;
    bool isFront = rawY >= 10.0;
    float posY = rawY - (isFront ? 10.0 : 0.0);
    float posXnorm = _surface.diffuseTexcoord.x;
    float posXabs = abs(posXnorm - 0.5) * 2.0;
    bool isArm = posXabs > 0.40;

    // Zone detection: Y height + X distance + front/back
    float intensity = 0.0;

    if (posY < 0.27) {
        // Calves (feet to knees)
        intensity = u_calves;
    } else if (posY < 0.46) {
        // Upper legs
        if (isArm) {
            intensity = 0.0;
        } else if (isFront) {
            intensity = u_quads;
        } else {
            intensity = u_hamstrings;
        }
    } else if (posY < 0.52) {
        // Hip / pelvis
        if (isArm) {
            intensity = 0.0;
        } else if (isFront) {
            intensity = u_core;
        } else {
            intensity = u_glutes;
        }
    } else if (posY < 0.64) {
        // Mid torso / upper arms
        if (isArm) {
            intensity = isFront ? u_biceps : u_triceps;
        } else {
            intensity = u_core;
        }
    } else if (posY < 0.77) {
        // Upper torso / shoulders
        if (isArm && posY > 0.72) {
            intensity = u_shoulders;
        } else if (isArm) {
            intensity = isFront ? u_biceps : u_triceps;
        } else if (isFront) {
            intensity = u_chest;
        } else {
            intensity = u_back;
        }
    } else if (posY < 0.84) {
        // Shoulder cap / neck
        intensity = isArm ? u_shoulders : 0.0;
    }

    // World-space wireframe grid (dm coordinates)
    float gridX = (posXnorm - 0.5) * 10.0;
    float gridY = posY * 16.7 - 8.2;
    float gridScale = 1.2;
    float lineW = 0.05;
    float gx = abs(fract(gridX * gridScale + 0.5) - 0.5);
    float gy = abs(fract(gridY * gridScale + 0.5) - 0.5);
    float lx = 1.0 - smoothstep(lineW * 0.3, lineW, gx);
    float ly = 1.0 - smoothstep(lineW * 0.3, lineW, gy);
    float grid = max(lx, ly);

    // Vertex dots at grid intersections
    float2 cell = float2(fract(gridX * gridScale), fract(gridY * gridScale));
    float d = length(cell - 0.5);
    float vertexDot = 1.0 - smoothstep(0.03, 0.10, d);
    grid = clamp(max(grid, vertexDot), 0.0, 1.0);

    // Subtle Fresnel edge — scaled by intensity so dead zones stay dark
    float3 viewDir = normalize(_surface.view);
    float3 norm = normalize(_surface.normal);
    float fresnel = pow(1.0 - abs(dot(viewDir, norm)), 3.0);
    float t = clamp(intensity, 0.0, 1.0);
    grid = clamp(grid + fresnel * 0.15 * (0.2 + t * 0.8), 0.0, 1.0);

    // Fade grid opacity with intensity — dead zones get faint wireframe
    float gridStrength = mix(0.12, 1.0, smoothstep(0.0, 0.4, t));
    grid *= gridStrength;

    // 5-stop heatmap color ramp
    float3 color;
    float alpha;
    if (t < 0.01) {
        // Dead zone: near-invisible ghost
        color = float3(0.0, 0.015, 0.04);
        alpha = grid * 0.08;
    } else if (t < 0.25) {
        // Low: faint dark blue trace
        float s = t / 0.25;
        color = mix(float3(0.0, 0.02, 0.06), float3(0.02, 0.05, 0.20), s);
        alpha = grid * mix(0.10, 0.30, s);
    } else if (t < 0.5) {
        // Medium-low: indigo → blue
        float s = (t - 0.25) / 0.25;
        color = mix(float3(0.02, 0.05, 0.20), float3(0.0, 0.25, 0.65), s);
        alpha = grid * mix(0.30, 0.55, s);
    } else if (t < 0.75) {
        // Medium-high: blue → cyan
        float s = (t - 0.5) / 0.25;
        color = mix(float3(0.0, 0.25, 0.65), float3(0.0, 0.65, 0.90), s);
        alpha = grid * mix(0.55, 0.75, s);
    } else {
        // Peak: cyan → white-hot
        float s = (t - 0.75) / 0.25;
        color = mix(float3(0.0, 0.65, 0.90), float3(0.5, 0.9, 1.0), s);
        alpha = grid * mix(0.75, 0.95, s);
    }

    _surface.emission = float4(color * grid, 1.0);
    _surface.transparent = float4(1.0, 1.0, 1.0, alpha);
    """

    // MARK: - Build Scene

    static func buildScene(muscleVolumes: [MuscleGroup: Double]) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Camera — model centered at Y≈0, scale 0.1 makes it ~1.67m tall
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 36
        cam.camera?.wantsHDR = true
        cam.camera?.bloomIntensity = 0.25
        cam.camera?.bloomThreshold = 0.8
        cam.camera?.bloomBlurRadius = 6.0
        cam.position = SCNVector3(0, 0.05, 3.5)
        cam.look(at: SCNVector3(0, 0.05, 0))
        scene.rootNode.addChildNode(cam)

        // Load OBJ
        let url = Bundle.main.url(forResource: "body", withExtension: "obj")
            ?? Bundle.main.url(forResource: "body", withExtension: "obj", subdirectory: "Models")

        if let url {
            let asset = MDLAsset(url: url)
            let objScene = SCNScene(mdlAsset: asset)

            let bodyRoot = SCNNode()
            bodyRoot.name = "bodyRoot"
            bodyRoot.scale = SCNVector3(0.1, 0.1, 0.1) // dm → meters

            for child in objScene.rootNode.childNodes {
                bodyRoot.addChildNode(child)
            }
            scene.rootNode.addChildNode(bodyRoot)
        } else {
            // Fallback: show placeholder text if OBJ fails to load
            let text = SCNText(string: "BODY\nMODEL\nN/A", extrusionDepth: 0.01)
            text.font = .monospacedSystemFont(ofSize: 0.15, weight: .bold)
            text.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 1.0)
            let textNode = SCNNode(geometry: text)
            textNode.name = "bodyFallback"
            textNode.position = SCNVector3(-0.3, -0.1, 0)
            scene.rootNode.addChildNode(textNode)
        }

        applyHologramMaterial(scene: scene, muscleVolumes: muscleVolumes)
        return scene
    }

    // MARK: - Update Intensities

    static func updateIntensities(scene: SCNScene, muscleVolumes: [MuscleGroup: Double]) {
        var mat: SCNMaterial?
        scene.rootNode.enumerateChildNodes { node, stop in
            if node.geometry != nil, node.camera == nil,
               let m = node.geometry?.materials.first {
                mat = m
                stop.pointee = true
            }
        }
        guard let mat else { return }
        setIntensityUniforms(mat, muscleVolumes: muscleVolumes)
    }

    // MARK: - Material

    private static func applyHologramMaterial(scene: SCNScene, muscleVolumes: [MuscleGroup: Double]) {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.blendMode = .add
        mat.writesToDepthBuffer = false
        mat.diffuse.contents = UIColor.white
        mat.transparent.contents = UIColor.white

        mat.shaderModifiers = [
            .geometry: geometryShader,
            .surface: surfaceShader,
        ]

        setIntensityUniforms(mat, muscleVolumes: muscleVolumes)

        // Apply to all geometry nodes
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.geometry != nil, node.camera == nil {
                node.geometry?.materials = [mat]
            }
        }
    }

    private static func setIntensityUniforms(_ mat: SCNMaterial, muscleVolumes: [MuscleGroup: Double]) {
        let mapping: [(String, MuscleGroup)] = [
            ("u_chest", .chest), ("u_back", .back), ("u_shoulders", .shoulders),
            ("u_biceps", .biceps), ("u_triceps", .triceps), ("u_quads", .quads),
            ("u_hamstrings", .hamstrings), ("u_glutes", .glutes),
            ("u_calves", .calves), ("u_core", .core),
        ]
        for (key, muscle) in mapping {
            mat.setValue(Float(muscleVolumes[muscle] ?? 0), forKey: key)
        }
    }
}
