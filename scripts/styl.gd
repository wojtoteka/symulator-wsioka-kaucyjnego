class_name Styl
## STYL WIZUALNY — jedno miejsce, które decyduje, jak wygląda CAŁA gra.
## Cel: mocno stylizowany, kreskówkowy look w duchu "Slackers - Carts of Glory":
## nasycone kolory, płaskie (toon) cieniowanie zamiast miękkich gradientów
## i czarny kontur wokół ważnych obiektów.
##
## Zamiast StandardMaterial3D.new() wszystkie skrypty wołają Styl.bryla(kolor).
##
## Jak działa kontur: to klasyczny "inverted hull" — do materiału podpinamy
## drugi przebieg (next_pass), który rysuje tę samą bryłę lekko rozdmuchaną
## (grow), od środka (CULL_FRONT) i na czarno. Efekt: obwódka jak w kreskówce.

# --- Ustawienia stylu (kręć nimi, żeby zmienić charakter grafiki) ---
const KONTUR_KOLOR := Color(0.05, 0.04, 0.07)
# Kontur "puchnie" o stałą wartość w metrach, więc musi być cienki: przy
# 0.05 głowa postaci (r=0.25) tonie w czerni, a płaskie pasy na jezdni
# znikają całkowicie. Te wartości są dobrane tak, żeby kreska była widoczna,
# ale nie zjadała detali.
const KONTUR_POSTAC := 0.022      # obwódka postaci i fantów
const KONTUR_OBIEKT := 0.02       # sprzęty, pojazdy, mała architektura
const KONTUR_BUDYNEK := 0.07      # duże bryły znoszą grubszą kreskę
const KONTUR_MIN_GRUBOSC := 0.1   # cieńszej bryły konturem już nie obrysujemy
# UWAGA: nasycenie podbija też post-process sceny (env.adjustment_saturation).
# Gdy oba były ustawione na 1.3, mnożyły się i trawa robiła się neonowa.
# Tutaj zostaje delikatna korekta, "sok" dokłada post-process.
const NASYCENIE := 1.07
const PODBICIE_JASNOSCI := 1.0    # jasność zostawiamy palecie

## Materiały bez emisji są współdzielone — dzięki temu setki sztachet i
## butelek używają garstki materiałów zamiast setek osobnych.
static var _cache: Dictionary = {}

## Podstawowa bryła. "kontur" to grubość obwódki (0 = bez konturu).
## "emisja" włącza świecenie (neony, lampy, złote fanty).
## "unikalny" wymuś, gdy zamierzasz zmieniać materiał w trakcie gry.
static func bryla(kolor: Color, kontur := 0.0, emisja := false, unikalny := false) -> StandardMaterial3D:
	var podkrecony := podkrec(kolor)
	var klucz := "%s|%.3f|%s" % [podkrecony.to_html(), kontur, emisja]
	if not unikalny and not emisja and _cache.has(klucz):
		return _cache[klucz]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = podkrecony
	# UWAGA: kusi, żeby dać DIFFUSE_TOON — ale w tym rendererze próg jest tak
	# ostry, że oświetlone ściany wychodzą jednolicie białe i bryły tracą
	# objętość. Kreskówkowość robią tu kontury i nasycenie, a cieniowanie
	# zostaje miękkie, żeby sześciany nadal wyglądały jak sześciany.
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED   # zero plastiku
	mat.roughness = 1.0
	if emisja:
		mat.emission_enabled = true
		mat.emission = podkrecony
		mat.emission_energy_multiplier = 1.1
	if kontur > 0.0:
		mat.next_pass = _kontur(kontur)
	if not unikalny and not emisja:
		_cache[klucz] = mat
	return mat

## Materiał konturu (drugi przebieg rysowania). Też cache'owany.
static func _kontur(grubosc: float) -> StandardMaterial3D:
	var klucz := "kontur|%.3f" % grubosc
	if _cache.has(klucz):
		return _cache[klucz]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = KONTUR_KOLOR
	mat.cull_mode = BaseMaterial3D.CULL_FRONT   # rysujemy tylny bok bryły
	mat.grow = true
	mat.grow_amount = grubosc
	# Kontur nie może zasłaniać samego obiektu ani rzucać cienia
	mat.shadow_to_opacity = false
	mat.disable_receive_shadows = true
	_cache[klucz] = mat
	return mat

