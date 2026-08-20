extends CharacterBody3D
## KONKURENT-WSIOK "HENIEK" — chodzi po mapie do najbliższych butelek
## i je zabiera. Wymusza pośpiech! Na szczęście jest wolniejszy od gracza
## i lubi sobie odpocząć. Złotych fantów "nie poznaje" — zostawia je.

const Kolekcjonerski := preload("res://scripts/collectible.gd")

const ZASIEG_ZBIERANIA := 1.3

## Heniek z każdym dniem kariery jest odrobinę szybszy (trenuje po godzinach)
var predkosc := Balans.PREDKOSC_HENKA

const TEKSTY_KRADZIEZY: Array[String] = [
	"Heniek zwinął butelkę sprzed nosa!",
	"Konkurencja nie śpi — Heniek znowu szybszy.",
	"Heniek: \"Kto pierwszy, ten lepszy, młody!\"",
	"Heniek pakuje TWOJĄ butelkę do swojej siaty.",
]

var grawitacja: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cel: Node3D = null        # butelka, do której idzie
var _odpoczynek := 3.0         # start z małym opóźnieniem — fory dla gracza
var _czas_w_miejscu := 0.0     # wykrywanie utknięcia na przeszkodzie
var _zbiera := false

func _ready() -> void:
	add_to_group("bijalne")   # można mu przywalić (F) — czasem oddaje
	predkosc = Balans.PREDKOSC_HENKA + minf(0.15 * (Game.dzien - 1), 1.2)
	_zbuduj_postac()
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := CapsuleShape3D.new()
	ksztalt.radius = 0.4
	ksztalt.height = 1.7
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 0.9, 0)
	add_child(kolizja)

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_postac() -> void:
	# Bordowy dres — konkurencyjna szkoła wsiokowania
	var tulow := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.35
	kapsula.height = 1.1
	tulow.mesh = kapsula
	tulow.material_override = _material(Color(0.45, 0.12, 0.15))
	tulow.position = Vector3(0, 0.8, 0)
	add_child(tulow)
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.26
	kula.height = 0.52
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.88, 0.7, 0.55))
	glowa.position = Vector3(0, 1.56, 0)
	add_child(glowa)
	# Siwa broda doświadczonego zbieracza
	var broda := MeshInstance3D.new()
	var pudlo_brody := BoxMesh.new()
	pudlo_brody.size = Vector3(0.24, 0.18, 0.1)
	broda.mesh = pudlo_brody
	broda.material_override = _material(Color(0.8, 0.8, 0.8))
	broda.position = Vector3(0, 1.42, -0.22)
	add_child(broda)
	# Siata z butelkami (zamiast plecaka)
	var siata := MeshInstance3D.new()
	var pudlo_siaty := BoxMesh.new()
	pudlo_siaty.size = Vector3(0.35, 0.45, 0.25)
	siata.mesh = pudlo_siaty
	siata.material_override = _material(Color(0.9, 0.9, 0.95))
	siata.position = Vector3(0.4, 0.5, 0)
	add_child(siata)
	# Imię nad głową — niech gracz wie, kto go okrada
	var imie := Styl.plakietka("Heniek", 64, Color(1.0, 0.6, 0.6))
	imie.position = Vector3(0, 2.2, 0)
	add_child(imie)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= grawitacja * delta
	if not Game.gra_trwa or Game.w_menu or _zbiera:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	# Odpoczynek między akcjami (Heniek nie jest już najmłodszy)
	if _odpoczynek > 0.0:
		_odpoczynek -= delta
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	# Szukamy celu, jeśli go nie ma albo zniknął
	if not is_instance_valid(_cel):
		_cel = _znajdz_cel()
		if not _cel:
			_odpoczynek = 2.0   # brak butelek — czekamy
			return
	# Idziemy do celu
	var kierunek := _cel.global_position - global_position
	kierunek.y = 0
	if kierunek.length() < ZASIEG_ZBIERANIA:
		_zbierz_cel()
		return
	kierunek = kierunek.normalized()
	velocity.x = kierunek.x * predkosc
	velocity.z = kierunek.z * predkosc
	# Obrót w stronę marszu
	look_at(global_position + kierunek, Vector3.UP)
	move_and_slide()
	# Wykrywanie utknięcia (np. na kontenerze) — po 2 s zmieniamy cel
	if Vector2(velocity.x, velocity.z).length() < 0.5:
		_czas_w_miejscu += delta
		if _czas_w_miejscu > 2.0:
			_czas_w_miejscu = 0.0
			_cel = null
			_odpoczynek = 1.0
	else:
		_czas_w_miejscu = 0.0

## Najbliższa butelka na mapie (złote ignoruje — "nie poznał się na złocie").
func _znajdz_cel() -> Node3D:
	var najlepszy: Node3D = null
	var najmniejszy_dystans := INF
	for obiekt in get_tree().get_nodes_in_group("kolekcjonerskie"):
		if not is_instance_valid(obiekt):
			continue
		if Kolekcjonerski.czy_zloty(obiekt.typ):
			continue
		var d: float = global_position.distance_to(obiekt.global_position)
		if d < najmniejszy_dystans:
			najmniejszy_dystans = d
			najlepszy = obiekt
	return najlepszy

## Heniek schyla się i zabiera butelkę.
func _zbierz_cel() -> void:
	_zbiera = true
	velocity.x = 0
	velocity.z = 0
	# Animacja schylania
	var tw := create_tween()
	tw.tween_property(self, "scale:y", 0.7, 0.3)
	tw.tween_property(self, "scale:y", 1.0, 0.3)
	tw.tween_callback(_zakoncz_zbieranie)

func _zakoncz_zbieranie() -> void:
	_zbiera = false
	if is_instance_valid(_cel) and _cel.zabierz_przez_konkurenta():
		# Nie spamujemy — komunikat tylko czasami
		if randf() < 0.35:
			Game.pokaz_komunikat(TEKSTY_KRADZIEZY.pick_random())
	_cel = null
	_odpoczynek = randf_range(4.0, 7.0)   # Heniek celebruje sukces

## Cios od gracza: zwykle gubi butelki, ale czasem przypomina sobie boks.
func oberwij(gracz: Node3D) -> void:
	_cel = null
	_odpoczynek = 6.0
	if randf() < Balans.SZANSA_BOKSU_HENKA:
		Game.pokaz_komunikat("Heniek trenował boks w latach 80. GLEBA.")
		gracz.gleba()
		return
	var ile := randi_range(1, 2)
	Game.pokaz_komunikat("Heniek upuścił %d szt.! Zbieraj, póki liczy gwiazdy!" % ile)
	for i in ile:
		var przedmiot := Kolekcjonerski.new()
		przedmiot.typ = Kolekcjonerski.losowy_typ()
		var kat := randf() * TAU
		przedmiot.position = global_position + Vector3(cos(kat), 0, sin(kat)) * randf_range(0.8, 1.4)
		get_parent().add_child(przedmiot)
	# Heniek się zatacza
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.3, 0.15)
	tw.tween_property(self, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE)
