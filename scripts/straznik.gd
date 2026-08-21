extends Node3D
## STRAŻ MIEJSKA - patroluje osiedle po stałej trasie.
## Przyłapie cię na grzebaniu w śmietniku (z bliska) = mandat.
## Podniesienie ręki na funkcjonariusza = mandat + gleba wychowawcza.

const PREDKOSC := 2.4
const PREDKOSC_POSCIGU := 4.6      # wolniej niż sprint gracza (8.0) - da się uciec
const PRZERWA_KOMENTARZY := 14.0
const DYSTANS_ZLAPANIA := 1.8      # z tej odległości cię dopadnie
const DYSTANS_UCIECZKI := 26.0     # dalej niż to = gubi cię z oczu
const CZAS_GUBIENIA := 4.0         # ile sekund poza zasięgiem, by odpuścił

enum Stan { PATROL, POSCIG }

const OKRZYKI_POSCIGU: Array[String] = [
	"STRAŻ: \"STAĆ! KONTROLA!\"",
	"STRAŻ: \"PROSZĘ SIĘ ZATRZYMAĆ!\"",
	"STRAŻ: \"I TAK PANA ZNAM Z WIDZENIA!\"",
	"STRAŻ: \"MANDAT ROŚNIE Z KAŻDYM METREM!\"",
]

const TEKSTY: Array[String] = [
	"Straż Miejska patrzy podejrzliwie.",
	"Strażnik notuje coś w notesiku. O tobie.",
	"Straż: \"Proszę się rozejść.\" (jesteś sam)",
	"Strażnik poprawia czapkę. Groźnie.",
]

## Trasa patrolu: pętla wokół centrum osiedla.
const TRASA: Array[Vector3] = [
	Vector3(8, 0, 18), Vector3(8, 0, -16), Vector3(-8, 0, -16), Vector3(-8, 0, 18),
]

var _cel_trasy := 0
var _odliczanie := 0.0
var _gracz: Node3D = null

var _stan: Stan = Stan.PATROL
var _poza_zasiegiem := 0.0     # jak długo gracz jest poza polem widzenia
var _sekundnik := 0.0          # do naliczania sekund ucieczki dla zleceń
var _okrzyk_odliczanie := 0.0
var _czas_poscigu := 0.0       # ile trwa bieżąca ucieczka (do komunikatów)

func _ready() -> void:
	add_to_group("straz")
	add_to_group("bijalne")   # bardzo zły pomysł, ale wolność wyboru
	_zbuduj_postac()
	await get_tree().process_frame
	var gracze := get_tree().get_nodes_in_group("gracz")
	if gracze.size() > 0:
		_gracz = gracze[0]

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_postac() -> void:
	# Granatowy mundur
	var cialo := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.36
	kapsula.height = 1.2
	cialo.mesh = kapsula
	cialo.material_override = _material(Color(0.12, 0.15, 0.3))
	cialo.position = Vector3(0, 0.8, 0)
	add_child(cialo)
	# Odblaskowa kamizelka (bezpieczeństwo przede wszystkim)
	var kamizelka := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(0.55, 0.5, 0.5)
	kamizelka.mesh = pudlo
	kamizelka.material_override = _material(Color(0.75, 0.95, 0.1))
	kamizelka.position = Vector3(0, 0.95, 0)
	add_child(kamizelka)
	# Głowa + czapka służbowa
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.25
	kula.height = 0.5
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.88, 0.7, 0.56))
	glowa.position = Vector3(0, 1.56, 0)
	add_child(glowa)
	var czapka := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.28
	walec.bottom_radius = 0.26
	walec.height = 0.14
	czapka.mesh = walec
	czapka.material_override = _material(Color(0.1, 0.12, 0.25))
	czapka.position = Vector3(0, 1.77, 0)
	add_child(czapka)
	# Podpis
	var podpis := Styl.plakietka("STRAŻ MIEJSKA", 44, Color(0.7, 0.85, 1.0))
	podpis.position = Vector3(0, 2.15, 0)
	add_child(podpis)

func _process(delta: float) -> void:
	if Game.w_menu or not Game.gra_trwa:
		return
	if _stan == Stan.POSCIG:
		_poscig(delta)
	else:
		_patrol(delta)