## Podkręcenie koloru: więcej nasycenia i odrobina jasności.
## Paleta zostaje spokojna, a scena i tak wychodzi soczysta.
static func podkrec(kolor: Color) -> Color:
	var wynik := Color.from_hsv(
		kolor.h,
		clampf(kolor.s * NASYCENIE, 0.0, 1.0),
		clampf(kolor.v * PODBICIE_JASNOSCI, 0.0, 1.0),
	)
	wynik.a = kolor.a
	return wynik

## Skrót dla postaci i fantów — gruba obwódka, mają się wyróżniać z tła.
static func postac(kolor: Color) -> StandardMaterial3D:
	return bryla(kolor, KONTUR_POSTAC)

## Skrót dla sprzętów, pojazdów i małej architektury.
static func obiekt(kolor: Color) -> StandardMaterial3D:
	return bryla(kolor, KONTUR_OBIEKT)

## Skrót dla dużych brył (bloki, sklep, garaże).
static func budynek(kolor: Color) -> StandardMaterial3D:
	return bryla(kolor, KONTUR_BUDYNEK)

## Skrót dla terenu i dróg — bez konturu, inaczej każda płyta dostaje ramkę.
static func teren(kolor: Color) -> StandardMaterial3D:
	return bryla(kolor)

## Metal: blacha garażu, latarnia, felga. Jedyne miejsce, gdzie wpuszczamy
## odblask — reszta gry jest matowa. Bez tego blaszaki i słupy wyglądają
## jak wycięte z kartonu, bo płaski kolor nie reaguje na obrót bryły.
static func metal(kolor: Color, kontur := KONTUR_OBIEKT) -> StandardMaterial3D:
	var klucz := "metal|%s|%.3f" % [kolor.to_html(), kontur]
	if _cache.has(klucz):
		return _cache[klucz]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = podkrec(kolor)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic = 0.55
	mat.metallic_specular = 0.4
	mat.roughness = 0.45     # niżej robi się chrom, wyżej wraca karton
	if kontur > 0.0:
		mat.next_pass = _kontur(kontur)
	_cache[klucz] = mat
	return mat

## Losowa odchyłka koloru dla powtarzalnych obiektów. Pięć identycznych
## garaży czyta się jak kopiuj-wklej; pięć garaży w pięciu odcieniach tego
## samego koloru czyta się jak rząd garaży.
static func wariant(kolor: Color, sila := 0.07) -> Color:
	var wynik := Color.from_hsv(
		fposmod(kolor.h + randf_range(-sila, sila) * 0.35, 1.0),
		clampf(kolor.s + randf_range(-sila, sila), 0.0, 1.0),
		clampf(kolor.v + randf_range(-sila, sila) * 1.4, 0.05, 1.0),
	)
	wynik.a = kolor.a
	return wynik

## Materiał terenu z PROCEDURALNYM SZUMEM (trawa, asfalt, chodnik, beton).
## To jest największa różnica między "makietą z papieru" a widokiem osiedla:
## jednolita zielona płyta 120x120 zdradza, że to jedno wielkie pudło. Plamy
## jaśniejszej i ciemniejszej zieleni od razu robią z tego teren.
##
## Tekstura jest GENEROWANA w kodzie (FastNoiseLite) — projekt nadal nie
## zawiera ani jednego pliku graficznego.
## "gestosc" to liczba kafli NA METR — nie na obiekt. To ważne: trawnik ma
## 120 m boku, a chodnik 4 m, więc gdyby teksturę rozciągać na całą bryłę,
## plamy na chodniku byłyby 30x większe niż na trawie. Dlatego używamy
## triplanar: mapowanie liczy się z pozycji w przestrzeni, a nie z UV siatki,
## dzięki czemu kafelek ma wszędzie ten sam rozmiar w metrach.
static func teren_szum(kolor: Color, gestosc := 0.16, sila := 0.1) -> StandardMaterial3D:
	var klucz := "szum|%s|%.3f|%.3f" % [kolor.to_html(), gestosc, sila]
	if _cache.has(klucz):
		return _cache[klucz]
	var mat := StandardMaterial3D.new()
	# Kolor niesie tekstura, więc albedo zostaje białe — inaczej mnożyłoby
	# się z rampą i teren robiłby się dwa razy ciemniejszy.
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = _tekstura_szumu(podkrec(kolor), sila)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(gestosc, gestosc, gestosc)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[klucz] = mat
	return mat

