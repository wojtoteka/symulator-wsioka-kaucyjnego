class_name Balans
## BALANS GRY - wszystkie "magiczne liczby" w jednym miejscu.
## Chcesz łatwiejszą/trudniejszą grę? Zmieniaj tutaj, nie w logice.

# --- Runda ---
const CZAS_RUNDY := 300.0          # długość dnia (sekundy)
const POJEMNOSC_PLECAKA := 20
const ILE_BUTELEK_NA_START := 26   # przedmioty rozrzucone na mapie
const ILE_KAMIENI := 12            # przeszkody do potykania

# --- Cel dnia (losowany codziennie, rośnie z karierą) ---
# Stała kwota szybko przestawała cokolwiek znaczyć: po kilku dniach gracz
# robił ją w dwie minuty i reszta dnia była bez stawki. Teraz cel zależy od
# dnia kariery i ma losowe wahanie, więc każdy poranek jest inny.
const CEL_BAZOWY := 55.0           # cel pierwszego dnia
const CEL_ZA_DZIEN := 11.0         # o tyle rośnie z każdym dniem kariery
const CEL_WAHANIE := 0.18          # +/- 18% losowo
const CEL_ZAOKRAGLENIE := 5.0      # do pełnych piątek, żeby ładnie wyglądał

# --- Rozliczenie dnia ---
# Dzień ma dwa zadania: cel kwotowy i wyzwanie. Oba wykonane = premia,
# cokolwiek niewykonane = kara ściągana z banku kariery.
const PREMIA_BAZOWA := 20.0
const PREMIA_ZA_DZIEN := 6.0
const KARA_BAZOWA := 12.0
const KARA_ZA_DZIEN := 4.0

# --- Sklepik: na co przepuścić kaucję ---
const CENA_ENERGETYKA := 5.0
const CENA_BATONA := 3.0
const CENA_WODY := 2.0
const CENA_KAWY := 4.0
const ENERGETYK_CZAS := 22.0       # sekundy podkręcenia
const ENERGETYK_BONUS := 1.22      # mnożnik prędkości (mniej niż piwo, ale bez kaca)

# --- Combo ---
const COMBO_OKNO := 3.0            # sekundy na kolejne podniesienie
const MAKS_MNOZNIK := 4            # sufit mnożnika kaucji

# --- Kaucje i ceny (zł) ---
const KAUCJA_PLASTIK := 0.5
const KAUCJA_SZKLO := 1.0
const KAUCJA_PUSZKA := 0.5
const KAUCJA_ZLOTA_BUTELKA := 2.0
const KAUCJA_ZLOTA_PUSZKA := 5.0
const KAUCJA_PO_PIWIE := 0.5
const CENA_PIWA := 4.0

# --- ZŁOM (oddawany na SKUPIE, nie w butelkomacie!) ---
const CENA_ZLOMU_KABEL := 2.5      # miedź to miedź
const CENA_ZLOMU_BLACHA := 1.5
const CENA_ZLOMU_FELGA := 4.0
const CENA_ZLOMU_AKUMULATOR := 12.0   # gruba ryba, ale zajmuje pół plecaka
const MIEJSCA_AKUMULATOR := 4      # ile slotów plecaka zżera akumulator
const MIEJSCA_FELGA := 2
const ILE_ZLOMU_NA_START := 14     # kawałki złomu rozrzucone po mapie
const SKUP_MNOZNIK_MIN := 0.8      # dzienne wahania cen skupu
const SKUP_MNOZNIK_MAX := 1.45
const SKUP_ZAMYKA_SIE := 75.0      # sekundy przed końcem dnia: skup zamknięty
const SKUP_OSTRZEZENIE := 130.0    # kiedy Zdzisiek zaczyna marudzić, że zamyka

# --- Szanse losowania typu przedmiotu (progi skumulowane 0-1) ---
const PROG_ZLOTA_PUSZKA := 0.015
const PROG_ZLOTA_BUTELKA := 0.045
const PROG_PUSZKA := 0.34
const PROG_SZKLO := 0.54           # powyżej: plastik

# --- Wydarzenia losowe ---
# Butelkomat zapycha się często - to ma wnerwiać, ale nie blokować.
# Kopniak odtyka w 70% prób, więc awaria kosztuje kilka sekund i jeden
# przycisk, a nie utratę łupu. Przy podnoszeniu ZAPCHANIA nie ruszać
# ODETKANIA w dół: dopiero oba naraz robią z automatu ścianę.
const SZANSA_ZAPCHANIA := 0.35     # butelkomat się zapycha (było 0.18)
const SZANSA_ODETKANIA := 0.7      # kopniak pomaga
const SZANSA_ZAPCHANIA_OD_BICIA := 0.25   # bicie sprawnego automatu mści się
const SZANSA_SZCZURA := 0.10       # szczur w śmietniku
const SZANSA_ZLEGO_PSA := 0.4      # pies nie w nastroju do głaskania
const SZANSA_BOKSU_HENKA := 0.25   # Heniek oddaje
const SZANSA_TOREBKI := 0.5        # sąsiadka kontratakuje

