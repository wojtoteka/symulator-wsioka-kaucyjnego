extends Node
## AUTOTESTY (narzędzie deweloperskie) - uruchamiane przez:
##   godot --headless -- --autostart --testy
## Sprawdzają logikę, której nie da się przeklikać w trybie headless:
## plecak z kategoriami, wyprzedaż w butelkomacie/skupie, zlecenia z JSON-a.
## Wypisują raport i kończą grę kodem wyjścia 0 (sukces) albo 1 (błąd).

## Plan osiedla (JEZDNIE, BUDYNKI, czy_zajete) mieszka w scripts/plan_osiedla.gd
## i jest dostępny globalnie jako "Plan" - stąd brak preloadu.
const Auto := preload("res://scripts/auto.gd")

var _bledy := 0
var _testy := 0

func _ready() -> void:
	# Dajemy grze klatkę na złożenie świata, dopiero potem sprawdzamy
	await get_tree().process_frame
	await get_tree().process_frame
	print("\n===== AUTOTESTY: SYMULATOR WSIOKA KAUCYJNEGO =====")
	_test_plecak_kategorie()
	_test_miejsca_w_plecaku()
	_test_oddawanie_rozdzielne()
	_test_zlecenia_json()
	_test_przebieg_zlecenia()
	_test_kurs_zlomu()
	_test_swiat()
	await _test_kolizje()
	_test_rozmieszczenie()
	_test_kompas()
	_test_cel_i_rozliczenie()
	_test_limit_lotow()
	await _test_ruch_uliczny()
	_test_dni_tygodnia()
	_test_pogoda()
	_test_tryb_wsioka()
	_test_osiagniecia()
	_test_rywalizacja()
	_test_butelkomaty()
	print("=====================================================")
	if _bledy == 0:
		print("WYNIK: wszystkie %d testy przeszły. Kaucja bezpieczna." % _testy)
	else:
		printerr("WYNIK: %d z %d testów NIE przeszło!" % [_bledy, _testy])
	get_tree().quit(0 if _bledy == 0 else 1)

## Pojedyncze sprawdzenie z ładnym raportem.
func _sprawdz(opis: String, warunek: bool) -> void:
	_testy += 1
	if warunek:
		print("  [OK]  %s" % opis)
	else:
		_bledy += 1
		printerr("  [BŁĄD] %s" % opis)

## Czysty stan przed testem kwotowym. Wsiokometr zerujemy CELOWO: kolejne
## testy podnoszą dziesiątki fantów, pasek dobijał do 100%, odpalał TRYB
## WSIOKA i od tego momentu każda kwota w teście była podwójna. Test balansu
## musi liczyć w cenach normalnych.
func _wyczysc_plecak() -> void:
	Game.plecak.clear()
	Game.kasa = 0.0
	Game.combo = 0
	Game.wsiokometr = 0.0
	Game.tryb_wsioka = 0.0
	Game._legenda_ogloszona = false

# --- Testy ---

func _test_plecak_kategorie() -> void:
	print("\n[1] Plecak rozróżnia kaucję i złom")
	_wyczysc_plecak()
	Game.podnies_przedmiot({"nazwa": "butelka", "kaucja": 0.5, "kategoria": "kaucja", "miejsca": 1})
	Game.podnies_przedmiot({"nazwa": "felga", "kaucja": 4.0, "kategoria": "zlom", "miejsca": 2})
	_sprawdz("w plecaku 1 fant kaucyjny", Game.ile_w_plecaku("kaucja") == 1)
	_sprawdz("w plecaku 1 kawałek złomu", Game.ile_w_plecaku("zlom") == 1)
	_sprawdz("felga zajmuje 2 miejsca (razem 3)", Game.zajete_miejsca() == 3)

func _test_miejsca_w_plecaku() -> void:
	print("\n[2] Ciężki złom nie wchodzi do pełnego plecaka")
	_wyczysc_plecak()
	var pojemnosc := Game.pojemnosc_plecaka()
	# Zapełniamy plecak, zostawiając 2 wolne miejsca
	for i in pojemnosc - 2:
		Game.podnies_przedmiot({"nazwa": "puszka", "kaucja": 0.5})
	var wynik: Dictionary = Game.podnies_przedmiot({
		"nazwa": "akumulator", "kaucja": 12.0, "kategoria": "zlom", "miejsca": 4,
	})
	_sprawdz("akumulator (4 miejsca) odrzucony przy 2 wolnych", not wynik.get("ok", false))
	var wynik2: Dictionary = Game.podnies_przedmiot({"nazwa": "puszka", "kaucja": 0.5})
	_sprawdz("zwykła puszka nadal wchodzi", wynik2.get("ok", false))

