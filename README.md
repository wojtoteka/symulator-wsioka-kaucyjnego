# Symulator Wsioka Kaucyjnego

Gra 3D w Godot 4.3 o zbieraniu butelek na kaucję. Biegasz po osiedlu, wyciągasz puszki z koszy i trzepaków, oddajesz je do butelkomatu, a zarobek przepuszczasz w kiosku na energetyki i batony. Rzecz zrobiona pół żartem, ale z pełnym systemem ekonomii, kariery i wyzwań.

## Rozgrywka

**Dzień trwa 5 minut.** W tym czasie trzeba wyrobić losowany cel kwotowy i zaliczyć wyzwanie dnia. Oba wykonane - premia. Cokolwiek niezaliczone - kara ściągana z banku kariery.

- **Zbieranie i pojemność** - plecak mieści 20 przedmiotów, potem trzeba iść do butelkomatu albo skupu złomu.
- **Combo** - szybkie zbieranie pod rząd podbija mnożnik; przerwa dłuższa niż okno combo zbija go do zera.
- **Wsiokometr** - pasek 0-100 napędzany stylem gry.
- **Stamina i „Papieros"** - sprint kosztuje, regeneracja swoje trwa.
- **Upojenie i kac** - dwa niezależne parametry nakładające filtr koloru na HUD.
- **Kariera** - cel dnia rośnie z każdym przegranym dniem (`CEL_BAZOWY` 55 zł + 11 zł za dzień, ±18% losowego wahania, zaokrąglane do pełnych piątek), więc trudność skaluje się razem z graczem.
- **Tablica zleceń** - osobny system zadań (`zlecenia.gd`) z własnym postępem.
- **Zapis stanu** - rekord, ustawienia i postęp kariery lądują w `user://`.

**Świat jest zaludniony:** sąsiadka, przechodnie, kasjerka, strażnik, konkurent polujący na te same butelki, gołębie i pies. Do tego skuter, wózek, rampa, trzepak, lodówka, paleta i kiosk - każdy element ma własny skrypt.

## Architektura

Trzy autoloady trzymają globalny stan:

| Autoload | Odpowiedzialność |
|---|---|
| `Game` (`game_manager.gd`) | Kasa, plecak, czas dnia, combo, Wsiokometr, kariera, rekord |
| `Sfx` (`sfx.gd`) | Dźwięki |
| `Zlecenia` (`zlecenia.gd`) | Aktywne zlecenia z tablicy ogłoszeń |

Komunikacja idzie **sygnałami** - HUD nie odpytuje stanu w pętli, tylko podpina się pod `money_changed`, `combo_changed`, `wsiokometr_changed`, `upojenie` i resztę. Dzięki temu warstwa interfejsu (`ui/hud.gd`, `radar.gd`, `kompas.gd`, `nawigacja.gd`, `motion_lines.gd`) jest całkowicie oddzielona od logiki.

**Cały balans siedzi w jednym pliku.** `scripts/balans.gd` to `class_name Balans` z kompletem stałych: długość rundy, pojemność plecaka, ceny w kiosku, progi premii i kar. Żadna z tych liczb nie jest rozsiana po logice - chcesz przestawić trudność, zmieniasz jedno miejsce.

## Sterowanie

WSAD - ruch · **E** - podnieś/użyj · Shift - sprint · Mysz - rozglądanie

## Uruchomienie

Otwórz katalog jako projekt w **Godot 4.3** i uruchom `scenes/main.tscn` (jest ustawiona jako scena główna).

## Czego nie ma w repozytorium

- **`music/*.mp3`** - ścieżka dźwiękowa to komercyjne utwory disco polo objęte prawami autorskimi. Pliki `.import` zostały, więc wystarczy wrzucić własne `discopolo.mp3` i `temperatura.mp3` do `music/`, żeby dźwięk zagrał.
- **`build/`** - wyeksportowany plik gry (86 MB).
- **`.godot/`** - lokalny cache silnika, odtwarzany automatycznie przy pierwszym otwarciu projektu.
