extends StaticBody3D
## ŁAWKA OSIEDLOWA — można na niej usiąść (E) i odpocząć.
## Na siedząco "Papieros" regeneruje się podwójnie. E ponownie = wstajesz.

func _ready() -> void:
	add_to_group("interakcja")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	for czesc in [
		[Vector3(0, 0.45, 0), Vector3(1.8, 0.08, 0.5), Paleta.DREWNO],       # siedzisko
		[Vector3(0, 0.8, -0.22), Vector3(1.8, 0.5, 0.06), Paleta.DREWNO],    # oparcie
		[Vector3(-0.75, 0.22, 0), Vector3(0.1, 0.45, 0.4), Paleta.METAL],    # noga
		[Vector3(0.75, 0.22, 0), Vector3(0.1, 0.45, 0.4), Paleta.METAL],     # noga
	]:
		var mesh := MeshInstance3D.new()
		var pudlo := BoxMesh.new()
		pudlo.size = czesc[1]
		mesh.mesh = pudlo
		mesh.material_override = _material(czesc[2])
		mesh.position = czesc[0]
		add_child(mesh)
	# Kolizja całej ławki jednym pudłem
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(1.8, 1.0, 0.6)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 0.5, 0)
	add_child(kolizja)

func podpowiedz() -> String:
	return "E — usiądź na ławce"

## Sadzamy gracza na siedzisku, twarzą od oparcia.
func interakcja(gracz: Node3D) -> void:
	if gracz.has_method("usiadz"):
		var miejsce := to_global(Vector3(0, 0.05, 0.02))
		gracz.usiadz(miejsce, rotation.y + PI)