func _test_oddawanie_rozdzielne() -> void:
	print("\n[3] Butelkomat bierze butelki, skup bierze złom")
	_wyczysc_plecak()
	Game.podnies_przedmiot({"nazwa": "butelka", "kaucja": 1.0})
	Game.combo = 0   # zerujemy, żeby mnożnik nie zaburzał kwot
	Game.podnies_przedmiot({"nazwa": "kabel", "kaucja": 2.0, "kategoria": "zlom", "miejsca": 1})
	var przed := Game.kasa
	var butelki: Dictionary = Game.oddaj_wszystko()
	_sprawdz("butelkomat przyjął dokładnie 1 szt.", butelki["ile"] == 1)
	_sprawdz("złom został w plecaku", Game.ile_w_plecaku("zlom") == 1)
	var zlom: Dictionary = Game.oddaj_kategorie("zlom", 2.0)
	_sprawdz("skup przyjął złom", zlom["ile"] == 1)
	# Kabel wart 2 zł, kurs 2.0 -> 4 zł na rękę
	_sprawdz("kurs 2.0 podwoił wypłatę za złom", is_equal_approx(zlom["kwota"], 4.0))
	_sprawdz("plecak pusty po obu transakcjach", Game.plecak.is_empty())
	_sprawdz("kasa urosła", Game.kasa > przed)

func _test_zlecenia_json() -> void:
	print("\n[4] Zlecenia wczytane z data/zlecenia.json")
	_sprawdz("wczytano co najmniej 5 zleceń", Zlecenia.definicje.size() >= 5)
	_sprawdz("na tablicy wiszą oferty", Zlecenia.oferty.size() > 0)
	var komplet := true
	for zlecenie in Zlecenia.definicje:
		for pole in ["id", "opis", "zdarzenie", "cel", "czas", "nagroda"]:
			if not zlecenie.has(pole):
				komplet = false
	_sprawdz("każde zlecenie ma komplet pól", komplet)
	_sprawdz("bieżąca oferta nie jest pusta", not Zlecenia.biezaca_oferta().is_empty())

func _test_przebieg_zlecenia() -> void:
	print("\n[5] Pełny przebieg zlecenia: przyjęcie -> postęp -> nagroda")
	_wyczysc_plecak()
	Zlecenia.aktywne = {}
	var zlecenie := {
		"id": "test_zlecenie", "zleceniodawca": "Test", "tytul": "Testowe",
		"opis": "Zbierz %d szt.", "zdarzenie": "zebrano_kaucja", "cel": 3,
		"czas": 60, "nagroda": 10.0, "prestiz": 5.0,
	}
	_sprawdz("zlecenie przyjęte", Zlecenia.przyjmij(zlecenie))
	_sprawdz("drugie zlecenie odrzucone (jedno naraz)", not Zlecenia.przyjmij(zlecenie))
	Zlecenia.zglos("zebrano_kaucja")
	_sprawdz("postęp po 1 zgłoszeniu", int(Zlecenia.aktywne["postep"]) == 1)
	Zlecenia.zglos("zebrano_zlom")   # nie ten typ zdarzenia
	_sprawdz("obce zdarzenie nie liczy się do celu", int(Zlecenia.aktywne["postep"]) == 1)
	var kasa_przed := Game.kasa
	Zlecenia.zglos("zebrano_kaucja", 2)
	_sprawdz("zlecenie zamknięte po osiągnięciu celu", not Zlecenia.czy_aktywne())
	_sprawdz("nagroda wypłacona", is_equal_approx(Game.kasa, kasa_przed + 10.0))
	_sprawdz("zlecenie na liście wykonanych", Zlecenia.czy_wykonane("test_zlecenie"))

func _test_kurs_zlomu() -> void:
	print("\n[6] Skup, butelkomat i widełki balansu")
	# Widełki zależą od dnia tygodnia (poniedziałek tnie kurs), więc pytamy
	# o nie Game - inaczej test wywalałby się co siódmy dzień kariery
	var widelki: Array = Game.widelki_kursu()
	var w_zakresie: bool = Game.kurs_zlomu >= float(widelki[0]) - 0.001 and Game.kurs_zlomu <= float(widelki[1]) + 0.001
	_sprawdz("kurs mieści się w widełkach z balansu (%s)" % Game.nazwa_dnia_tygodnia(), w_zakresie)
	_sprawdz("opis kursu nie jest pusty", Game.opis_kursu().length() > 0)
	# Butelkomat ma wnerwiać, ale nie blokować. Zapchanie niczego nie odbiera -
	# gracz traci kilka sekund i jeden kopniak. Te dwa warunki pilnują, żeby
	# przy kolejnym podkręcaniu awaryjności nie zrobić z automatu ściany.
	_sprawdz("zapchany butelkomat zawsze da się odetkać", Balans.SZANSA_ODETKANIA > 0.5)
	_sprawdz("butelkomat częściej działa, niż się psuje", Balans.SZANSA_ZAPCHANIA < 0.5)

func _test_swiat() -> void:
	print("\n[7] Świat zawiera nowe obiekty")
	var drzewo := get_tree().root
	_sprawdz("są auta na obwodnicy", get_tree().get_nodes_in_group("auta").size() > 0)
	_sprawdz("są cele nawigacji (butelkomaty, skup, tablica, skuter)",
		get_tree().get_nodes_in_group("cel_nawigacji").size() >= 6)
	_sprawdz("jest patrol straży", get_tree().get_nodes_in_group("straz").size() > 0)
	var ile_fantow := get_tree().get_nodes_in_group("kolekcjonerskie").size()
	_sprawdz("na mapie leżą fanty (%d szt.)" % ile_fantow, ile_fantow >= 30)
	_sprawdz("gracz istnieje", get_tree().get_nodes_in_group("gracz").size() == 1)
	_sprawdz("drzewo sceny żyje", drzewo != null)

