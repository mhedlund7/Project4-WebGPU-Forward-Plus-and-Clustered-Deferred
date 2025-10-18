// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterNumLights: ClusterNumLights;
@group(${bindGroup_scene}) @binding(3) var<storage, read> clusterLightIndices: ClusterLightIndices;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @builtin(position) fragPos : vec4f // screen-space xy
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let dims = calculateClusterDims(cameraUniforms);
    // determine cluster
    let xIndex = min(u32(in.fragPos.x) / u32(cameraUniforms.clusterWidth), dims.x - 1);
    let yIndex = min(u32(in.fragPos.y) / u32(cameraUniforms.clusterHeight), dims.y - 1);

    // calc z index
    let worldPos = vec4f(in.pos, 1.0);
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
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}