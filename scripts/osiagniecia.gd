extends Node
## OSIĄGNIĘCIA (autoload "Osiagniecia") - "KSIĘGA WSIOKA".
##
## Gra od dawna liczy wszystko, co gracz robi (Game.statystyki), tyle że te
## liczby żyły jeden dzień i lądowały na ekranie podsumowania. Tutaj dostają
## drugie życie: sumują się przez całą karierę i odblokowują wpisy w Księdze.
## Zero nowej infrastruktury - liczniki idą tym samym kanałem, co reszta gry,
## a "toast" leci istniejącym sygnałem Game.meme.
##
## Dwa rodzaje wpisów:
##   - PROGOWE  ({"licznik": "smietniki", "prog": 100}) - odblokowuje sam
##     licznik, zgłaszany przez zglos() z dowolnego miejsca w grze.
##   - ZDARZENIOWE (bez licznika) - przyznawane wprost przez przyznaj("id").
##
## Zapis: sekcja [osiagniecia] w user://kariera.cfg, obok banku i ulepszeń.
## Game.zapisz_kariere() wczytuje plik przed zapisem, więc oba systemy piszą
## do tego samego pliku, nie kasując się nawzajem.

const SCIEZKA := "user://kariera.cfg"

## Odstęp między toastami. Bez kolejki dwa osiągnięcia zdobyte w tej samej
## sekundzie (a tak bywa: "pierwszy grosz" i "król kaucji") nadpisywały się
## nawzajem i gracz widział tylko drugie.
const ODSTEP_TOASTU := 3.4