## Czy świat jest FIZYCZNY, a nie tylko namalowany. Oglądanie zrzutów tego
## nie wykryje: obiekt bez kolizji wygląda identycznie jak z kolizją, różnicę
## widać dopiero, gdy gracz przez niego przejdzie. Dlatego pytamy wprost
## silnik fizyki, czy w danym punkcie stoi jakieś ciało.
func _test_kolizje() -> void:
	print("\n[8] Przez świat nie da się przejść na wylot")
	# Fizyka rejestruje nowe ciała dopiero w kroku fizycznym
	await get_tree().physics_frame
	await get_tree().physics_frame
	_sprawdz("latarnia przy chodniku jest twarda", _czy_cos_stoi(Vector3(2.6, 1.0, 16)))
	_sprawdz("płot wokół mapy zatrzymuje", _czy_cos_stoi(Vector3(0, 0.6, 59)))
	_sprawdz("krzak jest przeszkodą", _czy_cos_stoi(Vector3(-13.5, 0.25, 16)))
	_sprawdz("sterta opon jest przeszkodą", _czy_cos_stoi(Vector3(36.5, 0.5, 15)))
	# Działka przy x=-20: płotek stoi, ale furtka (środek boku od alejki)
	# musi zostać przejściem - ogrodzenie bez wejścia to pułapka, nie ogródek
	# Północny bok działki przy x=-21.5 oraz środek jej furtki (bok od alejki)
	_sprawdz("płotek działki jest twardy", _czy_cos_stoi(Vector3(-21.5, 0.5, 41.5)))
	_sprawdz("furtka w działce jest przejściem", not _czy_cos_stoi(Vector3(-16.5, 0.5, 47.5)))
	# Rampa przeniesiona z obwodnicy na plac garażowy
	# Rampa to pochylona deska grubości 14 cm - trafienie w nią punktem jest
	# loterią, więc mierzymy ją promieniem z góry: nad placem coś wystaje
	# ponad grunt, nad jezdnią już nie.
	_sprawdz("nad jezdnią (x=30) jest czysto", _wysokosc_terenu(30, 16) < 0.2)
	_sprawdz("rampa stoi na placu garażowym", _wysokosc_terenu(42, 12) > 0.2)
	# Korona drzewa musi zatrzymywać wysięgnik kamery, ale NIE gracza.
	# Bez tej osłony kamera TPP wjeżdżała w liście i - bo bryły mają kontur
	# rysowany od środka - pół ekranu robiło się czarne. Drzewo stoi w (26,0,28).
	#
	# Próbkę bierzemy 60 cm OBOK pnia: drzewa mają losową skalę (0,85-1,3),
	# więc przy tych większych pień sięga powyżej 2,55 m i punkt na osi trafiałby
	# raz w pień (warstwa świata), a raz nie - test wychodził losowo.
	var w_koronie := Vector3(26.6, 2.55, 28)
	_sprawdz("korona drzewa zasłania wysięgnik kamery",
		_czy_cos_stoi(w_koronie, Balans.WARSTWA_KAMERY))
	_sprawdz("ale gracza korona nie blokuje", not _czy_cos_stoi(w_koronie, 1))

## Czy cokolwiek nie stoi tam, gdzie już coś jest. Ten test powstał po tym,
## jak w grze znalazło się pięć drzew rosnących na obwodnicy, drzewo i krzak
## w środku bloku oraz dwa kontenery na jezdni - a sama obwodnica biegła
## przez Biedronkę, więc auta wyjeżdżały ze sklepu.
func _test_rozmieszczenie() -> void:
	print("\n[9] Nic nie stoi na jezdni ani w budynku")
	for grupa in ["drzewo", "krzak", "smietnik"]:
		var winne: Array[String] = []
		for wezel in get_tree().get_nodes_in_group(grupa):
			var p: Vector3 = wezel.global_position
			if Plan.czy_zajete(p.x, p.z):
				winne.append("(%.0f, %.0f)" % [p.x, p.z])
		_sprawdz("%s: żaden nie stoi w zajętym miejscu%s" % [
			grupa, "" if winne.is_empty() else " - winne: " + ", ".join(winne),
		], winne.is_empty())
	# Nic, co zajmuje teren, nie może przenikać jezdni. Auta jadą po torze,
	# a nie po fizyce, więc nachodzące się prostokąty oznaczają auta w środku
	# budynku (tak było z Biedronką) albo płotek na asfalcie (tak było
	# z działkami - wszystkie cztery wchodziły metrem na obwodnicę).
	var kolidujace: Array[String] = []
	for pas in Plan.JEZDNIE:
		for i in Plan.BUDYNKI.size():
			if _nachodza(Plan.BUDYNKI[i], pas):
				kolidujace.append("budynek %d" % i)
		for x in Plan.DZIALKI_X:
			if _nachodza(Plan.obrys_dzialki(x), pas):
				kolidujace.append("działka x=%.1f" % x)
	_sprawdz("nic nie przenika jezdni%s" % (
		"" if kolidujace.is_empty() else " - kolizje: " + ", ".join(kolidujace)
	), kolidujace.is_empty())
	# Działki nie mogą też wchodzić w budę Zdziśka na końcu alejki
	var na_skupie: Array[String] = []
	for x in Plan.DZIALKI_X:
		if _nachodza(Plan.obrys_dzialki(x), Plan.BUDYNKI[5]):
			na_skupie.append("x=%.1f" % x)
	_sprawdz("działki nie wchodzą w skup złomu%s" % (
		"" if na_skupie.is_empty() else " - " + ", ".join(na_skupie)
	), na_skupie.is_empty())
	# Fanty też nie mogą lądować w ścianie
	var w_scianie := 0
	for fant in get_tree().get_nodes_in_group("kolekcjonerskie"):
		var p: Vector3 = fant.global_position
		if Plan.czy_zajete(p.x, p.z):
			w_scianie += 1
	_sprawdz("żaden fant nie wpadł w budynek ani na jezdnię (%d)" % w_scianie, w_scianie == 0)

