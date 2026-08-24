class_name SwiatBudynki
extends Bryly
## BUDOWNICZY ARCHITEKTURY - wszystko, co stoi na fundamencie:
## Biedronka z wnętrzem, bloki z balkonami, garaże z rampami,
## ogródki działkowe ze skupem złomu, punkty butelkomatów i płot mapy.
##
## Wołane raz z world.gd:  SwiatBudynki.new(self).zbuduj()

const Butelkomat := preload("res://scripts/butelkomat.gd")
const Automat := preload("res://scripts/automat.gd")
const Wozek := preload("res://scripts/wozek.gd")
const Drzwi := preload("res://scripts/drzwi.gd")
const Lodowka := preload("res://scripts/lodowka.gd")
const Kasjerka := preload("res://scripts/kasjerka.gd")
const SkupZlomu := preload("res://scripts/skup_zlomu.gd")
const Skuter := preload("res://scripts/skuter.gd")
const Rampa := preload("res://scripts/rampa.gd")

## Drzewka owocowe na działkach rosną tym samym kodem, co reszta zieleni -
## world.gd podstawia tu gotowego budowniczego, żeby nie dublować drzewa.
var zielen: SwiatZielen = null

## Szyld "BIEDRONKA" - world.gd każe mu migać jak zepsuty neon.
var neon_napis: Label3D

# Bufory pod MultiMesh: drobiazgi z działek zbierane przed złożeniem w jeden
# węzeł. Dzięki temu setki sztachet kosztują tyle, co jeden obiekt.
var _sztachety: Array[Transform3D] = []
var _kolory_sztachet: Array[Color] = []
var _warzywa: Array[Transform3D] = []
var _kolory_warzyw: Array[Color] = []

func zbuduj() -> void:
	_biedronka()
	_bloki()
	_garaze()
	_dzialki()
	_butelkomaty_osiedlowe()
	_plot()
	_niewidzialne_sciany()

# =============================================================================
#  BIEDRONKA
# =============================================================================

