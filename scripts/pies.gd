extends Area3D
## PIES NA ŁAŃCUCHU — stoi przy budzie obok bloku. Gdy gracz podejdzie
## za blisko, szczeka i szarpie się na łańcuchu (nie może dosięgnąć).
## Można go pogłaskać (E)... na własne ryzyko. Bicie psa = hańba.

const ZASIEG_SZCZEKANIA := 6.0
const DLUGOSC_LANCUCHA := 2.0

var _pies: Node3D          # bryła psa (do animacji szarpania)
var _gracz: Node3D = null
var _odliczanie := 0.0
var _pozycja_bazowa: Vector3

func _ready() -> void:
	add_to_group("interakcja")   # E = głaskanie
	add_to_group("bijalne")      # F = ... lepiej nie
	# Strefa głaskania wokół psa (wykrywana przez zasięg gracza)
	var ksztalt_glaskania := CollisionShape3D.new()
	var kula_glaskania := SphereShape3D.new()
	kula_glaskania.radius = 1.5
	ksztalt_glaskania.shape = kula_glaskania
	ksztalt_glaskania.position = Vector3(0, 0.5, 1.6)
	add_child(ksztalt_glaskania)
	_zbuduj_bude()
	_zbuduj_psa()
	_pozycja_bazowa = _pies.position
	# Strefa wykrywania gracza
	var strefa := Area3D.new()
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = ZASIEG_SZCZEKANIA
	ksztalt.shape = kula
	strefa.add_child(ksztalt)
	strefa.position = Vector3(0, 1, 0)
	add_child(strefa)
	strefa.body_entered.connect(_ktos_wszedl)
	strefa.body_exited.connect(_ktos_wyszedl)

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_bude() -> void:
	var buda := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(1.3, 1.0, 1.3)
	buda.mesh = pudlo
	buda.material_override = _material(Color(0.4, 0.26, 0.13))
	buda.position = Vector3(0, 0.5, 0)
	add_child(buda)
	var dach := MeshInstance3D.new()
	var pudlo_dachu := BoxMesh.new()
	pudlo_dachu.size = Vector3(1.5, 0.15, 1.5)
	dach.mesh = pudlo_dachu
	dach.material_override = _material(Color(0.3, 0.18, 0.08))
	dach.position = Vector3(0, 1.07, 0)
	add_child(dach)
	# Czarne wejście
	var wejscie := MeshInstance3D.new()
	var pudlo_wejscia := BoxMesh.new()
	pudlo_wejscia.size = Vector3(0.55, 0.6, 0.05)
	wejscie.mesh = pudlo_wejscia
	wejscie.material_override = _material(Color(0.05, 0.05, 0.05))
	wejscie.position = Vector3(0, 0.4, 0.66)
	add_child(wejscie)

func _zbuduj_psa() -> void:
	_pies = Node3D.new()
	_pies.position = Vector3(0, 0, 1.6)
	add_child(_pies)
	# Tułów
	var tulow := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.2
	kapsula.height = 0.75
	tulow.mesh = kapsula
	tulow.material_override = _material(Color(0.25, 0.2, 0.15))
	tulow.rotation.x = PI / 2   # kapsuła poziomo = tułów psa
	tulow.position = Vector3(0, 0.35, 0)
	_pies.add_child(tulow)
	# Głowa
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.16
	kula.height = 0.32
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.3, 0.24, 0.18))
	glowa.position = Vector3(0, 0.5, 0.42)
	_pies.add_child(glowa)
	# Uszy (trójkątne pudełka)
	for x in [-0.08, 0.08]:
		var ucho := MeshInstance3D.new()
		var pudlo_ucha := BoxMesh.new()
		pudlo_ucha.size = Vector3(0.06, 0.12, 0.04)
		ucho.mesh = pudlo_ucha
		ucho.material_override = _material(Color(0.15, 0.12, 0.09))
		ucho.position = Vector3(x, 0.65, 0.4)
		_pies.add_child(ucho)
	# Ogon
	var ogon := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.03
	walec.bottom_radius = 0.05
	walec.height = 0.3
	ogon.mesh = walec
	ogon.material_override = _material(Color(0.25, 0.2, 0.15))
	ogon.rotation.x = -0.7
	ogon.position = Vector3(0, 0.5, -0.4)
	_pies.add_child(ogon)
	# Łańcuch — kilka ciemnych kulek między budą a psem
	for i in 4:
		var ogniwo := MeshInstance3D.new()
		var kulka := SphereMesh.new()
		kulka.radius = 0.05
		kulka.height = 0.1
		ogniwo.mesh = kulka
		ogniwo.material_override = _material(Color(0.35, 0.35, 0.38))
		ogniwo.position = Vector3(0, 0.25, 0.3 + i * 0.35)
		add_child(ogniwo)

func _process(_delta: float) -> void:
	if not _gracz:
		return
	# Pies patrzy na gracza
	var cel := _gracz.global_position
	cel.y = _pies.global_position.y
	if _pies.global_position.distance_to(cel) > 0.3:
		_pies.look_at(cel, Vector3.UP)
	# Szczeka co ~2,5 s, dopóki gracz jest w zasięgu
	_odliczanie -= _delta
	if _odliczanie <= 0.0 and Game.gra_trwa and not Game.w_menu:
		_odliczanie = 2.5
		Sfx.graj("szczek", 0.0, randf_range(0.9, 1.1))
		_szarpniecie()

## Pies rzuca się w stronę gracza, ale łańcuch go zatrzymuje.
func _szarpniecie() -> void:
	if not _gracz:
		return
	var kierunek := (_gracz.global_position - global_position)
	kierunek.y = 0
	var cel := _pozycja_bazowa + (kierunek.normalized() * DLUGOSC_LANCUCHA).rotated(Vector3.UP, -rotation.y)
	var tw := create_tween()
	tw.tween_property(_pies, "position", cel, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pies, "position", _pozycja_bazowa, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Głaskanie psa (E) — hazard emocjonalny.
func podpowiedz() -> String:
	return "E — pogłaszcz psa (na własne ryzyko)"

func interakcja(gracz: Node3D) -> void:
	if randf() > Balans.SZANSA_ZLEGO_PSA:
		Sfx.graj("pies_lubi")
		Game.dodaj_wsiokometr(10.0)
		Game.pokaz_komunikat("Pies merda ogonem! Wsiokometr +10. Serce topnieje.")
		_merdaj()
	else:
		Sfx.graj("szczek", 2.0, 1.15)
		Game.pokaz_komunikat("Pies NIE był w nastroju. Prawie zawał — gleba ze strachu.")
		gracz.gleba()

## Próba uderzenia psa — absolutnie nie.
func oberwij(gracz: Node3D) -> void:
	Sfx.graj("szczek", 4.0, 0.9)
	Game.dodaj_wsiokometr(-15.0)
	Game.pokaz_komunikat("PSA SIĘ NIE BIJE! Wstyd na całe osiedle. Wsiokometr -15, pies gryzie w kostkę.")
	gracz.gleba()

## Radosny podskok po udanym głaskaniu.
func _merdaj() -> void:
	var tw := create_tween()
	tw.tween_property(_pies, "position:y", 0.35, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pies, "position:y", _pozycja_bazowa.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _ktos_wszedl(cialo: Node3D) -> void:
	if cialo is CharacterBody3D and cialo.is_in_group("gracz"):
		_gracz = cialo
		Game.pokaz_komunikat("Pies: HAU HAU HAU! (wyczuł wsioka)")

func _ktos_wyszedl(cialo: Node3D) -> void:
	if cialo == _gracz:
		_gracz = null
