extends Node
## GAME MANAGER (autoload "Game")
## Globalny stan gry: kasa, plecak, czas dnia, combo, Wsiokometr,
## komunikaty, rekord. Dostępny z każdego skryptu jako "Game".

# --- Sygnały (HUD się na nie podpina) ---
signal money_changed(kwota: float)
signal backpack_changed(ile: int, maks: int)
signal time_changed(sekundy: float)
signal komunikat(tekst: String)          # śmieszne wiadomości na ekranie
signal prompt_changed(tekst: String)     # podpowiedź "E: podnieś butelkę"
signal round_ended(podsumowanie: Dictionary)
signal stamina_changed(procent: float, pali: bool)   # pasek "Papieros"
signal wsiokometr_changed(wartosc: float)            # pasek 0-100
signal combo_changed(poziom: int, mnoznik: int)      # combo przy zbieraniu
signal meme(tekst: String)                           # wielkie napisy motywacyjne
signal wstrzas(sila: float)                          # screen shake (odbiera kamera gracza)
signal przejscie(akcja: Callable)                    # fade: HUD ściemnia, wykonuje akcję, rozjaśnia
signal upojenie(pijanstwo: float, kac: float)        # 0-1: nakładka koloru na HUD
signal wyzwanie_changed(opis: String, postep: int, cel: int, zrobione: bool)
signal skup_zmiana(otwarty: bool)                    # skup złomu otwarty/zamknięty
signal zlecenie_changed(dane: Dictionary)            # aktywne zlecenie z tablicy ogłoszeń
signal tryb_wsioka_changed(aktywny: bool, pozostalo: float)   # Wsiokometr 100%
signal rywal_changed(kwota: float, sztuk: int)       # licznik Heńka obok Twojego
signal magnes_changed(sekundy: float, maks: float)   # bateria magnesu na butelki
signal szlugi_changed(sztuk: int, sekundy: float)    # paczka z kiosku + zapalony szlug
signal ustawienia_changed()                          # gracz przestawił coś w ustawieniach

# --- Ustawienia rundy (wartości w scripts/balans.gd) ---
const CZAS_RUNDY := Balans.CZAS_RUNDY
const COMBO_OKNO := Balans.COMBO_OKNO
const MAKS_MNOZNIK := Balans.MAKS_MNOZNIK
const SCIEZKA_ZAPISU := "user://najlepszy_wynik.save"
const SCIEZKA_USTAWIEN := "user://ustawienia.cfg"
const SCIEZKA_KARIERY := "user://kariera.cfg"

# --- Stan gry ---
var kasa := 0.0                  # zarobiona kaucja (zł)
var plecak: Array[Dictionary] = []   # lista przedmiotów: {"nazwa": ..., "kaucja": ...}
var czas := CZAS_RUNDY
var gra_trwa := true
var w_menu := true               # true = gracz jest w menu głównym (timer stoi)
var rekord := 0.0
var cel_dnia := Balans.CEL_BAZOWY   # losowany co dzień, patrz _losuj_cel_dnia()
var cel_osiagniety := false
var _zarobek_z_lotow := 0.0         # ile już wypłacono za akrobacje (limit dzienny)
var _ostatni_platny_lot := -99.0
var statystyki := {"zebrane": 0, "oddane": 0, "przeszukane_smietniki": 0, "zlote": 0, "combo_max": 1, "upadki": 0, "mandaty": 0, "zlom": 0, "oddany_zlom": 0, "zlecenia": 0, "loty": 0, "piwa": 0}

# --- Combo ---
var combo := 0                   # ile przedmiotów pod rząd
var _combo_odliczanie := 0.0

# --- Wsiokometr (0-100): rośnie za zbieranie, spada przy bezczynności ---
var wsiokometr := 0.0
var _czas_bezczynnosci := 0.0
var _legenda_ogloszona := false

## TRYB WSIOKA - ile sekund jeszcze trwa szał (0.0 = nie trwa).
## Odpala się sam przy Wsiokometrze 100%, patrz dodaj_wsiokometr().
var tryb_wsioka := 0.0

# --- POGODA (losowana raz na dzień) ---
## "slonecznie" / "pochmurno" / "deszcz". Nie jest to filtr na ekranie:
## deszcz zmienia liczbę przechodniów, przyczepność pojazdów i to, gdzie
## ludzie zostawiają butelki.
## "slonecznie" / "pochmurno" / "deszcz" / "snieg" (zima, od dnia ZIMA_OD_DNIA).
var pogoda := "slonecznie"

## BATERIA MAGNESU - sekundy realnej pracy, jakie zostały na dziś.
## Zużywa się tylko wtedy, gdy magnes faktycznie coś ciągnie; doładowuje się
## przy butelkomacie. Patrz zuzyj_magnes() i doladuj_magnes().
var magnes_bateria := Balans.MAGNES_BATERIA
var _magnes_ostrzezony := false

# --- RYWALIZACJA Z HEŃKIEM ---
## Heniek zawsze polował na te same butelki, tylko nikt tego nie liczył.
## Teraz jego łup ma wartość, widać ją obok Twojej kasy, a na koniec dnia
## jest rozliczenie i osobna premia za wygraną.
var konkurent_kasa := 0.0
var konkurent_sztuk := 0

## Dzienny kurs skupu złomu - codziennie inny, jak na prawdziwej giełdzie
## (a przynajmniej jak Zdzisiek twierdzi). Mnożnik ceny złomu.
var kurs_zlomu := 1.0
var skup_otwarty := true       # zamyka się przed końcem dnia - zdąż!

## Tryb narzędziowy (--testy / --zrzut): gra działa normalnie, ale NIE dotyka
## zapisu kariery gracza. Patrz zapisz_kariere().
var tryb_narzedziowy := false

var pierwszy_dzien := true     # tutorial tylko przy pierwszej rozgrywce

# --- USTAWIENIA GRACZA (user://ustawienia.cfg) ---
# Panel miał trzy pozycje i był raczej deklaracją, że ustawienia istnieją, niż
# ustawieniami. Wszystko poniżej ma jedną wspólną cechę: zmienia coś, co gracz
# WIDZI albo CZUJE od razu - i da się to wyłączyć, gdy przeszkadza.
var glosnosc := 1.0            # efekty (0-1)
var glosnosc_muzyki := 1.0     # disco polo z okna - osobno, bo nie każdy chce
var czulosc := 1.0             # mnożnik czułości myszy
var odwroc_os_y := false       # dla grających "jak w samolocie"
var pole_widzenia := 75.0      # FOV kamery (60-100)
var wstrzasy := true           # screen shake przy jacku, glebie i potrąceniu
var strzalka := true           # strzałka nawigacji prowadząca do celu
var podpowiedzi := true        # pasek tutoriala na dole ekranu

# --- KARIERA (utrzymuje się między dniami i między uruchomieniami gry) ---
var dzien := 1
var bank := 0.0                # odłożona kaucja z poprzednich dni - waluta ulepszeń
var ulepszenia := {
	"plecak": 0, "adidasy": 0, "czapka": 0, "pluca": 0, "kluczyki": 0, "dres": 0,
	"magnes": 0, "ochroniarz": 0, "przyczepa": 0,
}
## Sześć pierwszych ulepszeń podnosi LICZBY (+% do czegoś). Trzy ostatnie
## odblokowują CZASOWNIK - rzecz, której wcześniej w ogóle nie dało się zrobić.
## Dlatego są droższe i dlatego warto ich mieć więcej niż procentów.
const ULEPSZENIA_INFO := {
	"plecak": {"nazwa": "Większy plecak", "opis": "+5 miejsc za poziom", "ceny": [30.0, 60.0, 120.0]},
	"adidasy": {"nazwa": "Adidasy z bazaru", "opis": "+10% szybkości za poziom", "ceny": [40.0, 100.0]},
	"czapka": {"nazwa": "Czapka szczęścia", "opis": "Złote fanty 2x częściej", "ceny": [80.0]},
	"pluca": {"nazwa": "Mocne płuca", "opis": "Sprint pali 25% mniej za poziom", "ceny": [30.0, 70.0]},
	"kluczyki": {"nazwa": "Kluczyki do skutera", "opis": "Odpalisz Rometa przy garażach", "ceny": [90.0]},
	"dres": {"nazwa": "ZŁOTY DRES", "opis": "Prestiż +50%. Osiedle klęka", "ceny": [150.0]},
	"magnes": {"nazwa": "MAGNES NA BUTELKI", "opis": "Fanty z 3 m same wpadają do plecaka", "ceny": [120.0]},
	"ochroniarz": {"nazwa": "Znajomość z ochroniarzem", "opis": "Straż ostrzega zamiast mandatu", "ceny": [110.0]},
	"przyczepa": {"nazwa": "Przyczepka do skutera", "opis": "Skuter zbiera fanty w biegu", "ceny": [140.0]},
}

