shader_type spatial;
render_mode unshaded, fog_disabled, cull_front;

uniform sampler2D depth_texture : hint_depth_texture;

void vertex() {
  POSITION = vec4(VERTEX.xy*2.0, 1.0, 1.0);
}

void fragment() {
  float depth = texture(depth_texture, SCREEN_UV).x;
  vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  view.xyz /= view.w;
  float linear_depth = -view.z;

  vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  vec3 world_position = world.xyz / world.w;

  // Visualize linear depth
  ALBEDO.rgb = vec3(depth);

  // Visualize world coordinates
  //ALBEDO.rgb = fract(world_position).xyz;
}