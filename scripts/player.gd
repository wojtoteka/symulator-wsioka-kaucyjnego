extends CharacterBody3D
## GRACZ - "wsiok kaucyjny".
## Ruch WASD, skok (spacja), przysiad (Ctrl), sprint (Shift, zużywa "Papierosa"),
## interakcja (E), kamera TPP/FPP (V).
## Dodatkowo: komiczne potknięcia o kamienie i jazda wózkiem sklepowym.
## Wygląd postaci i kamera budowane są w kodzie w _ready().

const CZULOSC_MYSZY := 0.003
const ZASIEG_INTERAKCJI := 2.4

# Wartości ruchu i staminy - patrz scripts/balans.gd
const PREDKOSC_CHODU := Balans.PREDKOSC_CHODU
const PREDKOSC_SPRINTU := Balans.PREDKOSC_SPRINTU
const PREDKOSC_KUCANIA := Balans.PREDKOSC_KUCANIA
const SILA_SKOKU := Balans.SILA_SKOKU
const PAPIEROS_ZUZYCIE := Balans.PAPIEROS_ZUZYCIE
const PAPIEROS_REGENERACJA := Balans.PAPIEROS_REGENERACJA
const WOZEK_MAKS := Balans.WOZEK_MAKS
const WOZEK_PRZYSPIESZENIE := Balans.WOZEK_PRZYSPIESZENIE
const WOZEK_HAMOWANIE := Balans.WOZEK_HAMOWANIE

var grawitacja: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pierwsza_osoba := false
var papieros := 100.0             # 0-100
var lezy := false                 # true = leżymy po potknięciu
var w_wozku := false

var _ramie: SpringArm3D           # wysięgnik kamery
var _kamera: Camera3D
var _wyglad: Node3D               # wizualna część postaci (do chowania w FPP)
var _plecak_mesh: MeshInstance3D  # plecak rośnie z liczbą butelek
var _zasieg: Area3D               # wykrywa interaktywne obiekty
var _stopy: Area3D                # wykrywa kamienie (potknięcia)
var _najblizszy: Node3D = null    # najbliższy obiekt do interakcji
var _niesmiertelnosc := 0.0       # chwila spokoju po wstaniu z gleby
var _wozek: Node3D = null         # obiekt pojazdu na mapie (gdy nim jedziemy)
var _wozek_wizual: Node3D         # kopia wózka doczepiona do gracza
var _skuter_wizual: Node3D        # kopia skutera doczepiona do gracza
var _wozek_predkosc := 0.0
var _typ_pojazdu := "wozek"       # klucz w Balans.POJAZDY
var _drift := false               # czy właśnie idziemy bokiem
var _drift_dzwiek := 0.0          # odliczanie zgrzytu opon
var _czas_lotu := 0.0             # ile sekund w powietrzu (bonus za trick)
var _auto_zbieranie := 0.0        # timer automatycznego zbierania z wózka
var _reka_l: Node3D               # barki - do machania rękami
var _reka_p: Node3D
var _noga_l: Node3D               # biodra - do animacji nóg
var _noga_p: Node3D
var _faza_kroku := 0.0            # faza animacji chodu
var _piwo := 0.0                  # sekundy upojenia (kumuluje się z każdym piwem!)
var _piwa_wypite := 0             # licznik piw w tej "sesji" - im więcej, tym gorzej
var _kac := 0.0                   # sekundy kaca po zejściu upojenia
var _energetyk := 0.0             # sekundy podkręcenia z energetyka (bez kaca)
var _cwiczy := false              # true = podciąganie na trzepaku
var siedzi := false               # true = odpoczynek na ławce
var _wstrzas := 0.0               # siła screen shake'a (wygasa sama)
var _ostatni_krok := 0            # numer ostatniego kroku (dźwięki kroków)

const TEKSTY_GLEBY: Array[String] = [
	"GLEBA! Krawężnik: 1, Ty: 0.",
	"Efektowny upadek! Sąsiedzi dają 10/10 za styl.",
	"Prawa fizyki znowu wygrały.",
	"Kamień był szybszy.",
	"Sprint zakończony glebą. Klasyka.",
]

func _ready() -> void:
	add_to_group("gracz")   # po tej grupie rozpoznają nas NPC
	_zbuduj_postac()
	_zbuduj_kamere()
	_zbuduj_zasieg()
	_zbuduj_wozek_wizual()
	_zbuduj_skuter_wizual()
	# W menu głównym mysz jest wolna - HUD ją przechwyci po starcie
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.w_menu else Input.MOUSE_MODE_CAPTURED
	# Plecak wizualnie puchnie, gdy zbieramy butelki
	Game.backpack_changed.connect(_aktualizuj_plecak)
	# Screen shake na sygnał (złote fanty, gleby, jackpoty)
	Game.wstrzas.connect(func(sila: float) -> void: _wstrzas = maxf(_wstrzas, sila))

# --- Budowanie wyglądu (proste bryły w stylu "dres i czapka") ---

