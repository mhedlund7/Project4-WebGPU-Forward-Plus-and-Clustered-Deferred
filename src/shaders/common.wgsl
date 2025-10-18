// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

// Structs for cluster info
struct ClusterNumLights {
    clusterNumLights: array<u32>
}

struct ClusterLightIndices {
    clusterLightIndices: array<u32>
}

// TODO-2: you may want to create a ClusterSet struct similar to LightSet

// Have separate structs for cluster light counts and cluster indices so can have two arrays

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewMat: mat4x4f,
    // Added. more to camera uniforms
    projMat: mat4x4f,
    invProjMat: mat4x4f,
    invViewMat: mat4x4f,
    screenWidth: f32,
    screenHeight: f32,
    nearZ: f32,
    farZ: f32,
    clusterWidth: f32,
    clusterHeight: f32,
    zSlices: f32,
    maxLightsPerCluster: f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

// Common helper functions

fn calculateClusterDims(camera: CameraUniforms) -> vec3u {
    let x = u32(ceil(camera.screenWidth  / camera.clusterWidth));
    let y = u32(ceil(camera.screenHeight / camera.clusterHeight));
    let z = u32(camera.zSlices);
    return vec3u(x, y, z);
}

fn clusterIndex(xIndex: u32, yIndex: u32, zIndex: u32, dimensions: vec3u) -> u32{
    return (zIndex * dimensions.y * dimensions.x) + (yIndex * dimensions.x) + xIndex;
}