## Radar i strzałka nawigacji. Test powstał, bo minimapa była ODWRÓCONA:
## przy yaw=0 zgadzała się przypadkiem, więc błąd ujawniał się dopiero po
## obróceniu postaci - idąc do celu widziało się kropkę uciekającą w drugą
## stronę tarczy. Dlatego sprawdzamy oba przypadki: bez obrotu i po obrocie.
func _test_kompas() -> void:
	print("\n[10] Radar i strzałka wskazują właściwą stronę")
	# Postać patrzy wzdłuż własnej osi -Z. Ekran ma Y w dół, więc "przed nami"
	# to UJEMNY y.
	var przed := Kompas.na_ekran(Vector3(0, 0, -10), 0.0)
	_sprawdz("cel z przodu ląduje na górze tarczy", przed.y < -1.0 and absf(przed.x) < 0.01)
	var w_prawo := Kompas.na_ekran(Vector3(10, 0, 0), 0.0)
	_sprawdz("cel z prawej ląduje po prawej", w_prawo.x > 1.0 and absf(w_prawo.y) < 0.01)
	# Po obrocie o 90° postać patrzy na -X, a jej prawa ręka wskazuje -Z
	var przed_po_obrocie := Kompas.na_ekran(Vector3(-10, 0, 0), PI / 2.0)
	_sprawdz("po obrocie cel z przodu nadal na górze",
		przed_po_obrocie.y < -1.0 and absf(przed_po_obrocie.x) < 0.01)
	var bok_po_obrocie := Kompas.na_ekran(Vector3(0, 0, -10), PI / 2.0)
	_sprawdz("po obrocie cel z boku po właściwej stronie", bok_po_obrocie.x > 1.0)
	# Strzałka rysowana jest czubkiem do góry, więc kąt 0 = "prosto przed siebie"
	_sprawdz("strzałka do celu z przodu wskazuje w górę",
		absf(Kompas.kat_strzalki(Vector3(0, 0, -10), 0.0)) < 0.01)
	_sprawdz("strzałka do celu z prawej wskazuje w prawo",
		is_equal_approx(Kompas.kat_strzalki(Vector3(10, 0, 0), 0.0), PI / 2.0))

## Cel dnia ma być inny każdego dnia, a dzień ma się rozliczać.
func _test_cel_i_rozliczenie() -> void:
	print("\n[11] Cel dnia i rozliczenie")
	var baza: float = (Balans.CEL_BAZOWY + Balans.CEL_ZA_DZIEN * (Game.dzien - 1)) 		* Game.mnoznik_celu_dnia()
	var warianty := {}
	for i in 40:
		Game._losuj_cel_dnia()
		warianty[Game.cel_dnia] = true
		if Game.cel_dnia < baza * 0.75 or Game.cel_dnia > baza * 1.3:
			warianty["POZA_WIDELKAMI"] = true
	_sprawdz("cel bywa różny (%d wariantów)" % warianty.size(), warianty.size() >= 3)
	_sprawdz("cel trzyma się widełek wokół bazy", not warianty.has("POZA_WIDELKAMI"))
	_sprawdz("cel to okrągła kwota",
		is_zero_approx(fmod(Game.cel_dnia, Balans.CEL_ZAOKRAGLENIE)))
	_sprawdz("premia i kara są dodatnie", Game.premia_dnia() > 0.0 and Game.kara_dnia() > 0.0)
	# Cel musi zaliczać się z KAŻDEGO źródła kasy. Wcześniej sprawdzał się tylko
	# przy oddawaniu butelek, więc dało się skończyć dzień z kwotą ponad cel
	# (zarobioną na zleceniach czy trikach) i mimo to dostać karę.
	Game.cel_osiagniety = false
	Game.kasa = 0.0
	Game.cel_dnia = 10.0
	Game.dodaj_kase(12.0)
	_sprawdz("cel zalicza się z dowolnego przychodu, nie tylko z butelkomatu",
		Game.cel_osiagniety)
	Game.zaplac_mandat(11.0, "test")
	_sprawdz("mandat nie odbiera raz zdobytego celu", Game.cel_osiagniety)
	# Narzędzia nie mogą dotykać zapisu gracza - testy i zrzuty przewijają dni
	# i nabijają kasę, więc bez blokady każdy przebieg dopisywałby graczowi
	# kilkadziesiąt złotych do banku kariery
	_sprawdz("tryb narzędziowy jest włączony podczas testów", Game.tryb_narzedziowy)
	var przed := FileAccess.get_modified_time(Game.SCIEZKA_KARIERY)
	Game.bank += 999.0
	Game.zapisz_kariere()
	_sprawdz("zapis kariery nie został ruszony przez test",
		FileAccess.get_modified_time(Game.SCIEZKA_KARIERY) == przed)
	Game.bank -= 999.0
	# Poprzeczka ma rosnąć z karierą, inaczej po tygodniu gra przestaje stawiać opór
	var dzien_pierwotny := Game.dzien
	Game.dzien = 1
	var premia_dzien1 := Game.premia_dnia()
	Game.dzien = 6
	_sprawdz("premia rośnie z dniem kariery", Game.premia_dnia() > premia_dzien1)
	Game.dzien = dzien_pierwotny