func _biedronka() -> void:
	# Budynek sklepu - z cokołem i gzymsem, jak bloki (patrz _blok)
	pudlo(Vector3(0, 3.5, -34), Vector3(22, 7, 12), Paleta.BIEDRONKA_SCIANA)
	pudlo(Vector3(0, 0.55, -34), Vector3(22.3, 1.1, 12.3),
		Paleta.BIEDRONKA_SCIANA.darkened(0.45), false)
	pudlo(Vector3(0, 7.15, -34), Vector3(22.6, 0.5, 12.6),
		Paleta.BIEDRONKA_SCIANA.darkened(0.25), false)
	# Czerwony pas z logo nad wejściem
	pudlo(Vector3(0, 5.8, -27.8), Vector3(14, 1.6, 0.4), Paleta.CZERWIEN, false)
	var napis := Styl.szyld("BIEDRONKA", 220, Color(1.0, 1.0, 0.85))
	napis.pixel_size = 0.005
	napis.position = Vector3(0.6, 5.8, -27.55)
	swiat.add_child(napis)
	neon_napis = napis   # będzie migać jak zepsuty neon
	# Biedronka (owad) na szyldzie - czerwona kulka w kropki
	var zuk := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.45
	kula.height = 0.6
	zuk.mesh = kula
	zuk.material_override = material(Color(0.9, 0.15, 0.1), false, Styl.KONTUR_OBIEKT)
	zuk.position = Vector3(-5.6, 5.8, -27.5)
	swiat.add_child(zuk)
	for przesuniecie in [Vector3(-0.15, 0.2, 0.28), Vector3(0.18, 0.05, 0.33), Vector3(-0.05, -0.15, 0.35)]:
		var kropka := MeshInstance3D.new()
		var mala := SphereMesh.new()
		mala.radius = 0.08
		mala.height = 0.16
		kropka.mesh = mala
		kropka.material_override = material(Color.BLACK)
		kropka.position = zuk.position + przesuniecie
		swiat.add_child(kropka)
	# Drzwi wejściowe (ciemne szkło)
	pudlo(Vector3(-2, 1.5, -27.9), Vector3(3, 3, 0.2), Color(0.15, 0.2, 0.25), false)
	pudlo(Vector3(2, 1.5, -27.9), Vector3(3, 3, 0.2), Color(0.15, 0.2, 0.25), false)
	# PODCIEŃ nad wejściem - blaszany daszek na dwóch słupkach, ciągnący się
	# nad drzwiami i butelkomatem. To nie dekoracja: Plan.DACHY liczy tę strefę
	# jako zadaszoną, więc w deszczu chowa się tu łup, a szum deszczu przechodzi
	# w bębnienie o blachę (patrz scripts/pogoda.gd).
	var podcien := pudlo(Vector3(1.5, 3.3, -26.9), Vector3(14.0, 0.14, 3.0),
		Color(0.5, 0.16, 0.18), false, false, Styl.metal(Color(0.5, 0.16, 0.18)))
	podcien.rotation.z = 0.03
	for x in [-5.0, 8.0]:
		walec(Vector3(x, 1.63, -25.5), 0.08, 3.26, Paleta.METAL, false, false, true)
	# Butelkomat przy wejściu - flagowy punkt osiedla
	var automat := Butelkomat.new()
	automat.nazwa_punktu = "przy Biedronce"
	automat.position = Vector3(6.5, 0, -27.4)
	swiat.add_child(automat)
	# Automat z napojami obok butelkomatu - kaucja wychodzi i od razu wraca
	var automat_napojow := Automat.new()
	automat_napojow.position = Vector3(4.6, 0, -27.4)
	swiat.add_child(automat_napojow)
	# Wózek sklepowy do "pożyczenia"
	var wozek := Wozek.new()
	wozek.position = Vector3(9.5, 0, -25.0)
	wozek.rotation.y = 0.4
	swiat.add_child(wozek)
	# Drzwi wejściowe - teleport do wnętrza sklepu
	var wejscie := Drzwi.new()
	wejscie.position = Vector3(-2, 0, -27.6)
	wejscie.cel = Plan.WEJSCIE_SKLEPU
	wejscie.obrot_y = 0.0
	wejscie.etykieta = "E - wejdź do Biedronki"
	wejscie.komunikat = "Dzyń dzyń! Zapach świeżego pieczywa i promocji."
	swiat.add_child(wejscie)
	_wnetrze_biedronki()