## Materiał w stylu gry (toon + gruby kontur) - patrz scripts/styl.gd.
## Gracz dostaje najgrubszą obwódkę: musi być czytelny na każdym tle.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_postac() -> void:
	_wyglad = Node3D.new()
	_wyglad.name = "Wyglad"
	add_child(_wyglad)

	# Tułów - granatowy dres (krótszy, bo od teraz mamy prawdziwe NOGI).
	# Po kupieniu ZŁOTEGO DRESU w MELINIE strój zmienia się na złoty.
	var zloty: bool = int(Game.ulepszenia.get("dres", 0)) > 0
	var tulow := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.33
	kapsula.height = 0.95
	tulow.mesh = kapsula
	# Złoty dres dostaje własny (nie współdzielony) materiał - inaczej
	# metaliczność przelałaby się na wszystko w tym samym kolorze
	var mat_dresu := _material(Color(0.15, 0.2, 0.45))
	if zloty:
		mat_dresu = Styl.bryla(Color(0.85, 0.68, 0.12), Styl.KONTUR_POSTAC, false, true)
		mat_dresu.metallic = 0.7
		mat_dresu.roughness = 0.28
	tulow.material_override = mat_dresu
	tulow.position = Vector3(0, 1.0, 0)
	_wyglad.add_child(tulow)

	# Nogi - dresowe, machają przy chodzeniu (obrót w biodrze)
	for strona in [-1.0, 1.0]:
		var biodro := Node3D.new()
		biodro.position = Vector3(strona * 0.16, 0.62, 0)
		_wyglad.add_child(biodro)
		var noga := MeshInstance3D.new()
		var kapsula_nogi := CapsuleMesh.new()
		kapsula_nogi.radius = 0.11
		kapsula_nogi.height = 0.52
		noga.mesh = kapsula_nogi
		noga.material_override = _material(Color(0.72, 0.56, 0.1) if zloty else Color(0.12, 0.16, 0.38))
		noga.position = Vector3(0, -0.24, 0)
		biodro.add_child(noga)
		# Biały adidas (podróbka z bazaru)
		var but := MeshInstance3D.new()
		var pudlo_buta := BoxMesh.new()
		pudlo_buta.size = Vector3(0.16, 0.1, 0.3)
		but.mesh = pudlo_buta
		but.material_override = _material(Color(0.95, 0.95, 0.95))
		but.position = Vector3(0, -0.52, -0.05)
		biodro.add_child(but)
		if strona < 0:
			_noga_l = biodro
		else:
			_noga_p = biodro

	# Głowa
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.26
	kula.height = 0.52
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.9, 0.72, 0.58))
	glowa.position = Vector3(0, 1.64, 0)
	_wyglad.add_child(glowa)

	# Czapka z daszkiem (oczywiście)
	var czapka := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.27
	walec.bottom_radius = 0.28
	walec.height = 0.12
	czapka.mesh = walec
	czapka.material_override = _material(Color(0.75, 0.1, 0.1))
	czapka.position = Vector3(0, 1.84, 0)
	_wyglad.add_child(czapka)

	var daszek := MeshInstance3D.new()
	var pudlo_daszka := BoxMesh.new()
	pudlo_daszka.size = Vector3(0.3, 0.03, 0.22)
	daszek.mesh = pudlo_daszka
	daszek.material_override = _material(Color(0.75, 0.1, 0.1))
	daszek.position = Vector3(0, 1.8, -0.3)  # -Z to przód postaci
	_wyglad.add_child(daszek)

	# Ręce - machają przy chodzeniu (obrót w barku)
	for strona in [-1.0, 1.0]:
		var bark := Node3D.new()
		bark.position = Vector3(strona * 0.44, 1.35, 0)
		_wyglad.add_child(bark)
		var reka := MeshInstance3D.new()
		var kapsula_reki := CapsuleMesh.new()
		kapsula_reki.radius = 0.09
		kapsula_reki.height = 0.6
		reka.mesh = kapsula_reki
		reka.material_override = _material(Color(0.15, 0.2, 0.45))
		reka.position = Vector3(0, -0.25, 0)
		bark.add_child(reka)
		if strona < 0:
			_reka_l = bark
		else:
			_reka_p = bark

	# Plecak na butelki (rośnie z zapełnieniem)
	_plecak_mesh = MeshInstance3D.new()
	var pudlo_plecaka := BoxMesh.new()
	pudlo_plecaka.size = Vector3(0.45, 0.55, 0.3)
	_plecak_mesh.mesh = pudlo_plecaka
	_plecak_mesh.material_override = _material(Color(0.45, 0.3, 0.15))
	_plecak_mesh.position = Vector3(0, 1.05, 0.35)  # +Z to plecy
	_wyglad.add_child(_plecak_mesh)

func _zbuduj_kamere() -> void:
	_ramie = SpringArm3D.new()
	_ramie.position = Vector3(0, 1.55, 0)
	_ramie.spring_length = 4.0
	# Ramię widzi świat (warstwa 1) ORAZ korony drzew (warstwa kamery).
	# Bez tego kamera wjeżdżała w liście i kadr robił się czarny.
	_ramie.collision_mask = 1 | Balans.WARSTWA_KAMERY
	_ramie.add_excluded_object(get_rid())  # ramię nie zderza się z graczem
	add_child(_ramie)
	_kamera = Camera3D.new()
	_kamera.current = true
	_ramie.add_child(_kamera)
	_ramie.rotation.x = -0.25  # lekko z góry

func _zbuduj_zasieg() -> void:
	_zasieg = Area3D.new()
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = ZASIEG_INTERAKCJI
	ksztalt.shape = kula
	_zasieg.add_child(ksztalt)
	_zasieg.position = Vector3(0, 1.0, 0)
	add_child(_zasieg)
	# Mała strefa przy stopach - wykrywa kamienie do potknięcia
	_stopy = Area3D.new()
	var ksztalt_stop := CollisionShape3D.new()
	var kula_stop := SphereShape3D.new()
	kula_stop.radius = 0.5
	ksztalt_stop.shape = kula_stop
	_stopy.add_child(ksztalt_stop)
	_stopy.position = Vector3(0, 0.25, 0)
	add_child(_stopy)

## Kopia wózka doczepiona do gracza - pokazywana tylko podczas jazdy.
func _zbuduj_wozek_wizual() -> void:
	_wozek_wizual = Node3D.new()
	_wozek_wizual.visible = false
	add_child(_wozek_wizual)
	# Kosz
	var kosz := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.75, 0.55, 1.0)
	kosz.mesh = pudlo
	kosz.material_override = _material(Color(0.7, 0.72, 0.76))
	kosz.position = Vector3(0, 0.65, -0.1)
	_wozek_wizual.add_child(kosz)
	# Rączka
	var raczka := MeshInstance3D.new()
	var pudlo_raczki := BoxMesh.new()
	pudlo_raczki.size = Vector3(0.8, 0.06, 0.06)
	raczka.mesh = pudlo_raczki
	raczka.material_override = _material(Color(0.85, 0.2, 0.2))
	raczka.position = Vector3(0, 1.05, 0.45)
	_wozek_wizual.add_child(raczka)
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
		_wozek_wizual.add_child(kolo)

