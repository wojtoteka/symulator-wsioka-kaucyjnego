extends Node3D
## ŚWIAT - buduje całe osiedle proceduralnie z prostych brył:
## trawnik, chodniki, bloki z oknami, Biedronkę z butelkomatem,
## śmietniki, ławki, trzepak, sąsiadkę i rozrzucone butelki.
## Układ mapy: gracz startuje na południu (z=22), Biedronka na północy (z=-34).

const Kolekcjonerski := preload("res://scripts/collectible.gd")
const Smietnik := preload("res://scripts/trash_bin.gd")
const Butelkomat := preload("res://scripts/butelkomat.gd")
const Sasiadka := preload("res://scripts/npc_sasiadka.gd")
const Pies := preload("res://scripts/pies.gd")
const Konkurent := preload("res://scripts/konkurent.gd")
const Przechodzien := preload("res://scripts/przechodzien.gd")
const Wozek := preload("res://scripts/wozek.gd")
const Trzepak := preload("res://scripts/trzepak.gd")
const Drzwi := preload("res://scripts/drzwi.gd")
const Lodowka := preload("res://scripts/lodowka.gd")
const Kasjerka := preload("res://scripts/kasjerka.gd")
const Golebie := preload("res://scripts/golebie.gd")
const Straznik := preload("res://scripts/straznik.gd")
const Kiosk := preload("res://scripts/kiosk.gd")
const Lawka := preload("res://scripts/lawka.gd")
const SkupZlomu := preload("res://scripts/skup_zlomu.gd")
const Tablica := preload("res://scripts/tablica.gd")
const Rampa := preload("res://scripts/rampa.gd")
const Auto := preload("res://scripts/auto.gd")
const Skuter := preload("res://scripts/skuter.gd")
const Automat := preload("res://scripts/automat.gd")
const HUD := preload("res://ui/hud.gd")

# Wnętrze Biedronki jest zbudowane POD ZIEMIĄ (niewidoczne z mapy) -
# drzwi teleportują do środka i z powrotem
const WNETRZE := Vector3(60, -50, -60)            # środek podziemnego sklepu
const WEJSCIE_SKLEPU := WNETRZE + Vector3(0, 0.1, 3.2)   # lądowanie w środku
const WYJSCIE_SKLEPU := Vector3(0, 0.1, -25.5)    # lądowanie na osiedlu

const ILE_BUTELEK_NA_START := Balans.ILE_BUTELEK_NA_START
const ILE_KAMIENI := Balans.ILE_KAMIENI

# =============================================================================
#  PLAN OSIEDLA - jedno źródło prawdy
# =============================================================================
# Prostokąty [x_min, x_max, z_min, z_max]. Powstaje z nich asfalt i tor aut,
# a przede wszystkim: sprawdzenie, czy dane miejsce jest wolne.
#
# Dlaczego to musi być DANE, a nie liczby rozsypane po kodzie: gdy pozycje
# drzew, śmietników i jezdni żyją osobno, prędzej czy później drzewo wyrasta
# na środku ulicy, a kontener ląduje w ścianie bloku. Tak właśnie było -
# pięć drzew stało na obwodnicy, jedno w małym bloku, dwa kontenery na
# jezdni, a sama obwodnica przechodziła przez Biedronkę (auta dosłownie
# wyjeżdżały ze sklepu). Teraz pilnuje tego test [9] w autotest.gd.

const JEZDNIE: Array = [
	[-33.0, 33.0, -49.0, -43.0],   # północ - ZA Biedronką, nie przez nią
	[-33.0, 33.0, 35.0, 41.0],     # południe
	[-33.0, -27.0, -49.0, 41.0],   # zachód
	[27.0, 33.0, -49.0, 41.0],     # wschód
]

# Obrysy budynków POWIĘKSZONE o to, co z nich wystaje (balkony sięgają
# 1,1 m poza ścianę) - inaczej "wolne" miejsce okazuje się być pod balkonem.
const BUDYNKI: Array = [
	[-11.0, 11.0, -40.0, -28.0],     # Biedronka
	[-24.0, -14.8, -6.0, 14.0],      # blok lewy (balkony od wschodu)
	[14.8, 24.0, -6.0, 14.0],        # blok prawy (balkony od zachodu)
	[-21.0, -11.0, 20.0, 28.0],      # blok mały na południu
	[44.8, 51.5, -17.5, 17.5],       # garaże
	[-2.6, 2.6, 50.5, 56.5],         # skup złomu u Zdziśka (z wagą z przodu)
]

# Ogródki działkowe. Też muszą być DANYMI, bo płotek to obiekt jak każdy inny:
# przy poprzednim rozstawieniu (co 13 m od x=-33, środek z=46) wszystkie cztery
# wchodziły metrem na jezdnię południową, a skrajne dodatkowo pięcioma metrami
# na jezdnie boczne. Teraz mieszczą się w całości między obwodnicą a płotem,
# a test [9] pilnuje, żeby żadna nie dotknęła asfaltu ani budy Zdziśka.
const DZIALKI_X: Array = [-21.5, -9.5, 9.5, 21.5]
const DZIALKA_Z := 47.5
const DZIALKA_SZEROKOSC := 10.0
const DZIALKA_GLEBOKOSC := 12.0

## Prostokąt jednej działki [x_min, x_max, z_min, z_max].
static func obrys_dzialki(srodek_x: float) -> Array:
	return [
		srodek_x - DZIALKA_SZEROKOSC / 2.0, srodek_x + DZIALKA_SZEROKOSC / 2.0,
		DZIALKA_Z - DZIALKA_GLEBOKOSC / 2.0, DZIALKA_Z + DZIALKA_GLEBOKOSC / 2.0,
	]

## Czy w danym punkcie stoi jezdnia albo budynek - czyli miejsce, w którym
## NIC nie powinno stać. "margines" poszerza strefę: drzewo o koronie metrowej
## nie może rosnąć dokładnie na krawędzi asfaltu, bo i tak będzie nad nim wisieć.
##
## Działki celowo NIE liczą się jako zajęte: w środku ogródka stoi altanka
## i rośnie drzewko owocowe i tak ma być. Do rozrzutu fantów służy osobne
## sprawdzenie niżej, bo tam ogrodzony teren wypada omijać.
static func czy_zajete(x: float, z: float, margines := 0.0) -> bool:
	return _w_strefach(JEZDNIE + BUDYNKI, x, z, margines)

## Jak wyżej, ale dolicza ogrodzone działki - używane przy losowaniu miejsc
## dla butelek i złomu, żeby łup nie lądował za cudzym płotem.
static func czy_zajete_lub_dzialka(x: float, z: float, margines := 0.0) -> bool:
	if czy_zajete(x, z, margines):
		return true
	for srodek_x in DZIALKI_X:
		if _w_strefach([obrys_dzialki(srodek_x)], x, z, margines):
			return true
	return false

static func _w_strefach(strefy: Array, x: float, z: float, margines: float) -> bool:
	for strefa in strefy:
		if x >= strefa[0] - margines and x <= strefa[1] + margines \
				and z >= strefa[2] - margines and z <= strefa[3] + margines:
			return true
	return false

var _neon_napis: Label3D           # szyld "BIEDRONKA" - miga jak zepsuty neon

# Bufory pod MultiMesh: drobiazgi z działek zbierane przed złożeniem w jeden
# węzeł. Dzięki temu setki sztachet kosztują tyle, co jeden obiekt.
var _sztachety: Array[Transform3D] = []
var _kolory_sztachet: Array[Color] = []
var _warzywa: Array[Transform3D] = []
var _kolory_warzyw: Array[Color] = []

func _ready() -> void:
	_swiatlo_i_niebo()
	_teren()
	_biedronka()
	_bloki()
	_mala_architektura()
	_zielen()
	_plot()
	_chmury()
	_detale_drogi()
	_smietniki()
	_kamienie()
	_garaze()          # blaszaki, rampy i skuter - plac zabaw dla kaskaderów
	_dzialki()         # ogródki działkowe za osiedlem + SKUP ZŁOMU
	_tablica_ogloszen()
	_npce()
	_ruch_uliczny()    # auta krążące po obwodnicy osiedla
	_rozrzuc_butelki()
	_rozrzuc_zlom()
	_niewidzialne_sciany()
	add_child(HUD.new())
	_neon_petla()

# --- Pomocnicze funkcje budowania brył ---

## Materiał świata - cały styl (toon, nasycenie, kontur) siedzi w Styl.
## Grubość konturu dobiera się sama z wielkości bryły: płaskie płyty terenu
## i jezdni zostają bez obwódki, budynki dostają grubą kreskę.
## Domyślnie BEZ konturu - bo tę funkcję wołają też płaskie detale
## (pasy na jezdni, linie parkingowe), którym obwódka zjadłaby całą bryłę.
## Kontur dokładają _pudlo i _walec, które znają wymiary obiektu.
func _material(kolor: Color, emisja := false, kontur := 0.0) -> StandardMaterial3D:
	return Styl.bryla(kolor, kontur, emisja)

