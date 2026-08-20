extends Control
## RADAR OSIEDLOWY — minimapa w prawym dolnym rogu.
## Obraca się razem z graczem (góra ekranu = kierunek patrzenia), pokazuje
## fanty, złom, punkty skupu i straż miejską. Rysowany w całości w _draw(),
## więc nie kosztuje ani jednego dodatkowego renderu 3D.

const PROMIEN := 82.0          # promień radaru w pikselach
const ZASIEG := 46.0           # ile metrów świata mieści się na radarze
const ODSWIEZANIE := 0.12      # co ile sekund przebudowujemy listę obiektów

# Kolory kropek — spójne z tym, co gracz widzi w świecie
# Tło musi być mocno kryjące — przy 0.72 cienie budynków prześwitywały
# przez tarczę i wyglądały jak czarne plamy na radarze
const KOLOR_TLA := Color(0.04, 0.07, 0.1, 0.9)
const KOLOR_OBWODU := Color(1.0, 0.85, 0.3, 0.55)
const KOLOR_FANTU := Color(0.45, 0.85, 1.0)
const KOLOR_ZLOTA := Color(1.0, 0.82, 0.2)
const KOLOR_ZLOMU := Color(0.78, 0.55, 0.3)
const KOLOR_CELU := Color(0.4, 1.0, 0.55)
const KOLOR_STRAZY := Color(1.0, 0.35, 0.3)
const KOLOR_AUTA := Color(0.75, 0.75, 0.8)
const KOLOR_GRACZA := Color(1.0, 1.0, 1.0)

var _gracz: Node3D = null
var _odliczanie := 0.0
# Cache: listy obiektów przepisywane co ODSWIEZANIE sekund
var _fanty: Array = []
var _cele: Array = []
var _straz: Array = []
var _auta: Array = []
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(PROMIEN * 2.0, PROMIEN * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_znajdz_gracza()

func _znajdz_gracza() -> void:
	var gracze := get_tree().get_nodes_in_group("gracz")
	_gracz = gracze[0] if gracze.size() > 0 else null

func _process(delta: float) -> void:
	# W menu głównym i po zakończeniu dnia radar znika — nie zasłania panelu
	visible = not Game.w_menu and Game.gra_trwa
	if not visible:
		return
	if not is_instance_valid(_gracz):
		_znajdz_gracza()
	# Listę obiektów odświeżamy kilka razy na sekundę — co klatkę byłoby
	# marnotrawstwem, a i tak nikt tego nie zauważy
	_odliczanie -= delta
	if _odliczanie <= 0.0:
		_odliczanie = ODSWIEZANIE
		_fanty = get_tree().get_nodes_in_group("kolekcjonerskie")
		_cele = get_tree().get_nodes_in_group("cel_nawigacji")
		_straz = get_tree().get_nodes_in_group("straz")
		_auta = get_tree().get_nodes_in_group("auta")
	queue_redraw()   # pozycje i tak zmieniają się co klatkę

func _draw() -> void:
	var srodek := Vector2(PROMIEN, PROMIEN)
	# Tarcza radaru
	draw_circle(srodek, PROMIEN, KOLOR_TLA)
	draw_arc(srodek, PROMIEN, 0, TAU, 48, KOLOR_OBWODU, 2.0, true)
	# Krzyż orientacyjny
	draw_line(srodek + Vector2(-PROMIEN + 6, 0), srodek + Vector2(PROMIEN - 6, 0), Color(1, 1, 1, 0.08), 1.0)
	draw_line(srodek + Vector2(0, -PROMIEN + 6), srodek + Vector2(0, PROMIEN - 6), Color(1, 1, 1, 0.08), 1.0)
	if not is_instance_valid(_gracz):
		return

	# Obrót radaru: przód gracza zawsze na górze tarczy
	var yaw: float = _gracz.global_rotation.y
	var pozycja_gracza: Vector3 = _gracz.global_position

	# Obiekty — kolejność rysowania od najmniej do najważniejszych
	for auto in _auta:
		_kropka(srodek, pozycja_gracza, yaw, auto.global_position, KOLOR_AUTA, 2.5)
	for fant in _fanty:
		if not is_instance_valid(fant):
			continue
		var kolor := KOLOR_FANTU
		var rozmiar := 2.6
		# Rozróżniamy typy — złote i złom mają własne kolory
		var typ_fantu: int = fant.typ if "typ" in fant else -1
		if typ_fantu >= 0:
			if fant.kategoria(typ_fantu) == "zlom":
				kolor = KOLOR_ZLOMU
			elif fant.czy_zloty(typ_fantu):
				kolor = KOLOR_ZLOTA
				rozmiar = 3.6
		_kropka(srodek, pozycja_gracza, yaw, fant.global_position, kolor, rozmiar)
	for cel in _cele:
		if is_instance_valid(cel):
			_kropka(srodek, pozycja_gracza, yaw, cel.global_position, KOLOR_CELU, 4.2, true)
	for straznik in _straz:
		if is_instance_valid(straznik):
			_kropka(srodek, pozycja_gracza, yaw, straznik.global_position, KOLOR_STRAZY, 4.0, true)

	# Gracz — trójkąt zawsze skierowany w górę tarczy
	var strzalka := PackedVector2Array([
		srodek + Vector2(0, -7), srodek + Vector2(-5, 5), srodek + Vector2(5, 5),
	])
	draw_colored_polygon(strzalka, KOLOR_GRACZA)
	# Podpis skali
	draw_string(_font, srodek + Vector2(-PROMIEN + 8, PROMIEN - 8),
		"%d m" % int(ZASIEG), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

## Rysuje pojedynczy obiekt na tarczy. Obiekty poza zasięgiem są przyklejane
## do krawędzi (przygaszone), żeby gracz wiedział, w którą stronę biec.
func _kropka(srodek: Vector2, skad: Vector3, yaw: float, dokad: Vector3,
		kolor: Color, rozmiar: float, obwodka := false) -> void:
	var roznica := dokad - skad
	# Obrót do układu gracza liczy Kompas — wspólnie ze strzałką nawigacji.
	# Wcześniej był tu obrót o -yaw i radar wychodził odwrócony: przy yaw=0
	# zgadzał się przypadkiem, ale po obróceniu postaci kropki jechały
	# w przeciwną stronę, niż szedł gracz.
	var punkt := Kompas.na_ekran(roznica, yaw) * (PROMIEN / ZASIEG)
	var dystans := punkt.length()
	var poza_zasiegiem := dystans > PROMIEN - 6.0
	if poza_zasiegiem:
		punkt = punkt.normalized() * (PROMIEN - 6.0)
		kolor.a *= 0.5
		rozmiar *= 0.8
	draw_circle(srodek + punkt, rozmiar, kolor)
	if obwodka and not poza_zasiegiem:
		draw_arc(srodek + punkt, rozmiar + 2.5, 0, TAU, 12, Color(kolor, 0.7), 1.5, true)