## Kopia skutera doczepiona do gracza - pokazywana tylko podczas jazdy.
## Gracz "siedzi" okrakiem: nogi po bokach, ręce na kierownicy.
func _zbuduj_skuter_wizual() -> void:
	_skuter_wizual = Node3D.new()
	_skuter_wizual.visible = false
	add_child(_skuter_wizual)
	# Podłoga i owiewka
	var plyta := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.42, 0.12, 1.35)
	plyta.mesh = pudlo
	plyta.material_override = _material(Color(0.75, 0.18, 0.16))
	plyta.position = Vector3(0, 0.34, 0)
	_skuter_wizual.add_child(plyta)
	# Siedzisko
	var siedzenie := MeshInstance3D.new()
	var pudlo_siedzenia := BoxMesh.new()
	pudlo_siedzenia.size = Vector3(0.36, 0.18, 0.55)
	siedzenie.mesh = pudlo_siedzenia
	siedzenie.material_override = _material(Color(0.12, 0.12, 0.14))
	siedzenie.position = Vector3(0, 0.55, 0.28)
	_skuter_wizual.add_child(siedzenie)
	# Owiewka przednia z lampą
	var owiewka := MeshInstance3D.new()
	var pudlo_owiewki := BoxMesh.new()
	pudlo_owiewki.size = Vector3(0.34, 0.5, 0.22)
	owiewka.mesh = pudlo_owiewki
	owiewka.material_override = _material(Color(0.8, 0.2, 0.18))
	owiewka.position = Vector3(0, 0.68, -0.55)
	_skuter_wizual.add_child(owiewka)
	var lampa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.11
	kula.height = 0.22
	lampa.mesh = kula
	var mat_lampy := StandardMaterial3D.new()
	mat_lampy.albedo_color = Color(1.0, 0.97, 0.8)
	mat_lampy.emission_enabled = true
	mat_lampy.emission = Color(1.0, 0.95, 0.7)
	mat_lampy.emission_energy_multiplier = 1.6
	lampa.material_override = mat_lampy
	lampa.position = Vector3(0, 0.72, -0.66)
	_skuter_wizual.add_child(lampa)
	# Kierownica
	var kierownica := MeshInstance3D.new()
	var pudlo_kierownicy := BoxMesh.new()
	pudlo_kierownicy.size = Vector3(0.62, 0.05, 0.05)
	kierownica.mesh = pudlo_kierownicy
	kierownica.material_override = _material(Color(0.2, 0.2, 0.22))
	kierownica.position = Vector3(0, 0.98, -0.52)
	_skuter_wizual.add_child(kierownica)
	# Koła
	for przesuniecie in [Vector3(0, 0.24, -0.58), Vector3(0, 0.24, 0.58)]:
		var kolo := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.24
		walec.bottom_radius = 0.24
		walec.height = 0.1
		kolo.mesh = walec
		kolo.material_override = _material(Color(0.1, 0.1, 0.11))
		kolo.rotation.z = PI / 2
		kolo.position = przesuniecie
		_skuter_wizual.add_child(kolo)
	# Lusterko na patyku - bo bez lusterka to nie jest skuter
	var lusterko := MeshInstance3D.new()
	var pudlo_lusterka := BoxMesh.new()
	pudlo_lusterka.size = Vector3(0.12, 0.08, 0.03)
	lusterko.mesh = pudlo_lusterka
	lusterko.material_override = _material(Color(0.6, 0.65, 0.7))
	lusterko.position = Vector3(0.3, 1.16, -0.5)
	_skuter_wizual.add_child(lusterko)
	# PRZYCZEPKA (ulepszenie): dyszel, skrzynia i dwa kółka za skuterem.
	# Doczepiana tylko, gdy kupiona - i to ona zbiera fanty w biegu.
	if Game.ma_przyczepe():
		_zbuduj_przyczepe()

## Przyczepka doczepiana do skutera - widoczny dowód, że ulepszenie działa.
func _zbuduj_przyczepe() -> void:
	var dyszel := MeshInstance3D.new()
	var pret := BoxMesh.new()
	pret.size = Vector3(0.06, 0.06, 0.55)
	dyszel.mesh = pret
	dyszel.material_override = _material(Color(0.25, 0.25, 0.28))
	dyszel.position = Vector3(0, 0.32, 0.9)
	_skuter_wizual.add_child(dyszel)
	var skrzynia := MeshInstance3D.new()
	var pudlo_skrzyni := BoxMesh.new()
	pudlo_skrzyni.size = Vector3(0.62, 0.34, 0.7)
	skrzynia.mesh = pudlo_skrzyni
	skrzynia.material_override = _material(Color(0.55, 0.42, 0.22))
	skrzynia.position = Vector3(0, 0.42, 1.5)
	_skuter_wizual.add_child(skrzynia)
	for bok in [-0.3, 0.3]:
		var kolo := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.16
		walec.bottom_radius = 0.16
		walec.height = 0.08
		kolo.mesh = walec
		kolo.material_override = _material(Color(0.1, 0.1, 0.11))
		kolo.rotation.z = PI / 2
		kolo.position = Vector3(bok, 0.16, 1.5)
		_skuter_wizual.add_child(kolo)

# --- Sterowanie ---

func _unhandled_input(zdarzenie: InputEvent) -> void:
	if Game.w_menu:
		return
	# Obrót kamery myszą (tylko gdy mysz przechwycona)
	var ruch_myszy := zdarzenie as InputEventMouseMotion
	if ruch_myszy and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var czulosc: float = CZULOSC_MYSZY * Game.czulosc   # z ustawień gracza
		rotate_y(-ruch_myszy.relative.x * czulosc)
		var limit_gory := deg_to_rad(80) if pierwsza_osoba else deg_to_rad(35)
		_ramie.rotation.x = clampf(
			_ramie.rotation.x - ruch_myszy.relative.y * czulosc,
			deg_to_rad(-75), limit_gory
		)
	# Klik - złap mysz z powrotem (Esc/pauzę obsługuje HUD)
	var klik := zdarzenie as InputEventMouseButton
	if klik and klik.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and Game.gra_trwa and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Przełączenie kamery TPP <-> FPP
	if zdarzenie.is_action_pressed("toggle_camera"):
		pierwsza_osoba = not pierwsza_osoba
		_ramie.spring_length = 0.05 if pierwsza_osoba else 4.0
		_wyglad.visible = not pierwsza_osoba
	# Interakcja (E): w wózku = wysiadanie, na ławce = wstawanie
	if zdarzenie.is_action_pressed("interact") and Game.gra_trwa and not lezy and not _cwiczy:
		if w_wozku:
			wysiadz_z_wozka()
		elif siedzi:
			wstan()
		elif _najblizszy:
			_najblizszy.interakcja(self)
	# Nawalanie (F) - kultura osobista: poziom osiedle
	if zdarzenie.is_action_pressed("punch") and Game.gra_trwa \
			and not lezy and not w_wozku and not _cwiczy:
		_uderz()