## Wnętrze sklepu - podziemne pomieszczenie (teleport przez drzwi).
## Wszystkie pozycje to Plan.WNETRZE + przesunięcie, więc łatwo je przenieść.
func _wnetrze_biedronki() -> void:
	var wnetrze := Plan.WNETRZE
	# Podłoga, ściany i sufit
	pudlo(wnetrze + Vector3(0, -0.5, 0), Vector3(14, 1, 10), Color(0.85, 0.82, 0.75))
	pudlo(wnetrze + Vector3(0, 1.9, -5.2), Vector3(14.6, 3.8, 0.4), Color(0.93, 0.92, 0.88))
	pudlo(wnetrze + Vector3(0, 1.9, 5.2), Vector3(14.6, 3.8, 0.4), Color(0.93, 0.92, 0.88))
	pudlo(wnetrze + Vector3(-7.2, 1.9, 0), Vector3(0.4, 3.8, 10.4), Color(0.93, 0.92, 0.88))
	pudlo(wnetrze + Vector3(7.2, 1.9, 0), Vector3(0.4, 3.8, 10.4), Color(0.93, 0.92, 0.88))
	pudlo(wnetrze + Vector3(0, 3.9, 0), Vector3(14.6, 0.3, 10.6), Color(0.9, 0.9, 0.88), false)
	# Świetlówki na suficie
	for x in [-3.5, 3.5]:
		pudlo(wnetrze + Vector3(x, 3.72, 0), Vector3(3, 0.06, 1), Color(1.0, 0.98, 0.9), false, true)
	var swiatlo := OmniLight3D.new()
	swiatlo.position = wnetrze + Vector3(0, 3.2, 0)
	swiatlo.light_energy = 1.2
	swiatlo.omni_range = 14.0
	swiat.add_child(swiatlo)
	# Regały z "towarem" (kolorowe pudełka - promocje same się nie ułożą)
	for przesuniecie_regalu in [Vector3(-3.5, 0, 1.5), Vector3(-3.5, 0, -2), Vector3(3, 0, -2)]:
		var pozycja_regalu: Vector3 = wnetrze + przesuniecie_regalu
		pudlo(pozycja_regalu + Vector3(0, 0.9, 0), Vector3(3.2, 1.8, 0.7), Color(0.6, 0.45, 0.3))
		for i in 5:
			var produkt := MeshInstance3D.new()
			var pudlo_produktu := BoxMesh.new()
			pudlo_produktu.size = Vector3(0.4, 0.35, 0.35)
			produkt.mesh = pudlo_produktu
			produkt.material_override = material([
				Color(0.9, 0.3, 0.2), Color(0.95, 0.8, 0.2), Color(0.3, 0.6, 0.9),
				Color(0.4, 0.75, 0.3), Color(0.85, 0.5, 0.8),
			].pick_random())
			produkt.position = pozycja_regalu + Vector3(-1.2 + i * 0.6, 1.98, 0)
			swiat.add_child(produkt)
	# Lodówka z piwem (gwóźdź programu)
	var lodowka := Lodowka.new()
	lodowka.position = wnetrze + Vector3(6.4, 0, 0)
	lodowka.rotation.y = -PI / 2   # frontem do środka sklepu
	swiat.add_child(lodowka)
	# Lada i Pani Grażynka
	pudlo(wnetrze + Vector3(3, 0.5, 3.7), Vector3(2.2, 1.0, 0.8), Color(0.5, 0.35, 0.2))
	var kasjerka := Kasjerka.new()
	kasjerka.position = wnetrze + Vector3(3, 0, 2.7)
	kasjerka.rotation.y = PI   # twarzą do wejścia
	swiat.add_child(kasjerka)
	# Drzwi wyjściowe - teleport z powrotem na osiedle
	var wyjscie := Drzwi.new()
	wyjscie.position = wnetrze + Vector3(-3, 0, 4.4)
	wyjscie.cel = Plan.WYJSCIE_SKLEPU
	wyjscie.obrot_y = PI
	wyjscie.etykieta = "E - wyjdź na osiedle"
	swiat.add_child(wyjscie)
	# WIDOCZNE drzwi: framuga, dwa ciemne skrzydła i klamka na ścianie
	pudlo(wnetrze + Vector3(-3, 1.6, 4.94), Vector3(2.8, 3.2, 0.1), Color(0.4, 0.34, 0.28), false)
	pudlo(wnetrze + Vector3(-3.65, 1.5, 4.86), Vector3(1.25, 2.95, 0.1), Paleta.SZKLO_DRZWI, false)
	pudlo(wnetrze + Vector3(-2.35, 1.5, 4.86), Vector3(1.25, 2.95, 0.1), Paleta.SZKLO_DRZWI, false)
	pudlo(wnetrze + Vector3(-2.9, 1.35, 4.78), Vector3(0.22, 0.06, 0.08), Color(0.85, 0.85, 0.9), false)
	# Zielony napis WYJŚCIE (przepisy BHP to podstawa)
	var napis := Styl.szyld("WYJŚCIE", 64, Color(0.3, 1.0, 0.4))
	napis.position = wnetrze + Vector3(-3, 3.0, 4.5)
	swiat.add_child(napis)

# =============================================================================
#  BLOKI
# =============================================================================

