extends Node3D
## PORA DNIA - słońce, niebo i mgła zmieniające się w trakcie rundy.
##
## Dzień trwa pięć minut i do tej pory wyglądał przez cały czas identycznie:
## słońce ustawiane raz w _ready() i koniec. Timer na HUD-zie mówił, że czas
## ucieka, ale świat temu przeczył. Teraz ta sama liczba (Game.czas) prowadzi
## słońce od porannego światła, przez południe, po ZACHÓD w ostatniej minucie -
## i nagle "zostały dwie minuty" widać, zanim się to przeczyta.
##
## Wszystko idzie z jednej tabeli klatek kluczowych FAZY. Chcesz inną porę
## dnia albo dłuższy zachód? Przesuwasz liczby tutaj, nic więcej.
##
## Drugą warstwą jest POGODA (Game.zachmurzenie()): ta sama scena przykryta
## chmurami gaśnie, szarzeje i tonie we mgle. Deszcz i pora dnia mnożą się
## przez siebie - zachód w deszczu jest ponury, a nie pomarańczowy.

## Klatka kluczowa pory dnia. "t" to postęp rundy: 0.0 = start, 1.0 = koniec.
## Kolejność w tablicy musi być rosnąca po "t".
const FAZY: Array[Dictionary] = [
	{
		"t": 0.0, "nazwa": "poranek",
		"slonce": Vector2(-18, -95), "swiatlo": Color(1.0, 0.86, 0.68), "moc": 0.85,
		"niebo_gora": Color(0.22, 0.48, 0.86), "niebo_horyzont": Color(0.78, 0.86, 0.94),
		"ambient": Color(0.66, 0.70, 0.78), "ambient_moc": 0.50,
		"mgla": 0.0030, "ekspozycja": 0.78,
	},
	{
		"t": 0.30, "nazwa": "przedpołudnie",
		"slonce": Vector2(-58, -55), "swiatlo": Color(1.0, 0.96, 0.86), "moc": 1.20,
		"niebo_gora": Color(0.16, 0.45, 0.92), "niebo_horyzont": Color(0.62, 0.84, 1.0),
		"ambient": Color(0.72, 0.72, 0.68), "ambient_moc": 0.50,
		"mgla": 0.0022, "ekspozycja": 0.80,
	},
	{
		"t": 0.62, "nazwa": "popołudnie",
		"slonce": Vector2(-40, -14), "swiatlo": Color(1.0, 0.92, 0.74), "moc": 1.12,
		"niebo_gora": Color(0.18, 0.46, 0.88), "niebo_horyzont": Color(0.74, 0.84, 0.96),
		"ambient": Color(0.74, 0.71, 0.64), "ambient_moc": 0.50,
		"mgla": 0.0026, "ekspozycja": 0.80,
	},
	{
		"t": 0.86, "nazwa": "złota godzina",
		"slonce": Vector2(-19, 16), "swiatlo": Color(1.0, 0.74, 0.44), "moc": 1.00,
		"niebo_gora": Color(0.24, 0.38, 0.74), "niebo_horyzont": Color(1.0, 0.72, 0.42),
		"ambient": Color(0.80, 0.66, 0.50), "ambient_moc": 0.48,
		"mgla": 0.0038, "ekspozycja": 0.78,
	},
	{
		"t": 1.0, "nazwa": "zachód",
		"slonce": Vector2(-5, 33), "swiatlo": Color(1.0, 0.52, 0.26), "moc": 0.60,
		"niebo_gora": Color(0.15, 0.17, 0.42), "niebo_horyzont": Color(1.0, 0.46, 0.28),
		"ambient": Color(0.58, 0.48, 0.50), "ambient_moc": 0.42,
		"mgla": 0.0052, "ekspozycja": 0.72,
	},
]

## Do czego dąży scena przy pełnym zachmurzeniu (mnożnik/cel mieszania).
const DESZCZ_SWIATLO := Color(0.80, 0.85, 0.92)
const DESZCZ_NIEBO_GORA := Color(0.34, 0.38, 0.45)
const DESZCZ_NIEBO_HORYZONT := Color(0.60, 0.63, 0.67)
const DESZCZ_AMBIENT := Color(0.60, 0.63, 0.67)
const DESZCZ_MOC := 0.5           # mnożnik siły słońca
const DESZCZ_MGLA := 5.0          # mnożnik gęstości mgły
const DESZCZ_NASYCENIE := 0.78    # mnożnik saturacji post-processu