func _physics_process(delta: float) -> void:
	# Grawitacja działa zawsze
	if not is_on_floor():
		velocity.y -= grawitacja * delta
	_niesmiertelnosc = maxf(_niesmiertelnosc - delta, 0.0)

	if not Game.gra_trwa or Game.w_menu:
		# Menu / koniec dnia - postać stoi (dojeżdża tylko grawitacją)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	if lezy:
		# Leżymy po potknięciu - ślizgamy się siłą rozpędu, bez sterowania
		velocity.x = move_toward(velocity.x, 0, 5.0 * delta * PREDKOSC_SPRINTU)
		velocity.z = move_toward(velocity.z, 0, 5.0 * delta * PREDKOSC_SPRINTU)
		move_and_slide()
		return

	if _cwiczy:
		# Wisimy na trzepaku - pozycją steruje animacja podciągania
		velocity = Vector3.ZERO
		return

	if siedzi:
		# Odpoczynek na ławce: podwójna regeneracja "Papierosa"
		velocity = Vector3.ZERO
		papieros = minf(papieros + Balans.PAPIEROS_REGENERACJA * 2.0 * delta, 100.0)
		Game.ustaw_stamine(papieros, papieros < 100.0)
		Game.ustaw_prompt("E - wstań z ławki")
		# Ruch też podrywa z ławki
		if Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO:
			wstan()
		return

	if w_wozku:
		_fizyka_wozka(delta)
	else:
		_fizyka_chodu(delta)

	move_and_slide()
	Game.raportuj_ruch(Vector2(velocity.x, velocity.z).length(), delta)
	_sprawdz_potkniecie()
	_szukaj_interakcji()
	_magnes(delta)
	_efekt_piwa(delta)
	_efekt_wstrzasu(delta)

## MAGNES NA BUTELKI (ulepszenie z MELINY).
##
## To nie jest "+15% do czegoś" - to nowy sposób grania. Bez magnesu każda
## butelka to podejście i wciśnięcie E; z magnesem przebiegasz przez trawnik,
## a fanty same wpadają do plecaka. Zbieranie z czynności robi się trasą.
##
## Świadomie NIE ciągniemy niczego, gdy plecak jest pełny: fanty krążące
## wokół gracza, których nie da się podnieść, wyglądałyby jak usterka.
func _magnes(delta: float) -> void:
	if not Game.ma_magnes() or lezy or _cwiczy or siedzi:
		return
	var srodek := global_position + Vector3(0, 0.35, 0)
	for fant in get_tree().get_nodes_in_group("kolekcjonerskie"):
		if Game.zajete_miejsca() >= Game.pojemnosc_plecaka():
			return   # dobiliśmy do limitu w trakcie zbierania
		if not is_instance_valid(fant):
			continue
		var do_gracza: Vector3 = srodek - fant.global_position
		var dystans := do_gracza.length()
		if dystans > Balans.MAGNES_ZASIEG:
			continue
		if dystans < Balans.MAGNES_ZLAPANIE:
			fant.interakcja(self)
			continue
		# Im bliżej, tym szybciej - fant "wpada", zamiast leniwie dryfować
		var tempo: float = 1.5 + Balans.MAGNES_SILA * (1.0 - dystans / Balans.MAGNES_ZASIEG)
		fant.global_position += do_gracza.normalized() * tempo * delta

## Screen shake: kamera drży z malejącą siłą (sygnał Game.wstrzas).
func _efekt_wstrzasu(delta: float) -> void:
	if _wstrzas < 0.005:
		if _wstrzas > 0.0:
			_wstrzas = 0.0
			_kamera.h_offset = 0.0
			_kamera.v_offset = 0.0
		return
	_wstrzas = lerpf(_wstrzas, 0.0, 8.0 * delta)
	_kamera.h_offset = randf_range(-1.0, 1.0) * _wstrzas
	_kamera.v_offset = randf_range(-1.0, 1.0) * _wstrzas

## Czy stoimy na betonie/asfalcie? (układ mapy - patrz world.gd)
func _na_betonie() -> bool:
	var p := global_position
	if absf(p.x) <= 2.0 and p.z > -27.0 and p.z < 23.0:
		return true   # główny chodnik
	if absf(p.z - 6.0) <= 1.5 and absf(p.x) <= 18.0:
		return true   # chodnik poprzeczny
	if absf(p.x) <= 13.0 and p.z > -28.0 and p.z < -20.0:
		return true   # parking przed Biedronką
	return p.x > 50.0   # wnętrze sklepu (posadzka)

