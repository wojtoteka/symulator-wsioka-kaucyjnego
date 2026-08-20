extends Area3D
## TRZEPAK — legendarna siłownia osiedlowa. E = seria podciągnięć
## (pełna regeneracja Papierosa i +10 do Wsiokometru).

const WYSOKOSC_DRAZKA := 2.4

func _ready() -> void:
	add_to_group("interakcja")
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = 1.8
	ksztalt.shape = kula
	ksztalt.position = Vector3(0, 1.2, 0)
	add_child(ksztalt)
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	var kolor := Color(0.5, 0.15, 0.15)
	# Dwa słupki + poprzeczka
	for x in [-1.5, 1.5]:
		var slupek := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.06
		walec.bottom_radius = 0.06
		walec.height = 2.5
		slupek.mesh = walec
		slupek.material_override = _material(kolor)
		slupek.position = Vector3(x, 1.25, 0)
		add_child(slupek)
	var poprzeczka := MeshInstance3D.new()
	var walec_poprzeczki := CylinderMesh.new()
	walec_poprzeczki.top_radius = 0.05
	walec_poprzeczki.bottom_radius = 0.05
	walec_poprzeczki.height = 3.0
	poprzeczka.mesh = walec_poprzeczki
	poprzeczka.material_override = _material(kolor)
	poprzeczka.rotation.z = PI / 2
	poprzeczka.position = Vector3(0, WYSOKOSC_DRAZKA, 0)
	add_child(poprzeczka)

func podpowiedz() -> String:
	return "E — podciągnij się na trzepaku"

func interakcja(gracz: Node3D) -> void:
	gracz.podciagnij_sie(global_position + Vector3(0, WYSOKOSC_DRAZKA, 0))
