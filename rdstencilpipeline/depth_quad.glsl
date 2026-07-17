//EXAMPLE: SIMPLE QUAD
// #[vertex]

// #version 450

// layout(location = 0) in vec3 vertex_position;

// layout(push_constant, std430) uniform PushConstants {
//     mat4 mvp;
// } push_constants;

// void main() {
//     gl_Position = push_constants.mvp * vec4(vertex_position, 1.0);
// }

// #[fragment] 

// #version 450

// layout(location = 0) out vec4 frag_color;
 
// void main() {
//     frag_color = vec4(1.0, 0.0, 0.0, 1.0);
    

// }
 
//EXAMPLE: SPHERE IMPOSTOR
#[vertex]

#version 450

layout(location = 0) in vec3 vertex_position;

layout(push_constant, std430) uniform PushConstants {
    mat4 mvp;
} push_constants;

layout(location = 0) out vec3 local_pos;

void main() {
    local_pos = vertex_position;
    gl_Position = push_constants.mvp * vec4(vertex_position, 1.0);
}

#[fragment]

#version 450

layout(location = 0) in vec3 local_pos;
layout(location = 0) out vec4 frag_color;

layout(push_constant, std430) uniform PushConstants {
    mat4 mvp;
} push_constants;

void main() {
    float dist_from_center = length(local_pos.xy) / 0.5; // 0 at center, 1 at edge
    if (dist_from_center > 1.0) {
        discard; // outside the "circle" -- don't write color OR depth here
    }

    float bulge_height = sqrt(max(0.0, 1.0 - dist_from_center * dist_from_center));
    vec3 bulged_pos = vec3(local_pos.xy, local_pos.z + bulge_height * 0.5);

    vec4 clip_pos = push_constants.mvp * vec4(bulged_pos, 1.0);
    float ndc_depth = clip_pos.z / clip_pos.w;

    gl_FragDepth = ndc_depth;
    frag_color = vec4(1.0, 0.0, 0.0, 1.0);
}