const LISTA: Array[Dictionary] = [
	# --- Zbieractwo ---
	{"id": "pierwszy_grosz", "nazwa": "Pierwszy grosz", "opis": "Podnieś swój pierwszy fant",
		"licznik": "zebrane", "prog": 1},
	{"id": "setka_fantow", "nazwa": "Setka na liczniku", "opis": "Zbierz 100 fantów w karierze",
		"licznik": "zebrane", "prog": 100},
	{"id": "pol_tysiaca", "nazwa": "Pół tysiąca", "opis": "Zbierz 500 fantów w karierze",
		"licznik": "zebrane", "prog": 500},
	{"id": "sto_smietnikow", "nazwa": "100 śmietników", "opis": "Przeszukaj 100 śmietników",
		"licznik": "smietniki", "prog": 100},
	{"id": "staly_klient", "nazwa": "Stały klient automatu", "opis": "Oddaj 250 butelek",
		"licznik": "butelki_oddane", "prog": 250},
	{"id": "handlarz_metalem", "nazwa": "Handlarz metalem", "opis": "Sprzedaj Zdziśkowi 50 szt. złomu",
		"licznik": "zlom_oddany", "prog": 50},

	# --- Życie osiedlowe ---
	{"id": "znany_w_komendzie", "nazwa": "Znany w komendzie", "opis": "Zbierz 10 mandatów",
		"licznik": "mandaty", "prog": 10},
	{"id": "kaskader", "nazwa": "Kaskader amator", "opis": "Zalicz 25 gleb",
		"licznik": "gleby", "prog": 25},
	{"id": "piesc_osiedla", "nazwa": "Pięść osiedla", "opis": "Przywal komuś 30 razy",
		"licznik": "ciosy", "prog": 30},
	{"id": "bywalec_lodowki", "nazwa": "Bywalec lodówki", "opis": "Wypij 20 piw",
		"licznik": "piwa", "prog": 20},
	{"id": "przejechany", "nazwa": "Przejechany trzy razy", "opis": "Daj się potrącić autu 3 razy",
		"licznik": "auta", "prog": 3},
	{"id": "fachowiec", "nazwa": "Osiedlowy fachowiec", "opis": "Wykonaj 10 zleceń z tablicy",
		"licznik": "zlecenia", "prog": 10},

	# --- Kariera ---
	{"id": "tydzien", "nazwa": "Tydzień na osiedlu", "opis": "Dotrwaj do dnia 7",
		"licznik": "dzien_kariery", "prog": 7},
	{"id": "miesiac", "nazwa": "Miesiąc kariery", "opis": "Dotrwaj do dnia 30",
		"licznik": "dzien_kariery", "prog": 30},
	{"id": "magnat", "nazwa": "Magnat kaucyjny", "opis": "Uzbieraj 500 zł w banku kariery",
		"licznik": "bank", "prog": 500},
	{"id": "wyposazony", "nazwa": "Kompletnie wyposażony", "opis": "Wykup wszystkie ulepszenia w MELINIE"},
	{"id": "zloty_dres", "nazwa": "ZŁOTY DRES", "opis": "Kup złoty dres. Osiedle klęka"},

	# --- Wielkie momenty ---
	{"id": "zlota_puszka", "nazwa": "Fart życia", "opis": "Znajdź ZŁOTĄ PUSZKĘ"},
	{"id": "combo_krol", "nazwa": "Król kaucji", "opis": "Wykręć combo x4"},
	{"id": "legenda", "nazwa": "Legenda osiedla", "opis": "Dobij Wsiokometr do 100%"},
	{"id": "tryb_wsioka", "nazwa": "TRYB WSIOKA", "opis": "Odpal tryb wsioka"},
	{"id": "orbita", "nazwa": "Orbita osiedlowa", "opis": "Utrzymaj się w powietrzu ponad 2 sekundy"},
	{"id": "ucieczka", "nazwa": "Kondycja zawodowca", "opis": "Zgub Straż Miejską w pościgu"},

	# --- Dni z charakterem ---
	{"id": "dzien_bez_piwa", "nazwa": "Dzień na trzeźwo", "opis": "Wyrób cel dnia bez ani jednego piwa"},
	{"id": "deszcz", "nazwa": "Pogoda nie przeszkadza", "opis": "Wyrób cel dnia w deszczu"},
	{"id": "sobota", "nazwa": "Sprzątanie po imprezie", "opis": "Wyrób cel dnia w sobotę"},
	{"id": "snieg", "nazwa": "Zimowy wsiok", "opis": "Wyrób cel dnia podczas śnieżycy"},
	{"id": "wepchniety", "nazwa": "Bez kolejki", "opis": "Wepchnij się przed babcię i wyjdź z tego cało"},
	{"id": "palacz", "nazwa": "Pół paczki dziennie", "opis": "Zapal 25 szlugów",
		"licznik": "szlugi", "prog": 25},
	{"id": "bateria", "nazwa": "Bateria z bazaru", "opis": "Wypstrykaj magnes do zera"},
	{"id": "rywal", "nazwa": "Lepszy od Heńka", "opis": "Zakończ dzień z wyższym utargiem niż Heniek"},
]

## Id zdobytych osiągnięć (na zawsze).
var zdobyte: Array[String] = []
## Liczniki narastające przez całą karierę.
var postep := {}
## Co odblokowało się DZISIAJ - ekran podsumowania to wypisuje.
var zdobyte_dzis: Array[String] = []

var _kolejka: Array[Dictionary] = []
var _do_toastu := 0.0

func _ready() -> void:
	_wczytaj()

func _process(delta: float) -> void:
	if _kolejka.is_empty():
		return
	_do_toastu -= delta
	if _do_toastu > 0.0:
		return
	_do_toastu = ODSTEP_TOASTU
	_pokaz(_kolejka.pop_front())

# --- Zgłaszanie postępu ---

## Podbicie licznika o "ile" i sprawdzenie wszystkiego, co od niego zależy.
## Wołane z całej gry: Osiagniecia.zglos("smietniki").
func zglos(licznik: String, ile := 1) -> void:
	if ile <= 0:
		return
	postep[licznik] = int(postep.get(licznik, 0)) + ile
	_sprawdz_liczniki(licznik)

