extends StaticBody3D
## NPC SĄSIADKA - stoi przy bloku, obserwuje i komentuje z dezaprobatą,
## gdy gracz podejdzie za blisko. Obraca się w stronę gracza.

const TEKSTY: Array[String] = [
	"Sąsiadka patrzy z dezaprobatą.",
	"Sąsiadka: \"Znowu grzebiesz w śmieciach, Mariusz?\"",
	"Sąsiadka: \"Za moich czasów to się PRACOWAŁO.\"",
	"Sąsiadka: \"Powiem twojej matce!\"",
	"Sąsiadka szeptem do telefonu: \"...tak, znowu ten od butelek...\"",
	"Sąsiadka: \"A weź mi z kosza nie wyjadaj!\"",
]

const CZAS_ODNOWIENIA := 12.0  # sekundy między komentarzami

var _gracz_w_poblizu: Node3D = null
var _odliczanie := 0.0

func _ready() -> void:
	add_to_group("bijalne")   # można jej "nawalić" (F)... na własne ryzyko
	_zbuduj_bryle()
	# Strefa wykrywania gracza
	var strefa := Area3D.new()
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = 5.0
	ksztalt.shape = kula
	strefa.add_child(ksztalt)
	strefa.position = Vector3(0, 1, 0)
	add_child(strefa)
	strefa.body_entered.connect(_ktos_wszedl)
	strefa.body_exited.connect(_ktos_wyszedl)

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_bryle() -> void:
	# Płaszcz w kwiatki (no dobra, beżowy)
	var cialo := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.38
	kapsula.height = 1.15
	cialo.mesh = kapsula
	cialo.material_override = _material(Color(0.72, 0.6, 0.5))
	cialo.position = Vector3(0, 0.75, 0)
	add_child(cialo)
	# Głowa
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.24
	kula.height = 0.48
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.9, 0.75, 0.62))
	glowa.position = Vector3(0, 1.5, 0)
	add_child(glowa)
	# Beret (fioletowy, a jakże)
	var beret := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.2
	walec.bottom_radius = 0.28
	walec.height = 0.1
	beret.mesh = walec
	beret.material_override = _material(Color(0.45, 0.2, 0.5))
	beret.position = Vector3(0, 1.7, 0)
	add_child(beret)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := CapsuleShape3D.new()
	ksztalt.radius = 0.4
	ksztalt.height = 1.7
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 0.85, 0)
	add_child(kolizja)

func _process(delta: float) -> void:
	_odliczanie -= delta
	if _gracz_w_poblizu:
		# Obraca się w stronę gracza (tylko w osi Y) - "obserwuje"
		var cel := _gracz_w_poblizu.global_position
		cel.y = global_position.y
		if global_position.distance_to(cel) > 0.5:
			look_at(cel, Vector3.UP)
		# Komentarz co jakiś czas
		if _odliczanie <= 0.0 and Game.gra_trwa:
			_odliczanie = CZAS_ODNOWIENIA
			Game.pokaz_komunikat(TEKSTY.pick_random())

func _ktos_wszedl(cialo: Node3D) -> void:
	# Tylko gracz - Heńka sąsiadka zna od lat i już nie komentuje
	if cialo is CharacterBody3D and cialo.is_in_group("gracz"):
		_gracz_w_poblizu = cialo

func _ktos_wyszedl(cialo: Node3D) -> void:
	if cialo == _gracz_w_poblizu:
		_gracz_w_poblizu = null

## Ktoś podniósł rękę na sąsiadkę. Torebka waży 4 kg (same klucze).
func oberwij(gracz: Node3D) -> void:
	_odliczanie = CZAS_ODNOWIENIA   # obrażona - chwilę nie komentuje
	# Animacja oburzenia
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.15, 0.08)
	tw.tween_property(self, "rotation:z", -0.12, 0.08)
	tw.tween_property(self, "rotation:z", 0.0, 0.08)
	if randf() < Balans.SZANSA_TOREBKI:
		Game.pokaz_komunikat("Sąsiadka ODDAJE TOREBKĄ! Trafienie krytyczne - gleba!")
		gracz.gleba()
	else:
		Game.pokaz_komunikat("Sąsiadka: POLICJAAAA!!! (nikt nie przyjechał). Wsiokometr +5 za odwagę.")
		Game.dodaj_wsiokometr(5.0)