func _bloki() -> void:
	# Dwa bloki z wielkiej płyty po bokach osiedla
	_blok(Vector3(-20, 0, 4), true)   # okna od strony +X (do środka)
	_blok(Vector3(20, 0, 4), false)   # okna od strony -X
	# Mniejszy blok na południu - kamienica, więc bez balkonów, ale okna
	# i cokół obowiązkowe: bez nich to była największa gładka ściana na mapie
	var maly := Styl.wariant(Paleta.BLOK.lerp(Paleta.PASTELE.pick_random(), 0.45), 0.05)
	pudlo(Vector3(-16, 4, 24), Vector3(10, 8, 8), maly)
	pudlo(Vector3(-16, 0.6, 24), Vector3(10.3, 1.2, 8.3), maly.darkened(0.42), false)
	pudlo(Vector3(-16, 8.15, 24), Vector3(10.5, 0.5, 8.5), maly.darkened(0.22), false)
	# Okna na dwóch ścianach widocznych z osiedla (wschodniej i północnej)
	for pietro in 3:
		for kolumna in 3:
			for wschodnia in [true, false]:
				var swieci := randf() < 0.28
				var okno := MeshInstance3D.new()
				var szyba := BoxMesh.new()
				szyba.size = Vector3(0.1, 1.2, 1.0) if wschodnia else Vector3(1.0, 1.2, 0.1)
				okno.mesh = szyba
				okno.material_override = material(
					Paleta.OKNO_JASNE if swieci else Paleta.OKNO_CIEMNE, swieci)
				var wzdluz := -2.6 + kolumna * 2.6
				okno.position = Vector3(-10.95, 2.2 + pietro * 2.2, 24 + wzdluz) if wschodnia \
					else Vector3(-16 + wzdluz, 2.2 + pietro * 2.2, 19.95)
				swiat.add_child(okno)
	# TRANSPARENT na lewym bloku - motto osiedla, widoczne z daleka
	pudlo(Vector3(-15.8, 6, 4), Vector3(0.15, 1.5, 15), Color(0.96, 0.96, 0.93), false)
	var motto := Styl.szyld("NIECH ŻYJE KAUCJA I BEZROBOCIE", 88, Color(0.78, 0.08, 0.08))
	motto.pixel_size = 0.0075
	motto.outline_size = 0   # czerwona farba na białym płótnie, obwódka zbędna
	motto.position = Vector3(-15.68, 6, 4)
	motto.rotation.y = PI / 2   # frontem do osiedla
	swiat.add_child(motto)