## Dla wartości, które nie narastają, tylko OSIĄGAJĄ poziom (dzień kariery,
## stan banku). Licznik zapamiętuje najwyższy widziany wynik.
func sprawdz_prog(licznik: String, wartosc: float) -> void:
	var teraz := int(wartosc)
	if teraz <= int(postep.get(licznik, 0)):
		return
	postep[licznik] = teraz
	_sprawdz_liczniki(licznik)

## Przyznanie osiągnięcia wprost (zdarzenie, nie licznik).
func przyznaj(id: String) -> void:
	if zdobyte.has(id):
		return
	var wpis := znajdz(id)
	if wpis.is_empty():
		return
	zdobyte.append(id)
	zdobyte_dzis.append(str(wpis["nazwa"]))
	_kolejka.append(wpis)
	_zapisz()

func _sprawdz_liczniki(licznik: String) -> void:
	var wartosc := int(postep.get(licznik, 0))
	for wpis in LISTA:
		if wpis.get("licznik", "") == licznik and wartosc >= int(wpis.get("prog", 0)):
			przyznaj(str(wpis["id"]))

# --- Odpytywanie (HUD, ekran podsumowania) ---

func znajdz(id: String) -> Dictionary:
	for wpis in LISTA:
		if wpis["id"] == id:
			return wpis
	return {}

func ile_zdobytych() -> int:
	return zdobyte.size()

func ile_wszystkich() -> int:
	return LISTA.size()

## Czy dane osiągnięcie jest już w Księdze.
func czy_zdobyte(id: String) -> bool:
	return zdobyte.has(id)

## Postęp progowego osiągnięcia jako tekst ("62/100"). Pusty dla zdarzeniowych.
func opis_postepu(id: String) -> String:
	var wpis := znajdz(id)
	if wpis.is_empty() or not wpis.has("licznik"):
		return ""
	return "%d/%d" % [int(postep.get(wpis["licznik"], 0)), int(wpis["prog"])]

## Reset licznika "co dziś zdobyte" - wołany przy starcie nowego dnia.
func nowy_dzien() -> void:
	zdobyte_dzis.clear()

## Wyczyszczenie całej Księgi - wołane tylko przez Game.skasuj_kariere(),
## czyli z panelu ustawień, po dwukrotnym potwierdzeniu.
func skasuj() -> void:
	zdobyte.clear()
	zdobyte_dzis.clear()
	postep = {}
	_kolejka.clear()
	_zapisz()

# --- Toast ---

func _pokaz(wpis: Dictionary) -> void:
	Sfx.graj("zlota", -1.0, 1.15)
	Game.pokaz_meme("OSIĄGNIĘCIE: %s" % str(wpis["nazwa"]).to_upper())
	Game.pokaz_komunikat("Księga wsioka [%d/%d]: %s - %s" % [
		ile_zdobytych(), ile_wszystkich(), wpis["nazwa"], wpis["opis"],
	])

# --- Zapis w user://kariera.cfg (sekcja [osiagniecia]) ---

func _zapisz() -> void:
	# Narzędzia deweloperskie (--testy, --zrzut) przewijają dni i nabijają
	# statystyki. Bez tej blokady każdy przebieg testów odblokowywałby
	# graczowi pół Księgi.
	if Game.tryb_narzedziowy:
		return
	var cfg := ConfigFile.new()
	cfg.load(SCIEZKA)   # nie kasujemy sekcji pisanych przez Game
	cfg.set_value("osiagniecia", "zdobyte", zdobyte)
	cfg.set_value("osiagniecia", "postep", postep)
	cfg.save(SCIEZKA)

func _wczytaj() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SCIEZKA) != OK:
		return
	var wczytane: Variant = cfg.get_value("osiagniecia", "zdobyte", [])
	zdobyte.clear()
	for id in wczytane:
		# Wpisy usunięte z LISTY (np. po przebalansowaniu) po prostu odpadają
		if not znajdz(str(id)).is_empty():
			zdobyte.append(str(id))
	postep = cfg.get_value("osiagniecia", "postep", {})
