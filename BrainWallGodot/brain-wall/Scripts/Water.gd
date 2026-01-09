extends MeshInstance3D

var material: ShaderMaterial
var noise: Image

var noise_scale: float = 10.0
var wave_speed: float = 1.0
var height_scale: float = 1.0
var time: float = 0.0

func _ready():
	material = mesh.surface_get_material(0) as ShaderMaterial

	var wave_tex: NoiseTexture2D = material.get_shader_parameter("wave")
	if wave_tex:
		noise = wave_tex.get_image()
	else:
		push_error("No se encontró el parámetro 'wave' en el ShaderMaterial")

	noise_scale = material.get_shader_parameter("noise_scale") if material.get_shader_parameter("noise_scale") != null else noise_scale
	wave_speed = material.get_shader_parameter("wave_speed") if material.get_shader_parameter("wave_speed") != null else wave_speed
	height_scale = material.get_shader_parameter("height_scale") if material.get_shader_parameter("height_scale") != null else height_scale

func _process(delta: float) -> void:
	time += delta
	material.set_shader_parameter("wave_time", time)

func get_height(world_position: Vector3) -> float:
	if noise == null:
		return global_position.y

	var uv_x = wrapf(world_position.x / noise_scale + time * wave_speed, 0.0, 1.0)
	var uv_y = wrapf(world_position.z / noise_scale + time * wave_speed, 0.0, 1.0)

	var pixel_pos = Vector2(uv_x * noise.get_width(), uv_y * noise.get_height())
	return global_position.y + noise.get_pixelv(pixel_pos).r * height_scale
