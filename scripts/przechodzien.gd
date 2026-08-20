extends Node3D
## PRZECHODZIEŃ — spaceruje chodnikiem tam i z powrotem.
## Gdy gracz go mija, czasem pojawia się komentarz pełen dezaprobaty.

const PREDKOSC := 2.0
const ZASIEG_KOMENTARZA := 4.0
const PRZERWA_KOMENTARZY := 10.0

const TEKSTY: Array[String] = [
	"Ktoś kręci głową.",
	"Przechodzień przyspiesza kroku.",
	"Przechodzień udaje, że nie widzi.",
	"Słyszysz szept: \"...znowu ten od butelek...\"",
	"Przechodzień ściska siatkę mocniej.",
	"Ktoś robi ci zdjęcie. Pewnie na grupę osiedlową.",
]

## Trasa: spacer po głównym chodniku (oś Z), z nawrotami.
var punkt_a := Vector3(1.3, 0, 18.0)
var punkt_b := Vector3(1.3, 0, -22.0)

var _cel: Vector3
var _odliczanie := 0.0
var _ucieczka := 0.0   # sekundy panicznego sprintu po oberwaniu
var _gracz: Node3D = null

func _ready() -> void:
	add_to_group("bijalne")
	_zbuduj_postac()
	_cel = punkt_b
	# Znajdujemy gracza raz (po grupie)
	await get_tree().process_frame
	var gracze := get_tree().get_nodes_in_group("gracz")
	if gracze.size() > 0:
		_gracz = gracze[0]

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_postac() -> void:
	# Szary płaszcz "przeciętnego obywatela"
	var cialo := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.33
	kapsula.height = 1.2
	cialo.mesh = kapsula
	cialo.material_override = _material(Color(0.45, 0.45, 0.5))
	cialo.position = Vector3(0, 0.8, 0)
	add_child(cialo)
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.24
	kula.height = 0.48
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.88, 0.72, 0.6))
	glowa.position = Vector3(0, 1.55, 0)
	add_child(glowa)
	# Kapelusz
	var kapelusz := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.18
	walec.bottom_radius = 0.3
	walec.height = 0.14
	kapelusz.mesh = walec
	kapelusz.material_override = _material(Color(0.2, 0.2, 0.22))
	kapelusz.position = Vector3(0, 1.74, 0)
	add_child(kapelusz)
	# Siatka z zakupami (której NIE odda na kaucję)
	var siatka := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.25, 0.35, 0.2)
	siatka.mesh = pudlo
	siatka.material_override = _material(Color(0.85, 0.75, 0.3))
	siatka.position = Vector3(0.42, 0.45, 0)
	add_child(siatka)

func _process(delta: float) -> void:
	if Game.w_menu:
		return
	_odliczanie -= delta
	_ucieczka -= delta
	# Spacer do celu i nawrót (po oberwaniu — paniczny sprint)
	var predkosc := PREDKOSC * (3.2 if _ucieczka > 0.0 else 1.0)
	var kierunek := _cel - global_position
	kierunek.y = 0
	if kierunek.length() < 0.5:
		_cel = punkt_a if _cel == punkt_b else punkt_b
		return
	kierunek = kierunek.normalized()
	global_position += kierunek * predkosc * delta
	look_at(global_position + kierunek, Vector3.UP)
	# Komentarz przy mijaniu gracza
	if _gracz and _odliczanie <= 0.0 and Game.gra_trwa:
		if global_position.distance_to(_gracz.global_position) < ZASIEG_KOMENTARZA:
			_odliczanie = PRZERWA_KOMENTARZY
			Game.pokaz_komunikat(TEKSTY.pick_random())

## Oberwał — ucieka, godność zostaje na chodniku.
func oberwij(_gracz_bijacy: Node3D) -> void:
	_ucieczka = 6.0
	_odliczanie = PRZERWA_KOMENTARZY
	Game.pokaz_komunikat("Przechodzień ucieka sprintem! Zostawił za sobą godność.")
