class_name SwiatNpc
extends Bryly
## BUDOWNICZY ŻYCIA NA OSIEDLU - wszystko, co się rusza albo da się podnieść:
## sąsiadka, pies, Heniek, przechodnie, straż, kiosk, gołębie, ruch uliczny,
## śmietniki, tablica ogłoszeń i rozrzucony po mapie łup.
##
## Wołane raz z world.gd:  SwiatNpc.new(self).zbuduj()

const Kolekcjonerski := preload("res://scripts/collectible.gd")
const Smietnik := preload("res://scripts/trash_bin.gd")
const Sasiadka := preload("res://scripts/npc_sasiadka.gd")
const Pies := preload("res://scripts/pies.gd")
const Konkurent := preload("res://scripts/konkurent.gd")
const Przechodzien := preload("res://scripts/przechodzien.gd")
const Golebie := preload("res://scripts/golebie.gd")
const Straznik := preload("res://scripts/straznik.gd")
const Kiosk := preload("res://scripts/kiosk.gd")
const Tablica := preload("res://scripts/tablica.gd")
const Auto := preload("res://scripts/auto.gd")
const GlosnikDisco := preload("res://scripts/glosnik_disco.gd")

## Trasy przechodniów - w pogodę chodzą wszystkie, w deszczu tylko pierwsza.
const TRASY_PRZECHODNIOW: Array = [
	[Vector3(1.3, 0, 18.0), Vector3(1.3, 0, -22.0)],     # główny chodnik
	[Vector3(-14.0, 0, 6.5), Vector3(14.0, 0, 6.5)],     # chodnik poprzeczny
	[Vector3(-1.3, 0, -20.0), Vector3(-1.3, 0, 16.0)],   # druga strona alei
]

func zbuduj() -> void:
	_smietniki()
	_tablica_ogloszen()
	_npce()
	_ruch_uliczny()
	rozrzuc_butelki()
	rozrzuc_zlom()

# =============================================================================
#  ŚMIETNIKI
# =============================================================================

func _smietniki() -> void:
	# Duże kontenery przy blokach - 13 m od osi, czyli poza zasięgiem balkonów
	for pozycja in [Vector3(-13, 0, 10), Vector3(-13, 0, -4), Vector3(13, 0, 12), Vector3(13, 0, -2)]:
		_kontener(pozycja)
	# Kontenery przy działkach - grzebanie w nich to podstawa biznesu.
	# Stoją PRZED jezdnią (z=35..41), nie na niej; wcześniej były na asfalcie.
	for pozycja in [Vector3(-8, 0, 32), Vector3(8, 0, 32)]:
		_kontener(pozycja)
	# Małe kosze przy chodniku i pod Biedronką
	for pozycja in [Vector3(2.6, 0, 18), Vector3(-2.6, 0, 8), Vector3(2.6, 0, -6), Vector3(-2.6, 0, -18), Vector3(-6, 0, -26.5)]:
		var kosz := Smietnik.new()
		kosz.rodzaj = Smietnik.Rodzaj.KOSZ
		kosz.position = pozycja
		swiat.add_child(kosz)

func _kontener(pozycja: Vector3) -> void:
	var kontener := Smietnik.new()
	kontener.rodzaj = Smietnik.Rodzaj.KONTENER
	kontener.position = pozycja
	kontener.rotation.y = randf_range(-0.3, 0.3)
	swiat.add_child(kontener)

## Tablica ogłoszeń przy głównym chodniku - tu bierze się zlecenia.
func _tablica_ogloszen() -> void:
	var tablica := Tablica.new()
	tablica.position = Vector3(4.6, 0, 14)
	tablica.rotation.y = -PI / 2.0 - 0.25
	swiat.add_child(tablica)

# =============================================================================
#  MIESZKAŃCY
# =============================================================================

