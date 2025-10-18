// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

// Need lights array
// Need to output cluster data structure
@group(${bindGroup_cluster}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_cluster}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_cluster}) @binding(2) var<storage, read_write> outClusterNumLights: ClusterNumLights;
@group(${bindGroup_cluster}) @binding(3) var<storage, read_write> outClusterLightIndices: ClusterLightIndices;

const lightRadius : f32 = ${lightRadius};

// Compute z bounds of frustrum from the cluster's z index
fn getZBounds(zIndex: u32, dimensions: vec3u) -> vec2f {
    // exponential divisions
    let logNear = log(cameraUniforms.nearZ);
    let logFar = log(cameraUniforms.farZ);

    let near = exp(mix(logNear, logFar, f32(zIndex) / f32(dimensions.z)));
    let far = exp(mix(logNear, logFar, f32(zIndex + 1) / f32(dimensions.z)));
    return vec2f(near, far);
}

// From a given cluster index return a matrix with min and max corners of bounding box in world space
fn clusterBoundingBox(xIndex: u32, yIndex: u32, zIndex: u32, dimensions: vec3u) -> mat2x3f {

    // screen tiling dimensions
    let tileX0 = f32(xIndex) * cameraUniforms.clusterWidth;
    let tileX1 = min(tileX0 + cameraUniforms.clusterWidth, cameraUniforms.screenWidth);
    let tileY0 = f32(yIndex) * cameraUniforms.clusterHeight;
    let tileY1 = min(tileY0 + cameraUniforms.clusterHeight, cameraUniforms.screenHeight);

    let zDims = getZBounds(zIndex, dimensions);

    // confert four corners of screen tiling to (-1, 1)
    let  normalizedCoords = array<vec2f, 4> (
        vec2f((tileX0 / cameraUniforms.screenWidth) * 2.0 - 1.0, 1.0 - (tileY0 / cameraUniforms.screenHeight) * 2.0),
        vec2f((tileX1 / cameraUniforms.screenWidth) * 2.0 - 1.0, 1.0 - (tileY0 / cameraUniforms.screenHeight) * 2.0),
        vec2f((tileX0 / cameraUniforms.screenWidth) * 2.0 - 1.0, 1.0 - (tileY1 / cameraUniforms.screenHeight) * 2.0),
        vec2f((tileX1 / cameraUniforms.screenWidth) * 2.0 - 1.0, 1.0 - (tileY1 / cameraUniforms.screenHeight) * 2.0),
    );

    // convert to world space and track min and max corners
    var minCorner = vec3f(1e20, 1e20, 1e20);
    var maxCorner = vec3f(-1e20, -1e20, -1e20);
    // four corners
    for (var idx = 0; idx < 4; idx++) {
        // near vs far side
        for (var zIdx = 0; zIdx < 2; zIdx++) {
            // get to world coords
            let zView = -select(zDims.x, zDims.y, zIdx == 1);
            
            let xN = normalizedCoords[idx].x;
            let yN = normalizedCoords[idx].y;

            let view = vec4f(
                xN * (-zView) / cameraUniforms.projMat[0][0],
                yN * (-zView) / cameraUniforms.projMat[1][1],
                zView,
                1.0
            );
            let world = cameraUniforms.invViewMat * view;
            let worldPos = world.xyz;
            minCorner = min(minCorner, worldPos);
            maxCorner = max(maxCorner, worldPos);
        }
    }

    return mat2x3f(minCorner, maxCorner);
}

fn sphereBoxIntersection(sphereCenter: vec3f, radius: f32, minCorner: vec3f, maxCorner: vec3f) -> bool {
    // compare squared distance
    var dist = 0.0;
    // add up squared distance of seach component of phereCenter to bounding box
    for (var dim = 0; dim < 3; dim++) {
        let c = sphereCenter[dim];
        let mn = minCorner[dim];
        let mx = maxCorner[dim];
        var dimDist = 0.0;
        if (c < mn) {
            dimDist = mn - c;
        } else if (c > mx) {
            dimDist = c - mx;
        } else {
            dimDist = 0;
        }
        dist += dimDist * dimDist;
    }
    return dist <= radius * radius;
}

@compute @workgroup_size(${clusterWorkgroupSize})
fn main(@builtin(global_invocation_id) index: vec3u) {
    let id = index.x;
    let dims = calculateClusterDims(cameraUniforms);
    let numClusters = dims.x * dims.y * dims.z;
    if (id > numClusters) {
        return;
    }

    // get cluster x, y, z indices
    let zScaler = dims.x * dims.y;
    let zIndex = id / zScaler;
    let remain = id - zIndex * zScaler;
    let yIndex = remain / dims.x;
    let xIndex = remain - yIndex * dims.x;

    // get world space bounding box for cluster
    let bbox = clusterBoundingBox(xIndex, yIndex, zIndex, dims);
    let minCorner = bbox[0];
    let maxCorner = bbox[1];

    let maxLights = u32(cameraUniforms.maxLightsPerCluster);
    // starting index for this cluster into the array storing the cluster's lights
    let clusterLightIndicesStart = u32(id) * maxLights;
    
    var numLights : u32 = 0;
    // for each light detect if it overlaps the cluster add to the cluster's lights
    for (var lIdx: u32 = 0; lIdx < lightSet.numLights; lIdx++) {
        let light = lightSet.lights[lIdx];
        if (sphereBoxIntersection(light.pos, lightRadius, minCorner, maxCorner)) {
            if (numLights < maxLights) {
                outClusterLightIndices.clusterLightIndices[clusterLightIndicesStart + numLights] = lIdx;
                numLights++;
            }
        }
    }
    outClusterNumLights.clusterNumLights[id] = numLights;
}