# --- Gracz ---
const PREDKOSC_CHODU := 5.0
const PREDKOSC_SPRINTU := 8.0
const PREDKOSC_KUCANIA := 2.6
const PRZYSPIESZENIE := 28.0       # płynne nabieranie prędkości
const HAMOWANIE := 22.0
const SILA_SKOKU := 4.6
const PAPIEROS_ZUZYCIE := 24.0     # na sekundę sprintu
const PAPIEROS_REGENERACJA := 30.0
const BONUS_PIWA := 1.15           # mnożnik prędkości po piwie
const CZAS_PIWA := 10.0            # sekundy upojenia za jedno piwo
const MAKS_UPOJENIE := 30.0        # sufit kumulacji piw (sekundy)
const PIWA_DO_KACA := 2            # od ilu piw po zejściu przychodzi kac
const KAC_NA_PIWO := 10.0          # sekundy kaca za każde wypite piwo
const KARA_KACA := 0.8             # mnożnik prędkości na kacu
const SZANSA_KOPNIAKA_W_SMIETNIK := 0.5   # że coś wypadnie po ciosie

# --- Wózek sklepowy ---
const WOZEK_MAKS := 11.0
const WOZEK_PRZYSPIESZENIE := 5.5
const WOZEK_HAMOWANIE := 1.6

# --- POJAZDY (arcade) ---
## Model jazdy: "przyczepnosc" to tempo, w jakim wektor prędkości goni kierunek
## przodu. Niskie = pływanie i długie drifty (jak w Slackers), wysokie = jazda
## po szynach. Drift (Ctrl) tymczasowo tnie przyczepność i podbija skręt.
const POJAZDY := {
	"wozek": {
		"nazwa": "wózek z Biedronki",
		"maks": WOZEK_MAKS, "przyspieszenie": WOZEK_PRZYSPIESZENIE,
		"hamowanie": WOZEK_HAMOWANIE, "wsteczny": 3.0,
		"skret": 1.7, "przyczepnosc": 3.0, "skok": 0.7,
		"auto_zbieranie": true,     # butelki wpadają same do kosza
		"prog_wywrotki": 7.0,
	},
	"skuter": {
		"nazwa": "skuter Romet (pożyczony)",
		"maks": 17.0, "przyspieszenie": 9.0,
		"hamowanie": 3.2, "wsteczny": 4.0,
		"skret": 2.1, "przyczepnosc": 5.0, "skok": 1.0,
		"auto_zbieranie": false,    # na skuterze trzeba zatrzymać się po fant
		"prog_wywrotki": 11.0,      # twardszy, ale przy glebie boli bardziej
	},
}
const DRIFT_PRZYCZEPNOSC := 0.9    # jak bardzo drift uwalnia tył pojazdu
const DRIFT_SKRET := 1.55          # mnożnik skrętu w driftcie
const DRIFT_MIN_PREDKOSC := 5.0    # wolniej driftować się nie da
const RAMPA_WYRZUT := 7.5          # siła wybicia z rampy (pionowo)
const RAMPA_MIN_PREDKOSC := 5.5    # poniżej tego rampa jest tylko górką
const LOT_BONUS_ZA_SEKUNDE := 6.0  # zł za sekundę lotu (styl się opłaca)
const LOT_MIN_CZAS := 0.45         # od tylu sekund lot liczy się jako TRICK
# DZIENNY LIMIT kasy z akrobacji. Bez niego skuter + rampa to była maszynka
# do pieniędzy: skok co trzy sekundy, w kółko, do końca dnia. Po wyczerpaniu
# limitu triki nadal dają prestiż i napisy - po prostu przestają płacić.
const LOT_LIMIT_DZIENNY := 20.0
const LOT_ODSTEP := 2.5            # sekundy między płatnymi trikami

# --- Wsiokometr ---
const WSIOKOMETR_BUTELKA := 4.0
const WSIOKOMETR_ZLOTO := 8.0
const WSIOKOMETR_SMIETNIK := 2.0
const WSIOKOMETR_SPADEK := 4.0     # na sekundę bezczynności

# --- NPC ---
const PREDKOSC_HENKA := 3.2
const ILE_AUT := 8                 # auta na obwodnicy (pętla ma ~280 m)
## Warstwa kolizji dla brył, które mają zatrzymywać WYŁĄCZNIE wysięgnik kamery.
## Korony drzew miały kolizję tylko na pniu, więc kamera TPP wjeżdżała
## w liście - a że bryły mają kontur rysowany od środka (patrz Styl), ekran
## robił się wtedy czarny. Gracza korona nadal nie blokuje.
const WARSTWA_KAMERY := 4          # warstwa 3 w edytorze (bit o wartości 4)

# --- Symulator Polaka ---
const CENA_ZDRAPKI := 3.0
const MANDAT_GRZEBANIE := 2.0      # Straż Miejska za grzebanie w śmietniku
const MANDAT_NAPASC := 10.0        # za podniesienie ręki na funkcjonariusza
const MANDAT_ZLAPANIE := 8.0       # gdy dogoni cię w pościgu
const ZASIEG_STRAZY := 7.0         # z tej odległości strażnik widzi grzebanie
const SZANSA_POSCIGU := 0.45       # że przyłapanie przerodzi się w pogoń
