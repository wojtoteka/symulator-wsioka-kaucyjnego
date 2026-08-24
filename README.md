# Symulator Wsioka Kaucyjnego

Gra 3D w Godot 4.3 o zbieraniu butelek na kaucję. Biegasz po osiedlu, wyciągasz puszki z koszy i trzepaków, oddajesz je do butelkomatu, a zarobek przepuszczasz w kiosku na energetyki i batony. Rzecz zrobiona pół żartem, ale z pełnym systemem ekonomii, kariery i wyzwań.

## Rozgrywka

**Dzień trwa 5 minut.** W tym czasie trzeba wyrobić losowany cel kwotowy i zaliczyć wyzwanie dnia. Oba wykonane - premia. Cokolwiek niezaliczone - kara ściągana z banku kariery.

- **Zbieranie i pojemność** - plecak mieści 20 przedmiotów, potem trzeba iść do butelkomatu albo skupu złomu.
- **Trzy butelkomaty** - przy Biedronce, pod małym blokiem i na placu garażowym. Każdy potrafi mieć **kolejkę babć**, a kolejka **rośnie, kiedy w niej stoisz** (dochodzą kolejni), więc "przeczekam" ma swoją cenę. Do tego automat, z którego właśnie korzystałeś, **męczy się** i zapycha chętniej - opłaca się krążyć między punktami, a nie dreptać do jednego.
- **Combo** - szybkie zbieranie pod rząd podbija mnożnik; przerwa dłuższa niż okno combo zbija go do zera.
- **Wsiokometr i TRYB WSIOKA** - pasek 0-100 napędzany stylem gry. Ucieka cały czas (a przy staniu w miejscu szybciej), a ostatnie 30% stawia opór, więc końcówkę trzeba wyszarpać serią. Przy 100% odpala się kilkanaście sekund szału: **podwójna kaucja**, ekran w sepii i disco polo z okna na cały regulator. Potem pasek spada, więc trzeba wyrobić go od nowa.
- **Pojedynek z Heńkiem** - konkurent poluje na te same butelki, a jego utarg widać obok Twojego przez cały dzień. Z każdym dniem kariery odpoczywa krócej, a **od czwartego dnia poznaje się na złocie** - czyli poluje dokładnie na to, na co Ty. Na koniec rozliczenie („Ty 84 zł / Heniek 71 zł") i osobna premia za wygraną.
- **Stamina i „Papieros"** - sprint kosztuje, regeneracja swoje trwa.
- **Upojenie i kac** - dwa niezależne parametry nakładające filtr koloru na HUD.
- **Kariera** - cel dnia rośnie z każdym przegranym dniem (`CEL_BAZOWY` 55 zł + 11 zł za dzień, ±18% losowego wahania, zaokrąglane do pełnych piątek), więc trudność skaluje się razem z graczem.
- **Tablica zleceń** - osobny system zadań (`zlecenia.gd`) z własnym postępem.
- **Zapis stanu** - rekord, ustawienia, postęp kariery i Księga wsioka lądują w `user://`.

### Pora dnia

Runda to nie tylko licznik na HUD-zie. Słońce, niebo, mgła i chmury jadą po tej samej osi co zegar: od porannego światła, przez południe, po **zachód w ostatniej minucie**. „Zostały dwie minuty" widać na ekranie, zanim się to przeczyta. Cała krzywa to jedna tabela klatek kluczowych w `scripts/pora_dnia.gd`.

### Pogoda

Losowana raz na dzień: słonecznie, pochmurno, deszcz albo - od piętnastego dnia kariery - **śnieg**. Opad **nie jest filtrem na ekranie**:

- mniej przechodniów na osiedlu (ludzie siedzą w domach),
- śliska nawierzchnia - obniżona przyczepność pojazdów i gorsze hamowanie na piechotę,
- za to **więcej butelek pod wiatami**, bo kto pije w deszczu, ten pije pod dachem,
- do tego kałuże, krople i przygaszone, wyprane z błękitu światło.

**Pod dachem brzmi inaczej.** Wiaty butelkomatów i podcień przed Biedronką to realne strefy (`Plan.DACHY`): wchodzisz pod blachę, szum deszczu przygasa i wchodzi bębnienie o daszek. Zimą nic nie bębni - i ta cisza też jest informacją.

### Zima

Od **dnia 15 kariery** to, co spadłoby jako deszcz, spada jako śnieg. To nie jest deszcz w innym kolorze: zamieć jest **jasna**. Światło odbite od śniegu podbija ambient, cienie prawie znikają, mgła gęstnieje, a cała paleta terenu i zieleni blednie (`Styl.zimowo`). Ślisko jest wyraźnie bardziej niż na mokrym, płatki lecą wolno i wirują, a zaspy przykrywają trawniki.

Podglądniesz to bez dogrywania dwóch tygodni kariery: `godot -- --autostart --snieg`.

### Dni tygodnia

Dzień kariery ma nazwę, a każdy dzień tygodnia ma charakter:

| Dzień | Co się zmienia |
|---|---|
| Poniedziałek | Skup płaci marnie (kurs -25%), ale i cel dnia jest niższy |
| Czwartek | Zdzisiek robi **promocję na akumulatory** (+70% do ceny) |
| Sobota | Pod blokami leży pokłosie piątkowej imprezy - więcej fantów, wyższa poprzeczka |
| Niedziela | Osiedle śpi, cel dnia niżej |

### Księga wsioka

30 osiągnięć liczonych przez całą karierę („100 śmietników", „przejechany przez auto 3 razy", „dzień bez jednego piwa"). Liczniki idą tym samym kanałem, co reszta statystyk, toast leci istniejącym sygnałem `meme`, a stan siedzi w sekcji `[osiagniecia]` pliku `user://kariera.cfg`.

Całą listę - razem z postępem („62/100 śmietników") i tym, czego jeszcze brakuje - obejrzysz pod **Esc → KSIĘGA WSIOKA**.

### MELINA - sklep ulepszeń

Sześć ulepszeń podbija liczby (+% do czegoś). Trzy ostatnie **odblokowują czasownik** - rzecz, której wcześniej w ogóle nie dało się zrobić:

- **Magnes na butelki** - fanty z 3 m same wpadają do plecaka, zbieranie z czynności robi się trasą. Ma **baterię z bazaru**: czterdzieści sekund realnego przyciągania na dzień (samo chodzenie nie zużywa nic), doładowywaną z gniazdka butelkomatu,
- **Znajomość z ochroniarzem** - Straż Miejska ostrzega zamiast wypisywać mandat,
- **Przyczepka do skutera** - Romet zbiera fanty w biegu, jak wózek z Biedronki.

**Świat jest zaludniony:** sąsiadka, przechodnie, kasjerka, strażnik, konkurent polujący na te same butelki, gołębie i pies. Do tego skuter, wózek, rampa, trzepak, lodówka, paleta i kiosk - każdy element ma własny skrypt.

## Architektura

Cztery autoloady trzymają globalny stan:

| Autoload | Odpowiedzialność |
|---|---|
| `Game` (`game_manager.gd`) | Kasa, plecak, czas dnia, combo, Wsiokometr, tryb wsioka, pogoda, dzień tygodnia, kariera, rekord |
| `Sfx` (`sfx.gd`) | Dźwięki i muzyka |
| `Zlecenia` (`zlecenia.gd`) | Aktywne zlecenia z tablicy ogłoszeń |
| `Osiagniecia` (`osiagniecia.gd`) | Księga wsioka - liczniki i wpisy |

Komunikacja idzie **sygnałami** - HUD nie odpytuje stanu w pętli, tylko podpina się pod `money_changed`, `combo_changed`, `wsiokometr_changed`, `tryb_wsioka_changed`, `rywal_changed` i resztę. Dzięki temu warstwa interfejsu (`ui/hud.gd`, `radar.gd`, `kompas.gd`, `nawigacja.gd`, `motion_lines.gd`) jest całkowicie oddzielona od logiki.

**Cały balans siedzi w jednym pliku.** `scripts/balans.gd` to `class_name Balans` z kompletem stałych: długość rundy, pojemność plecaka, ceny w kiosku, progi premii i kar, modyfikatory dni tygodnia, szanse pogodowe, czas trybu wsioka. Żadna z tych liczb nie jest rozsiana po logice - chcesz przestawić trudność, zmieniasz jedno miejsce.

### Budowanie świata

Osiedle powstaje w całości z kodu, ale nie w jednym pliku. `world.gd` trzyma tylko kolejność budowania i to, co dotyczy całej sceny; robotę wykonują budowniczowie:

| Plik | Co buduje |
|---|---|
| `scripts/plan_osiedla.gd` | **Plan osiedla** - jedno źródło prawdy o tym, gdzie co stoi (`Plan.czy_zajete`, `Plan.pod_dachem`) |
| `scripts/world_bryly.gd` | Wspólne klocki: `pudlo()`, `walec()`, `przeszkoda()`, `multi()` |
| `scripts/world_budynki.gd` | Biedronka z wnętrzem, bloki, garaże, działki, wiaty z butelkomatami, płot |
| `scripts/world_zielen.gd` | Drzewa, krzaki, kamienie, chmury |
| `scripts/world_npc.gd` | Mieszkańcy, ruch uliczny, śmietniki, rozrzucony łup |
| `scripts/pora_dnia.gd` | Słońce, niebo, mgła i ich zmiana w czasie rundy |
| `scripts/pogoda.gd` | Opad: krople i płatki, kałuże i zaspy, szum, bębnienie o blachę |

## Sterowanie

WSAD - ruch · **E** - podnieś/użyj · Shift - sprint · **F** - argument siłowy · Ctrl - przysiad/drift · Mysz - rozglądanie · Esc - pauza · F11 - pełny ekran

## Uruchomienie

Otwórz katalog jako projekt w **Godot 4.3** i uruchom `scenes/main.tscn` (jest ustawiona jako scena główna).

### Tryby deweloperskie

```bash
godot -- --autostart              # pomija menu główne
godot -- --autostart --krotki-dzien   # runda skrócona do 8 s
godot --headless -- --autostart --testy   # autotesty, kod wyjścia 0/1
godot -- --autostart --zrzut      # obchodzi mapę i zapisuje PNG do user://zrzuty
godot -- --autostart --snieg      # wymusza zimę (bez czekania do dnia 15)
```

`--testy` to 147 sprawdzeń logiki, której nie da się przeklikać w headless: plecak z kategoriami, rozliczenie dnia, rozmieszczenie obiektów na mapie, kolumna aut, dni tygodnia, pogoda, tryb wsioka, Księga wsioka, pojedynek z Heńkiem, kolejki do butelkomatów, zima, bateria magnesu i zasięg wiat. Te same testy chodzą przy każdym pushu - patrz `.github/workflows/testy.yml`.

## Dźwięk

Wszystkie efekty są **generowane w kodzie** (`scripts/sfx.gd`) - projekt nie potrzebuje żadnych plików audio. Dotyczy to też muzyki: gdy w `music/` nie ma ani jednego pliku, przy wielkich momentach wchodzi **syntezowany kawałek disco polo** (bas na kwadracie, stopa, hi-hat i przygrywka - `_generuj_klasyk()`). Deszcz ma własny, generowany szum, a pod blaszanymi wiatami - osobną pętlę bębnienia (`petla_dachu()`, kilkaset losowych stuknięć zamiast filtrowanego szumu, bo dach to transjenty, nie woda).

Wrzucenie własnych `.mp3` do `music/` po prostu podmienia tę ścieżkę na prawdziwą - gra losuje wtedy jeden z Twoich utworów i gra jego refren.

## Czego nie ma w repozytorium

- **`music/*.mp3`** - ścieżka dźwiękowa to komercyjne utwory disco polo objęte prawami autorskimi. Gra działa bez nich (patrz wyżej); pliki `.import` zostały, więc wystarczy wrzucić własne `discopolo.mp3` i `temperatura.mp3` do `music/`.
- **`build/`** - wyeksportowany plik gry (86 MB).
- **`.godot/`** - lokalny cache silnika, odtwarzany automatycznie przy pierwszym otwarciu projektu.