# --- WYZWANIE DNIA (losowane codziennie, nagroda w zł) ---
var wyzwanie := {}
const WYZWANIA: Array = [
	{"id": "piwa", "opis": "Nachlaj się: wypij %d piwa", "cel": 3, "nagroda": 15.0},
	{"id": "zlote", "opis": "Znajdź %d złote fanty", "cel": 2, "nagroda": 20.0},
	{"id": "smietniki", "opis": "Przeszukaj %d śmietników", "cel": 6, "nagroda": 10.0},
	{"id": "trzepak", "opis": "Zalicz %d treningi na trzepaku", "cel": 2, "nagroda": 10.0},
	{"id": "gleby", "opis": "Zalicz %d gleby (styl dowolny)", "cel": 3, "nagroda": 10.0},
	{"id": "ciosy", "opis": "Nawal komuś %d razy", "cel": 4, "nagroda": 10.0},
	{"id": "combo", "opis": "Wykręć combo x4", "cel": 1, "nagroda": 15.0},
	{"id": "zlom", "opis": "Nazbieraj %d kawałki złomu", "cel": 5, "nagroda": 15.0},
	{"id": "zlecenia", "opis": "Wykonaj %d zlecenia z tablicy", "cel": 2, "nagroda": 25.0},
]

var _ostrzezenie_skupu := false   # czy Zdzisiek już krzyknął "zamykam!"
var _ostatni_prompt := ""
var _memy_odliczanie := 18.0   # pierwszy mem po 18 s gry
var _pierwszy_mem := true      # klasyk MUSI być pierwszy

## Wielkie "motywacyjne" napisy pojawiające się co jakiś czas na środku ekranu.
const MEMY: Array[String] = [
	"NIECH ŻYJE KAUCJA I BEZROBOCIE!",
	"KAUCJA TO NIE PRACA. KAUCJA TO STYL ŻYCIA.",
	"ZBIERAJ SZKŁO, NIE ZŁUDZENIA.",
	"BUTELKA W KRZAKACH = BUTELKA W PLECAKU.",
	"OSIEDLE PAMIĘTA. OSIEDLE DOCENIA.",
	"50 GROSZY BLIŻEJ MARZEŃ.",
	"PRACA? NIE ZNAM. KAUCJĘ ZNAM.",
]

# --- Śmieszne teksty przy podnoszeniu (losowane) ---
const TEKSTY_PODNOSZENIA: Array[String] = [
	"50 groszy to 50 groszy.",
	"Ktoś to wyrzucił? Ich strata.",
	"Pachnie... kaucją.",
	"Do kolekcji!",
	"Emerytura sama się nie uzbiera.",
	"Niezła fucha!",
	"Czysty zysk, panie.",
	"Ekologia się kłania.",
]

const TEKSTY_PELNY_PLECAK: Array[String] = [
	"Plecak pełny! Leć do butelkomatu przy Biedronce!",
	"Nie udźwigniesz więcej. Butelkomat czeka!",
	"Plecak trzeszczy w szwach. Czas na Biedronkę!",
]

## Co gracz "mógłby kupić" za zarobioną kwotę - do ekranu podsumowania.
## Format: [próg_od_zł, lista tekstów do wylosowania]
const ZAKUPY: Array = [
	[0.0, [
		"Stać cię na... nic. Ale próbowałeś i to się liczy.",
		"Za to nie kupisz nawet reklamówki. Jednorazowej.",
		"Możesz sobie kupić... powietrze. Osiedlowe.",
	]],
	[5.0, [
		"Stać cię na pół piwa. Bezalkoholowego.",
		"Starczy na bilet MPK. W jedną stronę.",
		"Kupisz zapiekankę. Bez sosu.",
	]],
	[15.0, [
		"Stać cię na kebab. Mały, ale z sosem mieszanym!",
		"Starczy na paczkę fajek i zostanie na zapalniczkę.",
		"Możesz szaleć: hot-dog Z BIEDRONKI plus napój!",
	]],
	[30.0, [
		"Stać cię na zgrzewkę piwa. Sąsiedzi już pytają o wspólne granie w kapsle.",
		"Starczy na pizzę. Dużą. Z DOWOZEM.",
		"Możesz kupić kwiaty sąsiadce. Może przestanie dzwonić po straży miejskiej.",
	]],
	[60.0, [
		"Stać cię na dres. NOWY. Z metką!",
		"Starczy na doładowanie telefonu I zgrzewkę. Żyjesz jak król.",
		"Za taką kasę to już można otworzyć własny skup butelek.",
	]],
	[100.0, [
		"REKIN BIZNESU KAUCYJNEGO. Biedronka powinna dać ci etat.",
		"Stać cię na hulajnogę elektryczną. Koniec z bieganiem!",
		"Taka kwota? Sąsiadka właśnie zaczęła się kłaniać PIERWSZA.",
	]],
]

func _ready() -> void:
	_wczytaj_rekord()
	_wczytaj_ustawienia()
	_wczytaj_kariere()
	_losuj_wyzwanie()
	_losuj_pogode()          # też PO karierze - pogoda zależy od dnia tygodnia
	_losuj_cel_dnia()        # musi być PO wczytaniu kariery - cel zależy od dnia
	_losuj_kurs_zlomu()
	# Tryb deweloperski: `godot -- --autostart` pomija menu główne,
	# a `--krotki-dzien` skraca rundę do 8 s (testy ekranu podsumowania)
	if OS.get_cmdline_user_args().has("--autostart"):
		w_menu = false
	if OS.get_cmdline_user_args().has("--krotki-dzien"):
		czas = 8.0
	# Wymuszenie zimy: śnieg losuje się dopiero od dnia ZIMA_OD_DNIA, a czekanie
	# dwóch tygodni kariery, żeby obejrzeć jedną pogodę, to nie jest narzędzie.
	# Ustawiamy PRZED budową świata, więc teren i zieleń też wchodzą w bieli.
	if OS.get_cmdline_user_args().has("--snieg"):
		dzien = maxi(dzien, Balans.ZIMA_OD_DNIA)
		pogoda = "snieg"
		# Przeskok dnia zmienia też dzień tygodnia, a od niego zależą cel
		# i kurs skupu - bez przeliczenia zostałyby z poprzedniego dnia
		_losuj_cel_dnia()
		_losuj_kurs_zlomu()
	# Tryb autotestów: `--autostart --testy` sprawdza logikę i kończy grę
	if OS.get_cmdline_user_args().has("--testy"):
		w_menu = false
		tryb_narzedziowy = true
		add_child(load("res://scripts/autotest.gd").new())
	# Tryb zrzutów ekranu: `--autostart --zrzut` obchodzi mapę i zapisuje PNG
	if OS.get_cmdline_user_args().has("--zrzut"):
		w_menu = false
		tryb_narzedziowy = true
		add_child(load("res://scripts/zrzut.gd").new())

# --- Ulepszenia w akcji (reszta gry pyta o te mnożniki) ---
func pojemnosc_plecaka() -> int:
	return Balans.POJEMNOSC_PLECAKA + 5 * ulepszenia["plecak"]

func mnoznik_predkosci() -> float:
	return 1.0 + 0.1 * ulepszenia["adidasy"]

func mnoznik_szczescia() -> float:
	return 2.0 if ulepszenia["czapka"] > 0 else 1.0

func mnoznik_papierosa() -> float:
	return 1.0 - 0.25 * ulepszenia["pluca"]

