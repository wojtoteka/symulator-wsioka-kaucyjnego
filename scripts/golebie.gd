extends Node3D
## GOŁĘBIE (dodatek od Claude'a) — stadko dziobie na chodniku.
## Podbiegasz — odlatują z furkotem i lądują gdzie indziej.
## Czasem któryś zostawi "prezent". Taki osiedlowy chrzest.

const ILE := 6
const DYSTANS_STRACHU := 2.6

var _ptaki: Array[Dictionary] = []   # {wezel, leci, timer}
var _gracz: Node3D = null

func _ready() -> void:
	for i in ILE:
		_stworz_golebia()
	await get_tree().process_frame
	var gracze := get_tree().get_nodes_in_group("gracz")
	if gracze.size() > 0:
		_gracz = gracze[0]

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _stworz_golebia() -> void:
	var ptak := Node3D.new()
	# Tułów — szara kulka
	var tulow := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.12
	kula.height = 0.2
	tulow.mesh = kula
	tulow.material_override = _material(Color(0.55, 0.55, 0.6))
	tulow.position = Vector3(0, 0.1, 0)
	ptak.add_child(tulow)
	# Głowa
	var glowa := MeshInstance3D.new()
	var mala := SphereMesh.new()
	mala.radius = 0.06
	mala.height = 0.12
	glowa.mesh = mala
	glowa.material_override = _material(Color(0.4, 0.45, 0.55))
	glowa.position = Vector3(0, 0.2, 0.1)
	ptak.add_child(glowa)
	# Ogon
	var ogon := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.08, 0.03, 0.14)
	ogon.mesh = pudlo
	ogon.material_override = _material(Color(0.45, 0.45, 0.5))
	ogon.position = Vector3(0, 0.12, -0.13)
	ptak.add_child(ogon)
	ptak.position = _losowe_miejsce()
	ptak.rotation.y = randf() * TAU
	add_child(ptak)
	_ptaki.append({"wezel": ptak, "leci": false, "timer": 0.0})

## Miejsca lądowania: okolice głównego chodnika.
func _losowe_miejsce() -> Vector3:
	return Vector3(randf_range(-2.5, 2.5), 0, randf_range(-22.0, 18.0))

func _process(delta: float) -> void:
	if not _gracz or Game.w_menu:
		return
	for dane in _ptaki:
		var ptak: Node3D = dane["wezel"]
		if dane["leci"]:
			dane["timer"] -= delta
			if dane["timer"] <= 0.0:
				# Ląduje w nowym miejscu, jakby nigdy nic
				dane["leci"] = false
				ptak.position = _losowe_miejsce()
				ptak.scale = Vector3.ONE
				ptak.rotation.y = randf() * TAU
		elif ptak.global_position.distance_to(_gracz.global_position) < DYSTANS_STRACHU:
			_odlec(dane)

## Panika: gołąb odlatuje w górę i w dal, malejąc w oczach.
func _odlec(dane: Dictionary) -> void:
	dane["leci"] = true
	dane["timer"] = randf_range(5.0, 9.0)
	var ptak: Node3D = dane["wezel"]
	Sfx.graj("furkot", -4.0, randf_range(0.9, 1.2))
	var kierunek := (ptak.global_position - _gracz.global_position).normalized()
	kierunek.y = 0
	var cel := ptak.position + kierunek * 8.0 + Vector3(0, 9.0, 0)
	var tw := ptak.create_tween()
	tw.tween_property(ptak, "position", cel, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ptak, "scale", Vector3.ONE * 0.4, 1.3)
	# Rzadki bonus fabularny
	if randf() < 0.1:
		Game.pokaz_komunikat("Gołąb zostawił ci prezent na czapce. Osiedlowy chrzest. Wsiokometr +3.")
		Game.dodaj_wsiokometr(3.0)