## Wszystkie NPC osiedla: sąsiadka, pies, konkurent Heniek, przechodnie.
func _npce() -> void:
	var sasiadka := Sasiadka.new()
	sasiadka.position = Vector3(-5, 0, 2)
	swiat.add_child(sasiadka)
	# Pies na łańcuchu przy prawym bloku
	var pies := Pies.new()
	pies.position = Vector3(14.5, 0, 6)
	pies.rotation.y = -PI / 2   # buda przodem do osiedla
	swiat.add_child(pies)
	# Konkurent Heniek - startuje po drugiej stronie mapy
	var heniek := Konkurent.new()
	heniek.position = Vector3(18, 0.2, 18)
	swiat.add_child(heniek)
	# Przechodnie. W deszczu i na śniegu ludzie siedzą w domach - zostaje jeden
	# zapaleniec, a osiedle robi się puste w sposób, który od razu czuć.
	var ile_przechodniow := 1 if Game.mokro() else TRASY_PRZECHODNIOW.size()
	for i in ile_przechodniow:
		var trasa: Array = TRASY_PRZECHODNIOW[i]
		var przechodzien := Przechodzien.new()
		przechodzien.punkt_a = trasa[0]
		przechodzien.punkt_b = trasa[1]
		przechodzien.position = trasa[0]
		swiat.add_child(przechodzien)
	# Stadko gołębi na chodniku (uciekają przed graczem)
	swiat.add_child(Golebie.new())
	# Patrol Straży Miejskiej - grzebanie przy nim kosztuje
	var straznik := Straznik.new()
	straznik.position = Vector3(8, 0, 18)
	swiat.add_child(straznik)
	# Kiosk RUCH ze zdrapkami, przy skrzyżowaniu chodników
	var kiosk := Kiosk.new()
	kiosk.position = Vector3(7, 0, 9.5)
	kiosk.rotation.y = PI / 2   # okienkiem do chodnika
	swiat.add_child(kiosk)
	# Okno z DISCO POLO (prawy blok) - muzyka przestrzenna + strefa morale
	var glosnik := GlosnikDisco.new()
	glosnik.position = Vector3(15.8, 5.5, 10)
	swiat.add_child(glosnik)

# =============================================================================
#  RUCH ULICZNY
# =============================================================================

## RUCH ULICZNY - obwodnica osiedla jako Path3D + auta (PathFollow3D).
func _ruch_uliczny() -> void:
	# Jezdnia budowana wprost z Plan.JEZDNIE - asfalt nie może się rozjechać
	# z tym, co uważa za jezdnię reszta gry (patrz Plan.czy_zajete).
	var nawierzchnia := Styl.teren_szum(Paleta.ASFALT, 0.9, 0.1)
	for pas in Plan.JEZDNIE:
		var srodek := Vector3((pas[0] + pas[1]) / 2.0, 0.012, (pas[2] + pas[3]) / 2.0)
		var rozmiar := Vector3(pas[1] - pas[0], 0.024, pas[3] - pas[2])
		pudlo(srodek, rozmiar, Paleta.ASFALT, false, false, nawierzchnia)
	# Przerywana linia środkowa. Północna jezdnia biegnie za Biedronką
	# (z=-46), pionowe łączą się z nią, więc są dłuższe niż kiedyś.
	for i in 34:
		var t := i / 34.0
		pudlo(Vector3(-30.0 + t * 60.0, 0.026, -46), Vector3(1.2, 0.02, 0.16), Paleta.LINIA, false)
		pudlo(Vector3(-30.0 + t * 60.0, 0.026, 38), Vector3(1.2, 0.02, 0.16), Paleta.LINIA, false)
		pudlo(Vector3(-30, 0.026, -46.0 + t * 84.0), Vector3(0.16, 0.02, 1.2), Paleta.LINIA, false)
		pudlo(Vector3(30, 0.026, -46.0 + t * 84.0), Vector3(0.16, 0.02, 1.2), Paleta.LINIA, false)

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
	swiat.add_child(sciezka)
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

# =============================================================================
#  ŁUP ROZRZUCONY PO MAPIE
# =============================================================================