## Zwykłe chodzenie: sprint zużywa "Papierosa", stanie go regeneruje.
func _fizyka_chodu(delta: float) -> void:
	# Skok
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = SILA_SKOKU
		Sfx.graj("skok", -6.0)

	# Przysiad (do zaglądania w śmietniki) - wolniej + postać się kurczy
	var kuca := Input.is_action_pressed("crouch")
	_wyglad.scale.y = lerpf(_wyglad.scale.y, 0.65 if kuca else 1.0, 12.0 * delta)
	_ramie.position.y = lerpf(_ramie.position.y, 1.0 if kuca else 1.55, 12.0 * delta)

	var wejscie := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var predkosc_pozioma := Vector2(velocity.x, velocity.z).length()

	# Sprint tylko, gdy jest jeszcze "Papieros"
	var sprintuje := Input.is_action_pressed("sprint") and papieros > 0.0 \
		and wejscie != Vector2.ZERO and not kuca
	if sprintuje:
		# "Mocne płuca" (ulepszenie) zmniejszają zużycie
		papieros = maxf(papieros - PAPIEROS_ZUZYCIE * Game.mnoznik_papierosa() * delta, 0.0)
	# Regeneracja TYLKO na stojąco ("zapalasz")
	var pali := predkosc_pozioma < 0.3 and is_on_floor() and papieros < 100.0
	if pali:
		papieros = minf(papieros + PAPIEROS_REGENERACJA * delta, 100.0)
	Game.ustaw_stamine(papieros, pali)

	var predkosc := PREDKOSC_CHODU
	if kuca:
		predkosc = PREDKOSC_KUCANIA
	elif sprintuje:
		predkosc = PREDKOSC_SPRINTU
	predkosc *= Game.mnoznik_predkosci()   # "Adidasy z bazaru" (ulepszenie)
	if _piwo > 0.0:
		predkosc *= Balans.BONUS_PIWA   # "odwaga w płynie" - chwilowy bonus prędkości
	elif _kac > 0.0:
		predkosc *= Balans.KARA_KACA    # na kacu wszystko boli
	if _energetyk > 0.0:
		_energetyk -= delta
		predkosc *= Balans.ENERGETYK_BONUS   # kumuluje się z piwem, bo czemu nie

	# Ruch względem obrotu postaci - z płynnym przyspieszaniem i hamowaniem
	var kierunek := (transform.basis * Vector3(wejscie.x, 0, wejscie.y)).normalized()
	# Po piwach postać sama znosi na boki (im więcej piw, tym mocniej)
	if _piwo > 0.0 and kierunek:
		var bok := Vector3(-kierunek.z, 0, kierunek.x)
		var znoszenie := sin(Time.get_ticks_msec() / 400.0) * 0.18 * minf(_piwa_wypite, 3)
		kierunek = (kierunek + bok * znoszenie).normalized()
	# Na mokrym adidasy buksują przy starcie i nie chcą hamować przy stopie.
	# To jeden mnożnik, ale czuć go natychmiast: w deszczu wyhamowanie przed
	# butelką trwa dłużej, niż podpowiada nawyk z suchego dnia.
	var przyspieszenie := Balans.PRZYSPIESZENIE * Game.mnoznik_przyspieszenia()
	var hamowanie := Balans.HAMOWANIE * Game.mnoznik_hamowania()
	if kierunek:
		velocity.x = move_toward(velocity.x, kierunek.x * predkosc, przyspieszenie * delta)
		velocity.z = move_toward(velocity.z, kierunek.z * predkosc, przyspieszenie * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, hamowanie * delta)
		velocity.z = move_toward(velocity.z, 0, hamowanie * delta)

	# Animacja chodu: podskoki, kołysanie i machanie rękami (szybciej = mocniej)
	var szybkosc_anim := Vector2(velocity.x, velocity.z).length()
	_faza_kroku += delta * szybkosc_anim * 2.2
	var amplituda := clampf(szybkosc_anim / PREDKOSC_SPRINTU, 0.0, 1.0)
	_wyglad.position.y = absf(sin(_faza_kroku)) * 0.07 * amplituda
	_wyglad.rotation.z = sin(_faza_kroku) * 0.06 * amplituda
	_wyglad.rotation.x = lerpf(_wyglad.rotation.x, -0.1 * amplituda, 8.0 * delta)
	if _reka_l:
		_reka_l.rotation.x = sin(_faza_kroku) * 0.9 * amplituda
		_reka_p.rotation.x = -sin(_faza_kroku) * 0.9 * amplituda
		_noga_l.rotation.x = -sin(_faza_kroku) * 0.8 * amplituda
		_noga_p.rotation.x = sin(_faza_kroku) * 0.8 * amplituda
	# Dźwięk kroku przy każdym "postawieniu stopy" - zależny od podłoża
	var numer_kroku := int(_faza_kroku / PI)
	if numer_kroku != _ostatni_krok and is_on_floor() and amplituda > 0.25:
		_ostatni_krok = numer_kroku
		var dzwiek := "krok_beton" if _na_betonie() else "krok_trawa"
		Sfx.graj(dzwiek, -14.0, randf_range(0.9, 1.1))

## Jazda wózkiem: rozpędzanie, poślizg, skręt zależny od prędkości.
## Wspólna fizyka arcade dla wózka i skutera. Parametry pojazdu siedzą
## w Balans.POJAZDY - model jazdy jest jeden, różnią się tylko liczby.
func _fizyka_wozka(delta: float) -> void:
	var dane: Dictionary = Balans.POJAZDY.get(_typ_pojazdu, Balans.POJAZDY["wozek"])
	var gaz := Input.get_axis("move_back", "move_forward")   # W = 1, S = -1
	var skret := Input.get_axis("move_right", "move_left")   # A/D
	var maks: float = dane["maks"]

	# --- DRIFT: Ctrl przy odpowiedniej prędkości uwalnia tył pojazdu ---
	var chce_driftowac := Input.is_action_pressed("crouch") and absf(skret) > 0.1
	_drift = chce_driftowac and absf(_wozek_predkosc) > Balans.DRIFT_MIN_PREDKOSC and is_on_floor()

	# Rozpędzanie i toczenie się (pojazd prawie nie hamuje sam!)
	if gaz > 0.0:
		_wozek_predkosc = move_toward(_wozek_predkosc, maks, float(dane["przyspieszenie"]) * delta)
	elif gaz < 0.0:
		_wozek_predkosc = move_toward(_wozek_predkosc, -float(dane["wsteczny"]), float(dane["przyspieszenie"]) * delta)
	else:
		_wozek_predkosc = move_toward(_wozek_predkosc, 0.0, float(dane["hamowanie"]) * delta)

	# Skręt rośnie z prędkością (i odwraca się na wstecznym), drift go podbija
	var moc_skretu: float = float(dane["skret"]) * (Balans.DRIFT_SKRET if _drift else 1.0)
	rotate_y(skret * moc_skretu * delta * clampf(_wozek_predkosc / 6.0, -1.0, 1.0))

	# Poślizg: velocity leniwie goni kierunek przodu. W driftcie goni go
	# DUŻO wolniej - stąd charakterystyczne "pływanie" bokiem.
	# Deszcz tnie przyczepność pojazdów - mokry asfalt zamienia wózek
	# w łódkę, a skuter w coś, co skręca dopiero po namyśle
	var przyczepnosc: float = Balans.DRIFT_PRZYCZEPNOSC if _drift \
		else float(dane["przyczepnosc"]) * Game.mnoznik_przyczepnosci()
	var przod := -transform.basis.z * _wozek_predkosc
	velocity.x = lerpf(velocity.x, przod.x, przyczepnosc * delta)
	velocity.z = lerpf(velocity.z, przod.z, przyczepnosc * delta)

	# Podskok pojazdem
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = SILA_SKOKU * float(dane["skok"])
		Sfx.graj("skok", -6.0)

	_obsluz_lot(delta)
	_efekt_driftu(delta)

	# Jazda to nie sprint - "Papieros" odpoczywa
	Game.ustaw_stamine(papieros, false)
	# Postać pochyla się nad kierownicą tym mocniej, im szybciej jedzie
	var pochylenie := -0.18 * absf(_wozek_predkosc) / maks
	if _typ_pojazdu == "skuter":
		pochylenie = -0.3 * absf(_wozek_predkosc) / maks   # na skuterze kładziemy się na baku
	_wyglad.rotation.x = lerpf(_wyglad.rotation.x, pochylenie, 6.0 * delta)
	# Przechył w driftcie - pojazd kładzie się w zakręcie
	var docelowy_przechyl := (0.25 * skret) if _drift else 0.0
	_wyglad.rotation.z = lerpf(_wyglad.rotation.z, docelowy_przechyl, 5.0 * delta)

	# AUTO-ZBIERANIE: wózkiem butelki wpadają same. Skuterem normalnie NIE -
	# chyba że kupiłeś PRZYCZEPKĘ w MELINIE. To jest właśnie sens ulepszenia
	# odblokowującego czasownik: skuter przestaje być samym transportem
	# i zaczyna być narzędziem pracy.
	if not (bool(dane["auto_zbieranie"]) or (_typ_pojazdu == "skuter" and Game.ma_przyczepe())):
		return
	_auto_zbieranie -= delta
	if _auto_zbieranie <= 0.0 and Game.zajete_miejsca() < Game.pojemnosc_plecaka():
		_auto_zbieranie = 0.15
		for obiekt in _zasieg.get_overlapping_areas():
			if obiekt.is_in_group("kolekcjonerskie"):
				obiekt.interakcja(self)
				break