## Bezszwowa tekstura szumu w dwóch odcieniach zadanego koloru.
static func _tekstura_szumu(kolor: Color, sila: float) -> NoiseTexture2D:
	var szum := FastNoiseLite.new()
	szum.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Wysoka częstotliwość + kilka oktaw = DROBNE ZIARNO, nie wielkie kleksy.
	# Pierwsze podejście miało 0.012 i teren wyglądał jak rozmazane błoto:
	# plamy były tak duże, że po rozciągnięciu na metry robiły się miękkimi
	# gradientami. Faktura ma być widoczna dopiero z bliska, a z daleka ma
	# tylko rozbijać jednolity kolor.
	szum.frequency = 0.045
	szum.fractal_octaves = 4
	szum.fractal_gain = 0.45
	szum.seed = 1337
	var rampa := Gradient.new()
	rampa.set_color(0, kolor.darkened(sila))
	rampa.set_color(1, kolor.lightened(sila * 0.8))
	var tekstura := NoiseTexture2D.new()
	tekstura.noise = szum
	tekstura.seamless = true       # bez tego widać szwy między kaflami
	tekstura.width = 512
	tekstura.height = 512
	tekstura.color_ramp = rampa
	return tekstura

## Dobiera grubość konturu do wymiarów bryły. Kluczowa zasada: jeśli
## najcieńszy wymiar jest mniejszy niż podwójna grubość kreski, obwódka
## pochłonęłaby obiekt — wtedy rezygnujemy z niej całkowicie.
static func kontur_dla(rozmiar: Vector3) -> float:
	var najcienszy := minf(rozmiar.x, minf(rozmiar.y, rozmiar.z))
	if najcienszy < KONTUR_MIN_GRUBOSC:
		return 0.0
	if rozmiar.length() > 14.0:
		return KONTUR_BUDYNEK
	return KONTUR_OBIEKT

# =============================================================================
#  NAPISY 3D
# =============================================================================
# Są DWA rodzaje napisów w świecie i mylenie ich to gotowy błąd graficzny:
#
#  1. SZYLD — napis fizycznie namalowany na czymś (logo nad sklepem, "SKOK!"
#     na desce rampy). Ma być zasłaniany przez to, co stoi przed nim, bo
#     inaczej przenika przez budynki.
#
#  2. PLAKIETKA — etykieta UNOSZĄCA SIĘ nad obiektem (imię NPC, kurs dnia).
#     Musi być czytelna z każdej strony. Tu wcześniej był błąd: plakietki
#     robiono jak szyldy, więc obracający się billboard wjeżdżał rogami
#     w ścianę za sobą i połowa liter znikała. Widać to było najlepiej nad
#     Zdziśkiem — tekst dało się przeczytać tylko stojąc dokładnie na wprost.
#     Lekarstwo: no_depth_test (rysuj zawsze na wierzchu) + obwódka, żeby
#     jasne litery nie ginęły na jasnym tle.

## Napis namalowany na obiekcie — normalnie zasłaniany przez geometrię.
static func szyld(tekst: String, rozmiar: int, kolor: Color) -> Label3D:
	var napis := Label3D.new()
	napis.text = tekst
	napis.font_size = rozmiar
	napis.pixel_size = 0.004
	napis.modulate = kolor
	# Cienka ciemna obwódka — bez niej jasny napis na jasnej ścianie znika
	napis.outline_size = maxi(4, rozmiar / 12)
	napis.outline_modulate = Color(0.06, 0.05, 0.08, 0.9)
	return napis

## Etykieta unosząca się nad obiektem — zawsze zwrócona do kamery
## i zawsze czytelna, nawet gdy za nią stoi ściana.
static func plakietka(tekst: String, rozmiar: int, kolor: Color) -> Label3D:
	var napis := szyld(tekst, rozmiar, kolor)
	napis.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	napis.no_depth_test = true          # klucz: nie daj się przyciąć ścianie
	napis.fixed_size = false
	napis.render_priority = 2           # rysowane po zwykłej geometrii
	napis.outline_render_priority = 1
	napis.outline_size = maxi(6, rozmiar / 8)   # grubsza, bo tło bywa dowolne
	return napis