## Butelki i puszki. Liczba i miejsca zależą od dnia tygodnia i pogody:
## w sobotę osiedle sprząta po piątkowej imprezie, a w deszczu ludzie
## dopijają pod dachem zamiast na ławkach.
func rozrzuc_butelki() -> void:
	# Strefy rozrzutu: (x_min, x_max, z_min, z_max) - środek osiedla i okolice
	var strefy := [
		[-13.0, 13.0, -20.0, 20.0],   # centralna część osiedla
		[-13.0, 13.0, -26.0, -20.0],  # przed Biedronką
		[-24.0, -15.0, 14.0, 20.0],   # za kontenerami lewego bloku
		[15.0, 24.0, 14.0, 20.0],     # za kontenerami prawego bloku
	]
	var ile := roundi(Balans.ILE_BUTELEK_NA_START * Game.mnoznik_fantow())
	for i in ile:
		var strefa: Array = strefy[randi() % strefy.size()]
		_fant(Plan.losuj_wolne(strefa), Kolekcjonerski.losowy_typ(Game.mnoznik_szczescia()))
	# SOBOTA: pokłosie piątkowej imprezy pod blokami. Kupka szkła i puszek
	# dokładnie tam, gdzie w nocy stało towarzystwo - obok ławek i trzepaka.
	if Game.dzien_tygodnia() == Balans.SOBOTA:
		for gniazdo: Vector3 in [Vector3(-12.5, 0, 13.0), Vector3(12.5, 0, 15.0), Vector3(-9.5, 0, 15.5)]:
			for i in randi_range(4, 6):
				var kat := randf() * TAU
				var pozycja := gniazdo + Vector3(cos(kat), 0, sin(kat)) * randf_range(0.4, 2.2)
				_fant(pozycja, Kolekcjonerski.losowy_typ(Game.mnoznik_szczescia()))
	# OPAD: kto pije w deszczu, ten pije pod dachem - a zimą tym bardziej.
	# Miejsca bierzemy wprost z Plan.DACHY, żeby po przesunięciu daszku łup
	# nie został na trawie.
	if Game.mokro():
		var dokladka := Balans.SNIEG_FANTY_POD_WIATA if Game.snieg() else 0
		for i in Plan.DACHY.size():
			var schronienie := Plan.srodek_dachu(i)
			for j in randi_range(3 + dokladka, 5 + dokladka):
				var kat := randf() * TAU
				var pozycja := schronienie + Vector3(cos(kat), 0, sin(kat)) * randf_range(0.5, 1.6)
				# Podcień Biedronki jest PRZYKLEJONY do ściany (bo tak wyglądają
				# podcienie), więc losowanie wokół jego środka potrafi trafić
				# w budynek. Zajęte miejsca odrzucamy - fant w ścianie to fant
				# nie do podniesienia.
				if Plan.czy_zajete(pozycja.x, pozycja.z, 0.4):
					continue
				_fant(pozycja, Kolekcjonerski.losowy_typ(Game.mnoznik_szczescia()))

## Złom rozrzucony po mapie - przy garażach, działkach i za blokami.
func rozrzuc_zlom() -> void:
	# Strefy celują w wolną przestrzeń: pas jezdni (±27..±33 i z 35..41) oraz
	# obrysy bloków są wyłączone. Plan.losuj_wolne i tak odrzuci trafienie
	# w coś zajętego, ale strefa wycelowana w ścianę zjada wszystkie próby.
	var strefy := [
		[34.0, 44.0, -16.0, 16.0],    # plac garażowy
		[-26.0, -20.0, 26.0, 33.0],   # nieużytki przed działkami
		[12.0, 26.0, 26.0, 33.0],
		[-24.0, -16.0, 15.0, 19.0],   # za lewym blokiem, od strony podwórka
	]
	for i in Balans.ILE_ZLOMU_NA_START:
		var strefa: Array = strefy[randi() % strefy.size()]
		_fant(Plan.losuj_wolne(strefa), Kolekcjonerski.losowy_typ_zlomu())
	# Złom leżący pod samymi garażami - naturalne łowisko
	for i in 6:
		_fant(Plan.losuj_wolne([36.0, 43.5, -16.0, 16.0]), Kolekcjonerski.losowy_typ_zlomu())

## Jeden fant na mapie.
func _fant(pozycja: Vector3, typ: int) -> void:
	var przedmiot := Kolekcjonerski.new()
	przedmiot.typ = typ
	przedmiot.position = pozycja
	swiat.add_child(przedmiot)