## Pudełko: z kolizją (StaticBody3D) albo czysto wizualne (MeshInstance3D).
## "material" pozwala podstawić gotowy materiał (np. teren z szumem)
## zamiast płaskiego koloru.
func _pudlo(pozycja: Vector3, rozmiar: Vector3, kolor: Color, kolizja := true,
		emisja := false, material: StandardMaterial3D = null) -> Node3D:
	var mesh := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = rozmiar
	mesh.mesh = pudlo
	mesh.material_override = material if material != null \
		else _material(kolor, emisja, Styl.kontur_dla(rozmiar))
	if not kolizja:
		mesh.position = pozycja
		add_child(mesh)
		return mesh
	var cialo := StaticBody3D.new()
	cialo.position = pozycja
	cialo.add_child(mesh)
	var ksztalt_kolizji := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = rozmiar
	ksztalt_kolizji.shape = ksztalt
	cialo.add_child(ksztalt_kolizji)
	add_child(cialo)
	return cialo

## Walec (słupek latarni, filar altanki, beczka).
## Domyślnie Z KOLIZJĄ - wcześniej walce były czysto wizualne i dało się
## przejść na wylot przez latarnię czy filar, co od razu psuło wrażenie
## realnego miejsca. "kolizja = false" zostaje dla drobiazgów na dachu
## (anteny) i tam, gdzie ciało fizyczne dokłada się osobno (pnie drzew).
func _walec(pozycja: Vector3, promien: float, wysokosc: float, kolor: Color,
		emisja := false, kolizja := true, metaliczny := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = promien
	walec.bottom_radius = promien
	walec.height = wysokosc
	mesh.mesh = walec
	var kreska := Styl.kontur_dla(Vector3(promien * 2.0, wysokosc, promien * 2.0))
	mesh.material_override = Styl.metal(kolor, kreska) if metaliczny \
		else _material(kolor, emisja, kreska)
	mesh.position = pozycja
	add_child(mesh)
	if kolizja:
		var cialo := StaticBody3D.new()
		cialo.position = pozycja
		var ksztalt_kolizji := CollisionShape3D.new()
		var ksztalt := CylinderShape3D.new()
		ksztalt.radius = promien
		ksztalt.height = wysokosc
		ksztalt_kolizji.shape = ksztalt
		cialo.add_child(ksztalt_kolizji)
		add_child(cialo)
	return mesh

## Niewidzialna przeszkoda - dla obiektów, których bryła jest zbyt
## poszarpana, żeby opisać ją kształtem 1:1 (płotki ze sztachet, sterty).
func _przeszkoda(pozycja: Vector3, rozmiar: Vector3) -> StaticBody3D:
	var cialo := StaticBody3D.new()
	cialo.position = pozycja
	var ksztalt_kolizji := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = rozmiar
	ksztalt_kolizji.shape = ksztalt
	cialo.add_child(ksztalt_kolizji)
	add_child(cialo)
	return cialo

# --- Elementy świata ---

func _swiatlo_i_niebo() -> void:
	# Mocne, kontrastowe słońce - kreskówka potrzebuje wyraźnych cieni,
	# nie miękkiego rozproszonego światła jak w symulatorze architektury
	var slonce := DirectionalLight3D.new()
	slonce.rotation_degrees = Vector3(-52, -40, 0)
	slonce.light_color = Color(1.0, 0.95, 0.83)
	slonce.light_energy = 1.15
	slonce.shadow_enabled = true
	# 0.9 dawało cienie prawie czarne - czytelne, ale wyglądające jak wycięte
	# nożyczkami. Odrobinę jaśniejsze i lekko zmiękczone czytają się jak cień,
	# a nie jak naklejona plama.
	slonce.shadow_opacity = 0.82
	slonce.shadow_blur = 1.4
	slonce.directional_shadow_max_distance = 90.0
	add_child(slonce)
	var srodowisko := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	# Niebo: nasycony błękit z wyraźnym przejściem do jasnego horyzontu
	var material_nieba := ProceduralSkyMaterial.new()
	material_nieba.sky_top_color = Color(0.16, 0.45, 0.92)
	material_nieba.sky_horizon_color = Color(0.62, 0.84, 1.0)
	material_nieba.sky_curve = 0.12       # ostrzejszy gradient = bardziej "rysowane"
	material_nieba.ground_bottom_color = Color(0.24, 0.42, 0.3)
	material_nieba.ground_horizon_color = Color(0.62, 0.84, 1.0)
	# Tarcza słońca na niebie - jest źródłem cieni, więc powinno być widać,
	# skąd padają. Puste niebo to kolejny drobiazg, który czyta się jako "render".
	material_nieba.sun_angle_max = 12.0
	material_nieba.sun_curve = 0.08
	var niebo := Sky.new()
	niebo.sky_material = material_nieba
	env.sky = niebo
	# Ambient jako WŁASNY kolor, nie z nieba: światło odbite od błękitnego
	# nieba malowało wszystko na niebiesko (chodniki wychodziły siwe).
	# Ciepły, neutralny ambient trzyma kolory takimi, jakie są w palecie.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.72, 0.68)
	env.ambient_light_energy = 0.5
	# Mgła tylko jako delikatna głębia w oddali
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.85, 1.0)
	env.fog_density = 0.0022
	# Poświata - neon, latarnie i złote fanty ładnie "błyszczą"
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	# ACES zamiast FILMIC: trzyma nasycenie zamiast je spłaszczać.
	# Whitepoint > 1 chroni jasne powierzchnie przed wypaleniem do bieli.
	# Wysoki whitepoint ratuje jasne ściany przed wypaleniem do bieli
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 2.2
	# Przymknięta "przysłona" - bez tego trawa i chodniki świecą tak mocno,
	# że cała scena wygląda na prześwietloną, a kolory tracą głębię
	env.tonemap_exposure = 0.8
	# Korekcja obrazu - to ona robi najwięcej dla "komiksowego" charakteru
	env.adjustment_enabled = true
	# Zbity kontrast plus mocna saturacja dawały efekt plakatu: kolory ładne,
	# ale wszystko wyglądało jak nadruk. Skoro detal niosą teraz tekstury
	# szumu i sylwetki budynków, korekcja może zejść na drugi plan.
	env.adjustment_saturation = 1.16
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.0
	srodowisko.environment = env
	add_child(srodowisko)

func _teren() -> void:
	# Trawnik - wielka zielona płyta (jej wierzch to y=0).
	# 120x120: mieści osiedle, obwodnicę, garaże na wschodzie i działki na południu.
	#
	# To był najbardziej "plastikowy" element całej gry: 120 metrów jednego
	# koloru czyta się jak arkusz papieru, bo w naturze nie ma płaszczyzny bez
	# ani jednej plamy. Szum daje przetarcia i wydeptane placki - nadal
	# stylizowane, ale teren wygląda jak teren.
	_pudlo(Vector3(0, -0.5, 0), Vector3(120, 1, 120), Paleta.TRAWA, true, false,
		Styl.teren_szum(Paleta.TRAWA, 0.6, 0.15))
	# Główny chodnik (północ-południe, do Biedronki) - cienki, bez kolizji
	_pudlo(Vector3(0, 0.02, -1), Vector3(4, 0.04, 52), Paleta.CHODNIK, false, false,
		Styl.teren_szum(Paleta.CHODNIK, 1.1, 0.07))
	# Chodnik poprzeczny (wschód-zachód)
	_pudlo(Vector3(0, 0.02, 6), Vector3(36, 0.04, 3), Paleta.CHODNIK, false, false,
		Styl.teren_szum(Paleta.CHODNIK, 1.1, 0.07))
	# Parking/asfalt przed Biedronką
	_pudlo(Vector3(0, 0.015, -24), Vector3(26, 0.03, 8), Paleta.ASFALT, false, false,
		Styl.teren_szum(Paleta.ASFALT, 0.9, 0.1))