## Limit kasy z akrobacji. Bez niego skuter + rampa to była maszynka do
## pieniędzy: skok co trzy sekundy w kółko aż do końca dnia.
func _test_limit_lotow() -> void:
	print("\n[12] Skakanie z rampy nie jest źródłem utrzymania")
	# Sięgamy do pól prywatnych, bo odstęp między trikami liczy się z zegara
	Game._zarobek_z_lotow = 0.0
	Game._ostatni_platny_lot = -99.0
	_sprawdz("pierwszy trik płaci", Game.nagroda_za_lot(5.0) > 0.0)
	_sprawdz("trik zaraz po poprzednim nie płaci", is_zero_approx(Game.nagroda_za_lot(5.0)))
	# Wypłaty sumarycznie nie mogą przekroczyć limitu, choćby gracz skakał bez końca
	Game._zarobek_z_lotow = 0.0
	var suma := 0.0
	for i in 40:
		Game._ostatni_platny_lot = -99.0   # udajemy, że minął odstęp
		suma += Game.nagroda_za_lot(10.0)
	_sprawdz("suma wypłat mieści się w dziennym limicie (%.2f zł)" % suma,
		suma <= Balans.LOT_LIMIT_DZIENNY + 0.01)
	_sprawdz("limit zgłasza wyczerpanie", Game.limit_lotow_wyczerpany())
	Game._ostatni_platny_lot = -99.0
	_sprawdz("po wyczerpaniu limitu trik nie płaci nic",
		is_zero_approx(Game.nagroda_za_lot(50.0)))

## Ruch na obwodnicy. Auta jadą po wspólnym torze i NIE MAJĄ ze sobą kolizji,
## więc bez pilnowania odstępu szybsze wjeżdżało w wolniejsze na wylot - dwa
## nadwozia jedno w drugim wyglądały jak tramwaj. Bug ujawniał się dopiero po
## kilkudziesięciu sekundach jazdy, dlatego test przewija czas.
func _test_ruch_uliczny() -> void:
	print("\n[13] Auta na obwodnicy jeżdżą, ale nie wjeżdżają w siebie")
	var auta := get_tree().get_nodes_in_group("auta")
	_sprawdz("na obwodnicy jest ruch (%d aut)" % auta.size(), auta.size() >= 6)
	# Sam wzór na odstęp: stój przy zderzaku, pełny gaz na wolnej drodze
	_sprawdz("przy zderzaku auto staje",
		is_zero_approx(Auto.predkosc_dla_luki(1.0, 9.0)))
	_sprawdz("na wolnej drodze auto jedzie pełną prędkością",
		is_equal_approx(Auto.predkosc_dla_luki(60.0, 9.0), 9.0))
	var posrednia := Auto.predkosc_dla_luki(
		(Auto.ODSTEP_MIN + Auto.ODSTEP_BEZPIECZNY) / 2.0, 9.0)
	_sprawdz("między progami auto zwalnia płynnie", posrednia > 0.0 and posrednia < 9.0)
	if auta.is_empty():
		return
	# Że auta w ogóle jadą - sprawdzamy na żywej scenie
	var start_pierwszego: float = auta[0].progress
	for i in 60:
		await get_tree().process_frame
	_sprawdz("auta faktycznie jadą", not is_equal_approx(auta[0].progress, start_pierwszego))
	# Że NIGDY na siebie nie wjadą - na żywej scenie tego nie udowodnimy:
	# usterka wychodziła dopiero po kilkudziesięciu sekundach, a w trybie
	# headless liczba klatek nie przekłada się na czas gry. Dlatego kolumnę
	# przewijamy w czystej symulacji: te same wzory, ustalony krok czasu,
	# trzy minuty jazdy w ułamku sekundy.
	_sprawdz("kolumna nie zderza się przez 3 minuty jazdy", _symuluj_kolumne(180.0))

