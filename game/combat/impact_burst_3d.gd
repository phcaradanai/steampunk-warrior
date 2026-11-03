class_name ImpactBurst3D
extends SubViewportContainer
# One-shot 3D spark burst over a 2D target; frees itself when the particles end.

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0, 10)
	viewport.add_child(camera)
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.45
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-1, 0.4, 0)
	process.spread = 80.0
	process.initial_velocity_min = 1.6
	process.initial_velocity_max = 3.4
	process.gravity = Vector3(0, -5, 0)
	process.damping_min = 2.0
	process.damping_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color("fff2b0"))
	fade.set_color(1, Color(0.94, 0.55, 0.2, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.035, 0.035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	viewport.add_child(particles)
	particles.finished.connect(queue_free)
	particles.emitting = true