func _blok(pozycja: Vector3, okna_na_wschod: bool) -> void:
	var rozmiar := Vector3(8, 12, 20)
	# Każdy blok dostaje własny kolor elewacji - szare pudła wyglądały
	# jak makieta architektoniczna, a nie jak polskie osiedle
	var pastel: Color = Styl.wariant(Paleta.PASTELE.pick_random(), 0.05)
	var elewacja := Paleta.BLOK.lerp(pastel, 0.55)
	pudlo(pozycja + Vector3(0, rozmiar.y / 2, 0), rozmiar, elewacja)
	# Mocniejsze pasy tego samego koloru - ślad po "termomodernizacji"
	for wysokosc in [4.0, 8.0]:
		pudlo(pozycja + Vector3(0, wysokosc, 0), Vector3(rozmiar.x + 0.12, 0.8, rozmiar.z + 0.12), pastel, false)
	# COKÓŁ - ciemniejszy pas przy ziemi. Drobiazg, a robi ogromną różnicę:
	# bryła przestaje "stać na trawie jak wycięta" i zaczyna wyglądać, jakby
	# wyrastała z gruntu. Do tego maskuje styk ściany z terenem.
	pudlo(pozycja + Vector3(0, 0.7, 0),
		Vector3(rozmiar.x + 0.3, 1.4, rozmiar.z + 0.3), elewacja.darkened(0.42), false)
	# GZYMS - attyka wystająca ponad elewację. Bez niej blok kończy się
	# ostrą krawędzią i wygląda jak ucięty w połowie.
	pudlo(pozycja + Vector3(0, rozmiar.y + 0.15, 0),
		Vector3(rozmiar.x + 0.55, 0.5, rozmiar.z + 0.55), elewacja.darkened(0.22), false)
	# Antena na dachu z kulką (bez kolizji - i tak nie do dosięgnięcia)
	walec(pozycja + Vector3(1.5, rozmiar.y + 0.9, 3), 0.04, 1.8, Color(0.2, 0.2, 0.2), false, false)
	var kulka := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.12
	kula.height = 0.24
	kulka.mesh = kula
	kulka.material_override = material(Color(0.8, 0.2, 0.2))
	kulka.position = pozycja + Vector3(1.5, rozmiar.y + 1.85, 3)
	swiat.add_child(kulka)
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
			var szyba := BoxMesh.new()
			szyba.size = Vector3(0.1, 1.3, 1.1)
			okno.mesh = szyba
			okno.material_override = material(kolor, swieci)
			var wysokosc_pietra := 2.0 + pietro * 2.6
			okno.position = Vector3(sciana_x, wysokosc_pietra, pozycja.z - 8.0 + kolumna * 3.2)
			swiat.add_child(okno)
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
	pudlo(Vector3(srodek_x, poziom, z), Vector3(wysiegnik, 0.14, szerokosc),
		Color(0.62, 0.6, 0.56), false)
	# Balustrada czołowa (kolorowa blacha) i dwie ścianki boczne
	pudlo(Vector3(czolo_x, poziom + 0.5, z), Vector3(0.09, 0.9, szerokosc), kolor, false)
	for bok in [-1.0, 1.0]:
		pudlo(Vector3(srodek_x, poziom + 0.5, z + bok * (szerokosc / 2.0 - 0.04)),
			Vector3(wysiegnik, 0.9, 0.08), kolor.darkened(0.12), false)

# =============================================================================
#  GARAŻE
# =============================================================================

## GARAŻE - rząd blaszaków na wschód od osiedla. Asfaltowy placyk,
## rampy do skakania i skuter czekający na właściciela (albo i nie).
func _garaze() -> void:
	# Placyk z popękanego betonu - jaśniejszy od jezdni, żeby garaże czytelnie
	# odcinały się od obwodnicy. Wysokości celowo różne (0.020 / 0.018 / 0.012
	# na obwodnicy), inaczej nachodzące płyty migotałyby z-fightingiem.
	# Placyk zaczyna się dopiero za obwodnicą (jezdnia zajmuje x 27..33) -
	# wcześniej beton wchodził pod asfalt i plac zlewał się z ulicą.
	var beton := Styl.teren_szum(Color(0.3, 0.29, 0.28), 0.85, 0.11)
	pudlo(Vector3(43, 0.020, 0), Vector3(18, 0.03, 34), Color(0.3, 0.29, 0.28), false, false, beton)
	# Dojazd łączący placyk z obwodnicą
	pudlo(Vector3(35, 0.018, 0), Vector3(10, 0.03, 6), Color(0.27, 0.27, 0.27), false, false, beton)
	# Rząd blaszaków: korpus + spadzisty dach + brama w innym kolorze
	var kolory_bram: Array[Color] = [
		Color(0.35, 0.45, 0.55), Color(0.55, 0.35, 0.25), Color(0.4, 0.5, 0.35),
		Color(0.5, 0.45, 0.3), Color(0.45, 0.3, 0.35),
	]
	for i in 5:
		var z := -14.0 + i * 7.0
		# Każdy blaszak w swoim odcieniu i z lekko innym przechyłem dachu -
		# pięć identycznych kopii obok siebie od razu zdradza generator
		pudlo(Vector3(48, 1.4, z), Vector3(6, 2.8, 5.6), Styl.wariant(Color(0.52, 0.5, 0.46)))
		var dach := pudlo(Vector3(48, 2.92, z), Vector3(6.4, 0.14, 6.0),
			Styl.wariant(Color(0.42, 0.26, 0.16), 0.09), false)
		dach.rotation.z = randf_range(0.05, 0.09)
		# Brama garażowa z uchwytem - blacha, więc z połyskiem (patrz Styl.metal)
		pudlo(Vector3(44.95, 1.15, z), Vector3(0.12, 2.3, 4.4), kolory_bram[i], false, false,
			Styl.metal(kolory_bram[i], 0.0))
		pudlo(Vector3(44.85, 1.0, z), Vector3(0.1, 0.12, 0.5), Color(0.2, 0.2, 0.22), false)
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
	swiat.add_child(skuter)
	# Sterta opon - obowiązkowy element każdego placu garażowego
	for i in 5:
		var opona := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.18
		torus.outer_radius = 0.42
		torus.rings = 8
		opona.mesh = torus
		opona.material_override = material(Color(0.11, 0.11, 0.12), false, Styl.KONTUR_OBIEKT)
		opona.rotation.x = PI / 2
		opona.rotation.z = randf() * TAU   # inaczej stos wygląda jak jedna bryła
		opona.position = Vector3(36.5 + randf_range(-0.2, 0.2), 0.12 + i * 0.2, 15 + randf_range(-0.2, 0.2))
		swiat.add_child(opona)
	# Jedna kolizja na cały stos - pięć torusów nie ma sensu opisywać osobno
	przeszkoda(Vector3(36.5, 0.5, 15), Vector3(0.95, 1.0, 0.95))