func _biedronka() -> void:
	# Budynek sklepu - z cokołem i gzymsem, jak bloki (patrz _blok)
	_pudlo(Vector3(0, 3.5, -34), Vector3(22, 7, 12), Paleta.BIEDRONKA_SCIANA)
	_pudlo(Vector3(0, 0.55, -34), Vector3(22.3, 1.1, 12.3),
		Paleta.BIEDRONKA_SCIANA.darkened(0.45), false)
	_pudlo(Vector3(0, 7.15, -34), Vector3(22.6, 0.5, 12.6),
		Paleta.BIEDRONKA_SCIANA.darkened(0.25), false)
	# Czerwony pas z logo nad wejściem
	_pudlo(Vector3(0, 5.8, -27.8), Vector3(14, 1.6, 0.4), Paleta.CZERWIEN, false)
	var napis := Styl.szyld("BIEDRONKA", 220, Color(1.0, 1.0, 0.85))
	napis.pixel_size = 0.005
	napis.position = Vector3(0.6, 5.8, -27.55)
	add_child(napis)
	_neon_napis = napis   # będzie migać jak zepsuty neon
	# Biedronka (owad) na szyldzie - czerwona kulka w kropki
	var zuk := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.45
	kula.height = 0.6
	zuk.mesh = kula
	zuk.material_override = _material(Color(0.9, 0.15, 0.1), false, Styl.KONTUR_OBIEKT)
	zuk.position = Vector3(-5.6, 5.8, -27.5)
	add_child(zuk)
	for przesuniecie in [Vector3(-0.15, 0.2, 0.28), Vector3(0.18, 0.05, 0.33), Vector3(-0.05, -0.15, 0.35)]:
		var kropka := MeshInstance3D.new()
		var mala := SphereMesh.new()
		mala.radius = 0.08
		mala.height = 0.16
		kropka.mesh = mala
		kropka.material_override = _material(Color.BLACK)
		kropka.position = zuk.position + przesuniecie
		add_child(kropka)
	# Drzwi wejściowe (ciemne szkło)
	_pudlo(Vector3(-2, 1.5, -27.9), Vector3(3, 3, 0.2), Color(0.15, 0.2, 0.25), false)
	_pudlo(Vector3(2, 1.5, -27.9), Vector3(3, 3, 0.2), Color(0.15, 0.2, 0.25), false)
	# Butelkomat przy wejściu
	var automat := Butelkomat.new()
	automat.position = Vector3(6.5, 0, -27.4)
	add_child(automat)
	# Automat z napojami obok butelkomatu - kaucja wychodzi i od razu wraca
	var automat_napojow := Automat.new()
	automat_napojow.position = Vector3(4.6, 0, -27.4)
	add_child(automat_napojow)
	# Wózek sklepowy do "pożyczenia"
	var wozek := Wozek.new()
	wozek.position = Vector3(9.5, 0, -25.0)
	wozek.rotation.y = 0.4
	add_child(wozek)
	# Drzwi wejściowe - teleport do wnętrza sklepu
	var wejscie := Drzwi.new()
	wejscie.position = Vector3(-2, 0, -27.6)
	wejscie.cel = WEJSCIE_SKLEPU
	wejscie.obrot_y = 0.0
	wejscie.etykieta = "E - wejdź do Biedronki"
	wejscie.komunikat = "Dzyń dzyń! Zapach świeżego pieczywa i promocji."
	add_child(wejscie)
	_wnetrze_biedronki()

## Wnętrze sklepu - podziemne pomieszczenie (teleport przez drzwi).
## Wszystkie pozycje to WNETRZE + przesunięcie, więc łatwo je przenieść.
func _wnetrze_biedronki() -> void:
	# Podłoga, ściany i sufit
	_pudlo(WNETRZE + Vector3(0, -0.5, 0), Vector3(14, 1, 10), Color(0.85, 0.82, 0.75))
	_pudlo(WNETRZE + Vector3(0, 1.9, -5.2), Vector3(14.6, 3.8, 0.4), Color(0.93, 0.92, 0.88))
	_pudlo(WNETRZE + Vector3(0, 1.9, 5.2), Vector3(14.6, 3.8, 0.4), Color(0.93, 0.92, 0.88))
	_pudlo(WNETRZE + Vector3(-7.2, 1.9, 0), Vector3(0.4, 3.8, 10.4), Color(0.93, 0.92, 0.88))
	_pudlo(WNETRZE + Vector3(7.2, 1.9, 0), Vector3(0.4, 3.8, 10.4), Color(0.93, 0.92, 0.88))
	_pudlo(WNETRZE + Vector3(0, 3.9, 0), Vector3(14.6, 0.3, 10.6), Color(0.9, 0.9, 0.88), false)
	# Świetlówki na suficie
	for x in [-3.5, 3.5]:
		_pudlo(WNETRZE + Vector3(x, 3.72, 0), Vector3(3, 0.06, 1), Color(1.0, 0.98, 0.9), false, true)
	var swiatlo := OmniLight3D.new()
	swiatlo.position = WNETRZE + Vector3(0, 3.2, 0)
	swiatlo.light_energy = 1.2
	swiatlo.omni_range = 14.0
	add_child(swiatlo)
	# Regały z "towarem" (kolorowe pudełka - promocje same się nie ułożą)
	for przesuniecie_regalu in [Vector3(-3.5, 0, 1.5), Vector3(-3.5, 0, -2), Vector3(3, 0, -2)]:
		var pozycja_regalu: Vector3 = WNETRZE + przesuniecie_regalu
		_pudlo(pozycja_regalu + Vector3(0, 0.9, 0), Vector3(3.2, 1.8, 0.7), Color(0.6, 0.45, 0.3))
		for i in 5:
			var produkt := MeshInstance3D.new()
			var pudlo_produktu := BoxMesh.new()
			pudlo_produktu.size = Vector3(0.4, 0.35, 0.35)
			produkt.mesh = pudlo_produktu
			produkt.material_override = _material([
				Color(0.9, 0.3, 0.2), Color(0.95, 0.8, 0.2), Color(0.3, 0.6, 0.9),
				Color(0.4, 0.75, 0.3), Color(0.85, 0.5, 0.8),
			].pick_random())
			produkt.position = pozycja_regalu + Vector3(-1.2 + i * 0.6, 1.98, 0)
			add_child(produkt)
	# Lodówka z piwem (gwóźdź programu)
	var lodowka := Lodowka.new()
	lodowka.position = WNETRZE + Vector3(6.4, 0, 0)
	lodowka.rotation.y = -PI / 2   # frontem do środka sklepu
	add_child(lodowka)
	# Lada i Pani Grażynka
	_pudlo(WNETRZE + Vector3(3, 0.5, 3.7), Vector3(2.2, 1.0, 0.8), Color(0.5, 0.35, 0.2))
	var kasjerka := Kasjerka.new()
	kasjerka.position = WNETRZE + Vector3(3, 0, 2.7)
	kasjerka.rotation.y = PI   # twarzą do wejścia
	add_child(kasjerka)
	# Drzwi wyjściowe - teleport z powrotem na osiedle
	var wyjscie := Drzwi.new()
	wyjscie.position = WNETRZE + Vector3(-3, 0, 4.4)
	wyjscie.cel = WYJSCIE_SKLEPU
	wyjscie.obrot_y = PI
	wyjscie.etykieta = "E - wyjdź na osiedle"
	add_child(wyjscie)
	# WIDOCZNE drzwi: framuga, dwa ciemne skrzydła i klamka na ścianie
	_pudlo(WNETRZE + Vector3(-3, 1.6, 4.94), Vector3(2.8, 3.2, 0.1), Color(0.4, 0.34, 0.28), false)
	_pudlo(WNETRZE + Vector3(-3.65, 1.5, 4.86), Vector3(1.25, 2.95, 0.1), Paleta.SZKLO_DRZWI, false)
	_pudlo(WNETRZE + Vector3(-2.35, 1.5, 4.86), Vector3(1.25, 2.95, 0.1), Paleta.SZKLO_DRZWI, false)
	_pudlo(WNETRZE + Vector3(-2.9, 1.35, 4.78), Vector3(0.22, 0.06, 0.08), Color(0.85, 0.85, 0.9), false)
	# Zielony napis WYJŚCIE (przepisy BHP to podstawa)
	var napis := Styl.szyld("WYJŚCIE", 64, Color(0.3, 1.0, 0.4))
	napis.position = WNETRZE + Vector3(-3, 3.0, 4.5)
	add_child(napis)

func _bloki() -> void:
	# Dwa bloki z wielkiej płyty po bokach osiedla
	_blok(Vector3(-20, 0, 4), true)   # okna od strony +X (do środka)
	_blok(Vector3(20, 0, 4), false)   # okna od strony -X
	# Mniejszy blok na południu - kamienica, więc bez balkonów, ale okna
	# i cokół obowiązkowe: bez nich to była największa gładka ściana na mapie
	var maly := Styl.wariant(Paleta.BLOK.lerp(Paleta.PASTELE.pick_random(), 0.45), 0.05)
	_pudlo(Vector3(-16, 4, 24), Vector3(10, 8, 8), maly)
	_pudlo(Vector3(-16, 0.6, 24), Vector3(10.3, 1.2, 8.3), maly.darkened(0.42), false)
	_pudlo(Vector3(-16, 8.15, 24), Vector3(10.5, 0.5, 8.5), maly.darkened(0.22), false)
	# Okna na dwóch ścianach widocznych z osiedla (wschodniej i północnej)
	for pietro in 3:
		for kolumna in 3:
			for wschodnia in [true, false]:
				var swieci := randf() < 0.28
				var okno := MeshInstance3D.new()
				var szyba := BoxMesh.new()
				szyba.size = Vector3(0.1, 1.2, 1.0) if wschodnia else Vector3(1.0, 1.2, 0.1)
				okno.mesh = szyba
				okno.material_override = _material(
					Paleta.OKNO_JASNE if swieci else Paleta.OKNO_CIEMNE, swieci)
				var wzdluz := -2.6 + kolumna * 2.6
				okno.position = Vector3(-10.95, 2.2 + pietro * 2.2, 24 + wzdluz) if wschodnia \
					else Vector3(-16 + wzdluz, 2.2 + pietro * 2.2, 19.95)
				add_child(okno)
	# TRANSPARENT na lewym bloku - motto osiedla, widoczne z daleka
	_pudlo(Vector3(-15.8, 6, 4), Vector3(0.15, 1.5, 15), Color(0.96, 0.96, 0.93), false)
	var motto := Styl.szyld("NIECH ŻYJE KAUCJA I BEZROBOCIE", 88, Color(0.78, 0.08, 0.08))
	motto.pixel_size = 0.0075
	motto.outline_size = 0   # czerwona farba na białym płótnie, obwódka zbędna
	motto.position = Vector3(-15.68, 6, 4)
	motto.rotation.y = PI / 2   # frontem do osiedla
	add_child(motto)

