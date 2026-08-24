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
# Osobna premia za pobicie Heńka. Rywal, którego widać na tablicy wyników,
# jest groźniejszy niż rywal, który po prostu chodzi - ale musi mieć stawkę.
const PREMIA_ZA_HENIEKA := 12.0

# --- DNI TYGODNIA ---
# Dzień kariery to nie tylko licznik do wzoru na cel: dzień 1 to poniedziałek,
# dzień 8 znowu poniedziałek. Każdy ma swój charakter, więc tydzień gry ma
# rytm, a nie siedem takich samych rund.
const PONIEDZIALEK := 0
const WTOREK := 1
const SRODA := 2
const CZWARTEK := 3
const PIATEK := 4
const SOBOTA := 5
const NIEDZIELA := 6
const DNI_TYGODNIA: Array[String] = [
	"poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela",
]
const SOBOTA_FANTY := 1.4          # po piątkowej imprezie leży wszędzie więcej
const SOBOTA_CEL := 1.12           # ...więc i poprzeczka idzie w górę
const PONIEDZIALEK_KURS := 0.75    # skup po weekendzie płaci marnie
const PONIEDZIALEK_CEL := 0.9      # w zamian osiedle mniej wymaga
const CZWARTEK_AKUMULATOR := 1.7   # promocja Zdziśka na akumulatory
const NIEDZIELA_CEL := 0.92        # niedziela handlowa? nie w tym mieście

# --- POGODA ---
# Losowana raz na dzień. Deszcz to nie filtr na ekranie: zmienia liczbę
# przechodniów, przyczepność pojazdów i miejsca, w których leży łup.
const SZANSA_DESZCZU := 0.22
const SZANSA_POCHMURNO := 0.28     # reszta przypadków to słońce
const DESZCZ_PRZYCZEPNOSC := 0.45  # mnożnik przyczepności pojazdów na mokrym
const DESZCZ_HAMOWANIE := 0.55     # mnożnik hamowania na piechotę (ślizg)
const DESZCZ_PRZYSPIESZENIE := 0.7 # i wolniejsze nabieranie prędkości

# --- ZIMA ---
# Kariera trwa tygodniami, a osiedle wyglądało cały czas tak samo. Od pewnego
# dnia przychodzi zima: to, co byłoby deszczem, pada jako ŚNIEG, a do tego
# dochodzi własna szansa na śnieżycę. Cała infrastruktura pogody już stała -
# doszła biała paleta i ślizganie mocniejsze niż na mokrym.
const ZIMA_OD_DNIA := 15           # od tego dnia kariery na osiedle wchodzi zima
const SZANSA_SNIEGU := 0.34        # dodatkowo, ponad "deszcz zamieniony w śnieg"
const SNIEG_PRZYCZEPNOSC := 0.28   # na ubitym śniegu wózek jedzie bokiem
const SNIEG_HAMOWANIE := 0.4
const SNIEG_PRZYSPIESZENIE := 0.62
## Zimą ludzie piją pod dachem jeszcze chętniej niż w deszczu
const SNIEG_FANTY_POD_WIATA := 2

# --- DESZCZ POD DACHEM ---
# Szum deszczu grał wszędzie tak samo, więc daszek był tylko bryłą. Pod dachem
# szum przygasa, a jego miejsce zajmuje bębnienie o blachę - i nagle wiadomo,
# że się gdzieś schowałeś.
const DACH_ZASIEG := 2.6           # promień strefy "pod dachem" wokół daszku
const DACH_SZUM_DB := -26.0        # przygaszony deszcz poza zadaszeniem
const DACH_BEBNIENIE_DB := -11.0   # blacha nad głową

# --- TRYB WSIOKA (Wsiokometr 100%) ---
# Pasek 0-100 rósł i spadał, i na tym się kończyło. Teraz pełny Wsiokometr
# odpala kilkanaście sekund szaleństwa: podwójna kaucja, sepia i disco polo
# na cały regulator. Po wszystkim pasek spada, więc trzeba go wyrobić od nowa.
const TRYB_WSIOKA_CZAS := 15.0
const TRYB_WSIOKA_MNOZNIK := 2.0   # podwójna kaucja za wszystko, co podniesiesz
const TRYB_WSIOKA_PO := 45.0       # do ilu spada Wsiokometr po zakończeniu