## Tworzy rampę o zadanym obrocie i wymiarach (patrz scripts/rampa.gd).
func _rampa(pozycja: Vector3, obrot: float, dlugosc: float, wysokosc: float) -> void:
	var rampa := Rampa.new()
	rampa.dlugosc = dlugosc
	rampa.wysokosc = wysokosc
	rampa.position = pozycja
	rampa.rotation.y = obrot
	swiat.add_child(rampa)

# =============================================================================
#  BUTELKOMATY POZA BIEDRONKĄ
# =============================================================================

## Jeden automat na całą mapę był wąskim gardłem: skoro zapycha się w ponad
## jednej trzeciej prób, a od dziś potrafi mieć jeszcze kolejkę babć, to
## gracz z pełnym plecakiem miał dokładnie zero alternatyw. Dwa dodatkowe
## punkty (pod małym blokiem i na placu garażowym) zamieniają irytację
## w decyzję: stoję w kolejce czy biegnę czterdzieści metrów dalej?
##
## Każdy stoi pod WIATĄ - a wiata to nie tylko dekoracja: w deszczu
## chowają się pod nią butelki (patrz SwiatNpc.rozrzuc_butelki).
func _butelkomaty_osiedlowe() -> void:
	_punkt_z_wiata(Vector3(-8.5, 0, 19.5), 0.0, "pod małym blokiem")
	_punkt_z_wiata(Vector3(36.0, 0, -13.0), -PI / 2.0, "przy garażach")

## Butelkomat + blaszana wiata. Obrót ustawia automat frontem w stronę,
## z której nadchodzi gracz.
##
## Wiata jest KWADRATOWA (3,4 m) świadomie: przy prostokątnej trzeba by
## obracać płytę razem z daszkiem i słupkami, a przy kwadracie obrót
## niczego nie rozjeżdża.
func _punkt_z_wiata(pozycja: Vector3, obrot: float, nazwa: String) -> void:
	var automat := Butelkomat.new()
	automat.nazwa_punktu = nazwa
	automat.position = pozycja
	automat.rotation.y = obrot
	swiat.add_child(automat)
	# Wektor "w prawo" i "przed siebie" po obrocie o "obrot" wokół osi Y
	var w_bok := Vector3(cos(obrot), 0, -sin(obrot))
	var w_przod := Vector3(-sin(obrot), 0, -cos(obrot))
	var srodek := pozycja + w_przod * 0.5
	# Płyta chodnikowa pod wiatą - automat nie stoi na trawie
	pudlo(srodek + Vector3(0, 0.03, 0), Vector3(3.4, 0.06, 3.4),
		Paleta.CHODNIK, false, false, Styl.teren_szum(Paleta.CHODNIK, 1.1, 0.07))
	# Cztery słupki (bez kolizji - pod wiatą ma być swobodnie) i daszek
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			walec(srodek + w_bok * x + w_przod * z + Vector3(0, 1.25, 0),
				0.07, 2.5, Paleta.METAL, false, false, true)
	var daszek := pudlo(srodek + Vector3(0, 2.6, 0),
		Vector3(3.8, 0.12, 3.8), Color(0.42, 0.46, 0.5), false, false,
		Styl.metal(Color(0.42, 0.46, 0.5)))
	daszek.rotation.z = 0.05
	# Ławeczka z boku wiaty - dla oczekujących w kolejce
	var lawka := pudlo(srodek + w_bok * 2.4 + Vector3(0, 0.45, 0),
		Vector3(0.4, 0.1, 2.0), Paleta.DREWNO)
	lawka.rotation.y = obrot