## Złoty dres podbija cały przyrost Wsiokometru - prestiż to prestiż.
func mnoznik_prestizu() -> float:
	return 1.5 if int(ulepszenia.get("dres", 0)) > 0 else 1.0

## Czy gracz ma kluczyki do skutera (bez nich Romet nie odpali).
func ma_kluczyki() -> bool:
	return int(ulepszenia.get("kluczyki", 0)) > 0

## MAGNES NA BUTELKI - fanty w promieniu kilku metrów same lecą do plecaka.
func ma_magnes() -> bool:
	return int(ulepszenia.get("magnes", 0)) > 0

## ZNAJOMOŚĆ Z OCHRONIARZEM - straż ostrzega, zamiast wypisywać mandat.
func ma_ochroniarza() -> bool:
	return int(ulepszenia.get("ochroniarz", 0)) > 0

## PRZYCZEPKA DO SKUTERA - Romet zbiera fanty w biegu, jak wózek.
func ma_przyczepe() -> bool:
	return int(ulepszenia.get("przyczepa", 0)) > 0

# --- BATERIA MAGNESU ---
# Magnes bez ograniczeń robił z celu dnia formalność. Bateria nie odbiera mu
# mocy - odbiera ciągłość: masz kilkadziesiąt sekund PRACY na dzień i sam
# decydujesz, kiedy je wydać. Doładowanie leży przy butelkomacie, czyli tam,
# gdzie i tak musisz dojść, więc pętla dnia się domyka zamiast rozjeżdżać.

## Czy magnes ma jeszcze prąd (samo posiadanie ulepszenia nie wystarczy).
func magnes_dziala() -> bool:
	return ma_magnes() and magnes_bateria > 0.0

## Zużycie baterii za sekundę realnego przyciągania. Wołane przez gracza
## TYLKO wtedy, gdy magnes faktycznie coś ciągnie - zwykłe chodzenie po pustym
## trawniku nie ma prawa kosztować prądu.
func zuzyj_magnes(delta: float) -> void:
	if magnes_bateria <= 0.0:
		return
	magnes_bateria = maxf(magnes_bateria - delta, 0.0)
	magnes_changed.emit(magnes_bateria, Balans.MAGNES_BATERIA)
	if magnes_bateria <= 0.0:
		Osiagniecia.przyznaj("bateria")
		Sfx.graj("blad", -8.0)
		pokaz_komunikat("Magnes padł. Bateria z bazaru trzyma tyle, ile kosztowała - oddaj butelki, to się doładuje.")
	elif not _magnes_ostrzezony and magnes_bateria <= Balans.MAGNES_OSTRZEZENIE:
		_magnes_ostrzezony = true
		pokaz_komunikat("Magnes słabnie - zostało %d s. Butelkomat ładuje." % int(ceilf(magnes_bateria)))

# --- PACZKA SZLUGÓW ---
# Wsiokometr ucieka cały czas, więc dobicie do 100% wymaga nieprzerwanej serii -
# a seria bywa przerwana przez rzeczy, na które nie masz wpływu (kolejka,
# zapchany automat, Straż Miejska). Zapalony szlug ZATRZYMUJE ten spadek na
# kilkanaście sekund. To pierwsze narzędzie w grze, którym TRYB WSIOKA da się
# zaplanować zamiast na niego trafić - i dlatego kosztuje: przy fajce nie ma
# sprintu, a "Papieros" ledwo się regeneruje.

## Ile szlugów zostało w paczce (przechodzi na następny dzień - to jest rzecz,
## którą się KUPIŁO, a nie dzienny zasób jak bateria magnesu).
var szlugi := 0
## Sekundy palenia, jakie zostały z aktualnie zapalonego szluga.
var szlug := 0.0

## Kiosk sprzedał paczkę.
func kup_paczke() -> bool:
	if not wydaj_kase(Balans.CENA_PACZKI):
		return false
	szlugi += Balans.SZLUGI_W_PACZCE
	szlugi_changed.emit(szlugi, szlug)
	zapisz_kariere()
	return true

## Czy gracz właśnie pali (pyta o to i gracz, i Wsiokometr).
func pali_szluga() -> bool:
	return szlug > 0.0

## Zapalenie szluga (klawisz Q). Zwraca powód odmowy albo pusty tekst.
func zapal_szluga() -> String:
	if szlug > 0.0:
		return "Jeden już się pali. Dwa naraz to już nie styl, tylko desperacja."
	if szlugi <= 0:
		return "Paczka pusta. Kiosk ma nową za %s." % zl(Balans.CENA_PACZKI)
	szlugi -= 1
	szlug = Balans.SZLUG_CZAS
	dodaj_wsiokometr(Balans.SZLUG_WSIOKOMETR)
	szlugi_changed.emit(szlugi, szlug)
	Osiagniecia.zglos("szlugi")
	zapisz_kariere()
	return ""

## Doładowanie przy butelkomacie (jedna transakcja = jedno ładowanie).
func doladuj_magnes() -> void:
	if not ma_magnes():
		return
	var przed := magnes_bateria
	magnes_bateria = minf(magnes_bateria + Balans.MAGNES_LADOWANIE, Balans.MAGNES_BATERIA)
	if magnes_bateria > przed:
		_magnes_ostrzezony = magnes_bateria <= Balans.MAGNES_OSTRZEZENIE
		magnes_changed.emit(magnes_bateria, Balans.MAGNES_BATERIA)
		pokaz_komunikat("Magnes doładowany z gniazdka butelkomatu (%d s). Nikt nie widział." % int(magnes_bateria))

# =============================================================================
#  DZIEŃ TYGODNIA
# =============================================================================
# Dzień kariery był dotąd tylko licznikiem do wzoru na cel. Teraz dzień 1 to
# poniedziałek, dzień 8 znowu poniedziałek - i każdy dzień ma osobowość:
# w sobotę pod blokami leży pokłosie imprezy, w poniedziałek skup płaci marnie,
# w czwartek Zdzisiek robi promocję na akumulatory.

## 0 = poniedziałek ... 6 = niedziela.
func dzien_tygodnia() -> int:
	return (dzien - 1) % Balans.DNI_TYGODNIA.size()

func nazwa_dnia_tygodnia() -> String:
	return Balans.DNI_TYGODNIA[dzien_tygodnia()]

## Jednozdaniowy opis, czym dziś różni się osiedle - HUD i intro go pokazują.
func opis_dnia() -> String:
	# Śnieg przebija dzień tygodnia: zamieć jest ważniejszą informacją niż to,
	# że Zdzisiek ma promocję na akumulatory.
	if snieg():
		return "Zima na osiedlu - sypie, ślisko, a butelki leżą pod podcieniem Biedronki."
	match dzien_tygodnia():
		Balans.PONIEDZIALEK:
			return "Poniedziałek - skup płaci marnie, ale i osiedle mniej wymaga."
		Balans.CZWARTEK:
			return "Czwartek - Zdzisiek ma PROMOCJĘ na akumulatory!"
		Balans.SOBOTA:
			return "Sobota - po piątkowej imprezie pod blokami leży wszystko."
		Balans.NIEDZIELA:
			return "Niedziela - osiedle śpi, poprzeczka niżej."
		_:
			return "Zwykły dzień na osiedlu. Kaucja sama się nie uzbiera."

## Ile razy więcej fantów rozrzucić po mapie (sobota = po imprezie).
func mnoznik_fantow() -> float:
	return Balans.SOBOTA_FANTY if dzien_tygodnia() == Balans.SOBOTA else 1.0

## Bonus do wartości akumulatora (czwartkowa promocja Zdziśka).
func mnoznik_akumulatora() -> float:
	return Balans.CZWARTEK_AKUMULATOR if dzien_tygodnia() == Balans.CZWARTEK else 1.0

# =============================================================================
#  POGODA
# =============================================================================

