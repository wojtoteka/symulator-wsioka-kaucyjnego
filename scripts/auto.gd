extends PathFollow3D
## RUCH ULICZNY — auto jadące po ścieżce (Path3D) dookoła osiedla.
## Trąbi na gapiących się, a jak wejdziesz mu pod koła, to boli:
## gleba, wysypane fanty i utrata combo. Patrz na drogę, wsioku.
##
## Tworzone przez world.gd: rodzicem MUSI być Path3D z gotową krzywą.

const KOLORY: Array[Color] = [
	Color(0.75, 0.16, 0.14),   # czerwone maluchy i inne klasyki
	Color(0.85, 0.85, 0.88),
	Color(0.18, 0.32, 0.6),
	Color(0.25, 0.5, 0.3),
	Color(0.55, 0.55, 0.58),
	Color(0.9, 0.75, 0.2),     # taksówka osiedlowa
]

const TEKSTY_TRABIENIA: Array[String] = [
	"Kierowca trąbi: \"Z DROGI!\"",
	"Auto zatrąbiło. Klasyczny osiedlowy dialog.",
	"Kierowca pokazuje coś przez szybę. Chyba nie \"cześć\".",
	"BIP BIP! Ktoś się spieszy do Biedronki.",
]

# --- Jazda w kolumnie ---
# Auta jadą po wspólnym torze (PathFollow3D), a rodzeństwo na torze NIE MA
# ze sobą kolizji. Przy różnych prędkościach szybsze auto po kilkudziesięciu
# sekundach dojeżdżało do wolniejszego i wjeżdżało w nie na wylot — dwa
# nadwozia jedno w drugim wyglądały jak tramwaj. Dlatego każde auto pilnuje
# odstępu do poprzednika i zwalnia, zamiast go przenikać.
const ODSTEP_MIN := 5.5        # bliżej niż tyle = stój (nadwozie ma 3,9 m)
const ODSTEP_BEZPIECZNY := 13.0   # od tego dystansu jedziemy pełnym gazem
const PRZYSPIESZENIE := 4.0
const HAMOWANIE := 9.0

var predkosc := 7.0            # docelowa prędkość na wolnej drodze (m/s)
var _predkosc_biezaca := 0.0
var _dlugosc_trasy := 1.0
var _strefa: Area3D
var _odliczanie_trabienia := 0.0
var _czas_w_korku := 0.0
var _bryla: Node3D

func _ready() -> void:
	add_to_group("auta")
	loop = true
	rotation_mode = PathFollow3D.ROTATION_Y   # auto samo obraca się wzdłuż trasy
	var sciezka := get_parent() as Path3D
	if sciezka != null and sciezka.curve != null:
		_dlugosc_trasy = maxf(sciezka.curve.get_baked_length(), 1.0)
	_predkosc_biezaca = predkosc
	_zbuduj_bryle()
	_zbuduj_strefe()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

