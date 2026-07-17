@tool
class_name DepthWritingQuadEffect
extends CompositorEffect

var QUAD_VERTICES :PackedFloat32Array= PackedFloat32Array([
	-0.5, -0.5, 0.0,
	 0.5, -0.5, 0.0,
	-0.5,  0.5, 0.0,
	 0.5,  0.5, 0.0,
])

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var vertex_buffer: RID
var vertex_array: RID
var vertex_format: int

var model_transform := Transform3D.IDENTITY

var _warned_framebuffer := false
var _warned_draw_list := false


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
	rd = RenderingServer.get_rendering_device()
	if rd:
		_setup()


func _setup() -> void:
	var shader_file: RDShaderFile = load("res://rdstencilpipeline/depth_quad.glsl")
	if not shader_file:
		push_error("DepthWritingQuadEffect: Shader file path is invalid.")
		return

	var shader_spirv := shader_file.get_spirv()
	if not shader_spirv:
		push_error("DepthWritingQuadEffect: SPIR-V compilation failed. Check file import status.")
		return

	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		return

	# Setup vertex buffer and format
	var vertex_bytes := QUAD_VERTICES.to_byte_array()
	vertex_buffer = rd.vertex_buffer_create(vertex_bytes.size(), vertex_bytes)
	
	var attr := RDVertexAttribute.new()
	attr.location = 0
	attr.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	attr.stride = 3 * 4

	vertex_format = rd.vertex_format_create([attr] as Array[RDVertexAttribute])
	vertex_array = rd.vertex_array_create(4, vertex_format, [vertex_buffer])


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if not shader.is_valid() or not rd or callback_type != EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		return

	var scene_buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene_data := render_data.get_render_scene_data() as RenderSceneDataRD
	if not scene_buffers or not scene_data:
		return

	var size := scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	for view in scene_buffers.get_view_count():
		_draw_quad_for_view(scene_buffers, scene_data, view)


func _draw_quad_for_view(scene_buffers: RenderSceneBuffersRD, scene_data: RenderSceneDataRD, view: int) -> void:
	var color_tex := scene_buffers.get_color_layer(view)
	var depth_tex := scene_buffers.get_depth_layer(view)

	# Fetch cached framebuffer layout
	var framebuffer := FramebufferCacheRD.get_cache_multipass([color_tex, depth_tex], [], 1)
	if not framebuffer.is_valid():
		if not _warned_framebuffer:
			push_error("DepthWritingQuadEffect: Failed to acquire valid Framebuffer.")
			_warned_framebuffer = true
		return

	# Lazy initialize pipeline once format is known
	if not pipeline.is_valid():
		_create_pipeline(framebuffer)
		if not pipeline.is_valid():
			return

	# Calculate and pack MVP matrix
	var mvp := _get_mvp(scene_data, view)
	var push_constants := PackedFloat32Array([
		mvp.x.x, mvp.x.y, mvp.x.z, mvp.x.w,
		mvp.y.x, mvp.y.y, mvp.y.z, mvp.y.w,
		mvp.z.x, mvp.z.y, mvp.z.z, mvp.z.w,
		mvp.w.x, mvp.w.y, mvp.w.z, mvp.w.w,
	]).to_byte_array()

	# Execute drawing commands
	var draw_list := rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_DEFAULT_ALL)
	if draw_list < 0:
		if not _warned_draw_list:
			push_error("DepthWritingQuadEffect: draw_list_begin failed.")
			_warned_draw_list = true
		return

	rd.draw_list_bind_render_pipeline(draw_list, pipeline)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_set_push_constant(draw_list, push_constants, push_constants.size())
	rd.draw_list_draw(draw_list, false, 1, 4)
	rd.draw_list_end()

#Model-View-Projection
func _get_mvp(scene_data: RenderSceneDataRD, view: int) -> Projection:
	var cam_transform := scene_data.get_cam_transform()
	var view_matrix := cam_transform.affine_inverse()
	var projection := scene_data.get_view_projection(view)

	return projection * Projection(view_matrix) * Projection(model_transform)


func _create_pipeline(framebuffer: RID) -> void:
	var raster := RDPipelineRasterizationState.new()
	var multisample := RDPipelineMultisampleState.new()
	
	var blend_attachment := RDPipelineColorBlendStateAttachment.new()
	var blend := RDPipelineColorBlendState.new()
	blend.attachments = [blend_attachment]

	var depth_stencil := RDPipelineDepthStencilState.new()
	depth_stencil.enable_depth_test = true
	depth_stencil.enable_depth_write = true
	depth_stencil.depth_compare_operator = RenderingDevice.COMPARE_OP_GREATER_OR_EQUAL

	var fb_format := rd.framebuffer_get_format(framebuffer)

	pipeline = rd.render_pipeline_create(
		shader,
		fb_format,
		vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLE_STRIPS,
		raster,
		multisample,
		depth_stencil,
		blend
	)