## Pogoda na dziś. W sobotę częściej świeci (bo tak trzeba), w poniedziałek
## częściej leje (bo tak jest).
func _losuj_pogode() -> void:
	var los := randf()
	var deszczowo := Balans.SZANSA_DESZCZU
	if dzien_tygodnia() == Balans.SOBOTA:
		deszczowo *= 0.5
	elif dzien_tygodnia() == Balans.PONIEDZIALEK:
		deszczowo *= 1.5
	# ZIMA: od pewnego dnia kariery to, co spadłoby jako deszcz, spada jako
	# śnieg - i dochodzi własna szansa na śnieżycę przy skądinąd suchym dniu.
	if zima():
		deszczowo += Balans.SZANSA_SNIEGU
	if los < deszczowo:
		pogoda = "snieg" if zima() else "deszcz"
	elif los < deszczowo + Balans.SZANSA_POCHMURNO:
		pogoda = "pochmurno"
	else:
		pogoda = "slonecznie"

## Czy kariera dobrnęła już do zimy (patrz Balans.ZIMA_OD_DNIA).
func zima() -> bool:
	return dzien >= Balans.ZIMA_OD_DNIA

func deszcz() -> bool:
	return pogoda == "deszcz"

func snieg() -> bool:
	return pogoda == "snieg"

## Deszcz i śnieg różnią się obrazem i tym, jak bardzo się ślizga - ale dla
## reszty świata (przechodnie w domach, łup pod wiatami) znaczą to samo.
## Jedna funkcja zamiast dwóch warunków w każdym miejscu.
func mokro() -> bool:
	return deszcz() or snieg()

## 0.0 = czyste niebo, 1.0 = pełne zachmurzenie. PoraDnia miesza po tym
## całą scenę: światło, kolory nieba, mgłę i nasycenie.
func zachmurzenie() -> float:
	match pogoda:
		"deszcz": return 1.0
		"snieg": return 0.85   # śnieżyca jest jasna, mimo że nieba nie widać
		"pochmurno": return 0.45
		_: return 0.0

func opis_pogody() -> String:
	match pogoda:
		"deszcz": return "leje jak z cebra"
		"snieg": return "sypie śniegiem"
		"pochmurno": return "szaro i buro"
		_: return "słonecznie"

## Mnożnik przyczepności pojazdów - na mokrym wózek pływa, na śniegu jedzie bokiem.
func mnoznik_przyczepnosci() -> float:
	if snieg(): return Balans.SNIEG_PRZYCZEPNOSC
	return Balans.DESZCZ_PRZYCZEPNOSC if deszcz() else 1.0

## Mnożnik hamowania na piechotę - w deszczu i na śniegu dłużej się wytraca prędkość.
func mnoznik_hamowania() -> float:
	if snieg(): return Balans.SNIEG_HAMOWANIE
	return Balans.DESZCZ_HAMOWANIE if deszcz() else 1.0

## Mnożnik przyspieszania na piechotę - na mokrym adidasy buksują.
func mnoznik_przyspieszenia() -> float:
	if snieg(): return Balans.SNIEG_PRZYSPIESZENIE
	return Balans.DESZCZ_PRZYSPIESZENIE if deszcz() else 1.0

# =============================================================================
#  TRYB WSIOKA
# =============================================================================

func tryb_wsioka_aktywny() -> bool:
	return tryb_wsioka > 0.0

## Mnożnik kaucji przy podnoszeniu. Poza TRYBEM WSIOKA to zwykłe 1.0.
func mnoznik_kaucji() -> float:
	return Balans.TRYB_WSIOKA_MNOZNIK if tryb_wsioka_aktywny() else 1.0

## Odpalenie szału. Wołane z dodaj_wsiokometr() po dobiciu do 100%.
func odpal_tryb_wsioka() -> void:
	if tryb_wsioka_aktywny():
		return
	tryb_wsioka = Balans.TRYB_WSIOKA_CZAS
	tryb_wsioka_changed.emit(true, tryb_wsioka)
	Sfx.odpal_klasyk()   # legenda osiedla ma swój hymn
	wstrzasnij(0.45)
	meme.emit("TRYB WSIOKA! PODWÓJNA KAUCJA!")
	pokaz_komunikat("WSIOKOMETR 100%%! Przez %d s wszystko warte podwójnie. LEĆ!" % int(Balans.TRYB_WSIOKA_CZAS))
	Osiagniecia.przyznaj("tryb_wsioka")

## Koniec szału - Wsiokometr spada, więc trzeba wyrobić go od nowa.
func _zakoncz_tryb_wsioka() -> void:
	tryb_wsioka = 0.0
	wsiokometr = minf(wsiokometr, Balans.TRYB_WSIOKA_PO)
	_legenda_ogloszona = false
	wsiokometr_changed.emit(wsiokometr)
	tryb_wsioka_changed.emit(false, 0.0)
	Sfx.graj("koniec", -6.0)
	pokaz_komunikat("Tryb wsioka wygasł. Kaucja znowu w normalnej cenie.")

# =============================================================================
#  RYWALIZACJA Z HEŃKIEM
# =============================================================================

## Heniek zgłasza swój łup - wołane z konkurent.gd po każdej zwiniętej butelce.
func konkurent_zebral(wartosc: float) -> void:
	konkurent_kasa += wartosc
	konkurent_sztuk += 1
	rywal_changed.emit(konkurent_kasa, konkurent_sztuk)

## O ile złotych prowadzisz nad Heńkiem (ujemne = przegrywasz).
func przewaga_nad_konkurentem() -> float:
	return kasa - konkurent_kasa

## Cena następnego poziomu ulepszenia; -1 gdy maks.
func cena_ulepszenia(id: String) -> float:
	var poziom: int = ulepszenia[id]
	var ceny: Array = ULEPSZENIA_INFO[id]["ceny"]
	return -1.0 if poziom >= ceny.size() else ceny[poziom]

## Zakup w "MELINIE" (ekran podsumowania). Płacimy z banku kariery.
func kup_ulepszenie(id: String) -> bool:
	var cena := cena_ulepszenia(id)
	if cena < 0.0 or bank < cena:
		return false
	bank -= cena
	ulepszenia[id] += 1
	if id == "dres":
		Osiagniecia.przyznaj("zloty_dres")
	zapisz_kariere()
	return true

## Kurs skupu na dziś. Zdzisiek ogłasza go rano i nie podlega negocjacji.
## W poniedziałek po weekendzie płaci wyraźnie gorzej - hurtownia zamknięta,
## a Zdzisiek "musi z czegoś żyć".
func _losuj_kurs_zlomu() -> void:
	kurs_zlomu = randf_range(Balans.SKUP_MNOZNIK_MIN, Balans.SKUP_MNOZNIK_MAX)
	if dzien_tygodnia() == Balans.PONIEDZIALEK:
		kurs_zlomu *= Balans.PONIEDZIALEK_KURS
	skup_otwarty = true
	_ostrzezenie_skupu = false

## Widełki, w jakich MOŻE dziś wylądować kurs (z uwzględnieniem poniedziałku).
## Wydzielone, bo pilnuje ich test [6] - a sam mnożnik dnia tygodnia potrafi
## zejść poniżej SKUP_MNOZNIK_MIN i test bez tego wywalałby się co siódmy dzień.
func widelki_kursu() -> Array:
	var mnoznik := Balans.PONIEDZIALEK_KURS if dzien_tygodnia() == Balans.PONIEDZIALEK else 1.0
	return [Balans.SKUP_MNOZNIK_MIN * mnoznik, Balans.SKUP_MNOZNIK_MAX * mnoznik]

## Opis kursu do dymków Zdziśka i HUD-u.
func opis_kursu() -> String:
	if kurs_zlomu >= 1.3:
		return "kurs %d%% - ŻNIWA, miedź w górę!" % roundi(kurs_zlomu * 100)
	elif kurs_zlomu >= 1.05:
		return "kurs %d%% - dziś płacą przyzwoicie" % roundi(kurs_zlomu * 100)
	elif kurs_zlomu >= 0.95:
		return "kurs %d%% - normalka" % roundi(kurs_zlomu * 100)
	return "kurs %d%% - kryzys, Zdzisiek płacze" % roundi(kurs_zlomu * 100)