func _pudlo(pozycja: Vector3, rozmiar: Vector3, kolor: Color, emisja := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = rozmiar
	mesh.mesh = pudlo
	mesh.material_override = _material(kolor, emisja)
	mesh.position = pozycja
	_bryla.add_child(mesh)
	return mesh

func _zbuduj_bryle() -> void:
	_bryla = Node3D.new()
	add_child(_bryla)
	var kolor: Color = Styl.wariant(KOLORY.pick_random(), 0.06)
	# Nadwozie. Kluczowe dla sylwetki: kabina jest WYRAŹNIE węższa i krótsza
	# od nadwozia i cofnięta do tyłu — dzięki temu z boku widać maskę, kabinę
	# i bagażnik zamiast jednego prostopadłościanu.
	_pudlo(Vector3(0, 0.5, 0), Vector3(1.72, 0.52, 3.9), kolor)
	# Maska i bagażnik — niskie nadbudówki, które łamią górną krawędź
	_pudlo(Vector3(0, 0.8, -1.35), Vector3(1.6, 0.14, 1.2), kolor)
	_pudlo(Vector3(0, 0.8, 1.45), Vector3(1.6, 0.14, 0.9), kolor)
	# Kabina + dach
	_pudlo(Vector3(0, 1.05, 0.1), Vector3(1.5, 0.58, 1.85), kolor.lightened(0.1))
	_pudlo(Vector3(0, 1.36, 0.1), Vector3(1.38, 0.08, 1.7), kolor.darkened(0.15))
	# Szyby: przód, tył i boczne (te ostatnie robią najwięcej dla czytelności)
	_pudlo(Vector3(0, 1.06, -0.85), Vector3(1.34, 0.4, 0.06), Color(0.16, 0.22, 0.3))
	_pudlo(Vector3(0, 1.06, 1.05), Vector3(1.34, 0.4, 0.06), Color(0.16, 0.22, 0.3))
	for bok in [-0.77, 0.77]:
		_pudlo(Vector3(bok, 1.06, 0.1), Vector3(0.05, 0.38, 1.6), Color(0.16, 0.22, 0.3))
	# Zderzaki — bez nich przód i tył kończą się „na ostro"
	for z in [-1.98, 1.98]:
		_pudlo(Vector3(0, 0.42, z), Vector3(1.78, 0.2, 0.14), Color(0.22, 0.22, 0.24))
	# Światła: przednie białe, tylne czerwone
	_pudlo(Vector3(-0.55, 0.66, -1.97), Vector3(0.34, 0.16, 0.06), Color(1.0, 0.96, 0.8), true)
	_pudlo(Vector3(0.55, 0.66, -1.97), Vector3(0.34, 0.16, 0.06), Color(1.0, 0.96, 0.8), true)
	_pudlo(Vector3(-0.55, 0.66, 1.97), Vector3(0.34, 0.16, 0.06), Color(0.9, 0.15, 0.1), true)
	_pudlo(Vector3(0.55, 0.66, 1.97), Vector3(0.34, 0.16, 0.06), Color(0.9, 0.15, 0.1), true)
	# Koła — nieco szersze niż nadwozie, jak w zabawkowym aucie
	for przesuniecie in [
		Vector3(-0.86, 0.32, -1.3), Vector3(0.86, 0.32, -1.3),
		Vector3(-0.86, 0.32, 1.3), Vector3(0.86, 0.32, 1.3),
	]:
		var kolo := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.32
		walec.bottom_radius = 0.32
		walec.height = 0.22
		kolo.mesh = walec
		kolo.material_override = _material(Color(0.09, 0.09, 0.1))
		kolo.rotation.z = PI / 2
		kolo.position = przesuniecie
		_bryla.add_child(kolo)

## Strefa potrącenia — auta nie mają kolizji fizycznej, tylko "boli, gdy wejdziesz".
func _zbuduj_strefe() -> void:
	_strefa = Area3D.new()
	add_child(_strefa)
	var ksztalt := CollisionShape3D.new()
	var pudlo := BoxShape3D.new()
	pudlo.size = Vector3(1.9, 1.4, 4.0)
	ksztalt.shape = pudlo
	ksztalt.position = Vector3(0, 0.7, 0)
	_strefa.add_child(ksztalt)
	_strefa.body_entered.connect(_na_potracenie)

## Auto tuż przy kamerze chowamy. Kamera TPP wisi 4 m za graczem i nie ma
## fizyki, więc przejeżdżający samochód potrafi ją po prostu połknąć — a że
## nadwozie ma kontur rysowany od środka (patrz Styl), ekran robi się wtedy
## CZARNY na pół kadru.
##
## Podpięcie tego pod wysięgnik kamery nie działa: SpringArm3D reaguje tylko
## na przeszkody na swojej osi, a tu auto wjeżdża w kamerę z boku. Do tego
## każde mijające auto szarpałoby wtedy kadrem. Chowanie bryły jest tańsze
## i niewidoczne dla gracza — zasłaniałaby mu i tak cały ekran.
func _ukryj_gdy_w_kamerze() -> void:
	var kamera := get_viewport().get_camera_3d()
	if kamera == null:
		return
	_bryla.visible = global_position.distance_to(kamera.global_position) > 2.8

func _process(delta: float) -> void:
	if Game.w_menu or not Game.gra_trwa:
		return
	_ukryj_gdy_w_kamerze()
	# Jedziemy tak szybko, jak pozwala auto z przodu
	var luka := _luka_do_poprzednika()
	var docelowa := predkosc_dla_luki(luka, predkosc)
	var zmiana := HAMOWANIE if docelowa < _predkosc_biezaca else PRZYSPIESZENIE
	_predkosc_biezaca = move_toward(_predkosc_biezaca, docelowa, zmiana * delta)
	progress += _predkosc_biezaca * delta
	# Trąbienie na gapiów przy jezdni ORAZ na tego, kto blokuje przejazd
	_odliczanie_trabienia -= delta
	if _predkosc_biezaca < 1.0 and docelowa < 1.0:
		_czas_w_korku += delta
	else:
		_czas_w_korku = 0.0
	if _odliczanie_trabienia <= 0.0 and _czas_w_korku > 2.0:
		_odliczanie_trabienia = randf_range(4.0, 8.0)
		Sfx.graj("blad", -14.0, 2.4)   # zniecierpliwione "biip" w korku
	elif _odliczanie_trabienia <= 0.0:
		var gracze := get_tree().get_nodes_in_group("gracz")
		if gracze.size() > 0 and gracze[0].global_position.distance_to(global_position) < 6.0:
			_odliczanie_trabienia = randf_range(9.0, 16.0)
			Sfx.graj("blad", -12.0, 2.2)   # krótkie "biip"
			Game.pokaz_komunikat(TEKSTY_TRABIENIA.pick_random())

## Odległość (wzdłuż trasy) do najbliższego auta JADĄCEGO PRZED NAMI.
## Trasa jest pętlą, więc liczymy modulo jej długość.
func _luka_do_poprzednika() -> float:
	var najmniejsza := INF
	for inne in get_parent().get_children():
		if inne == self or not (inne is PathFollow3D):
			continue
		var luka: float = fposmod(inne.progress - progress, _dlugosc_trasy)
		najmniejsza = minf(najmniejsza, luka)
	return najmniejsza

## Jak szybko wolno jechać przy danym odstępie do poprzednika.
## Poniżej ODSTEP_MIN stoimy, powyżej ODSTEP_BEZPIECZNY pełny gaz,
## pomiędzy — płynnie, żeby kolumna nie szarpała.
static func predkosc_dla_luki(luka: float, maks: float) -> float:
	if luka <= ODSTEP_MIN:
		return 0.0
	if luka >= ODSTEP_BEZPIECZNY:
		return maks
	return maks * (luka - ODSTEP_MIN) / (ODSTEP_BEZPIECZNY - ODSTEP_MIN)

## Potrącenie gracza: gleba, wysypane fanty i mocny wstrząs.
## Nie odbieramy kasy — gra ma być śmieszna, nie okrutna.
func _na_potracenie(cialo: Node3D) -> void:
	if not cialo.is_in_group("gracz") or not Game.gra_trwa:
		return
	if cialo.lezy:
		return   # leżącego auto już nie przejedzie drugi raz
	Sfx.graj("blad", 0.0, 1.4)
	Sfx.graj("upadek")
	Game.wstrzasnij(0.6)
	Game.zgub_combo()
	Game.pokaz_komunikat([
		"POTRĄCENIE! Kierowca nawet nie zwolnił.",
		"Auto cię zahaczyło. Osiedle się śmieje.",
		"Zderzenie z blachą. Blacha wygrała.",
	].pick_random())
	cialo.gleba()
	# Wypada część fantów — potoczyły się po asfalcie
	var zgubione: int = Game.zgub_fanty(2)
	if zgubione > 0:
		Game.pokaz_komunikat("Wysypało ci się %d szt. z plecaka. Zbieraj, mistrzu." % zgubione)