# =============================================================================
#  OGRÓDKI DZIAŁKOWE + SKUP ZŁOMU
# =============================================================================

## OGRÓDKI DZIAŁKOWE - za obwodnicą na południu. Altanki, grządki,
## drzewka owocowe, a na końcu SKUP ZŁOMU u Zdziśka.
func _dzialki() -> void:
	# Alejka dojazdowa - ubita ziemia z żużlem
	pudlo(Vector3(0, 0.015, 46), Vector3(3, 0.03, 24), Color(0.6, 0.55, 0.45), false, false,
		Styl.teren_szum(Color(0.6, 0.55, 0.45), 1.0, 0.12))
	# Działki po dwie z każdej strony alejki - pozycje z Plan.DZIALKI_X, żeby
	# obrys znany reszcie gry zgadzał się z tym, co faktycznie stoi na mapie
	for x in Plan.DZIALKI_X:
		_dzialka(Vector3(x, 0, Plan.DZIALKA_Z))
	# Sztachety i warzywa ze WSZYSTKICH działek jako dwa MultiMeshe.
	# Same płotki to ~260 elementów - jako osobne węzły zabiłyby wydajność.
	var sztacheta := BoxMesh.new()
	sztacheta.size = Vector3(0.1, 1.0, 0.1)
	multi(sztacheta, _sztachety, _kolory_sztachet, 78.0)
	var warzywo := SphereMesh.new()
	warzywo.radius = 0.16
	warzywo.height = 0.3
	warzywo.radial_segments = 6      # drobiazg z bliska, nie trzeba kuli idealnej
	warzywo.rings = 3
	multi(warzywo, _warzywa, _kolory_warzyw, 46.0)
	# Skup złomu na końcu alejki - okienkiem i wagą do gracza, który
	# nadchodzi od strony osiedla (czyli od mniejszych Z)
	var skup := SkupZlomu.new()
	skup.position = Vector3(0, 0, 54)
	skup.rotation.y = PI
	swiat.add_child(skup)

