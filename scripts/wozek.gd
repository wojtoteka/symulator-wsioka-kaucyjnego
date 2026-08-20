extends StaticBody3D
## WÓZEK SKLEPOWY — stoi przy Biedronce. E = wsiadasz i jeździsz
## (śliska fizyka obsługiwana w player.gd). Podczas jazdy obiekt
## na mapie się chowa, a przy wysiadaniu wraca obok gracza.

var _kolizja: CollisionShape3D

func _ready() -> void:
	add_to_group("interakcja")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	# Kosz
	var kosz := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.75, 0.55, 1.0)
	kosz.mesh = pudlo
	kosz.material_override = _material(Color(0.7, 0.72, 0.76))
	kosz.position = Vector3(0, 0.65, -0.1)
	add_child(kosz)
	# Rączka
	var raczka := MeshInstance3D.new()
	var pudlo_raczki := BoxMesh.new()
	pudlo_raczki.size = Vector3(0.8, 0.06, 0.06)
	raczka.mesh = pudlo_raczki
	raczka.material_override = _material(Color(0.85, 0.2, 0.2))
	raczka.position = Vector3(0, 1.05, 0.45)
	add_child(raczka)
	# Kółka
	for przesuniecie in [Vector3(-0.3, 0.12, -0.5), Vector3(0.3, 0.12, -0.5), Vector3(-0.3, 0.12, 0.35), Vector3(0.3, 0.12, 0.35)]:
		var kolo := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.1
		walec.bottom_radius = 0.1
		walec.height = 0.05
		kolo.mesh = walec
		kolo.material_override = _material(Color(0.15, 0.15, 0.15))
		kolo.rotation.z = PI / 2
		kolo.position = przesuniecie
		add_child(kolo)
	# Kolizja
	_kolizja = CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(0.8, 1.1, 1.1)
	_kolizja.shape = ksztalt
	_kolizja.position = Vector3(0, 0.55, 0)
	add_child(_kolizja)

func podpowiedz() -> String:
	return "E — wsiądź do wózka (Biedronka tego nie pochwala)"

## Gracz wsiada — wózek znika z mapy (postać "przejmuje" jego wygląd).
func interakcja(gracz: Node3D) -> void:
	if not gracz.is_in_group("gracz"):
		return
	gracz.wsiadz_do_wozka(self)
	visible = false
	_kolizja.set_deferred("disabled", true)

## Gracz wysiada — wózek wraca na mapę we wskazanym miejscu.
func odstaw(pozycja: Vector3) -> void:
	global_position = Vector3(pozycja.x, 0, pozycja.z)
	visible = true
	_kolizja.set_deferred("disabled", false)