# --- Cel dnia ---
## Cel rośnie z dniem kariery i ma losowe wahanie, więc nigdy nie jest ten sam.
## Zaokrąglamy do pełnych piątek - "Cel: 87,43 zł" czytałoby się jak błąd.
func _losuj_cel_dnia() -> void:
	var baza := Balans.CEL_BAZOWY + Balans.CEL_ZA_DZIEN * (dzien - 1)
	# Dzień tygodnia przesuwa poprzeczkę: w sobotę pod blokami leży dwa razy
	# tyle szkła, więc cel musi być wyższy, żeby dzień nadal był dniem pracy.
	# W poniedziałek i niedzielę odwrotnie - osiedle odpuszcza.
	baza *= mnoznik_celu_dnia()
	var wahanie := randf_range(1.0 - Balans.CEL_WAHANIE, 1.0 + Balans.CEL_WAHANIE)
	cel_dnia = maxf(
		Balans.CEL_ZAOKRAGLENIE,
		roundf(baza * wahanie / Balans.CEL_ZAOKRAGLENIE) * Balans.CEL_ZAOKRAGLENIE,
	)
	_zarobek_z_lotow = 0.0
	_ostatni_platny_lot = -99.0

## Ile razy wyższy (albo niższy) jest dziś cel przez sam dzień tygodnia.
## Osobna funkcja, bo pyta o nią też test [11] - inaczej "widełki wokół bazy"
## wywalałyby się w każdą sobotę.
func mnoznik_celu_dnia() -> float:
	match dzien_tygodnia():
		Balans.SOBOTA: return Balans.SOBOTA_CEL
		Balans.PONIEDZIALEK: return Balans.PONIEDZIALEK_CEL
		Balans.NIEDZIELA: return Balans.NIEDZIELA_CEL
		_: return 1.0

## Premia za wykonanie OBU zadań dnia i kara za odpuszczenie któregokolwiek.
func premia_dnia() -> float:
	return Balans.PREMIA_BAZOWA + Balans.PREMIA_ZA_DZIEN * (dzien - 1)

func kara_dnia() -> float:
	return Balans.KARA_BAZOWA + Balans.KARA_ZA_DZIEN * (dzien - 1)

# --- Akrobacje ---
## Wypłata za lot z rampy, ograniczona limitem dziennym i odstępem czasu.
## Zwraca kwotę FAKTYCZNIE wypłaconą (0.0 = limit wyczerpany albo za szybko
## po poprzednim triku). Prestiż i napisy dostaje gracz tak czy siak - chodzi
## o to, żeby skakanie w kółko przestało być źródłem utrzymania.
func nagroda_za_lot(kwota: float) -> float:
	var teraz := Time.get_ticks_msec() / 1000.0
	if teraz - _ostatni_platny_lot < Balans.LOT_ODSTEP:
		return 0.0
	var zostalo := Balans.LOT_LIMIT_DZIENNY - _zarobek_z_lotow
	if zostalo <= 0.01:
		return 0.0
	var wyplata := minf(kwota, zostalo)
	_zarobek_z_lotow += wyplata
	_ostatni_platny_lot = teraz
	dodaj_kase(wyplata)
	return wyplata

## Czy dzienny limit kasy za akrobacje został już wyczerpany.
func limit_lotow_wyczerpany() -> bool:
	return _zarobek_z_lotow >= Balans.LOT_LIMIT_DZIENNY - 0.01

# --- Wyzwanie dnia ---
func _losuj_wyzwanie() -> void:
	wyzwanie = WYZWANIA.pick_random().duplicate()
	wyzwanie["postep"] = 0
	wyzwanie["zrobione"] = false
	wyzwanie_changed.emit(opis_wyzwania(), 0, wyzwanie["cel"], false)

func opis_wyzwania() -> String:
	# Część wyzwań ma opis bez "%d" (np. "Wykręć combo x4") - podstawianie
	# celu wywalałoby wtedy błąd formatowania
	var opis := str(wyzwanie.get("opis", ""))
	return opis % wyzwanie["cel"] if opis.contains("%") else opis

## Zgłoszenie postępu wyzwania (wołane z całej gry po id).
func postep_wyzwania(id: String, ile := 1) -> void:
	if wyzwanie.is_empty() or wyzwanie["id"] != id or wyzwanie["zrobione"] or not gra_trwa:
		return
	wyzwanie["postep"] += ile
	if wyzwanie["postep"] >= wyzwanie["cel"]:
		wyzwanie["zrobione"] = true
		dodaj_kase(wyzwanie["nagroda"])
		Sfx.graj("zlota")
		wstrzasnij(0.2)
		meme.emit("WYZWANIE DNIA ZALICZONE! +%s" % zl(wyzwanie["nagroda"]))
	wyzwanie_changed.emit(opis_wyzwania(), wyzwanie["postep"], wyzwanie["cel"], wyzwanie["zrobione"])

# --- Zapis kariery ---
func zapisz_kariere() -> void:
	# Narzędzia deweloperskie (--zrzut, --testy) przewijają dni i sztucznie
	# nabijają kasę, żeby dało się obejrzeć ekran podsumowania. Bez tej blokady
	# każde uruchomienie narzędzia dopisywało graczowi kilkadziesiąt złotych
	# do banku kariery i trzeba było ręcznie odtwarzać zapis.
	if tryb_narzedziowy:
		return
	var cfg := ConfigFile.new()
	# Wczytujemy PRZED zapisem, bo w tym samym pliku mieszkają osiągnięcia
	# (scripts/osiagniecia.gd pisze własną sekcję). Bez tego każdy zapis
	# kariery kasowałby "Księgę wsioka".
	cfg.load(SCIEZKA_KARIERY)
	cfg.set_value("kariera", "dzien", dzien)
	cfg.set_value("kariera", "bank", bank)
	cfg.set_value("kariera", "szlugi", szlugi)   # kupione, więc przechodzi na jutro
	for id in ulepszenia:
		cfg.set_value("ulepszenia", id, ulepszenia[id])
	cfg.save(SCIEZKA_KARIERY)

func _wczytaj_kariere() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SCIEZKA_KARIERY) != OK:
		return
	dzien = cfg.get_value("kariera", "dzien", 1)
	bank = cfg.get_value("kariera", "bank", 0.0)
	szlugi = cfg.get_value("kariera", "szlugi", 0)
	for id in ulepszenia:
		ulepszenia[id] = cfg.get_value("ulepszenia", id, 0)

## Gracz raportuje poziom upojenia/kaca - HUD nakłada kolorowy filtr.
func raportuj_upojenie(pijanstwo: float, kac: float) -> void:
	upojenie.emit(pijanstwo, kac)

## Screen shake - kamera gracza nasłuchuje sygnału "wstrzas".
## Da się wyłączyć w ustawieniach: dla części grających trzęsąca się kamera
## to nie "czuć jackpot", tylko powód, żeby przestać grać.
func wstrzasnij(sila: float) -> void:
	if not wstrzasy:
		return
	wstrzas.emit(sila)

## Prośba o płynne przejście: HUD ściemnia ekran, wykonuje akcję, rozjaśnia.
func popros_przejscie(akcja: Callable) -> void:
	przejscie.emit(akcja)

# --- Ustawienia gracza (zapisywane na dysku) ---
func ustaw_glosnosc(v: float) -> void:
	glosnosc = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(glosnosc, 0.001)))
	AudioServer.set_bus_mute(0, glosnosc <= 0.0)

## Muzyka (disco polo z okna) osobno od efektów - klasyk na cały regulator
## bawi raz, a gra się w to godzinami. Sfx sam czyta stąd wartość przy każdym
## odpaleniu klasyka: Game jest pierwszym autoloadem, więc w chwili wczytywania
## ustawień Sfx jeszcze nie istnieje i wołanie go tutaj wywaliłoby grę na starcie.
func ustaw_glosnosc_muzyki(v: float) -> void:
	glosnosc_muzyki = clampf(v, 0.0, 1.0)

## Pole widzenia kamery. Gracz zgłasza się po nie sygnałem, bo kamera należy
## do gracza, a ten może jeszcze nie istnieć, gdy panel się buduje.
func ustaw_pole_widzenia(v: float) -> void:
	pole_widzenia = clampf(v, 60.0, 100.0)
	ustawienia_changed.emit()