# --- KOLEJKA DO BUTELKOMATU ---
# Butelkomat na osiedlu jest JEDEN - ten przy Biedronce. Trzy rozstawione po
# mapie robiły z niego infrastrukturę: zawsze któryś był wolny, zawsze któryś
# działał, i żadna awaria niczego nie znaczyła. Jeden automat to punkt, wokół
# którego kręci się dzień - ale wtedy kolejka nie może być ścianą, tylko
# WYBOREM. Stąd niższy sufit kolejki, łagodniejsze zmęczenie i wpychanie się.
const SZANSA_KOLEJKI := 0.4        # że przy automacie ktoś już stoi
const KOLEJKA_MIN := 6.0
const KOLEJKA_MAX := 11.0
const KOLEJKA_PRZERWA_MIN := 22.0  # co ile automat losuje nową babcię
const KOLEJKA_PRZERWA_MAX := 45.0
## KOLEJKA ROŚNIE, GDY W NIEJ STOISZ - stanie pod automatem dokłada kolejnych
## gości. Przy jednym punkcie sufit musiał zejść z 20 do 14 sekund: dwadzieścia
## sekund bez żadnej alternatywy to już nie złośliwość osiedla, tylko kara.
const KOLEJKA_ZASIEG := 6.0        # z tej odległości liczysz się jako stojący
const KOLEJKA_DOKLADKA_CO := 4.0   # co tyle sekund ktoś MOŻE dojść
const KOLEJKA_SZANSA_DOKLADKI := 0.6
const KOLEJKA_DOKLADKA_MIN := 2.5
const KOLEJKA_DOKLADKA_MAX := 4.5
const KOLEJKA_MAKS := 14.0         # sufit - osiedle jest złośliwe, nie okrutne

## WPYCHANIE SIĘ BEZ KOLEJKI. Odkąd automat jest jeden, "poczekaj" było jedyną
## odpowiedzią - a jedyna odpowiedź to nie wybór, tylko przerwa w graniu.
## Teraz E w kolejce to zakład: albo wchodzisz przed babcię i osiedle zapamięta
## Ci to na Wsiokometrze, albo dostajesz torebką i kolejka robi się dłuższa.
const SZANSA_WEPCHNIECIA := 0.55   # że babcia odpuści
const WEPCHNIECIE_WSIOKOMETR := 14.0
const WEPCHNIECIE_KARA := 4.0      # sekundy dokładane do kolejki po torebce
const WEPCHNIECIE_MANDAT := 6.0    # gdy Straż Miejska akurat patrzy

## ZMĘCZENIE AUTOMATU. Przy trzech punktach miało zmuszać do krążenia; przy
## jednym pilnuje czegoś innego - żeby opłacało się przyjść z PEŁNYM plecakiem,
## a nie wpadać co chwilę z trzema puszkami. Dlatego sufit spadł z 30 do 16 pp.:
## automat ma się ociągać, a nie zamieniać w ścianę bez objazdu.
const ZMECZENIE_ZA_KURS := 0.08    # o tyle rośnie szansa zapchania po transakcji
const ZMECZENIE_MAKS := 0.16       # sufit dodatku
const ZMECZENIE_SPADEK := 0.02     # na sekundę - automat "odpoczywa"

# --- Sklepik: na co przepuścić kaucję ---
const CENA_ENERGETYKA := 5.0
const CENA_BATONA := 3.0
const CENA_WODY := 2.0
const CENA_KAWY := 4.0
const ENERGETYK_CZAS := 22.0       # sekundy podkręcenia
const ENERGETYK_BONUS := 1.22      # mnożnik prędkości (mniej niż piwo, ale bez kaca)