## Odświeżanie 10 razy na sekundę. Co klatkę byłoby marnotrawstwem: przy
## pięciominutowym dniu kolory zmieniają się o ułamek procenta na klatkę,
## a przemalowanie proceduralnego nieba nie jest darmowe.
const ODSWIEZANIE := 0.1

var slonce: DirectionalLight3D
var srodowisko: WorldEnvironment
var _env: Environment
var _niebo: ProceduralSkyMaterial
var _odliczanie := 0.0
var _zachmurzenie := 0.0      # płynnie goni Game.zachmurzenie()
var _faza_nazwa := "poranek"

func _ready() -> void:
	_zbuduj_slonce()
	_zbuduj_srodowisko()
	_zachmurzenie = Game.zachmurzenie()
	_zastosuj(_stan_dla(_postep()))

## Nazwa bieżącej pory dnia - HUD pokazuje ją obok zegara.
func nazwa_fazy() -> String:
	return _faza_nazwa

func _process(delta: float) -> void:
	_odliczanie -= delta
	if _odliczanie > 0.0:
		return
	_odliczanie = ODSWIEZANIE
	# Zachmurzenie dochodzi płynnie - dzięki temu przejście do deszczu
	# w trakcie dnia (i powrót) nie jest cięciem montażowym
	_zachmurzenie = move_toward(_zachmurzenie, Game.zachmurzenie(), 0.6 * ODSWIEZANIE)
	_zastosuj(_stan_dla(_postep()))

## Postęp rundy 0..1. W menu głównym stoimy na porannym świetle - ekran
## tytułowy ma wyglądać jak początek dnia, a nie jak jego koniec.
func _postep() -> float:
	if Game.w_menu:
		return 0.0
	return clampf(1.0 - Game.czas / Balans.CZAS_RUNDY, 0.0, 1.0)

## Interpolacja między dwiema sąsiednimi klatkami kluczowymi.
func _stan_dla(t: float) -> Dictionary:
	var poprzednia: Dictionary = FAZY[0]
	var nastepna: Dictionary = FAZY[FAZY.size() - 1]
	for i in FAZY.size():
		if float(FAZY[i]["t"]) <= t:
			poprzednia = FAZY[i]
			nastepna = FAZY[mini(i + 1, FAZY.size() - 1)]
	var rozpietosc := float(nastepna["t"]) - float(poprzednia["t"])
	var u := 0.0 if rozpietosc <= 0.0 else clampf((t - float(poprzednia["t"])) / rozpietosc, 0.0, 1.0)
	# Wygładzenie: bez niego widać moment przejścia między klatkami jako
	# lekkie "szarpnięcie" koloru nieba
	u = smoothstep(0.0, 1.0, u)
	_faza_nazwa = str(poprzednia["nazwa"] if u < 0.5 else nastepna["nazwa"])
	return {
		"slonce": Vector2(poprzednia["slonce"]).lerp(Vector2(nastepna["slonce"]), u),
		"swiatlo": Color(poprzednia["swiatlo"]).lerp(Color(nastepna["swiatlo"]), u),
		"moc": lerpf(float(poprzednia["moc"]), float(nastepna["moc"]), u),
		"niebo_gora": Color(poprzednia["niebo_gora"]).lerp(Color(nastepna["niebo_gora"]), u),
		"niebo_horyzont": Color(poprzednia["niebo_horyzont"]).lerp(Color(nastepna["niebo_horyzont"]), u),
		"ambient": Color(poprzednia["ambient"]).lerp(Color(nastepna["ambient"]), u),
		"ambient_moc": lerpf(float(poprzednia["ambient_moc"]), float(nastepna["ambient_moc"]), u),
		"mgla": lerpf(float(poprzednia["mgla"]), float(nastepna["mgla"]), u),
		"ekspozycja": lerpf(float(poprzednia["ekspozycja"]), float(nastepna["ekspozycja"]), u),
	}

