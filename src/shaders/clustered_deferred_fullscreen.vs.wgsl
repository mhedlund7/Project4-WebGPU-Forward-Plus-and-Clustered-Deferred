// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.

struct VertexOutput
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
};

@vertex
fn main(@builtin(vertex_index) vid: u32) -> VertexOutput {
    // Fullscreen triangle vertex data - index with vId
    var pos = array<vec2f, 3> (
        vec2f(-1.0, -3.0),
        vec2f(3.0, 1.0),
        vec2f(-1.0, 1.0)
    );
    var uv = array<vec2f, 3> (
        vec2f(0.0, 2.0),
        vec2f(2.0, 0.0),
        vec2f(0.0, 0.0)
    );

    var out: VertexOutput;
    out.pos = vec4f(pos[vid], 0.0, 1.0);
    out.uv = uv[vid];
    return out;
}