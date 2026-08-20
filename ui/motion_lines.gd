extends Control
## MOTION LINES — kreski pędu przy krawędziach ekranu.
## Im szybciej gracz jedzie, tym gęstsze i dłuższe. Wjeżdżają dopiero
## powyżej prędkości biegu, żeby zwykłe chodzenie nie migotało.
## Rysowane w _draw() — zero kosztu, gdy stoimy w miejscu.

const PROG_PREDKOSCI := 7.0     # od tylu m/s zaczynają się pojawiać
const PELNA_PREDKOSC := 17.0    # przy tej prędkości efekt jest maksymalny
const ILE_KRESEK := 26
const NARASTANIE := 6.0         # jak szybko efekt się pojawia/znika

var _gracz: Node3D = null
var _sila := 0.0                # 0-1, wygładzona
var _losowe: Array[float] = []  # stałe "ziarno" kątów, żeby kreski nie skakały

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ILE_KRESEK:
		_losowe.append(randf())
	_znajdz_gracza()

func _znajdz_gracza() -> void:
	var gracze := get_tree().get_nodes_in_group("gracz")
	_gracz = gracze[0] if gracze.size() > 0 else null

func _process(delta: float) -> void:
	if not is_instance_valid(_gracz):
		_znajdz_gracza()
		return
	var predkosc := Vector2(_gracz.velocity.x, _gracz.velocity.z).length()
	var cel := clampf((predkosc - PROG_PREDKOSCI) / (PELNA_PREDKOSC - PROG_PREDKOSCI), 0.0, 1.0)
	# Drift dorzuca swoje — bokiem zawsze wygląda szybciej niż jest
	if "_drift" in _gracz and _gracz._drift:
		cel = maxf(cel, 0.55)
	var poprzednia := _sila
	_sila = lerpf(_sila, cel, NARASTANIE * delta)
	# Przerysowujemy tylko, gdy faktycznie coś się zmienia
	if absf(_sila - poprzednia) > 0.002 or _sila > 0.01:
		queue_redraw()

func _draw() -> void:
	if _sila <= 0.02:
		return
	var ekran := size
	var srodek := ekran * 0.5
	var maks_promien := srodek.length()
	# Kreski startują bliżej krawędzi i biegną promieniście na zewnątrz
	for i in ILE_KRESEK:
		var kat := (float(i) / ILE_KRESEK) * TAU + _losowe[i] * 0.22
		var kierunek := Vector2(cos(kat), sin(kat))
		# Środek ekranu zostaje czysty — kreski tylko przy brzegach
		var poczatek := srodek + kierunek * (maks_promien * (0.62 - 0.12 * _sila))
		var dlugosc := maks_promien * (0.1 + 0.28 * _sila) * (0.6 + _losowe[i] * 0.8)
		var koniec := poczatek + kierunek * dlugosc
		var alpha := (0.1 + 0.5 * _sila) * (0.5 + _losowe[i] * 0.5)
		draw_line(poczatek, koniec, Color(1, 1, 1, alpha), 1.0 + 2.0 * _sila, true)
