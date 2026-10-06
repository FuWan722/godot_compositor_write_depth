Written in Godot 4.6

Example Compositor Effect that replicate the impostor 2d quad drawn as a 3d sphere with depth test: https://paroj.github.io/gltut/Illumination/Tut13%20Deceit%20in%20Depth.html

The compositor effect draw a quad at the origin, and use the `RDPipelineDepthStencilState` class and `RenderingDevice.render_pipeline_create()` method to create the rendering pipeline.
The vertex and fragment stages are in the `depth_quad.glsl`.

Custom depth per fragment pixel can be assigned in the fragment stage using the property `gl_FragDepth` (https://registry.khronos.org/OpenGL-Refpages/gl4/html/gl_FragDepth.xhtml).