## Pojedyncza działka: płotek, altanka, grządki i drzewko.
## Sztachety i warzywa NIE są osobnymi węzłami - trafiają do wspólnych
## tablic, z których _dzialki() składa dwa MultiMeshe.
func _dzialka(srodek: Vector3) -> void:
	var szerokosc := Plan.DZIALKA_SZEROKOSC
	var glebokosc := Plan.DZIALKA_GLEBOKOSC
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
	pudlo(alt + Vector3(0, 0.1, 0), Vector3(3.4, 0.2, 3.0), Paleta.DREWNO)
	for x in [-1.5, 1.5]:
		for z in [-1.3, 1.3]:
			walec(alt + Vector3(x, 1.1, z), 0.08, 2.0, Paleta.DREWNO_CIEMNE)
	var dach_altany := pudlo(alt + Vector3(0, 2.25, 0), Vector3(4.0, 0.16, 3.6), Color(0.5, 0.26, 0.2), false)
	dach_altany.rotation.x = 0.1
	# Grządki - rzędy ciemnej ziemi z "warzywami" (warzywa idą do MultiMesha)
	for rzad in 3:
		var z := srodek.z + 1.5 + rzad * 1.6
		pudlo(Vector3(srodek.x, 0.06, z), Vector3(7.0, 0.12, 0.9), Color(0.32, 0.22, 0.14), false)
		for i in 7:
			_warzywa.append(Transform3D(Basis.IDENTITY, Vector3(srodek.x - 3.0 + i, 0.2, z)))
			_kolory_warzyw.append(Color(0.3, 0.55, 0.22).lerp(Color(0.7, 0.3, 0.2), randf() * 0.5))
	# Drzewko owocowe w rogu (rośnie tym samym kodem, co reszta zieleni)
	if zielen:
		zielen.drzewo(srodek + Vector3(szerokosc / 2.0 - 1.5, 0, glebokosc / 2.0 - 1.5))
	# Beczka na deszczówkę
	walec(srodek + Vector3(-szerokosc / 2.0 + 1.2, 0.45, -glebokosc / 2.0 + 1.2), 0.45, 0.9, Color(0.25, 0.35, 0.5))

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
		przeszkoda(srodek_boku,
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
		przeszkoda(srodek_boku + przesuniecie,
			Vector3(dlugosc_segmentu, 1.0, 0.14) if wzdluz_x
			else Vector3(0.14, 1.0, dlugosc_segmentu))

# =============================================================================
#  GRANICE MAPY
# =============================================================================

## Niski płot wokół osiedla - granica mapy wygląda celowo, nie "ucięte".
func _plot() -> void:
	var kolor := Paleta.PLOT
	for strona in 4:
		var wzdluz_x := strona < 2   # 0,1 = ściany północ/południe
		var znak := 1.0 if strona % 2 == 0 else -1.0
		# Dwie poziome poprzeczki
		for wysokosc in [0.45, 0.9]:
			var poprzeczka := MeshInstance3D.new()
			var ksztalt := BoxMesh.new()
			ksztalt.size = Vector3(118, 0.07, 0.07) if wzdluz_x else Vector3(0.07, 0.07, 118)
			poprzeczka.mesh = ksztalt
			poprzeczka.material_override = material(kolor)
			poprzeczka.position = Vector3(0, wysokosc, znak * 59) if wzdluz_x else Vector3(znak * 59, wysokosc, 0)
			swiat.add_child(poprzeczka)
		# Słupki co ~5,5 m (kolizję niesie ciągła bariera niżej, więc same
		# słupki zostają wizualne - inaczej gracz zaczepiałby o co drugi)
		for i in 22:
			var wzdluz := -58.0 + i * 5.5
			var pozycja := Vector3(wzdluz, 0.55, znak * 59) if wzdluz_x else Vector3(znak * 59, 0.55, wzdluz)
			walec(pozycja, 0.07, 1.1, kolor, false, false)
		# Ciągła bariera wzdłuż całego boku - płot ma ZATRZYMYWAĆ, a nie być
		# dekoracją, przez którą przechodzi się na niewidzialną ścianę metr dalej
		przeszkoda(
			Vector3(0, 0.6, znak * 59) if wzdluz_x else Vector3(znak * 59, 0.6, 0),
			Vector3(118, 1.2, 0.12) if wzdluz_x else Vector3(0.12, 1.2, 118))

## Niewidzialne ściany na krawędziach mapy, żeby nie spaść z trawnika.
func _niewidzialne_sciany() -> void:
	for dane in [
		[Vector3(0, 5, 60), Vector3(120, 10, 1)],
		[Vector3(0, 5, -60), Vector3(120, 10, 1)],
		[Vector3(60, 5, 0), Vector3(1, 10, 120)],
		[Vector3(-60, 5, 0), Vector3(1, 10, 120)],
	]:
		przeszkoda(dane[0], dane[1])