## Liczenie czasu w powietrzu. Długi lot = TRICK, kasa i wielki napis.
func _obsluz_lot(delta: float) -> void:
	if not is_on_floor():
		_czas_lotu += delta
		return
	if _czas_lotu <= 0.0:
		return
	var lot := _czas_lotu
	_czas_lotu = 0.0
	if lot < Balans.LOT_MIN_CZAS:
		return
	# Nagroda rośnie z długością lotu, ale przechodzi przez dzienny limit -
	# inaczej skuter plus rampa to maszynka do pieniędzy. Prestiż, napis
	# i statystyka lecą zawsze: styl ma się opłacać, tylko nie w złotówkach.
	var bonus := lot * Balans.LOT_BONUS_ZA_SEKUNDE
	var wyplata := Game.nagroda_za_lot(bonus)
	Game.dodaj_wsiokometr(10.0)
	Game.wstrzasnij(0.3)
	Sfx.graj("zlota", -3.0, 1.2)
	Game.statystyki["loty"] += 1
	Game.postep_zlecenia("lot")
	if lot >= 2.0:
		Osiagniecia.przyznaj("orbita")
	var opis := "PIĘKNY LOT!" if lot < 1.0 else ("KOSMICZNY SKOK!" if lot < 1.6 else "ORBITA OSIEDLOWA!")
	if wyplata > 0.0:
		Game.pokaz_meme("%s %.1f s w powietrzu - bonus %s" % [opis, lot, Game.zl(wyplata)])
	elif Game.limit_lotow_wyczerpany():
		Game.pokaz_meme("%s Ale osiedle już to dziś widziało - za styl nie płacą." % opis)
	else:
		Game.pokaz_meme("%s Za szybko po poprzednim - bez premii." % opis)
	Efekty.kurz(get_parent(), global_position)

## Wizualne i dźwiękowe potwierdzenie driftu (bez tego drift jest niewyczuwalny).
func _efekt_driftu(delta: float) -> void:
	_drift_dzwiek -= delta
	if not _drift:
		return
	if _drift_dzwiek <= 0.0:
		_drift_dzwiek = 0.35
		Sfx.graj("krok_beton", -14.0, 0.55)   # zgrzyt opon o asfalt
	# Kurz spod kół co jakiś czas
	if randf() < 0.25:
		Efekty.kurz(get_parent(), global_position - transform.basis.z * -0.5)

# --- Potknięcia (pseudo-ragdoll) ---

## Sprawdza, czy wbiegliśmy z impetem na kamień.
func _sprawdz_potkniecie() -> void:
	if lezy or _niesmiertelnosc > 0.0:
		return
	var szybkosc := Vector2(velocity.x, velocity.z).length()
	# Każdy pojazd ma własny próg wywrotki (skuter wybacza więcej niż wózek)
	var prog := 6.2
	if w_wozku:
		prog = float(Balans.POJAZDY.get(_typ_pojazdu, Balans.POJAZDY["wozek"])["prog_wywrotki"])
	if szybkosc < prog:
		return
	for obiekt in _stopy.get_overlapping_areas():
		if obiekt.is_in_group("przeszkoda"):
			_potknij_sie()
			return

## Komiczny upadek: postać leci na twarz, obraca się i wstaje po chwili.
## z_tekstem = false, gdy powód gleby ogłasza kto inny (np. sąsiadka).
func _potknij_sie(z_tekstem := true) -> void:
	lezy = true
	_niesmiertelnosc = 3.0
	Game.statystyki["upadki"] += 1
	Game.postep_wyzwania("gleby")
	Osiagniecia.zglos("gleby")
	if w_wozku:
		Sfx.graj("brzek")
		Sfx.odpal_klasyk()   # spektakularna wywrotka = muzyczna oprawa
		Game.wstrzasnij(0.5)
		if _typ_pojazdu == "skuter":
			Game.pokaz_komunikat("SKUTER W POPRZEK CHODNIKA! Romet widział gorsze dni. Chyba.")
		else:
			Game.pokaz_komunikat("WYWROTKA WÓZKIEM! Koła jeszcze się kręcą...")
		wysiadz_z_wozka()
		lezy = true   # wysiadz_z_wozka nie ma nas podnosić
	else:
		Game.wstrzasnij(0.35)
		if z_tekstem:
			Game.pokaz_komunikat(TEKSTY_GLEBY.pick_random())
	Sfx.graj("upadek")
	Efekty.kurz(get_parent(), global_position)   # kłąb kurzu przy glebie
	velocity.x *= 1.3   # ślizg po glebie siłą rozpędu
	velocity.z *= 1.3
	# Przesadzony obrót na twarz z odbiciem
	var tw := create_tween()
	tw.tween_property(_wyglad, "rotation:x", -PI / 2.0, 0.35)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_wyglad, "position:y", 0.15, 0.35)
	tw.tween_interval(1.3)          # leżenie i przemyślenia życiowe
	tw.tween_property(_wyglad, "rotation:x", 0.0, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_wyglad, "position:y", 0.0, 0.4)
	tw.tween_callback(func() -> void: lezy = false)