func _blok(pozycja: Vector3, okna_na_wschod: bool) -> void:
	var rozmiar := Vector3(8, 12, 20)
	# Każdy blok dostaje własny kolor elewacji - szare pudła wyglądały
	# jak makieta architektoniczna, a nie jak polskie osiedle
	var pastel: Color = Styl.wariant(Paleta.PASTELE.pick_random(), 0.05)
	var elewacja := Paleta.BLOK.lerp(pastel, 0.55)
	_pudlo(pozycja + Vector3(0, rozmiar.y / 2, 0), rozmiar, elewacja)
	# Mocniejsze pasy tego samego koloru - ślad po "termomodernizacji"
	for wysokosc in [4.0, 8.0]:
		_pudlo(pozycja + Vector3(0, wysokosc, 0), Vector3(rozmiar.x + 0.12, 0.8, rozmiar.z + 0.12), pastel, false)
	# COKÓŁ - ciemniejszy pas przy ziemi. Drobiazg, a robi ogromną różnicę:
	# bryła przestaje "stać na trawie jak wycięta" i zaczyna wyglądać, jakby
	# wyrastała z gruntu. Do tego maskuje styk ściany z terenem.
	_pudlo(pozycja + Vector3(0, 0.7, 0),
		Vector3(rozmiar.x + 0.3, 1.4, rozmiar.z + 0.3), elewacja.darkened(0.42), false)
	# GZYMS - attyka wystająca ponad elewację. Bez niej blok kończy się
	# ostrą krawędzią i wygląda jak ucięty w połowie.
	_pudlo(pozycja + Vector3(0, rozmiar.y + 0.15, 0),
		Vector3(rozmiar.x + 0.55, 0.5, rozmiar.z + 0.55), elewacja.darkened(0.22), false)
	# Antena na dachu z kulką (bez kolizji - i tak nie do dosięgnięcia)
	_walec(pozycja + Vector3(1.5, rozmiar.y + 0.9, 3), 0.04, 1.8, Color(0.2, 0.2, 0.2), false, false)
	var kulka := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.12
	kula.height = 0.24
	kulka.mesh = kula
	kulka.material_override = _material(Color(0.8, 0.2, 0.2))
	kulka.position = pozycja + Vector3(1.5, rozmiar.y + 1.85, 3)
	add_child(kulka)
	# Siatka okien na ścianie od strony osiedla; część losowo "świeci"
	var kierunek_x := 1.0 if okna_na_wschod else -1.0
	var sciana_x := pozycja.x + kierunek_x * (rozmiar.x / 2 + 0.05)
	# Kolor wypełnienia balustrad - jeden na cały blok, jak w prawdziwym
	# bloku, gdzie spółdzielnia kupiła jedną partię blachy
	var kolor_balustrad: Color = Paleta.PASTELE.pick_random()
	for pietro in 4:
		for kolumna in 6:
			var swieci := randf() < 0.3
			var kolor := Paleta.OKNO_JASNE if swieci else Paleta.OKNO_CIEMNE
			var okno := MeshInstance3D.new()
			var pudlo := BoxMesh.new()
			pudlo.size = Vector3(0.1, 1.3, 1.1)
			okno.mesh = pudlo
			okno.material_override = _material(kolor, swieci)
			var wysokosc_pietra := 2.0 + pietro * 2.6
			okno.position = Vector3(sciana_x, wysokosc_pietra, pozycja.z - 8.0 + kolumna * 3.2)
			add_child(okno)
			# Balkony na dwóch kolumnach każdego piętra
			if kolumna == 1 or kolumna == 4:
				_balkon(sciana_x, kierunek_x, wysokosc_pietra, okno.position.z, kolor_balustrad)

## Balkon: płyta wysunięta ze ściany plus balustrada. To on nadaje blokowi
## sylwetkę - bez balkonów każdy blok jest po prostu prostopadłościanem
## i żadna paleta tego nie ukryje.
func _balkon(sciana_x: float, kierunek_x: float, wysokosc: float, z: float, kolor: Color) -> void:
	var wysiegnik := 1.1        # jak daleko balkon wychodzi ze ściany
	var szerokosc := 2.6
	var srodek_x := sciana_x + kierunek_x * (wysiegnik / 2.0)
	var czolo_x := sciana_x + kierunek_x * wysiegnik
	var poziom := wysokosc - 0.78   # płyta tuż pod parapetem okna
	# Płyta balkonowa - surowy beton
	_pudlo(Vector3(srodek_x, poziom, z), Vector3(wysiegnik, 0.14, szerokosc),
		Color(0.62, 0.6, 0.56), false)
	# Balustrada czołowa (kolorowa blacha) i dwie ścianki boczne
	_pudlo(Vector3(czolo_x, poziom + 0.5, z), Vector3(0.09, 0.9, szerokosc), kolor, false)
	for bok in [-1.0, 1.0]:
		_pudlo(Vector3(srodek_x, poziom + 0.5, z + bok * (szerokosc / 2.0 - 0.04)),
			Vector3(wysiegnik, 0.9, 0.08), kolor.darkened(0.12), false)

func _mala_architektura() -> void:
	# Ławki przy chodniku
	_lawka(Vector3(3.2, 0, 12), PI)
	_lawka(Vector3(-3.2, 0, 0), 0.0)
	_lawka(Vector3(3.2, 0, -12), PI)
	# Trzepak - klasyk osiedla, a od teraz też SIŁOWNIA (E = podciąganie)
	var trzepak := Trzepak.new()
	trzepak.position = Vector3(-10, 0, 14)
	add_child(trzepak)
	# Latarnie wzdłuż chodnika - słup jest metalowy i ma kolizję
	for z in [16, 2, -12]:
		_walec(Vector3(2.6, 2.0, z), 0.09, 4.0, Color(0.34, 0.34, 0.37), false, true, true)
		var klosz := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = 0.22
		kula.height = 0.44
		klosz.mesh = kula
		klosz.material_override = _material(Color(1.0, 0.95, 0.75), true)
		klosz.position = Vector3(2.6, 4.1, z)
		add_child(klosz)