# --- PACZKA SZLUGÓW (kiosk) ---
# Kiosk sprzedawał tylko zdrapkę, czyli czysty hazard - wydajesz i czekasz,
# co wylosuje. Paczka szlugów to zakup, który coś ROBI, i to dokładnie w tym
# miejscu, gdzie gra była najbardziej sucha: Wsiokometr ucieka cały czas, więc
# dobicie do 100% wymaga nieprzerwanej serii. Zapalony szlug ZATRZYMUJE spadek
# na kilkanaście sekund - to jedyne narzędzie, którym da się TRYB WSIOKA
# zaplanować, zamiast na niego trafić. Cena: przy fajce nie ma sprintu,
# bo z fajką w zębach się nie biega, tylko idzie z godnością.
const CENA_PACZKI := 9.0
const SZLUGI_W_PACZCE := 10
const SZLUG_CZAS := 14.0           # sekundy jednego szluga
const SZLUG_WSIOKOMETR := 10.0     # natychmiastowy zastrzyk przy zapaleniu
const SZLUG_REGENERACJA := 0.25    # mnożnik regeneracji "Papierosa" przy fajce

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

# --- ULEPSZENIA ODBLOKOWUJĄCE CZASOWNIK ---
# Sześć pierwszych ulepszeń było liniowe (+% do czegoś). Te trzy zmieniają
# to, CO gracz może zrobić, a nie o ile lepiej to robi - i dlatego są droższe.
const MAGNES_ZASIEG := 3.0         # z ilu metrów fanty same lecą do plecaka
const MAGNES_SILA := 7.0           # jak szybko przyciąga (m/s przy pełnym zasięgu)
const MAGNES_ZLAPANIE := 0.7       # z tej odległości fant wpada do plecaka
## BATERIA Z BAZARU. Magnes bez ograniczeń robił z celu dnia formalność:
## wystarczyło przebiec trawnik. Teraz ma zasilanie na kilkadziesiąt sekund
## PRACY (samo chodzenie nie zużywa nic), a doładowuje się przy butelkomacie -
## czyli w miejscu, do którego i tak trzeba wracać.
const MAGNES_BATERIA := 40.0       # sekundy realnego przyciągania na dzień
const MAGNES_LADOWANIE := 14.0     # ile wraca za jedną transakcję w automacie
const MAGNES_OSTRZEZENIE := 8.0    # przy tylu sekundach magnes zaczyna marudzić

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
const WSIOKOMETR_SPADEK := 6.0     # na sekundę bezczynności
## Pasek pełzł w górę sam z siebie, bo spadał TYLKO przy staniu w miejscu.
## TRYB WSIOKA odpalał się więc "przy okazji", zamiast być czymś, po co się
## sięga. Teraz Wsiokometr ucieka cały czas, a ostatnie 30% stawia opór -
## końcówkę trzeba wyszarpać serią, nie samym graniem.
const WSIOKOMETR_SPADEK_STALY := 1.7   # na sekundę, niezależnie od ruchu
const WSIOKOMETR_OPOR_OD := 70.0       # powyżej tego progu przyrost maleje
const WSIOKOMETR_OPOR := 0.45          # mnożnik przyrostu nad progiem

# --- NPC ---
const PREDKOSC_HENKA := 3.2
## Heniek odpoczywał 4-7 s po każdej butelce, więc przez pięć minut robił
## kilkanaście złotych, a premia za wygraną była praktycznie gwarantowana.
## Rywal, którego nie da się przegrać, to nie rywal - tylko dodatek do wypłaty.
const HENIEK_ODPOCZYNEK_MIN := 2.0
const HENIEK_ODPOCZYNEK_MAX := 3.6
const HENIEK_WPRAWA_ZA_DZIEN := 0.06   # o tyle krótszy odpoczynek z każdym dniem
const HENIEK_WPRAWA_MAKS := 0.85       # ...ale nie szybciej niż o tyle
const HENIEK_ZLOTO_OD_DNIA := 4        # od tego dnia poznaje się na złocie
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
