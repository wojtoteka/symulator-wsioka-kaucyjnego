class_name Efekty
## PROSTE EFEKTY CZĄSTECZKOWE — tworzone w całości w kodzie.
## Użycie: Efekty.blysk(rodzic, pozycja, kolor) / Efekty.kurz(rodzic, pozycja)

## Iskierki przy podnoszeniu przedmiotu (złote fanty = złote iskry).
static func blysk(rodzic: Node, pozycja: Vector3, kolor: Color) -> void:
	var p := _czastki(kolor, 0.06)
	p.amount = 14
	p.lifetime = 0.5
	p.spread = 55.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -7, 0)
	p.position = pozycja
	rodzic.add_child(p)
	_posprzataj(rodzic, p)

## Kłęby kurzu przy glebie / wywrotce wózkiem.
static func kurz(rodzic: Node, pozycja: Vector3) -> void:
	var p := _czastki(Color(0.55, 0.48, 0.38), 0.14)
	p.amount = 18
	p.lifetime = 0.7
	p.spread = 85.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -2, 0)
	p.position = pozycja + Vector3(0, 0.2, 0)
	rodzic.add_child(p)
	_posprzataj(rodzic, p)

## Wspólna konfiguracja emitera (jeden wybuch cząsteczek).
static func _czastki(kolor: Color, promien: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	var kula := SphereMesh.new()
	kula.radius = promien
	kula.height = promien * 2
	kula.radial_segments = 6
	kula.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kolor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kula.material = mat
	p.mesh = kula
	return p

## Emiter sam znika po zakończeniu wybuchu.
static func _posprzataj(rodzic: Node, p: CPUParticles3D) -> void:
	rodzic.get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