## Spokojny marsz po trasie + groźne komentarze.
func _patrol(delta: float) -> void:
	_odliczanie -= delta
	var cel := TRASA[_cel_trasy]
	var kierunek := cel - global_position
	kierunek.y = 0
	if kierunek.length() < 0.6:
		_cel_trasy = (_cel_trasy + 1) % TRASA.size()
		return
	kierunek = kierunek.normalized()
	global_position += kierunek * PREDKOSC * delta
	look_at(global_position + kierunek, Vector3.UP)
	# Groźna obecność
	if _gracz and _odliczanie <= 0.0:
		if global_position.distance_to(_gracz.global_position) < 5.0:
			_odliczanie = PRZERWA_KOMENTARZY
			Game.pokaz_komunikat(TEKSTY.pick_random())

## Pościg: biegnie za graczem, krzyczy, a po dogonieniu wlepia mandat.
## Każda przetrwana sekunda liczy się do zleceń typu "ucieczka".
func _poscig(delta: float) -> void:
	if not is_instance_valid(_gracz):
		_odpusc(false)
		return
	var do_gracza := _gracz.global_position - global_position
	do_gracza.y = 0
	var dystans := do_gracza.length()
	_czas_poscigu += delta
	# Ruch w stronę uciekiniera
	if dystans > 0.1:
		var kierunek := do_gracza.normalized()
		global_position += kierunek * PREDKOSC_POSCIGU * delta
		look_at(global_position + kierunek, Vector3.UP)
	# Sekundy ucieczki - paliwo dla zlecenia "Test refleksu"
	_sekundnik += delta
	if _sekundnik >= 1.0:
		_sekundnik -= 1.0
		Game.postep_zlecenia("ucieczka")
	# Okrzyki co kilka sekund
	_okrzyk_odliczanie -= delta
	if _okrzyk_odliczanie <= 0.0:
		_okrzyk_odliczanie = randf_range(3.5, 6.0)
		Sfx.graj("blad", -10.0, 1.6)
		Game.pokaz_komunikat(OKRZYKI_POSCIGU.pick_random())
	# Złapanie
	if dystans < DYSTANS_ZLAPANIA:
		_zlap()
		return
	# Gubienie z oczu
	if dystans > DYSTANS_UCIECZKI:
		_poza_zasiegiem += delta
		if _poza_zasiegiem >= CZAS_GUBIENIA:
			_odpusc(true)
	else:
		_poza_zasiegiem = 0.0

## Start pościgu - wołane, gdy gracz przegnie (grzebanie na oczach patrolu,
## cios w funkcjonariusza, kradzież wózka pod nosem).
func rozpocznij_poscig(powod := "") -> void:
	if _stan == Stan.POSCIG or not Game.gra_trwa:
		return
	_stan = Stan.POSCIG
	_poza_zasiegiem = 0.0
	_sekundnik = 0.0
	_czas_poscigu = 0.0
	_okrzyk_odliczanie = 1.0
	Sfx.graj("blad", -4.0, 1.8)
	Game.wstrzasnij(0.15)
	Game.pokaz_meme("STRAŻ MIEJSKA W AKCJI!")
	if powod != "":
		Game.pokaz_komunikat("Strażnik cię namierzył: %s. WIEJ!" % powod)

## Dopadł gracza: mandat, gleba i chwila wstydu.
func _zlap() -> void:
	_stan = Stan.PATROL
	_poza_zasiegiem = 0.0
	Game.zaplac_mandat(Balans.MANDAT_ZLAPANIE, "zakłócanie porządku")
	Game.pokaz_komunikat("Złapany po %d s ucieczki. Strażnik dyszy, ale wygrał." % int(_czas_poscigu))
	if is_instance_valid(_gracz) and _gracz.has_method("gleba"):
		_gracz.gleba()

## Odpuszcza pościg - gracz uciekł albo cel zniknął.
func _odpusc(gracz_uciekl: bool) -> void:
	_stan = Stan.PATROL
	_poza_zasiegiem = 0.0
	if gracz_uciekl:
		Game.dodaj_wsiokometr(12.0)   # ucieczka to prestiż osiedlowy
		Sfx.graj("okrzyk2")
		Game.pokaz_komunikat("Zgubiłeś straż po %d s! Kondycja jak u zawodowca." % int(_czas_poscigu))

## Podniesienie ręki na funkcjonariusza. Serio?
func oberwij(gracz: Node3D) -> void:
	Game.zaplac_mandat(Balans.MANDAT_NAPASC, "napaść na funkcjonariusza")
	Game.pokaz_komunikat("Strażnik: \"To był BARDZO zły pomysł.\" Gleba wychowawcza.")
	Sfx.odpal_klasyk()   # dramatyczne momenty wymagają dramatycznej muzyki
	gracz.gleba()
	# Po takim numerze funkcjonariusz już ci nie odpuści
	await get_tree().create_timer(1.2, false).timeout
	if is_inside_tree():
		rozpocznij_poscig("napaść na mundur")