## Przełożenie policzonego stanu na scenę - z domieszką pogody.
func _zastosuj(stan: Dictionary) -> void:
	var ch := _zachmurzenie
	var kat: Vector2 = stan["slonce"]
	slonce.rotation_degrees = Vector3(kat.x, kat.y, 0)
	slonce.light_color = Color(stan["swiatlo"]).lerp(DESZCZ_SWIATLO, ch)
	slonce.light_energy = float(stan["moc"]) * lerpf(1.0, DESZCZ_MOC, ch)
	# W deszczu cienie miękną i bledną - ostry cień przy zachmurzonym niebie
	# to najczęstszy zdradliwy detal "renderu"
	slonce.shadow_opacity = lerpf(0.82, 0.35, ch)
	slonce.shadow_blur = lerpf(1.4, 3.2, ch)

	var horyzont: Color = Color(stan["niebo_horyzont"]).lerp(DESZCZ_NIEBO_HORYZONT, ch)
	_niebo.sky_top_color = Color(stan["niebo_gora"]).lerp(DESZCZ_NIEBO_GORA, ch)
	_niebo.sky_horizon_color = horyzont
	_niebo.ground_horizon_color = horyzont

	_env.ambient_light_color = Color(stan["ambient"]).lerp(DESZCZ_AMBIENT, ch)
	_env.ambient_light_energy = float(stan["ambient_moc"]) * lerpf(1.0, 0.9, ch)
	_env.fog_light_color = horyzont
	_env.fog_density = float(stan["mgla"]) * lerpf(1.0, DESZCZ_MGLA, ch)
	_env.tonemap_exposure = float(stan["ekspozycja"]) * lerpf(1.0, 0.92, ch)
	_env.adjustment_saturation = 1.16 * lerpf(1.0, DESZCZ_NASYCENIE, ch)
	_pomaluj_chmury(horyzont, ch)

## Chmury dostają kolor horyzontu - o zachodzie robią się różowe, w deszczu
## siwe. Bez tego nad pomarańczowym niebem wisiałyby białe waciki.
func _pomaluj_chmury(horyzont: Color, zachmurzenie: float) -> void:
	var kolor := Color.WHITE.lerp(horyzont, 0.55).lerp(Color(0.5, 0.52, 0.56), zachmurzenie * 0.8)
	kolor.a = 0.95
	for chmura in get_tree().get_nodes_in_group("chmura"):
		for klab in chmura.get_children():
			if klab is MeshInstance3D and klab.material_override is StandardMaterial3D:
				klab.material_override.albedo_color = kolor

# --- Budowa sceny świetlnej (raz, w _ready) ---

func _zbuduj_slonce() -> void:
	# Mocne, kontrastowe słońce - kreskówka potrzebuje wyraźnych cieni,
	# nie miękkiego rozproszonego światła jak w symulatorze architektury
	slonce = DirectionalLight3D.new()
	slonce.shadow_enabled = true
	# 0.9 dawało cienie prawie czarne - czytelne, ale wyglądające jak wycięte
	# nożyczkami. Odrobinę jaśniejsze i lekko zmiękczone czytają się jak cień,
	# a nie jak naklejona plama.
	slonce.shadow_opacity = 0.82
	slonce.shadow_blur = 1.4
	slonce.directional_shadow_max_distance = 90.0
	add_child(slonce)

func _zbuduj_srodowisko() -> void:
	srodowisko = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	# Niebo: nasycony błękit z wyraźnym przejściem do jasnego horyzontu
	_niebo = ProceduralSkyMaterial.new()
	_niebo.sky_curve = 0.12       # ostrzejszy gradient = bardziej "rysowane"
	_niebo.ground_bottom_color = Color(0.24, 0.42, 0.3)
	# Tarcza słońca na niebie - jest źródłem cieni, więc powinno być widać,
	# skąd padają. Puste niebo to kolejny drobiazg, który czyta się jak "render".
	_niebo.sun_angle_max = 12.0
	_niebo.sun_curve = 0.08
	var kopula := Sky.new()
	kopula.sky_material = _niebo
	env.sky = kopula
	# Ambient jako WŁASNY kolor, nie z nieba: światło odbite od błękitnego
	# nieba malowało wszystko na niebiesko (chodniki wychodziły siwe).
	# Ciepły, neutralny ambient trzyma kolory takimi, jakie są w palecie.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Mgła tylko jako delikatna głębia w oddali (w deszczu gęstnieje)
	env.fog_enabled = true
	# Poświata - neon, latarnie i złote fanty ładnie "błyszczą"
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	# ACES zamiast FILMIC: trzyma nasycenie zamiast je spłaszczać.
	# Wysoki whitepoint ratuje jasne ściany przed wypaleniem do bieli.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 2.2
	# Korekcja obrazu - to ona robi najwięcej dla "komiksowego" charakteru.
	# Zbity kontrast plus mocna saturacja dawały efekt plakatu: kolory ładne,
	# ale wszystko wyglądało jak nadruk. Skoro detal niosą teraz tekstury
	# szumu i sylwetki budynków, korekcja może zejść na drugi plan.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.0
	srodowisko.environment = env
	_env = env
	add_child(srodowisko)