## GARAŻE - rząd blaszaków na wschód od osiedla. Asfaltowy placyk,
## rampy do skakania i skuter czekający na właściciela (albo i nie).
func _garaze() -> void:
	# Placyk z popękanego betonu - jaśniejszy od jezdni, żeby garaże czytelnie
	# odcinały się od obwodnicy. Wysokości celowo różne (0.020 / 0.018 / 0.012
	# na obwodnicy), inaczej nachodzące płyty migotałyby z-fightingiem.
	# (ciemniej niż intuicja podpowiada - przy ambiencie 0.85 z jasnego nieba
	# każdy szary powyżej 0.4 wychodzi na ekranie prawie biały)
	# Placyk zaczyna się dopiero za obwodnicą (jezdnia zajmuje x 27..33) -
	# wcześniej beton wchodził pod asfalt i plac zlewał się z ulicą.
	var beton := Styl.teren_szum(Color(0.3, 0.29, 0.28), 0.85, 0.11)
	_pudlo(Vector3(43, 0.020, 0), Vector3(18, 0.03, 34), Color(0.3, 0.29, 0.28), false, false, beton)
	# Dojazd łączący placyk z obwodnicą
	_pudlo(Vector3(35, 0.018, 0), Vector3(10, 0.03, 6), Color(0.27, 0.27, 0.27), false, false, beton)
	# Rząd blaszaków: korpus + spadzisty dach + brama w innym kolorze
	var kolory_bram: Array[Color] = [
		Color(0.35, 0.45, 0.55), Color(0.55, 0.35, 0.25), Color(0.4, 0.5, 0.35),
		Color(0.5, 0.45, 0.3), Color(0.45, 0.3, 0.35),
	]
	for i in 5:
		var z := -14.0 + i * 7.0
		# Każdy blaszak w swoim odcieniu i z lekko innym przechyłem dachu -
		# pięć identycznych kopii obok siebie od razu zdradza generator
		_pudlo(Vector3(48, 1.4, z), Vector3(6, 2.8, 5.6), Styl.wariant(Color(0.52, 0.5, 0.46)))
		var dach := _pudlo(Vector3(48, 2.92, z), Vector3(6.4, 0.14, 6.0),
			Styl.wariant(Color(0.42, 0.26, 0.16), 0.09), false)
		dach.rotation.z = randf_range(0.05, 0.09)
		# Brama garażowa z uchwytem - blacha, więc z połyskiem (patrz Styl.metal)
		_pudlo(Vector3(44.95, 1.15, z), Vector3(0.12, 2.3, 4.4), kolory_bram[i], false, false,
			Styl.metal(kolory_bram[i], 0.0))
		_pudlo(Vector3(44.85, 1.0, z), Vector3(0.1, 0.12, 0.5), Color(0.2, 0.2, 0.22), false)
	# Rampy - trzy różne kalibry, od "podskok" do "orbita".
	# Stromiej niż 25° robi się ściana, płasko poniżej 15° nie wybija.
	# WSZYSTKIE stoją na placu, nie na jezdni: rampa postawiona na obwodnicy
	# (a taka tu wcześniej stała, na x=30) nie miała sensu - auta krążące
	# po ścieżce przejeżdżały przez nią na wylot, bo jadą po torze, nie po
	# fizyce. Plac garażowy to jedyne miejsce, gdzie taka konstrukcja się klei.
	_rampa(Vector3(38, 0, -8), 0.0, 2.8, 0.9)
	_rampa(Vector3(38, 0, 8), PI, 3.4, 1.4)
	_rampa(Vector3(42, 0, 12), -PI / 2.0, 3.0, 1.15)   # wybija w głąb placu
	# Skuter przy pierwszym garażu
	var skuter := Skuter.new()
	skuter.position = Vector3(41, 0, -16)
	skuter.rotation.y = -PI / 2.0
	add_child(skuter)
	# Sterta opon - obowiązkowy element każdego placu garażowego
	for i in 5:
		var opona := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.18
		torus.outer_radius = 0.42
		torus.rings = 8
		opona.mesh = torus
		opona.material_override = _material(Color(0.11, 0.11, 0.12), false, Styl.KONTUR_OBIEKT)
		opona.rotation.x = PI / 2
		opona.rotation.z = randf() * TAU   # inaczej stos wygląda jak jedna bryła
		opona.position = Vector3(36.5 + randf_range(-0.2, 0.2), 0.12 + i * 0.2, 15 + randf_range(-0.2, 0.2))
		add_child(opona)
	# Jedna kolizja na cały stos - pięć torusów nie ma sensu opisywać osobno
	_przeszkoda(Vector3(36.5, 0.5, 15), Vector3(0.95, 1.0, 0.95))
	# Złom leżący pod garażami - naturalne łowisko
	for i in 6:
		var zlom := Kolekcjonerski.new()
		zlom.typ = Kolekcjonerski.losowy_typ_zlomu()
		zlom.position = _losuj_wolne([36.0, 43.5, -16.0, 16.0])
		add_child(zlom)

## Tworzy rampę o zadanym obrocie i wymiarach (patrz scripts/rampa.gd).
func _rampa(pozycja: Vector3, obrot: float, dlugosc: float, wysokosc: float) -> void:
	var rampa := Rampa.new()
	rampa.dlugosc = dlugosc
	rampa.wysokosc = wysokosc
	rampa.position = pozycja
	rampa.rotation.y = obrot
	add_child(rampa)

## OGRÓDKI DZIAŁKOWE - za obwodnicą na południu. Altanki, grządki,
## drzewka owocowe, a na końcu SKUP ZŁOMU u Zdziśka.
func _dzialki() -> void:
	# Alejka dojazdowa - ubita ziemia z żużlem
	_pudlo(Vector3(0, 0.015, 46), Vector3(3, 0.03, 24), Color(0.6, 0.55, 0.45), false, false,
		Styl.teren_szum(Color(0.6, 0.55, 0.45), 1.0, 0.12))
	# Działki po dwie z każdej strony alejki - pozycje z DZIALKI_X, żeby
	# obrys znany reszcie gry zgadzał się z tym, co faktycznie stoi na mapie
	for x in DZIALKI_X:
		_dzialka(Vector3(x, 0, DZIALKA_Z))
	# Sztachety i warzywa ze WSZYSTKICH działek jako dwa MultiMeshe.
	# Same płotki to ~260 elementów - jako osobne węzły zabiłyby wydajność.
	var sztacheta := BoxMesh.new()
	sztacheta.size = Vector3(0.1, 1.0, 0.1)
	_multi(sztacheta, _sztachety, _kolory_sztachet, 78.0)
	var warzywo := SphereMesh.new()
	warzywo.radius = 0.16
	warzywo.height = 0.3
	warzywo.radial_segments = 6      # drobiazg z bliska, nie trzeba kuli idealnej
	warzywo.rings = 3
	_multi(warzywo, _warzywa, _kolory_warzyw, 46.0)
	# Skup złomu na końcu alejki - okienkiem i wagą do gracza, który
	# nadchodzi od strony osiedla (czyli od mniejszych Z)
	var skup := SkupZlomu.new()
	skup.position = Vector3(0, 0, 54)
	skup.rotation.y = PI
	add_child(skup)
	# Kontenery przy działkach - grzebanie w nich to podstawa biznesu.
	# Stoją PRZED jezdnią (z=35..41), nie na niej; wcześniej były na asfalcie.
	for pozycja in [Vector3(-8, 0, 32), Vector3(8, 0, 32)]:
		var kontener := Smietnik.new()
		kontener.rodzaj = Smietnik.Rodzaj.KONTENER
		kontener.position = pozycja
		kontener.rotation.y = randf_range(-0.3, 0.3)
		add_child(kontener)

## Pojedyncza działka: płotek, altanka, grządki i drzewko.
## Sztachety i warzywa NIE są osobnymi węzłami - trafiają do wspólnych
## tablic, z których _dzialki() składa dwa MultiMeshe (patrz niżej).
func _dzialka(srodek: Vector3) -> void:
	var szerokosc := DZIALKA_SZEROKOSC
	var glebokosc := DZIALKA_GLEBOKOSC
	# Płotek ze sztachet dookoła (co 1 m, każda lekko krzywa - bo osiedle).
	# Od strony alejki zostaje przerwa na FURTKĘ: ogrodzona działka bez wejścia
	# to zagadka, a nie ogródek.
	var kolor_plotu := Color(0.55, 0.42, 0.28).lerp(Color(0.4, 0.5, 0.35), randf())
	var bok_furtki := 2 if srodek.x < 0.0 else 3   # bok zwrócony do alejki
	const POLOWA_FURTKI := 1.4
	for bok in 4:
		var wzdluz_x := bok < 2
		var znak := 1.0 if bok % 2 == 0 else -1.0
		var dlugosc_boku := szerokosc if wzdluz_x else glebokosc
		for i in int(dlugosc_boku):
			var przesuniecie := -dlugosc_boku / 2.0 + i + 0.5
			if bok == bok_furtki and absf(przesuniecie) < POLOWA_FURTKI:
				continue   # tędy się wchodzi
			var pozycja := srodek + (
				Vector3(przesuniecie, 0.5, znak * glebokosc / 2.0) if wzdluz_x
				else Vector3(znak * szerokosc / 2.0, 0.5, przesuniecie)
			)
			var obrot := Basis(Vector3.FORWARD, randf_range(-0.06, 0.06))
			_sztachety.append(Transform3D(obrot, pozycja))
			_kolory_sztachet.append(Styl.wariant(kolor_plotu, 0.05))
		# Kolizja płotka. Sztachety są rysowane jako MultiMesh (jeden węzeł na
		# wszystkie działki), a MultiMesh nie ma żadnej fizyki - bez tego
		# ogrodzenie było czystą dekoracją i wchodziło się przez nie na wylot.
		_kolizja_plotka(srodek, szerokosc, glebokosc, wzdluz_x, znak,
			POLOWA_FURTKI if bok == bok_furtki else 0.0)
	# Altanka: podłoga (można na nią wejść), cztery słupki, dach
	var alt := srodek + Vector3(0, 0, -3.0)
	_pudlo(alt + Vector3(0, 0.1, 0), Vector3(3.4, 0.2, 3.0), Paleta.DREWNO)
	for x in [-1.5, 1.5]:
		for z in [-1.3, 1.3]:
			_walec(alt + Vector3(x, 1.1, z), 0.08, 2.0, Paleta.DREWNO_CIEMNE)
	var dach_altany := _pudlo(alt + Vector3(0, 2.25, 0), Vector3(4.0, 0.16, 3.6), Color(0.5, 0.26, 0.2), false)
	dach_altany.rotation.x = 0.1
	# Grządki - rzędy ciemnej ziemi z "warzywami" (warzywa idą do MultiMesha)
	for rzad in 3:
		var z := srodek.z + 1.5 + rzad * 1.6
		_pudlo(Vector3(srodek.x, 0.06, z), Vector3(7.0, 0.12, 0.9), Color(0.32, 0.22, 0.14), false)
		for i in 7:
			_warzywa.append(Transform3D(Basis.IDENTITY, Vector3(srodek.x - 3.0 + i, 0.2, z)))
			_kolory_warzyw.append(Color(0.3, 0.55, 0.22).lerp(Color(0.7, 0.3, 0.2), randf() * 0.5))
	# Drzewko owocowe w rogu
	_drzewo(srodek + Vector3(szerokosc / 2.0 - 1.5, 0, glebokosc / 2.0 - 1.5))
	# Beczka na deszczówkę
	_walec(srodek + Vector3(-szerokosc / 2.0 + 1.2, 0.45, -glebokosc / 2.0 + 1.2), 0.45, 0.9, Color(0.25, 0.35, 0.5))

