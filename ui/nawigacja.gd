extends Control
## STRZAŁKA NAWIGACJI - nad radarem. Sama decyduje, co jest teraz
## najważniejsze (pełny plecak? złom do sprzedania? brak zlecenia?)
## i pokazuje kierunek oraz dystans do tego celu.
##
## Cele to obiekty z grupy "cel_nawigacji" z metodą nazwa_celu().

const SZEROKOSC := 200.0
const WYSOKOSC := 34.0
const ODSWIEZANIE := 0.25

var _gracz: Node3D = null
var _cel: Node3D = null
var _opis := ""
var _odliczanie := 0.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(SZEROKOSC, WYSOKOSC)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	visible = not Game.w_menu and Game.gra_trwa
	if not visible:
		return
	if not is_instance_valid(_gracz):
		var gracze := get_tree().get_nodes_in_group("gracz")
		_gracz = gracze[0] if gracze.size() > 0 else null
		if _gracz == null:
			return
	_odliczanie -= delta
	if _odliczanie <= 0.0:
		_odliczanie = ODSWIEZANIE
		_wybierz_cel()
	queue_redraw()

## Priorytety: pełny plecak > złom przy otwartym skupie > brak zlecenia >
## najbliższy fant. Dokładnie w tej kolejności gracz traci najwięcej kasy.
func _wybierz_cel() -> void:
	_cel = null
	_opis = ""
	if not Game.gra_trwa:
		return
	var pelny := Game.zajete_miejsca() >= Game.pojemnosc_plecaka() - 1
	var ma_butelki := Game.ile_w_plecaku("kaucja") > 0
	var ma_zlom := Game.ile_w_plecaku("zlom") > 0

	if pelny and ma_butelki:
		_ustaw("butelkomat", "PLECAK PEŁNY - butelkomat")
		if _cel:
			return
	if ma_zlom and Game.skup_otwarty:
		_ustaw("skup", "Sprzedaj złom u Zdziśka")
		if _cel:
			return
	if ma_butelki and Game.zajete_miejsca() >= 6:
		_ustaw("butelkomat", "Oddaj butelki")
		if _cel:
			return
	if not Zlecenia.czy_aktywne():
		_ustaw("tablica", "Weź zlecenie")
		if _cel:
			return
	_najblizszy_fant()

## Szuka celu po nazwie zwracanej przez nazwa_celu().
##
## Od kiedy butelkomatów jest trzy, "pierwszy z brzegu" przestał wystarczać -
## strzałka potrafiła prowadzić przez pół mapy do automatu przy Biedronce,
## gdy dwa metry dalej stał wolny. Wybieramy NAJBLIŻSZY, a punkt z kolejką
## traktujemy tak, jakby był o 25 m dalej: zwykle opłaca się iść do wolnego,
## ale gdy stoisz przy zajętym, strzałka nie każe biec na drugi koniec osiedla.
const KARA_ZA_KOLEJKE := 25.0

func _ustaw(nazwa: String, opis: String) -> void:
	var najlepszy: Node3D = null
	var najlepszy_koszt := INF
	for kandydat in get_tree().get_nodes_in_group("cel_nawigacji"):
		if not (is_instance_valid(kandydat) and kandydat.has_method("nazwa_celu")):
			continue
		if kandydat.nazwa_celu() != nazwa:
			continue
		var koszt: float = _gracz.global_position.distance_to(kandydat.global_position)
		if kandydat.has_method("czy_kolejka") and kandydat.czy_kolejka():
			koszt += KARA_ZA_KOLEJKE
		if koszt < najlepszy_koszt:
			najlepszy_koszt = koszt
			najlepszy = kandydat
	if najlepszy:
		_cel = najlepszy
		_opis = opis

## Gdy nie ma pilniejszych spraw - prowadzimy do najbliższej butelki.
func _najblizszy_fant() -> void:
	var najlepszy: Node3D = null
	var najblizej := INF
	for fant in get_tree().get_nodes_in_group("kolekcjonerskie"):
		if not is_instance_valid(fant):
			continue
		var dystans: float = _gracz.global_position.distance_to(fant.global_position)
		if dystans < najblizej:
			najblizej = dystans
			najlepszy = fant
	if najlepszy:
		_cel = najlepszy
		_opis = "Najbliższy fant"

func _draw() -> void:
	if _cel == null or not is_instance_valid(_cel) or not is_instance_valid(_gracz):
		return
	var roznica: Vector3 = _cel.global_position - _gracz.global_position
	var dystans := Vector2(roznica.x, roznica.z).length()
	# Kąt do celu względem kierunku patrzenia gracza. Ten sam Kompas co radar -
	# poprzedni wzór zgadzał się dla celów PRZED graczem, ale cele z boku
	# wskazywał lustrzanie (obiekt po prawej -> strzałka w lewo).
	var yaw: float = _gracz.global_rotation.y
	var kat := Kompas.kat_strzalki(roznica, yaw)
	# Tło paska
	var prostokat := Rect2(Vector2.ZERO, Vector2(SZEROKOSC, WYSOKOSC))
	draw_rect(prostokat, Color(0.04, 0.07, 0.1, 0.72), true)
	draw_rect(prostokat, Color(1.0, 0.85, 0.3, 0.4), false, 1.5)
	# Strzałka obrócona w stronę celu
	var srodek := Vector2(22, WYSOKOSC / 2.0)
	var punkty := PackedVector2Array()
	for wierzcholek in [Vector2(0, -11), Vector2(-7.5, 8), Vector2(0, 4), Vector2(7.5, 8)]:
		punkty.append(srodek + wierzcholek.rotated(kat))
	draw_colored_polygon(punkty, Color(1.0, 0.85, 0.25))
	# Opis i dystans
	draw_string(_font, Vector2(44, 15), _opis, HORIZONTAL_ALIGNMENT_LEFT,
		SZEROKOSC - 50, 13, Color(1, 1, 1, 0.9))
	draw_string(_font, Vector2(44, 29), "%d m" % int(dystans), HORIZONTAL_ALIGNMENT_LEFT,
		SZEROKOSC - 50, 12, Color(1.0, 0.85, 0.4, 0.85))