# --- Wózek sklepowy ---

## Wywoływane przez wozek.gd / skuter.gd, gdy gracz wciśnie E przy pojeździe.
## "typ" to klucz w Balans.POJAZDY - decyduje o fizyce i wyglądzie.
func wsiadz_do_wozka(pojazd: Node3D, typ := "wozek") -> void:
	w_wozku = true
	_wozek = pojazd
	_typ_pojazdu = typ
	_wozek_predkosc = 0.0
	_czas_lotu = 0.0
	if typ == "skuter":
		_skuter_wizual.visible = true
		_wyglad.position.y = 0.5    # siedzimy okrakiem na siodełku
		Sfx.graj("furkot", -2.0, 0.7)
		Game.pokaz_komunikat("Skuter odpalony! Kask? Kask jest w domu.")
	else:
		_wozek_wizual.visible = true
		_wyglad.position.y = 0.35   # postać stoi W koszu
		Game.pokaz_komunikat("Wsiadasz do wózka. Biedronka tego nie pochwala.")

func wysiadz_z_wozka() -> void:
	w_wozku = false
	_wozek_wizual.visible = false
	_skuter_wizual.visible = false
	_wyglad.position.y = 0.0
	_wyglad.rotation.z = 0.0
	_wozek_predkosc = 0.0
	_drift = false
	# Pojazd wraca na mapę tuż obok gracza
	if _wozek:
		_wozek.odstaw(global_position - transform.basis.z * 1.2)
		_wozek = null

# --- Interakcje ---

## Co klatkę fizyki: znajdź najbliższy interaktywny obiekt i pokaż podpowiedź.
func _szukaj_interakcji() -> void:
	if w_wozku:
		var nazwa := "skutera" if _typ_pojazdu == "skuter" else "wózka"
		if _drift:
			Game.ustaw_prompt("DRIFT! Trzymaj tak dalej")
		else:
			Game.ustaw_prompt("E - wysiądź z %s | Ctrl+skręt = DRIFT | rampy dają bonus" % nazwa)
		return
	var kandydaci: Array = []
	kandydaci.append_array(_zasieg.get_overlapping_areas())   # butelki (Area3D)
	kandydaci.append_array(_zasieg.get_overlapping_bodies())  # śmietniki, butelkomat
	_najblizszy = null
	var najmniejszy_dystans := INF
	for obiekt in kandydaci:
		if not obiekt.is_in_group("interakcja"):
			continue
		var d: float = global_position.distance_to(obiekt.global_position)
		if d < najmniejszy_dystans:
			najmniejszy_dystans = d
			_najblizszy = obiekt
	Game.ustaw_prompt(_najblizszy.podpowiedz() if _najblizszy else "")