func zapisz_ustawienia() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "glosnosc", glosnosc)
	cfg.set_value("audio", "muzyka", glosnosc_muzyki)
	cfg.set_value("sterowanie", "czulosc", czulosc)
	cfg.set_value("sterowanie", "odwroc_os_y", odwroc_os_y)
	cfg.set_value("obraz", "pole_widzenia", pole_widzenia)
	cfg.set_value("obraz", "wstrzasy", wstrzasy)
	cfg.set_value("interfejs", "strzalka", strzalka)
	cfg.set_value("interfejs", "podpowiedzi", podpowiedzi)
	cfg.save(SCIEZKA_USTAWIEN)
	ustawienia_changed.emit()

func _wczytaj_ustawienia() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SCIEZKA_USTAWIEN) != OK:
		return
	czulosc = cfg.get_value("sterowanie", "czulosc", 1.0)
	odwroc_os_y = cfg.get_value("sterowanie", "odwroc_os_y", false)
	pole_widzenia = clampf(cfg.get_value("obraz", "pole_widzenia", 75.0), 60.0, 100.0)
	wstrzasy = cfg.get_value("obraz", "wstrzasy", true)
	strzalka = cfg.get_value("interfejs", "strzalka", true)
	podpowiedzi = cfg.get_value("interfejs", "podpowiedzi", true)
	ustaw_glosnosc(cfg.get_value("audio", "glosnosc", 1.0))
	ustaw_glosnosc_muzyki(cfg.get_value("audio", "muzyka", 1.0))

## Skasowanie kariery i start od zera. Nie duplikujemy resetu stanu rundy:
## dzień ustawiamy na 0, a nowy_dzien() zaraz doda 1 i wyczyści wszystko tak
## samo jak co rano. Lądujemy dokładnie na dniu 1, jednym torem kodu.
func restart_kariery() -> void:
	skasuj_kariere()
	dzien = 0
	bank = 0.0
	nowy_dzien()

## Skasowanie kariery: bank, dzień, ulepszenia i Księga wsioka. Nieodwracalne,
## więc panel ustawień pyta dwa razy - tutaj tylko wykonujemy.
func skasuj_kariere() -> void:
	dzien = 1
	bank = 0.0
	szlugi = 0
	for id in ulepszenia:
		ulepszenia[id] = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCIEZKA_KARIERY))
	Osiagniecia.skasuj()
	rekord = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCIEZKA_ZAPISU))

func _process(delta: float) -> void:
	if not gra_trwa or w_menu:
		return
	# Odliczanie czasu dnia
	czas -= delta
	time_changed.emit(maxf(czas, 0.0))
	if czas <= 0.0:
		koniec_dnia()
		return
	# Skup złomu zamyka się przed końcem dnia - Zdzisiek ma swoje życie
	if skup_otwarty:
		if not _ostrzezenie_skupu and czas <= Balans.SKUP_OSTRZEZENIE:
			_ostrzezenie_skupu = true
			pokaz_komunikat("Zdzisiek ze skupu: \"Zamykam za 2 minuty! Kto ma złom, ten leci!\"")
		if czas <= Balans.SKUP_ZAMYKA_SIE:
			skup_otwarty = false
			skup_zmiana.emit(false)
			Sfx.graj("blad")
			pokaz_komunikat("SKUP ZAMKNIĘTY. Złom w plecaku jest teraz wart tyle, co Twoje plany na jutro.")
	# Odliczanie okna combo
	if combo > 0:
		_combo_odliczanie -= delta
		if _combo_odliczanie <= 0.0:
			combo = 0
			combo_changed.emit(0, 1)
	# TRYB WSIOKA odlicza się niezależnie od wszystkiego innego
	if tryb_wsioka > 0.0:
		tryb_wsioka -= delta
		if tryb_wsioka <= 0.0:
			_zakoncz_tryb_wsioka()
		else:
			tryb_wsioka_changed.emit(true, tryb_wsioka)
	# Wsiokometr ucieka CAŁY CZAS, a przy staniu w miejscu ucieka szybciej.
	# (W TRYBIE WSIOKA stoi - szał trwa swoje piętnaście sekund niezależnie
	# od tego, co robisz. Przy zapalonym szlugu też stoi - za to się płaci.)
	elif wsiokometr > 0.0 and szlug <= 0.0:
		var spadek := Balans.WSIOKOMETR_SPADEK_STALY
		if _czas_bezczynnosci > 3.0:
			spadek = Balans.WSIOKOMETR_SPADEK
		wsiokometr = maxf(wsiokometr - spadek * delta, 0.0)
		wsiokometr_changed.emit(wsiokometr)
	# Zapalony szlug: odliczanie i meldunek do HUD-u co klatkę
	if szlug > 0.0:
		szlug = maxf(szlug - delta, 0.0)
		szlugi_changed.emit(szlugi, szlug)
		if szlug <= 0.0:
			Sfx.graj("grzebanie", -18.0, 0.7)
			pokaz_komunikat("Szlug do filtra. Pet w kratkę i wracamy do roboty.")
	if wsiokometr < 60.0:
		_legenda_ogloszona = false   # można zostać legendą ponownie
	# Memy motywacyjne co ~pół minuty
	_memy_odliczanie -= delta
	if _memy_odliczanie <= 0.0:
		_memy_odliczanie = randf_range(28.0, 45.0)
		if _pierwszy_mem:
			_pierwszy_mem = false
			meme.emit(MEMY[0])   # "NIECH ŻYJE KAUCJA I BEZROBOCIE!" - gwarantowany
		else:
			meme.emit(MEMY.pick_random())

## Start gry z menu głównego.
func start_gry() -> void:
	w_menu = false

## Gracz raportuje swoją prędkość co klatkę - do liczenia bezczynności.
func raportuj_ruch(predkosc_pozioma: float, delta: float) -> void:
	if predkosc_pozioma > 0.5:
		_czas_bezczynnosci = 0.0
	else:
		_czas_bezczynnosci += delta

## Pasek "Papieros" (stamina) - gracz przekazuje stan, HUD wyświetla.
func ustaw_stamine(procent: float, pali: bool) -> void:
	stamina_changed.emit(procent, pali)

## Ile slotów plecaka jest zajętych (akumulator zajmuje 4, felga 2).
func zajete_miejsca() -> int:
	var suma := 0
	for przedmiot in plecak:
		suma += int(przedmiot.get("miejsca", 1))
	return suma

## Ile sztuk danej kategorii ("kaucja" / "zlom") niesiemy.
func ile_w_plecaku(kat: String) -> int:
	var ile := 0
	for przedmiot in plecak:
		if przedmiot.get("kategoria", "kaucja") == kat:
			ile += 1
	return ile

## Podniesienie przedmiotu: obsługuje plecak, combo i Wsiokometr.
## Zwraca {"ok": bool, "kaucja": float po mnożniku, "combo": int, "mnoznik": int}
func podnies_przedmiot(dane: Dictionary, bonus_wsiokometru := 4.0) -> Dictionary:
	var slotow := int(dane.get("miejsca", 1))
	if zajete_miejsca() + slotow > pojemnosc_plecaka():
		if slotow > 1 and zajete_miejsca() < pojemnosc_plecaka():
			pokaz_komunikat("%s się nie zmieści - potrzeba %d wolnych miejsc. Opróżnij plecak!" % [dane["nazwa"], slotow])
		else:
			pokaz_komunikat(TEKSTY_PELNY_PLECAK.pick_random())
		return {"ok": false}
	# Combo: kolejne podniesienie w oknie czasowym zwiększa mnożnik kaucji
	combo += 1
	_combo_odliczanie = COMBO_OKNO
	var mnoznik: int = mini(combo, MAKS_MNOZNIK)
	statystyki["combo_max"] = maxi(statystyki["combo_max"], mnoznik)
	# Combo mnoży kaucję, a TRYB WSIOKA mnoży jeszcze raz na wierzchu -
	# stąd przy pełnym Wsiokometrze i combo x4 pojedyncza puszka potrafi
	# być warta cztery złote
	var kaucja: float = dane["kaucja"] * mnoznik * mnoznik_kaucji()
	plecak.append({
		"nazwa": dane["nazwa"], "kaucja": kaucja,
		"kategoria": dane.get("kategoria", "kaucja"), "miejsca": slotow,
	})
	statystyki["zebrane"] += 1
	Osiagniecia.zglos("zebrane")
	backpack_changed.emit(zajete_miejsca(), pojemnosc_plecaka())
	combo_changed.emit(combo, mnoznik)
	dodaj_wsiokometr(bonus_wsiokometru)
	if mnoznik >= MAKS_MNOZNIK:
		wstrzasnij(0.12)   # maksymalne combo lekko trzęsie ekranem
		postep_wyzwania("combo")
		Osiagniecia.przyznaj("combo_krol")
	return {"ok": true, "kaucja": kaucja, "combo": combo, "mnoznik": mnoznik}

