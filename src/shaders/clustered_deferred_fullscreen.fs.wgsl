// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read> clusterNumLights: ClusterNumLights;
@group(0) @binding(3) var<storage, read> clusterLightIndices: ClusterLightIndices;

@group(1) @binding(0) var gAlbedo: texture_2d<f32>;
@group(1) @binding(1) var gNormal: texture_2d<f32>;
@group(1) @binding(2) var gPosition: texture_2d<f32>;
@group(1) @binding(3) var gSampler: sampler;

struct FragmentInput
{
    @location(0) uv: vec2f,
    @builtin(position) fragPos : vec4f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {

    // sample
    let albedo = textureSample(gAlbedo, gSampler, in.uv);
    if (albedo.a < 0.5) {
        discard;
    }
    let normal = textureSample(gNormal, gSampler, in.uv).xyz;
    let position = textureSample(gPosition, gSampler, in.uv).xyz;


    let dims = calculateClusterDims(cameraUniforms);
    // determine cluster
    let xIndex = min(u32(in.fragPos.x) / u32(cameraUniforms.clusterWidth), dims.x - 1);
    let yIndex = min(u32(in.fragPos.y) / u32(cameraUniforms.clusterHeight), dims.y - 1);

    // calc z index
    let worldPos = vec4f(position, 1.0);
    let viewPosVec = cameraUniforms.viewMat * worldPos;
    let viewZ = -viewPosVec.z;
    
    let logNear = log(cameraUniforms.nearZ);
    let logFar = log(cameraUniforms.farZ);
    let logZ = log(viewZ);
    
    let r = (logZ - logNear) / (logFar - logNear);
    
    // Convert to cluster index
    let zIndex = min(u32(clamp(r * f32(dims.z), 0.0, f32(dims.z) - 1.0)), dims.z - 1);

    let cIndex = clusterIndex(xIndex, yIndex, zIndex, dims);

    // go through lights in cluster
    let maxLights = u32(cameraUniforms.maxLightsPerCluster);
    let lightIndexStart = cIndex * maxLights;
    let numLights = clusterNumLights.clusterNumLights[cIndex];

    var totalLightContrib = vec3f(0, 0, 0);

    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let lIdx = clusterLightIndices.clusterLightIndices[lightIndexStart + lightIdx];
        let light = lightSet.lights[lIdx];
        totalLightContrib += calculateLightContrib(light, position, normalize(normal));
    }

    var finalColor = albedo.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}