## Plecak na plecach rośnie wraz z liczbą butelek.
func _aktualizuj_plecak(ile: int, maks: int) -> void:
	var procent := float(ile) / maks
	var tw := create_tween()
	tw.tween_property(_plecak_mesh, "scale", Vector3.ONE * (1.0 + procent * 0.9), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Nowe akcje: cios, gleba, teleport, piwo, trzepak ---

## Cios pięścią (F): zamach, mały wykrok do przodu i sprawdzenie,
## czy ktoś/coś oberwało. Bijalne są NPC-e, śmietniki i butelkomat.
func _uderz() -> void:
	Sfx.graj("cios")
	Game.wstrzasnij(0.08)
	# Wykrok - cios ma ciężar
	velocity.x += -transform.basis.z.x * 2.5
	velocity.z += -transform.basis.z.z * 2.5
	var tw := create_tween()
	tw.tween_property(_reka_p, "rotation:x", -2.0, 0.1)
	tw.tween_property(_reka_p, "rotation:x", 0.0, 0.25)
	# Najbliższy bijalny obiekt w zasięgu ciosu
	var najblizszy: Node = null
	var dystans := INF
	for obiekt in get_tree().get_nodes_in_group("bijalne"):
		var d: float = global_position.distance_to(obiekt.global_position)
		if d < dystans:
			dystans = d
			najblizszy = obiekt
	if najblizszy and dystans < 2.4 and najblizszy.has_method("oberwij"):
		najblizszy.oberwij(self)
		Game.postep_wyzwania("ciosy")
		Osiagniecia.zglos("ciosy")
	elif randf() < 0.3:
		Game.pokaz_komunikat("Machnąłeś w powietrze. Powietrze niewzruszone.")

## Publiczna gleba - gdy powali nas NPC (sąsiadka torebką, pies itd.).
func gleba() -> void:
	if siedzi:
		wstan()
	if not lezy:
		_potknij_sie(false)

## Siadanie na ławce (wywoływane przez lawka.gd).
func usiadz(miejsce: Vector3, obrot: float) -> void:
	if siedzi or lezy or w_wozku or _cwiczy:
		return
	siedzi = true
	global_position = miejsce
	rotation.y = obrot
	velocity = Vector3.ZERO
	# Poza siedząca: tułów niżej, nogi wyprostowane do przodu
	_wyglad.position.y = -0.32
	_noga_l.rotation.x = -1.35
	_noga_p.rotation.x = -1.35
	Game.pokaz_komunikat("Siadasz. Osiedle wygląda ładniej na siedząco.")

func wstan() -> void:
	if not siedzi:
		return
	siedzi = false
	_wyglad.position.y = 0.0
	_noga_l.rotation.x = 0.0
	_noga_p.rotation.x = 0.0
	# Krok w przód, żeby nie utknąć w kolizji ławki
	global_position += -transform.basis.z * 0.8
	Game.ustaw_prompt("")

## Teleport (drzwi Biedronki). Obrót w radianach wokół osi Y.
func teleportuj(pozycja: Vector3, obrot_y: float) -> void:
	global_position = pozycja
	rotation.y = obrot_y
	velocity = Vector3.ZERO

## Piwo z Biedronki: pełny "Papieros", odwaga... i KUMULACJA.
## Każde kolejne piwo wzmacnia efekt, a po zejściu przychodzi KAC.
func wypij_piwo() -> void:
	papieros = 100.0
	_piwa_wypite += 1
	_piwo = minf(_piwo + Balans.CZAS_PIWA, Balans.MAKS_UPOJENIE)
	_kac = 0.0
	Sfx.graj("czkawka", -2.0)
	Game.statystyki["piwa"] += 1
	Game.postep_wyzwania("piwa")
	Osiagniecia.zglos("piwa")
	match _piwa_wypite:
		1: Game.pokaz_komunikat("Piwo wypite na miejscu, klasyka. Odwaga +15%, świat lekko płynie.")
		2: Game.pokaz_komunikat("Drugie piwo. Świat nabiera kolorów i przechyłu.")
		3: Game.pokaz_komunikat("Trzecie?! Nogi zaczynają mieć własne zdanie.")
		_: Game.pokaz_komunikat("Pani Grażynka kręci głową, ale sprzedaje.")

## ENERGETYK z lodówki: pełny "Papieros" i podkręcenie na kilkanaście sekund.
## Świadomie słabszy od piwa, ale bez kaca i bez plączących się nóg - to jest
## uczciwy zakup, a nie pułapka.
func wypij_energetyka() -> void:
	papieros = 100.0
	_energetyk = Balans.ENERGETYK_CZAS
	Sfx.graj("czkawka", -8.0, 1.6)
	Game.pokaz_komunikat("Energetyk w siebie. Serce wali, ale nogi niosą!")

## Baton - leczy kaca i dorzuca trochę sił. Cukier to cukier.
func zjedz_batona() -> void:
	papieros = minf(papieros + 45.0, 100.0)
	if _kac > 0.0:
		_kac = 0.0
		_ramie.rotation.z = 0.0
		Game.pokaz_komunikat("Baton zjedzony. Kac odpuścił, świat znowu do zniesienia.")
	else:
		Game.pokaz_komunikat("Baton zjedzony. Nie ratuje życia, ale poprawia.")

## Woda - najtańsze wyjście z kaca.
func wypij_wode() -> void:
	papieros = minf(papieros + 25.0, 100.0)
	_kac = maxf(_kac - 12.0, 0.0)
	if _kac <= 0.0:
		_ramie.rotation.z = 0.0
	Game.pokaz_komunikat("Woda. Nudne, ale organizm dziękuje.")

## Efekty upojenia i kaca: bujanie kamery, pulsujące FOV, czkawka,
## plączące się nogi, a na kacu - jęki i spowolnienie.
func _efekt_piwa(delta: float) -> void:
	var czas_s := Time.get_ticks_msec() / 1000.0
	if _piwo > 0.0:
		_piwo -= delta
		var sila := minf(float(_piwa_wypite), 3.0)
		var zejscie := minf(_piwo, 3.0) / 3.0   # efekt łagodnie wygasa pod koniec
		# Kamera na fali + świat "oddycha" (FOV)
		_ramie.rotation.z = sin(czas_s * 5.5) * 0.045 * sila * zejscie
		_kamera.fov = 75.0 + sin(czas_s * 2.6) * 3.5 * sila * zejscie
		# Losowa czkawka
		if randf() < delta * 0.12 * sila:
			Sfx.graj("czkawka", -5.0, randf_range(0.85, 1.2))
		# Przy 3+ piwach nogi czasem odmawiają współpracy
		if _piwa_wypite >= 3 and not lezy and randf() < delta * 0.06:
			Game.pokaz_komunikat("Nogi się poplątały. Grawitacja wygrywa.")
			_potknij_sie(false)
		# Zejście: przychodzi kac (jeśli było czym zasłużyć)
		if _piwo <= 0.0:
			_ramie.rotation.z = 0.0
			_kamera.fov = 75.0
			if _piwa_wypite >= Balans.PIWA_DO_KACA:
				_kac = Balans.KAC_NA_PIWO * _piwa_wypite
				Sfx.graj("jek")
				Game.pokaz_komunikat("KAC ATAKUJE. Świat jest zbyt głośny i zbyt jasny.")
			else:
				Game.pokaz_komunikat("Świat przestał płynąć. Szkoda.")
			_piwa_wypite = 0
	elif _kac > 0.0:
		_kac -= delta
		# Powolne, męczące kołysanie
		_ramie.rotation.z = sin(czas_s * 1.2) * 0.018
		if randf() < delta * 0.08:
			Sfx.graj("jek", -4.0, randf_range(0.9, 1.1))
		if _kac <= 0.0:
			_ramie.rotation.z = 0.0
			Game.pokaz_komunikat("Kac minął. Wracamy do pracy.")
	# HUD nakłada kolorowy filtr zależny od stanu
	var pijanstwo := clampf(_piwo / 10.0, 0.0, 1.0) * (0.4 + 0.2 * minf(_piwa_wypite, 3))
	Game.raportuj_upojenie(clampf(pijanstwo, 0.0, 1.0), clampf(_kac / 15.0, 0.0, 1.0))

## Podciąganie na trzepaku: 3 powtórzenia, pełna regeneracja i szacun.
func podciagnij_sie(drazek: Vector3) -> void:
	if _cwiczy or lezy or w_wozku:
		return
	_cwiczy = true
	Game.pokaz_komunikat("SIŁOWNIA OSIEDLOWA: OTWARTA.")
	# Ręce w górę - chwyt drążka
	_reka_l.rotation.x = PI
	_reka_p.rotation.x = PI
	var pod_drazkiem := Vector3(drazek.x, 0.05, drazek.z)
	var tw := create_tween()
	tw.tween_property(self, "global_position", pod_drazkiem, 0.25)
	for i in 3:
		tw.tween_property(self, "global_position:y", drazek.y - 1.9, 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: Sfx.graj("okrzyk1", -4.0, 0.8))
		tw.tween_property(self, "global_position:y", 0.05, 0.35)
	tw.tween_callback(func() -> void:
		_cwiczy = false
		velocity = Vector3.ZERO
		_reka_l.rotation.x = 0.0
		_reka_p.rotation.x = 0.0
		papieros = 100.0
		Game.dodaj_wsiokometr(10.0)
		Game.postep_wyzwania("trzepak")
		Game.pokaz_komunikat("Trening zaliczony! Wsiokometr +10, Papieros odnowiony.")
	)