## Zerowanie combo (potrącenie przez auto, gleba z pojazdu).
func zgub_combo() -> void:
	if combo == 0:
		return
	combo = 0
	_combo_odliczanie = 0.0
	combo_changed.emit(0, 1)

## Wysypanie części plecaka - np. po spotkaniu z maską auta.
## Zwraca liczbę faktycznie zgubionych sztuk.
func zgub_fanty(ile: int) -> int:
	var zgubione := 0
	for i in ile:
		if plecak.is_empty():
			break
		plecak.remove_at(randi() % plecak.size())
		zgubione += 1
	if zgubione > 0:
		backpack_changed.emit(zajete_miejsca(), pojemnosc_plecaka())
	return zgubione

## Wygrana/premia - kasa rośnie poza butelkomatem (np. zdrapka).
func dodaj_kase(kwota: float) -> void:
	kasa += kwota
	money_changed.emit(kasa)
	_sprawdz_cel_dnia()

## Cel dnia ZATRZASKUJE się po osiągnięciu: raz zdobyty, zostaje zdobyty,
## nawet jeśli później mandat zejdzie poniżej progu. Dzięki temu komunikat
## w grze i rozliczenie na koniec dnia zawsze mówią to samo.
##
## Sprawdzenie siedzi tutaj, a nie przy samym butelkomacie, bo kasa wpływa
## też ze zleceń, zdrapek i akrobacji - wcześniej te drogi nie zaliczały celu
## i dało się skończyć dzień z kwotą ponad cel, a mimo to dostać karę.
func _sprawdz_cel_dnia() -> void:
	if cel_osiagniety or kasa < cel_dnia:
		return
	cel_osiagniety = true
	pokaz_komunikat("CEL DNIA OSIĄGNIĘTY (%s)! Zostało jeszcze wyzwanie." % zl(cel_dnia))

## Mandat od Straży Miejskiej. Płacisz ile masz - reszta "w systemie".
func zaplac_mandat(kwota: float, powod: String) -> void:
	# ZNAJOMOŚĆ Z OCHRONIARZEM (ulepszenie): strażnik zna cię z widzenia,
	# więc kończy się na pogadance. To jest właśnie ulepszenie odblokowujące
	# czasownik: nie "mandat o 20% mniejszy", tylko "grzebiesz bez stresu".
	if ma_ochroniarza():
		Sfx.graj("blad", -12.0)
		pokaz_komunikat("Strażnik: \"Panie, ja pana znam. Tym razem tylko upominam - %s.\"" % powod)
		return
	var zaplacono := minf(kwota, kasa)
	kasa -= zaplacono
	money_changed.emit(kasa)
	statystyki["mandaty"] += 1
	Osiagniecia.zglos("mandaty")
	Sfx.graj("blad")
	if zaplacono < kwota:
		pokaz_komunikat("MANDAT za %s: %s. Nie masz tyle - reszta 'w systemie'." % [powod, zl(kwota)])
	else:
		pokaz_komunikat("MANDAT za %s: -%s. Piękna Polska." % [powod, zl(kwota)])

## Wydanie kasy (np. piwo w Biedronce). Zwraca false, gdy brakuje środków.
func wydaj_kase(kwota: float) -> bool:
	if kasa < kwota:
		return false
	kasa -= kwota
	money_changed.emit(kasa)
	return true

## Dodanie przedmiotu do plecaka BEZ combo (np. butelka po wypitym piwie).
func dodaj_przedmiot_bez_combo(nazwa: String, kaucja: float, kat := "kaucja") -> bool:
	if zajete_miejsca() >= pojemnosc_plecaka():
		return false
	plecak.append({"nazwa": nazwa, "kaucja": kaucja, "kategoria": kat, "miejsca": 1})
	statystyki["zebrane"] += 1
	backpack_changed.emit(zajete_miejsca(), pojemnosc_plecaka())
	return true

## Wsiokometr rośnie (zbieranie, grzebanie). Przy 100 odpala się TRYB WSIOKA.
##
## Wcześniej pełny pasek dawał tylko fanfarę i napis "legenda osiedla" -
## czyli dokładnie nic. Teraz jest nagroda, po którą warto biegać: kilkanaście
## sekund podwójnej kaucji. A skoro po nich pasek spada, to i powód, żeby nie
## stać w miejscu.
func dodaj_wsiokometr(ile: float) -> void:
	var przyrost := ile * mnoznik_prestizu()
	# OPÓR KOŃCÓWKI: powyżej progu każdy punkt jest wart mniej. Bez tego pasek
	# dojeżdżał do stu sam z siebie i tryb odpalał się przy okazji - a ma być
	# czymś, po co się sięga.
	if wsiokometr >= Balans.WSIOKOMETR_OPOR_OD:
		przyrost *= Balans.WSIOKOMETR_OPOR
	wsiokometr = clampf(wsiokometr + przyrost, 0.0, 100.0)
	wsiokometr_changed.emit(wsiokometr)
	if wsiokometr >= 100.0 and not _legenda_ogloszona:
		_legenda_ogloszona = true
		Osiagniecia.przyznaj("legenda")
		odpal_tryb_wsioka()

## Oddanie zawartości plecaka z danej kategorii ("kaucja" - butelkomat,
## "zlom" - skup). Reszta zostaje w plecaku. Zwraca {"ile", "kwota"}.
## "mnoznik_ceny" pozwala skupowi zapłacić wg dziennego kursu złomu.
func oddaj_kategorie(kat: String, mnoznik_ceny := 1.0) -> Dictionary:
	var ile := 0
	var kwota := 0.0
	var zostaje: Array[Dictionary] = []
	for przedmiot in plecak:
		if przedmiot.get("kategoria", "kaucja") == kat:
			ile += 1
			kwota += przedmiot["kaucja"] * mnoznik_ceny
		else:
			zostaje.append(przedmiot)
	plecak = zostaje
	kasa += kwota
	statystyki["oddane"] += ile
	backpack_changed.emit(zajete_miejsca(), pojemnosc_plecaka())
	money_changed.emit(kasa)
	if kat == "zlom":
		statystyki["oddany_zlom"] += ile
		Osiagniecia.zglos("zlom_oddany", ile)
	else:
		Osiagniecia.zglos("butelki_oddane", ile)
	_sprawdz_cel_dnia()
	return {"ile": ile, "kwota": kwota}

## Oddanie butelek i puszek w butelkomacie (złom zostaje - ten idzie na skup).
func oddaj_wszystko() -> Dictionary:
	return oddaj_kategorie("kaucja")

## Losowy żartobliwy komentarz "co możesz kupić" za daną kwotę.
func co_moge_kupic(kwota: float) -> String:
	var wybrane: Array = ZAKUPY[0][1]
	for prog in ZAKUPY:
		if kwota >= prog[0]:
			wybrane = prog[1]
	return wybrane.pick_random()