## Dzień kariery ma teraz nazwę i charakter. Test pilnuje, żeby modyfikatory
## nie wyszły poza sens: sobota ma być lepsza w fantach, poniedziałek gorszy
## w kursie skupu, a tydzień ma się zawijać (dzień 8 = znowu poniedziałek).
func _test_dni_tygodnia() -> void:
	print("\n[14] Dni tygodnia mają charakter")
	var dzien_pierwotny := Game.dzien
	Game.dzien = 1
	_sprawdz("dzień 1 to poniedziałek", Game.dzien_tygodnia() == Balans.PONIEDZIALEK)
	Game.dzien = 8
	_sprawdz("dzień 8 to znowu poniedziałek (tydzień się zawija)",
		Game.dzien_tygodnia() == Balans.PONIEDZIALEK)
	Game.dzien = 6
	_sprawdz("dzień 6 to sobota", Game.dzien_tygodnia() == Balans.SOBOTA)
	_sprawdz("w sobotę leży więcej fantów", Game.mnoznik_fantow() > 1.0)
	Game.dzien = 4
	_sprawdz("w czwartek akumulatory na promocji", Game.mnoznik_akumulatora() > 1.0)
	Game.dzien = 2
	_sprawdz("we wtorek żadnych promocji", is_equal_approx(Game.mnoznik_akumulatora(), 1.0))
	# Poniedziałkowy kurs musi faktycznie być gorszy - to jedyny sposób,
	# żeby sprawdzić modyfikator, który siedzi w losowaniu
	Game.dzien = 1
	Game._losuj_kurs_zlomu()
	var kurs_poniedzialek := Game.kurs_zlomu
	_sprawdz("poniedziałkowy kurs mieści się w obniżonych widełkach",
		kurs_poniedzialek <= Balans.SKUP_MNOZNIK_MAX * Balans.PONIEDZIALEK_KURS + 0.001)
	var nazwy_ok := true
	for i in 7:
		Game.dzien = i + 1
		if Game.nazwa_dnia_tygodnia().is_empty() or Game.opis_dnia().is_empty():
			nazwy_ok = false
	_sprawdz("każdy dzień tygodnia ma nazwę i opis", nazwy_ok)
	Game.dzien = dzien_pierwotny
	Game._losuj_kurs_zlomu()

## Pogoda ma być realną zmienną rozgrywki, nie filtrem: mnożniki muszą
## faktycznie schodzić poniżej 1.0, a zachmurzenie mieścić się w 0..1.
func _test_pogoda() -> void:
	print("\n[15] Pogoda zmienia zasady, nie tylko kolory")
	var pogoda_pierwotna := Game.pogoda
	var warianty := {}
	for i in 200:
		Game._losuj_pogode()
		warianty[Game.pogoda] = true
		if Game.zachmurzenie() < 0.0 or Game.zachmurzenie() > 1.0:
			warianty["POZA_ZAKRESEM"] = true
	_sprawdz("losują się wszystkie trzy pogody", warianty.size() >= 3)
	_sprawdz("zachmurzenie zawsze w zakresie 0-1", not warianty.has("POZA_ZAKRESEM"))
	Game.pogoda = "slonecznie"
	_sprawdz("przy słońcu nic nie jest mnożone",
		is_equal_approx(Game.mnoznik_przyczepnosci(), 1.0)
		and is_equal_approx(Game.mnoznik_hamowania(), 1.0)
		and is_zero_approx(Game.zachmurzenie()))
	Game.pogoda = "deszcz"
	_sprawdz("deszcz to deszcz", Game.deszcz())
	_sprawdz("w deszczu pojazdy tracą przyczepność", Game.mnoznik_przyczepnosci() < 1.0)
	_sprawdz("w deszczu gorzej się hamuje na piechotę", Game.mnoznik_hamowania() < 1.0)
	_sprawdz("pełne zachmurzenie przy deszczu", is_equal_approx(Game.zachmurzenie(), 1.0))
	Game.pogoda = "pochmurno"
	_sprawdz("pochmurno jest pośrodku",
		Game.zachmurzenie() > 0.0 and Game.zachmurzenie() < 1.0)
	Game.pogoda = pogoda_pierwotna

## TRYB WSIOKA - nagroda za pełny Wsiokometr. Kluczowe jest to, że po
## zakończeniu pasek SPADA: bez tego szał odpalałby się w kółko i podwójna
## kaucja przestałaby być wydarzeniem.
func _test_tryb_wsioka() -> void:
	print("\n[16] Wsiokometr 100% odpala TRYB WSIOKA")
	# Czyścimy PRZED odpaleniem trybu - _wyczysc_plecak() gasi też Wsiokometr,
	# więc wywołane w środku testu wyłączyłoby to, co właśnie sprawdzamy
	_wyczysc_plecak()
	_sprawdz("bez trybu kaucja liczy się normalnie", is_equal_approx(Game.mnoznik_kaucji(), 1.0))
	Game.dodaj_wsiokometr(100.0)
	_sprawdz("pełny Wsiokometr odpala tryb", Game.tryb_wsioka_aktywny())
	_sprawdz("w trybie kaucja jest podwójna",
		is_equal_approx(Game.mnoznik_kaucji(), Balans.TRYB_WSIOKA_MNOZNIK))
	# Podniesienie w trybie musi faktycznie płacić podwójnie
	var wynik: Dictionary = Game.podnies_przedmiot({"nazwa": "puszka", "kaucja": 1.0})
	_sprawdz("fant podniesiony w trybie wart podwójnie (%.2f zł)" % float(wynik["kaucja"]),
		is_equal_approx(float(wynik["kaucja"]), 1.0 * int(wynik["mnoznik"]) * Balans.TRYB_WSIOKA_MNOZNIK))
	Game._zakoncz_tryb_wsioka()
	_sprawdz("po wygaśnięciu tryb jest wyłączony", not Game.tryb_wsioka_aktywny())
	_sprawdz("po wygaśnięciu Wsiokometr spada (%.0f%%)" % Game.wsiokometr,
		Game.wsiokometr <= Balans.TRYB_WSIOKA_PO)
	_sprawdz("kaucja wraca do normalnej ceny", is_equal_approx(Game.mnoznik_kaucji(), 1.0))
	_wyczysc_plecak()