## Losuje punkt w zadanej strefie [x_min, x_max, z_min, z_max], omijając
## jezdnie i budynki. Ręcznie dobierane strefy zawsze w końcu zahaczą o coś,
## co ktoś później przesunie - tu odrzucamy trafienia i losujemy ponownie.
## Po wyczerpaniu prób oddajemy ostatni punkt: lepiej jedna butelka w złym
## miejscu niż zawieszona gra.
func _losuj_wolne(strefa: Array, proby := 24) -> Vector3:
	var punkt := Vector3.ZERO
	for i in proby:
		punkt = Vector3(randf_range(strefa[0], strefa[1]), 0, randf_range(strefa[2], strefa[3]))
		if not czy_zajete_lub_dzialka(punkt.x, punkt.z, 0.6):
			return punkt
	return punkt

## Bariera wzdłuż jednego boku płotka działki. Gdy "polowa_furtki" jest
## większa od zera, bok dzieli się na dwa segmenty z przerwą pośrodku.
func _kolizja_plotka(srodek: Vector3, szerokosc: float, glebokosc: float,
		wzdluz_x: bool, znak: float, polowa_furtki: float) -> void:
	var dlugosc_boku := szerokosc if wzdluz_x else glebokosc
	# Środek boku: przy ścianie północnej/południowej albo wschodniej/zachodniej
	var srodek_boku := srodek + (
		Vector3(0, 0.5, znak * glebokosc / 2.0) if wzdluz_x
		else Vector3(znak * szerokosc / 2.0, 0.5, 0)
	)
	if polowa_furtki <= 0.0:
		_przeszkoda(srodek_boku,
			Vector3(dlugosc_boku, 1.0, 0.14) if wzdluz_x
			else Vector3(0.14, 1.0, dlugosc_boku))
		return
	# Dwa segmenty po bokach furtki
	var dlugosc_segmentu := dlugosc_boku / 2.0 - polowa_furtki
	if dlugosc_segmentu <= 0.1:
		return   # furtka zjadłaby cały bok
	var odsuniecie := polowa_furtki + dlugosc_segmentu / 2.0
	for kierunek in [-1.0, 1.0]:
		var przesuniecie := Vector3(kierunek * odsuniecie, 0, 0) if wzdluz_x \
			else Vector3(0, 0, kierunek * odsuniecie)
		_przeszkoda(srodek_boku + przesuniecie,
			Vector3(dlugosc_segmentu, 1.0, 0.14) if wzdluz_x
			else Vector3(0.14, 1.0, dlugosc_segmentu))

## Składa zebrane transformacje w jeden MultiMeshInstance3D.
## Zamiast setek osobnych węzłów (i setek wywołań rysowania) mamy JEDEN
## obiekt na wszystkie sztachety wszystkich działek. "znikaj_od" to LOD:
## z większej odległości drobiazg przestaje się rysować.
func _multi(mesh: Mesh, transformy: Array, kolory: Array, znikaj_od := 0.0) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transformy.size()
	for i in transformy.size():
		multi.set_instance_transform(i, transformy[i])
		multi.set_instance_color(i, kolory[i])
	var wezel := MultiMeshInstance3D.new()
	wezel.multimesh = multi
	# Materiał musi czytać kolor instancji, inaczej wszystko byłoby białe
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	wezel.material_override = mat
	if znikaj_od > 0.0:
		wezel.visibility_range_end = znikaj_od
		wezel.visibility_range_end_margin = 6.0
		wezel.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(wezel)
	return wezel

## Tablica ogłoszeń przy głównym chodniku - tu bierze się zlecenia.
func _tablica_ogloszen() -> void:
	var tablica := Tablica.new()
	tablica.position = Vector3(4.6, 0, 14)
	tablica.rotation.y = -PI / 2.0 - 0.25
	add_child(tablica)

## RUCH ULICZNY - obwodnica osiedla jako Path3D + auta (PathFollow3D).
func _ruch_uliczny() -> void:
	# Jezdnia budowana wprost z JEZDNIE - asfalt nie może się rozjechać
	# z tym, co uważa za jezdnię reszta gry (patrz czy_zajete).
	var nawierzchnia := Styl.teren_szum(Paleta.ASFALT, 0.9, 0.1)
	for pas in JEZDNIE:
		var srodek := Vector3((pas[0] + pas[1]) / 2.0, 0.012, (pas[2] + pas[3]) / 2.0)
		var rozmiar := Vector3(pas[1] - pas[0], 0.024, pas[3] - pas[2])
		_pudlo(srodek, rozmiar, Paleta.ASFALT, false, false, nawierzchnia)
	# Przerywana linia środkowa. Północna jezdnia biegnie teraz za Biedronką
	# (z=-46), pionowe łączą się z nią, więc są dłuższe niż kiedyś.
	for i in 34:
		var t := i / 34.0
		_pudlo(Vector3(-30.0 + t * 60.0, 0.026, -46), Vector3(1.2, 0.02, 0.16), Paleta.LINIA, false)
		_pudlo(Vector3(-30.0 + t * 60.0, 0.026, 38), Vector3(1.2, 0.02, 0.16), Paleta.LINIA, false)
		_pudlo(Vector3(-30, 0.026, -46.0 + t * 84.0), Vector3(0.16, 0.02, 1.2), Paleta.LINIA, false)
		_pudlo(Vector3(30, 0.026, -46.0 + t * 84.0), Vector3(0.16, 0.02, 1.2), Paleta.LINIA, false)

	# Ścieżka aut - zamknięta pętla po obwodnicy, z zaokrąglonymi rogami
	var sciezka := Path3D.new()
	var krzywa := Curve3D.new()
	var punkty := [
		Vector3(-27, 0, -46), Vector3(27, 0, -46),
		Vector3(30, 0, -43), Vector3(30, 0, 35),
		Vector3(27, 0, 38), Vector3(-27, 0, 38),
		Vector3(-30, 0, 35), Vector3(-30, 0, -43),
	]
	for punkt in punkty:
		krzywa.add_point(punkt)
	krzywa.add_point(punkty[0])   # domknięcie pętli
	sciezka.curve = krzywa
	add_child(sciezka)
	# Auta rozstawione równo po trasie, każde w swoim tempie.
	# Pętla ma ~280 m, więc przy czterech autach mijało się jedno raz na 70 m
	# i osiedle sprawiało wrażenie wymarłego. Przy Balans.ILE_AUT odstęp
	# schodzi do kilkudziesięciu metrów i ruch faktycznie widać.
	var dlugosc_trasy := krzywa.get_baked_length()
	for i in Balans.ILE_AUT:
		var samochod := Auto.new()
		samochod.predkosc = randf_range(6.0, 9.5)
		sciezka.add_child(samochod)
		samochod.progress = dlugosc_trasy * (float(i) / float(Balans.ILE_AUT))

## Złom rozrzucony po mapie - przy garażach, działkach i za blokami.
func _rozrzuc_zlom() -> void:
	# Strefy celują w wolną przestrzeń: pas jezdni (±27..±33 i z 35..41) oraz
	# obrysy bloków są wyłączone. _losuj_wolne i tak odrzuci trafienie w coś
	# zajętego, ale strefa wycelowana w ścianę zjada wszystkie próby.
	var strefy := [
		[34.0, 44.0, -16.0, 16.0],    # plac garażowy
		[-26.0, -20.0, 26.0, 33.0],   # nieużytki przed działkami
		[12.0, 26.0, 26.0, 33.0],
		[-24.0, -16.0, 15.0, 19.0],   # za lewym blokiem, od strony podwórka
	]
	for i in Balans.ILE_ZLOMU_NA_START:
		var strefa: Array = strefy[randi() % strefy.size()]
		var zlom := Kolekcjonerski.new()
		zlom.typ = Kolekcjonerski.losowy_typ_zlomu()
		zlom.position = _losuj_wolne(strefa)
		add_child(zlom)