## Koniec rundy - zatrzymuje grę i wysyła podsumowanie do HUD.
func koniec_dnia() -> void:
	if not gra_trwa:
		return
	gra_trwa = false
	Sfx.graj("koniec")
	var nowy_rekord := kasa > rekord
	if nowy_rekord:
		rekord = kasa
		_zapisz_rekord()
	# Dzienny zarobek trafia do banku kariery (na ulepszenia w MELINIE)
	bank += kasa
	# ROZLICZENIE: dzień ma dwa zadania i liczą się oba naraz.
	# Ostatnie sprawdzenie na wypadek, gdyby kasa zmieniła się bez dodaj_kase().
	_sprawdz_cel_dnia()
	var cel_ok := cel_osiagniety
	var wyzwanie_ok: bool = wyzwanie.get("zrobione", false)
	var premia := 0.0
	var kara := 0.0
	if cel_ok and wyzwanie_ok:
		premia = premia_dnia()
		bank += premia
	else:
		# Kara nie może wpędzić w minus - osiedle jest surowe, ale nie okrutne
		kara = minf(kara_dnia(), bank)
		bank -= kara
	# POJEDYNEK Z HEŃKIEM rozliczany osobno od celu dnia: można przegrać
	# z osiedlem, a i tak wygrać z konkurencją (albo odwrotnie).
	var wygrana_z_rywalem := kasa > konkurent_kasa
	var premia_rywal := 0.0
	if wygrana_z_rywalem:
		premia_rywal = Balans.PREMIA_ZA_HENIEKA
		bank += premia_rywal
		Osiagniecia.przyznaj("rywal")
	_sprawdz_osiagniecia_konca_dnia(cel_ok)
	zapisz_kariere()
	round_ended.emit({
		"cel_kwota": cel_dnia,
		"cel_ok": cel_ok,
		"premia": premia,
		"kara": kara,
		"powod_kary": _powod_kary(cel_ok, wyzwanie_ok),
		"kasa": kasa,
		"rekord": rekord,
		"nowy_rekord": nowy_rekord,
		"zebrane": statystyki["zebrane"],
		"oddane": statystyki["oddane"],
		"smietniki": statystyki["przeszukane_smietniki"],
		"zlote": statystyki["zlote"],
		"zlom": statystyki["oddany_zlom"],
		"zlecenia": statystyki["zlecenia"],
		"loty": statystyki["loty"],
		"combo_max": statystyki["combo_max"],
		"upadki": statystyki["upadki"],
		"mandaty": statystyki["mandaty"],
		"w_plecaku": plecak.size(),   # to, czego nie zdążył oddać - przepada :)
		"cel": cel_osiagniety,
		"zakupy": co_moge_kupic(kasa),
		"dzien": dzien,
		"bank": bank,
		"wyzwanie_opis": opis_wyzwania(),
		"wyzwanie_ok": wyzwanie.get("zrobione", false),
		"dzien_tygodnia": nazwa_dnia_tygodnia(),
		"pogoda": opis_pogody(),
		"zima": zima(),
		"rywal_kasa": konkurent_kasa,
		"rywal_sztuk": konkurent_sztuk,
		"rywal_wygrany": wygrana_z_rywalem,
		"premia_rywal": premia_rywal,
		"osiagniecia_dzis": Osiagniecia.zdobyte_dzis.duplicate(),
	})

## Osiągnięcia, które da się ocenić dopiero po dzwonku: dzień bez piwa,
## progi kariery, stan banku.
func _sprawdz_osiagniecia_konca_dnia(cel_ok: bool) -> void:
	if cel_ok and statystyki.get("piwa", 0) == 0:
		Osiagniecia.przyznaj("dzien_bez_piwa")
	if cel_ok and deszcz():
		Osiagniecia.przyznaj("deszcz")
	if cel_ok and snieg():
		Osiagniecia.przyznaj("snieg")
	if cel_ok and dzien_tygodnia() == Balans.SOBOTA:
		Osiagniecia.przyznaj("sobota")
	Osiagniecia.sprawdz_prog("dzien_kariery", dzien)
	Osiagniecia.sprawdz_prog("bank", bank)
	var komplet := true
	for id in ULEPSZENIA_INFO:
		if int(ulepszenia.get(id, 0)) < int(ULEPSZENIA_INFO[id]["ceny"].size()):
			komplet = false
			break
	if komplet:
		Osiagniecia.przyznaj("wyposazony")

## Za co konkretnie osiedle ściąga karę - gracz ma wiedzieć, co odpuścił.
func _powod_kary(cel_ok: bool, wyzwanie_ok: bool) -> String:
	if cel_ok and wyzwanie_ok:
		return ""
	if not cel_ok and not wyzwanie_ok:
		return "ani celu, ani wyzwania"
	if not cel_ok:
		return "cel kwotowy niewykonany"
	return "wyzwanie dnia odpuszczone"

## Reset stanu i przeładowanie sceny - nowy dzień na osiedlu.
func nowy_dzien() -> void:
	pierwszy_dzien = false   # tutorial już się nie powtarza
	_pierwszy_mem = true     # ale klasyk wraca każdego dnia
	dzien += 1               # kariera idzie do przodu (Heniek też, niestety)
	zapisz_kariere()
	_losuj_wyzwanie()
	_losuj_pogode()          # nowy dzień = nowa pogoda (i nowy dzień tygodnia)
	_losuj_cel_dnia()        # nowy dzień = nowa poprzeczka
	_losuj_kurs_zlomu()
	Zlecenia.nowy_dzien()   # nowe kartki na tablicy ogłoszeń
	Osiagniecia.nowy_dzien()
	kasa = 0.0
	plecak.clear()
	czas = CZAS_RUNDY
	gra_trwa = true
	w_menu = false        # restart pomija menu główne - od razu gramy
	cel_osiagniety = false
	combo = 0
	wsiokometr = 0.0
	tryb_wsioka = 0.0
	konkurent_kasa = 0.0
	konkurent_sztuk = 0
	magnes_bateria = Balans.MAGNES_BATERIA   # noc na ładowarce
	_magnes_ostrzezony = false
	szlug = 0.0              # paczka zostaje, zapalony szlug nie przeżywa nocy
	_czas_bezczynnosci = 0.0
	_legenda_ogloszona = false
	statystyki = {"zebrane": 0, "oddane": 0, "przeszukane_smietniki": 0, "zlote": 0, "combo_max": 1, "upadki": 0, "mandaty": 0, "zlom": 0, "oddany_zlom": 0, "zlecenia": 0, "loty": 0, "piwa": 0}
	get_tree().paused = false
	get_tree().reload_current_scene()

## Wyświetla komunikat na HUD.
func pokaz_komunikat(tekst: String) -> void:
	komunikat.emit(tekst)

## Wielki napis na środku ekranu (zlecenia, wielkie momenty).
func pokaz_meme(tekst: String) -> void:
	meme.emit(tekst)

## HUD dostaje stan aktywnego zlecenia (pusty słownik = brak zlecenia).
func ustaw_zlecenie_hud(dane: Dictionary) -> void:
	zlecenie_changed.emit(dane)

## Wygodny skrót dla reszty gry: zgłoszenie zdarzenia do systemu zleceń.
## Dzięki temu obiekty świata wołają tylko Game, bez znajomości autoloadu.
func postep_zlecenia(zdarzenie: String, ile := 1) -> void:
	Zlecenia.zglos(zdarzenie, ile)

## Ustawia podpowiedź interakcji (wywoływane co klatkę przez gracza).
func ustaw_prompt(tekst: String) -> void:
	if tekst == _ostatni_prompt:
		return
	_ostatni_prompt = tekst
	prompt_changed.emit(tekst)

## Losowy tekst przy podnoszeniu zwykłego przedmiotu.
func losowy_tekst_podnoszenia() -> String:
	return TEKSTY_PODNOSZENIA.pick_random()

## Formatowanie kwoty po polsku, np. 12.5 -> "12,50 zł".
static func zl(kwota: float) -> String:
	return ("%.2f zł" % kwota).replace(".", ",")

# --- Zapis/odczyt rekordu (user://) ---
func _zapisz_rekord() -> void:
	var plik := FileAccess.open(SCIEZKA_ZAPISU, FileAccess.WRITE)
	if plik:
		plik.store_var(rekord)

func _wczytaj_rekord() -> void:
	if FileAccess.file_exists(SCIEZKA_ZAPISU):
		var plik := FileAccess.open(SCIEZKA_ZAPISU, FileAccess.READ)
		if plik:
			rekord = float(plik.get_var())