## KSIĘGA WSIOKA. Sam fakt, że wpisy się przyznają, to za mało - najgorsze
## błędy w takim systemie to duplikaty id i wpisy progowe bez progu, bo
## odblokowują się wtedy natychmiast albo nigdy.
func _test_osiagniecia() -> void:
	print("\n[17] Osiągnięcia (Księga wsioka)")
	_sprawdz("Księga ma co najmniej 20 wpisów (%d)" % Osiagniecia.ile_wszystkich(),
		Osiagniecia.ile_wszystkich() >= 20)
	var id_widziane := {}
	var duplikaty: Array[String] = []
	var bez_progu: Array[String] = []
	for wpis in Osiagniecia.LISTA:
		var id := str(wpis["id"])
		if id_widziane.has(id):
			duplikaty.append(id)
		id_widziane[id] = true
		if wpis.has("licznik") and int(wpis.get("prog", 0)) <= 0:
			bez_progu.append(id)
		if str(wpis.get("nazwa", "")).is_empty() or str(wpis.get("opis", "")).is_empty():
			bez_progu.append(id + " (brak opisu)")
	_sprawdz("każde id jest unikalne%s" % (
		"" if duplikaty.is_empty() else " - duplikaty: " + ", ".join(duplikaty)
	), duplikaty.is_empty())
	_sprawdz("wpisy progowe mają dodatni próg i komplet opisów%s" % (
		"" if bez_progu.is_empty() else " - winne: " + ", ".join(bez_progu)
	), bez_progu.is_empty())
	# Przyznawanie i odporność na powtórki
	Osiagniecia.przyznaj("legenda")
	var ile_po_pierwszym := Osiagniecia.ile_zdobytych()
	Osiagniecia.przyznaj("legenda")
	_sprawdz("to samo osiągnięcie nie liczy się dwa razy",
		Osiagniecia.ile_zdobytych() == ile_po_pierwszym)
	_sprawdz("zdobyte osiągnięcie jest w Księdze", Osiagniecia.czy_zdobyte("legenda"))
	Osiagniecia.przyznaj("nie_ma_takiego_osiagniecia")
	_sprawdz("nieznane id nie psuje Księgi",
		Osiagniecia.ile_zdobytych() == ile_po_pierwszym)
	# Licznik progowy: "pierwszy grosz" odblokowuje pierwszy zebrany fant
	Osiagniecia.zglos("zebrane")
	_sprawdz("licznik odblokowuje wpis progowy", Osiagniecia.czy_zdobyte("pierwszy_grosz"))
	_sprawdz("opis postępu wpisu progowego nie jest pusty",
		not Osiagniecia.opis_postepu("sto_smietnikow").is_empty())
	_sprawdz("wpis zdarzeniowy nie ma opisu postępu",
		Osiagniecia.opis_postepu("legenda").is_empty())
	# sprawdz_prog zapamiętuje NAJWYŻSZY wynik, a nie sumuje
	Osiagniecia.sprawdz_prog("bank", 100.0)
	Osiagniecia.sprawdz_prog("bank", 50.0)
	_sprawdz("próg zapamiętuje najwyższy wynik, nie sumuje",
		int(Osiagniecia.postep.get("bank", 0)) == 100)

## POJEDYNEK Z HEŃKIEM - licznik rywala i rozliczenie na koniec dnia.
func _test_rywalizacja() -> void:
	print("\n[18] Pojedynek z Heńkiem")
	Game.konkurent_kasa = 0.0
	Game.konkurent_sztuk = 0
	Game.kasa = 0.0
	Game.konkurent_zebral(1.5)
	Game.konkurent_zebral(0.5)
	_sprawdz("łup Heńka się sumuje", is_equal_approx(Game.konkurent_kasa, 2.0))
	_sprawdz("licznik sztuk rośnie", Game.konkurent_sztuk == 2)
	_sprawdz("przy pustej kasie prowadzi Heniek", Game.przewaga_nad_konkurentem() < 0.0)
	Game.dodaj_kase(5.0)
	_sprawdz("po zarobku prowadzisz ty", Game.przewaga_nad_konkurentem() > 0.0)
	_sprawdz("premia za wygraną z Heńkiem jest dodatnia", Balans.PREMIA_ZA_HENIEKA > 0.0)
	# Fant na mapie musi umieć podać swoją wartość - inaczej Heniek zbierałby
	# butelki "za darmo" i licznik stałby w miejscu
	var fanty := get_tree().get_nodes_in_group("kolekcjonerskie")
	var wartosci_ok := true
	for fant in fanty:
		if not fant.has_method("wartosc") or float(fant.wartosc()) <= 0.0:
			wartosci_ok = false
			break
	_sprawdz("każdy fant zna swoją wartość (Heniek ją liczy)", wartosci_ok)
	_wyczysc_plecak()