func _lawka(pozycja: Vector3, obrot: float) -> void:
	# Ławka to interaktywny obiekt (siadanie) - patrz scripts/lawka.gd
	var lawka := Lawka.new()
	lawka.position = pozycja
	lawka.rotation.y = obrot
	add_child(lawka)

func _smietniki() -> void:
	# Duże kontenery przy blokach - 13 m od osi, czyli poza zasięgiem balkonów
	for pozycja in [Vector3(-13, 0, 10), Vector3(-13, 0, -4), Vector3(13, 0, 12), Vector3(13, 0, -2)]:
		var kontener := Smietnik.new()
		kontener.rodzaj = Smietnik.Rodzaj.KONTENER
		kontener.position = pozycja
		kontener.rotation.y = randf_range(-0.3, 0.3)
		add_child(kontener)
	# Małe kosze przy chodniku i pod Biedronką
	for pozycja in [Vector3(2.6, 0, 18), Vector3(-2.6, 0, 8), Vector3(2.6, 0, -6), Vector3(-2.6, 0, -18), Vector3(-6, 0, -26.5)]:
		var kosz := Smietnik.new()
		kosz.rodzaj = Smietnik.Rodzaj.KOSZ
		kosz.position = pozycja
		add_child(kosz)

## Wszystkie NPC osiedla: sąsiadka, pies, konkurent Heniek, przechodzień.
func _npce() -> void:
	var sasiadka := Sasiadka.new()
	sasiadka.position = Vector3(-5, 0, 2)
	add_child(sasiadka)
	# Pies na łańcuchu przy prawym bloku
	var pies := Pies.new()
	pies.position = Vector3(14.5, 0, 6)
	pies.rotation.y = -PI / 2   # buda przodem do osiedla
	add_child(pies)
	# Konkurent Heniek - startuje po drugiej stronie mapy
	var heniek := Konkurent.new()
	heniek.position = Vector3(18, 0.2, 18)
	add_child(heniek)
	# Przechodzień spacerujący chodnikiem
	var przechodzien := Przechodzien.new()
	przechodzien.position = Vector3(1.3, 0, 16)
	add_child(przechodzien)
	# Stadko gołębi na chodniku (uciekają przed graczem)
	add_child(Golebie.new())
	# Patrol Straży Miejskiej - grzebanie przy nim kosztuje
	var straznik := Straznik.new()
	straznik.position = Vector3(8, 0, 18)
	add_child(straznik)
	# Kiosk RUCH ze zdrapkami, przy skrzyżowaniu chodników
	var kiosk := Kiosk.new()
	kiosk.position = Vector3(7, 0, 9.5)
	kiosk.rotation.y = PI / 2   # okienkiem do chodnika
	add_child(kiosk)
	# Okno z DISCO POLO (prawy blok) - muzyka przestrzenna + strefa morale
	var glosnik := AudioStreamPlayer3D.new()
	glosnik.stream = Sfx.petla_disco()
	glosnik.position = Vector3(15.8, 5.5, 10)
	glosnik.unit_size = 5.0
	glosnik.max_distance = 28.0
	glosnik.volume_db = -4.0
	glosnik.autoplay = true
	add_child(glosnik)
	var strefa_disco := Area3D.new()
	var ksztalt_strefy := CollisionShape3D.new()
	var kula_strefy := SphereShape3D.new()
	kula_strefy.radius = 8.0
	ksztalt_strefy.shape = kula_strefy
	strefa_disco.add_child(ksztalt_strefy)
	strefa_disco.position = Vector3(14, 1, 10)
	add_child(strefa_disco)
	strefa_disco.body_entered.connect(_wejscie_w_disco)

var _ostatnie_disco := -999.0   # cooldown bonusu za disco polo

## Wejście w zasięg disco polo: morale (Wsiokometr) rośnie.
func _wejscie_w_disco(cialo: Node3D) -> void:
	if not (cialo is CharacterBody3D and cialo.is_in_group("gracz")):
		return
	var teraz := Time.get_ticks_msec() / 1000.0
	if teraz - _ostatnie_disco < 30.0:
		return
	_ostatnie_disco = teraz
	Game.dodaj_wsiokometr(5.0)
	Game.pokaz_komunikat("Z okna leci disco polo. Morale rośnie! Wsiokometr +5.")

## Zieleń: drzewa, krzaki i łaty trawy - osiedle przestaje być gołe.
func _zielen() -> void:
	# Drzewa rozstawione po obrzeżach i między blokami.
	# Uwaga: wszystkie muszą omijać pas jezdni (x od ±27 do ±33) - wcześniej
	# pięć z nich rosło dokładnie na obwodnicy, a jedno w środku małego bloku.
	for pozycja in [
		Vector3(-25, 0, 16), Vector3(-36, 0, 4), Vector3(-36, 0, -8), Vector3(-25, 0, -18),
		Vector3(25, 0, 18), Vector3(36, 0, 6), Vector3(25, 0, -6), Vector3(36, 0, -16),
		Vector3(-26, 0, 26), Vector3(26, 0, 28), Vector3(-8, 0, 30), Vector3(10, 0, 32),
		Vector3(-24, 0, -24), Vector3(24, 0, -22), Vector3(6, 0, 26), Vector3(-8, 0, 22),
	]:
		_drzewo(pozycja)
	# Krzaki pod blokami i przy Biedronce (odsunięte od ścian, bo balkony
	# wychodzą 1,1 m poza elewację)
	for pozycja in [
		Vector3(-13.5, 0, 16), Vector3(-13.5, 0, 0), Vector3(13.5, 0, 16), Vector3(13.5, 0, 1),
		Vector3(-12.5, 0, -26), Vector3(12.5, 0, -26.5), Vector3(4, 0, 20), Vector3(-4, 0, 14),
		Vector3(-9.5, 0, 18), Vector3(11, 0, 22),
	]:
		_krzak(pozycja)
	# Łaty ciemniejszej trawy - łamią jednolitą zieleń trawnika
	for i in 16:
		var laty := MeshInstance3D.new()
		var pudlo := BoxMesh.new()
		pudlo.size = Vector3(randf_range(1.5, 3.5), 0.02, randf_range(1.5, 3.5))
		laty.mesh = pudlo
		laty.material_override = _material(Paleta.TRAWA_CIEMNA if randf() < 0.5 else Paleta.TRAWA_JASNA)
		laty.position = Vector3(
			signf(randf() - 0.5) * randf_range(3.5, 26.0), 0.012, randf_range(-26.0, 30.0)
		)
		add_child(laty)

func _drzewo(pozycja: Vector3) -> void:
	var skala := randf_range(0.85, 1.3)
	# Pień - kolizję dokładamy niżej osobno (szerszą niż sam pień, żeby
	# gracz nie wchodził twarzą w koronę), więc walec zostaje wizualny
	_walec(pozycja + Vector3(0, 1.1 * skala, 0), 0.18 * skala, 2.2 * skala, Paleta.PIEN, false, false)
	var cialo := StaticBody3D.new()
	cialo.add_to_group("drzewo")   # test [9] sprawdza, gdzie stoją drzewa
	cialo.position = pozycja + Vector3(0, 1.1 * skala, 0)
	var kolizja := CollisionShape3D.new()
	var walec := CylinderShape3D.new()
	walec.radius = 0.2 * skala
	walec.height = 2.2 * skala
	kolizja.shape = walec
	cialo.add_child(kolizja)
	add_child(cialo)
	# Korona - trzy zielone kule w różnych odcieniach
	for dane in [
		[Vector3(0, 2.7, 0), 0.95, Paleta.KORONY[0]],
		[Vector3(0.5, 2.3, 0.3), 0.7, Paleta.KORONY[1]],
		[Vector3(-0.45, 2.4, -0.25), 0.65, Paleta.KORONY[2]],
	]:
		var kula_mesh := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = dane[1] * skala
		kula.height = dane[1] * 2.0 * skala
		kula_mesh.mesh = kula
		# Odcień per kula, nie per gatunek - inaczej wszystkie drzewa na mapie
		# mają dokładnie te same trzy zielenie i widać, że to jeden prefab
		kula_mesh.material_override = _material(Styl.wariant(dane[2], 0.08), false, Styl.KONTUR_OBIEKT)
		kula_mesh.position = pozycja + dane[0] * skala
		kula_mesh.rotation.y = randf() * TAU
		add_child(kula_mesh)
	# Korona zatrzymuje WYŁĄCZNIE wysięgnik kamery (patrz Balans.WARSTWA_KAMERY).
	# Gracz przez liście nadal przechodzi - blokuje go tylko pień - ale kamera
	# TPP nie wjeżdża już w środek korony, gdzie widać sam czarny kontur.
	var korona := StaticBody3D.new()
	korona.collision_layer = Balans.WARSTWA_KAMERY
	korona.collision_mask = 0
	korona.position = pozycja + Vector3(0, 2.55 * skala, 0)
	var oslona := CollisionShape3D.new()
	var kula_oslony := SphereShape3D.new()
	kula_oslony.radius = 1.15 * skala
	oslona.shape = kula_oslony
	korona.add_child(oslona)
	add_child(korona)

func _krzak(pozycja: Vector3) -> void:
	var krzak := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = randf_range(0.5, 0.8)
	kula.height = kula.radius * 1.3
	krzak.mesh = kula
	# Każdy krzak w swoim odcieniu - rząd identycznych zielonych kul
	# natychmiast zdradza, że to kopie jednego obiektu
	krzak.material_override = _material(Styl.wariant(Paleta.KRZAK, 0.09), false, Styl.KONTUR_OBIEKT)
	krzak.position = pozycja + Vector3(0, kula.height * 0.35, 0)
	krzak.rotation.y = randf() * TAU
	add_child(krzak)
	# Krzak jest przeszkodą - niższą niż wygląda, żeby dało się go przeskoczyć
	_przeszkoda(pozycja + Vector3(0, kula.radius * 0.5, 0),
		Vector3(kula.radius * 1.6, kula.radius, kula.radius * 1.6)).add_to_group("krzak")

## Niski płot wokół osiedla - granica mapy wygląda celowo, nie "ucięte".
func _plot() -> void:
	var kolor := Paleta.PLOT
	for strona in 4:
		var wzdluz_x := strona < 2   # 0,1 = ściany północ/południe
		var znak := 1.0 if strona % 2 == 0 else -1.0
		# Dwie poziome poprzeczki
		for wysokosc in [0.45, 0.9]:
			var poprzeczka := MeshInstance3D.new()
			var pudlo := BoxMesh.new()
			pudlo.size = Vector3(118, 0.07, 0.07) if wzdluz_x else Vector3(0.07, 0.07, 118)
			poprzeczka.mesh = pudlo
			poprzeczka.material_override = _material(kolor)
			poprzeczka.position = Vector3(0, wysokosc, znak * 59) if wzdluz_x else Vector3(znak * 59, wysokosc, 0)
			add_child(poprzeczka)
		# Słupki co ~5,5 m (kolizję niesie ciągła bariera niżej, więc same
		# słupki zostają wizualne - inaczej gracz zaczepiałby o co drugi)
		for i in 22:
			var wzdluz := -58.0 + i * 5.5
			var pozycja := Vector3(wzdluz, 0.55, znak * 59) if wzdluz_x else Vector3(znak * 59, 0.55, wzdluz)
			_walec(pozycja, 0.07, 1.1, kolor, false, false)
		# Ciągła bariera wzdłuż całego boku - płot ma ZATRZYMYWAĆ, a nie być
		# dekoracją, przez którą przechodzi się na niewidzialną ścianę metr dalej
		_przeszkoda(
			Vector3(0, 0.6, znak * 59) if wzdluz_x else Vector3(znak * 59, 0.6, 0),
			Vector3(118, 1.2, 0.12) if wzdluz_x else Vector3(0.12, 1.2, 118))

## Kreskówkowe chmury sunące po niebie.
func _chmury() -> void:
	for i in 7:
		var chmura := Node3D.new()
		chmura.position = Vector3(randf_range(-40, 40), randf_range(22, 32), randf_range(-40, 40))
		add_child(chmura)
		for j in 3:
			var klab := MeshInstance3D.new()
			var kula := SphereMesh.new()
			kula.radius = randf_range(1.8, 3.2)
			kula.height = kula.radius * 1.2
			klab.mesh = kula
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1, 1, 1, 0.95)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			klab.material_override = mat
			klab.position = Vector3(j * 2.4 - 2.4, randf_range(-0.4, 0.4), randf_range(-1, 1))
			chmura.add_child(klab)
		# Powolny dryf tam i z powrotem
		var tw := chmura.create_tween().set_loops()
		tw.tween_property(chmura, "position:x", chmura.position.x + 18.0, randf_range(35.0, 55.0))
		tw.tween_property(chmura, "position:x", chmura.position.x, randf_range(35.0, 55.0))

## Linie parkingowe i pasy - asfalt przestaje być gołą płytą.
func _detale_drogi() -> void:
	# Miejsca parkingowe przed Biedronką
	for i in 6:
		var linia := MeshInstance3D.new()
		var pudlo := BoxMesh.new()
		pudlo.size = Vector3(0.15, 0.02, 6)
		linia.mesh = pudlo
		linia.material_override = _material(Color(0.9, 0.9, 0.9))
		linia.position = Vector3(-10.0 + i * 4.0, 0.045, -24)
		add_child(linia)
	# Pasy przed wejściem do sklepu
	for i in 5:
		var pas := MeshInstance3D.new()
		var pudlo := BoxMesh.new()
		pudlo.size = Vector3(0.8, 0.02, 3.2)
		pas.mesh = pudlo
		pas.material_override = _material(Color(0.9, 0.9, 0.9))
		pas.position = Vector3(-2.4 + i * 1.2, 0.05, -20.5)
		add_child(pas)

## Kamienie na trawnikach - sprint po nich kończy się glebą.
func _kamienie() -> void:
	for i in ILE_KAMIENI:
		# Nie kładziemy kamieni na chodniku ani przy spawnie gracza
		var pozycja := Vector3(randf_range(-13, 13), 0, randf_range(-24, 18))
		if absf(pozycja.x) < 2.5 or pozycja.distance_to(Vector3(0, 0, 22)) < 5.0:
			pozycja.x = signf(pozycja.x) * randf_range(3.5, 13.0)
		# Widoczny kamień (spłaszczona kula)
		var kamien := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = randf_range(0.2, 0.35)
		kula.height = kula.radius
		kamien.mesh = kula
		kamien.material_override = _material(Paleta.KAMIEN, false, Styl.KONTUR_OBIEKT)
		kamien.position = pozycja
		kamien.rotation.y = randf() * TAU
		add_child(kamien)
		# Strefa potknięcia (Area3D w grupie "przeszkoda")
		var strefa := Area3D.new()
		strefa.add_to_group("przeszkoda")
		var ksztalt := CollisionShape3D.new()
		var kula_strefy := SphereShape3D.new()
		kula_strefy.radius = 0.45
		ksztalt.shape = kula_strefy
		strefa.add_child(ksztalt)
		strefa.position = pozycja + Vector3(0, 0.2, 0)
		add_child(strefa)

## Neon Biedronki miga w losowych odstępach - czasem seria "zwarć".
func _neon_petla() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 6.0), false).timeout
		if not is_instance_valid(_neon_napis):
			return
		if randf() < 0.35:
			# Seria szybkich mrugnięć - klasyczne zwarcie
			for i in randi_range(2, 5):
				_neon_napis.visible = false
				await get_tree().create_timer(randf_range(0.04, 0.12), false).timeout
				_neon_napis.visible = true
				await get_tree().create_timer(randf_range(0.05, 0.15), false).timeout
		else:
			# Pojedyncze dłuższe mrugnięcie
			_neon_napis.visible = false
			await get_tree().create_timer(randf_range(0.15, 0.5), false).timeout
			_neon_napis.visible = true

func _rozrzuc_butelki() -> void:
	# Strefy rozrzutu: (x_min, x_max, z_min, z_max) - środek osiedla i okolice
	var strefy := [
		[-13.0, 13.0, -20.0, 20.0],   # centralna część osiedla
		[-13.0, 13.0, -26.0, -20.0],  # przed Biedronką
		[-24.0, -15.0, 14.0, 20.0],   # za kontenerami lewego bloku
		[15.0, 24.0, 14.0, 20.0],     # za kontenerami prawego bloku
	]
	for i in ILE_BUTELEK_NA_START:
		var strefa: Array = strefy[randi() % strefy.size()]
		var przedmiot := Kolekcjonerski.new()
		przedmiot.typ = Kolekcjonerski.losowy_typ(Game.mnoznik_szczescia())
		przedmiot.position = _losuj_wolne(strefa)
		add_child(przedmiot)

## Niewidzialne ściany na krawędziach mapy, żeby nie spaść z trawnika.
func _niewidzialne_sciany() -> void:
	for dane in [
		[Vector3(0, 5, 60), Vector3(120, 10, 1)],
		[Vector3(0, 5, -60), Vector3(120, 10, 1)],
		[Vector3(60, 5, 0), Vector3(1, 10, 120)],
		[Vector3(-60, 5, 0), Vector3(1, 10, 120)],
	]:
		var sciana := StaticBody3D.new()
		sciana.position = dane[0]
		var kolizja := CollisionShape3D.new()
		var ksztalt := BoxShape3D.new()
		ksztalt.size = dane[1]
		kolizja.shape = ksztalt
		sciana.add_child(kolizja)
		add_child(sciana)