## Trzy butelkomaty zamiast jednego i kolejka babć.
func _test_butelkomaty() -> void:
	print("\n[19] Butelkomaty: trzy punkty i kolejka")
	var automaty := get_tree().get_nodes_in_group("butelkomat")
	_sprawdz("na mapie stoją co najmniej trzy butelkomaty (%d)" % automaty.size(),
		automaty.size() >= 3)
	var nazwy := {}
	var rozstawione := true
	for automat in automaty:
		nazwy[str(automat.nazwa_punktu)] = true
		if not automat.has_method("czy_kolejka"):
			rozstawione = false
	_sprawdz("każdy punkt ma własną nazwę (%d różnych)" % nazwy.size(),
		nazwy.size() == automaty.size())
	_sprawdz("każdy automat umie zgłosić kolejkę", rozstawione)
	# Punkty muszą być ROZRZUCONE - trzy automaty obok siebie nie dają
	# żadnego wyboru, a o wybór w tym chodzi
	var najmniejszy_odstep := INF
	for i in automaty.size():
		for j in range(i + 1, automaty.size()):
			najmniejszy_odstep = minf(najmniejszy_odstep,
				automaty[i].global_position.distance_to(automaty[j].global_position))
	_sprawdz("automaty dzieli co najmniej 20 m (%.0f m)" % najmniejszy_odstep,
		najmniejszy_odstep >= 20.0)
	_sprawdz("kolejka nie trwa dłużej niż kilkanaście sekund",
		Balans.KOLEJKA_MAX <= 15.0 and Balans.KOLEJKA_MIN > 0.0)

## Symulacja kolumny aut na pętli tą samą logiką, co w grze.
## Zwraca false, jeśli w którymkolwiek momencie odstęp spadł poniżej długości
## nadwozia (czyli auta zaczęłyby się przenikać).
func _symuluj_kolumne(sekundy: float) -> bool:
	const DLUGOSC_PETLI := 281.0     # obwodnica osiedla
	const DLUGOSC_NADWOZIA := 3.9
	var ile: int = Balans.ILE_AUT
	var pozycje: Array[float] = []
	var maks: Array[float] = []
	var predkosci: Array[float] = []
	for i in ile:
		pozycje.append(DLUGOSC_PETLI * float(i) / float(ile))
		# Rozrzut prędkości jak w world.gd (6.0-9.5), ale deterministyczny
		maks.append(6.0 + 3.5 * float(i) / float(ile - 1))
		predkosci.append(maks[i])
	var krok := 1.0 / 60.0
	var klatki := int(sekundy / krok)
	for klatka in klatki:
		var nowe := predkosci.duplicate()
		for i in ile:
			var luka := INF
			for j in ile:
				if i == j:
					continue
				luka = minf(luka, fposmod(pozycje[j] - pozycje[i], DLUGOSC_PETLI))
			if luka < DLUGOSC_NADWOZIA:
				return false   # auta weszły w siebie
			var cel := Auto.predkosc_dla_luki(luka, maks[i])
			var zmiana := Auto.HAMOWANIE if cel < predkosci[i] else Auto.PRZYSPIESZENIE
			nowe[i] = move_toward(predkosci[i], cel, zmiana * krok)
		predkosci = nowe
		for i in ile:
			pozycje[i] += predkosci[i] * krok
	return true

## Czy dwa prostokąty [x_min, x_max, z_min, z_max] zachodzą na siebie.
func _nachodza(a: Array, b: Array) -> bool:
	return a[0] < b[1] and a[1] > b[0] and a[2] < b[3] and a[3] > b[2]

## Na jakiej wysokości promień puszczony z góry trafia w coś twardego.
## Sam trawnik daje 0.0, więc każdy wynik wyżej oznacza obiekt nad gruntem.
func _wysokosc_terenu(x: float, z: float) -> float:
	var przestrzen := get_tree().root.get_world_3d().direct_space_state
	var promien := PhysicsRayQueryParameters3D.create(
		Vector3(x, 4.0, z), Vector3(x, -0.5, z))
	# Tylko warstwa świata: auta mają własną bryłę dla kamery i przejeżdżający
	# samochód potrafiłby udawać, że nad jezdnią coś stoi
	promien.collision_mask = 1
	var trafienie := przestrzen.intersect_ray(promien)
	return 0.0 if trafienie.is_empty() else float(trafienie["position"].y)

## Czy w podanym punkcie znajduje się jakiekolwiek ciało statyczne.
func _czy_cos_stoi(punkt: Vector3, warstwy := 1) -> bool:
	var przestrzen := get_tree().root.get_world_3d().direct_space_state
	var zapytanie := PhysicsPointQueryParameters3D.new()
	zapytanie.position = punkt
	zapytanie.collide_with_bodies = true
	zapytanie.collide_with_areas = false
	zapytanie.collision_mask = warstwy   # domyślnie sama geometria świata
	return not przestrzen.intersect_point(zapytanie, 1).is_empty()
