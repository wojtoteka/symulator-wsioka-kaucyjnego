extends Node
## ZLECENIA OSIEDLOWE (autoload "Zlecenia") — data-driven system misji.
##
## Definicje mieszkają w res://data/zlecenia.json — dopisanie nowej misji
## NIE wymaga dotykania kodu. Jeśli pliku brak (albo ma literówkę), wchodzi
## awaryjny zestaw z ZAPASOWE, żeby gra nigdy nie została bez zleceń.
##
## Przepływ: tablica ogłoszeń pokazuje ofertę -> gracz przyjmuje (E) ->
## gra zgłasza zdarzenia przez Zlecenia.zglos("zebrano_szklo") ->
## po osiągnięciu celu leci nagroda; po przekroczeniu czasu — porażka.

signal oferta_zmieniona(dane: Dictionary)      # tablica pokazuje inne zlecenie
signal zlecenie_przyjete(dane: Dictionary)
signal zlecenie_postep(dane: Dictionary)       # HUD odświeża pasek
signal zlecenie_zakonczone(dane: Dictionary, sukces: bool)

const SCIEZKA_DANYCH := "res://data/zlecenia.json"
const ILE_OFERT := 3          # ile zleceń wisi na tablicy danego dnia

## Awaryjne zlecenia, gdyby pliku JSON zabrakło w buildzie.
const ZAPASOWE: Array = [
	{
		"id": "awaryjne_butelki", "zleceniodawca": "Osiedle",
		"tytul": "Zbiórka osiedlowa", "opis": "Zbierz %d fantów",
		"zdarzenie": "zebrano_kaucja", "cel": 10, "czas": 120,
		"nagroda": 20.0, "prestiz": 15.0,
		"start": "Klasyka: zbierz, oddaj, powtórz.",
		"sukces": "Zbiórka zaliczona!", "porazka": "Czas minął.",
	},
]

var definicje: Array = []          # wszystkie wczytane zlecenia
var oferty: Array = []             # to, co dziś wisi na tablicy
var _indeks_oferty := 0            # która oferta jest pokazywana
var aktywne := {}                  # bieżące zlecenie (pusty = brak)
var wykonane: Array[String] = []   # id zaliczonych dziś zleceń

func _ready() -> void:
	_wczytaj_definicje()
	losuj_oferty()

## Wczytanie definicji z JSON-a. Błędy nie wywalają gry — jest fallback.
func _wczytaj_definicje() -> void:
	definicje = []
	if FileAccess.file_exists(SCIEZKA_DANYCH):
		var plik := FileAccess.open(SCIEZKA_DANYCH, FileAccess.READ)
		if plik:
			var wynik: Variant = JSON.parse_string(plik.get_as_text())
			if wynik is Dictionary and wynik.has("zlecenia"):
				for pozycja in wynik["zlecenia"]:
					if _poprawne(pozycja):
						definicje.append(pozycja)
	if definicje.is_empty():
		push_warning("Zlecenia: brak poprawnych danych w %s — wchodzą zapasowe." % SCIEZKA_DANYCH)
		definicje = ZAPASOWE.duplicate(true)

## Walidacja pojedynczej definicji — brak pola = zlecenie pomijane.
func _poprawne(pozycja: Variant) -> bool:
	if not pozycja is Dictionary:
		return false
	for pole in ["id", "opis", "zdarzenie", "cel", "czas", "nagroda"]:
		if not pozycja.has(pole):
			push_warning("Zlecenia: pomijam zlecenie bez pola '%s'." % pole)
			return false
	return true

## Losuje zestaw ofert na dziś (bez powtórek).
func losuj_oferty() -> void:
	var pula := definicje.duplicate()
	pula.shuffle()
	oferty = pula.slice(0, mini(ILE_OFERT, pula.size()))
	_indeks_oferty = 0
	wykonane.clear()
	aktywne = {}
	oferta_zmieniona.emit(biezaca_oferta())

## Zlecenie aktualnie pokazywane na tablicy.
func biezaca_oferta() -> Dictionary:
	if oferty.is_empty():
		return {}
	return oferty[_indeks_oferty % oferty.size()]

## Przewinięcie kartki na tablicy (gracz wali w nią pięścią — działa).
func nastepna_oferta() -> void:
	if oferty.size() <= 1:
		return
	_indeks_oferty = (_indeks_oferty + 1) % oferty.size()
	oferta_zmieniona.emit(biezaca_oferta())

## Czy dane zlecenie zostało już dziś wykonane.
func czy_wykonane(id: String) -> bool:
	return wykonane.has(id)

func czy_aktywne() -> bool:
	return not aktywne.is_empty()

## Opis aktywnego zlecenia z podstawionym celem (np. "Zbierz 6 butelek szklanych").
func opis_aktywnego() -> String:
	if aktywne.is_empty():
		return ""
	return str(aktywne["opis"]) % int(aktywne["cel"])

## Przyjęcie zlecenia z tablicy. Zwraca false, gdy już coś robimy.
func przyjmij(dane: Dictionary) -> bool:
	if dane.is_empty() or czy_aktywne() or czy_wykonane(str(dane["id"])):
		return false
	aktywne = dane.duplicate(true)
	aktywne["postep"] = 0
	aktywne["pozostalo"] = float(aktywne["czas"])
	zlecenie_przyjete.emit(aktywne)
	Game.pokaz_komunikat(str(aktywne.get("start", "Zlecenie przyjęte!")))
	Game.ustaw_zlecenie_hud(_dane_hud())
	Sfx.graj("sklep")
	return true

## Rezygnacja (bez kary — osiedle wybacza).
func porzuc() -> void:
	if not czy_aktywne():
		return
	var id := str(aktywne["id"])
	aktywne = {}
	Game.ustaw_zlecenie_hud({})
	Game.pokaz_komunikat("Zlecenie odpuszczone. Nikt nie oceniał. Prawie nikt.")
	zlecenie_zakonczone.emit({"id": id}, false)

## Zgłoszenie zdarzenia z gry. Pasuje do aktywnego zlecenia po polu "zdarzenie".
func zglos(zdarzenie: String, ile := 1) -> void:
	if not czy_aktywne() or not Game.gra_trwa:
		return
	if str(aktywne["zdarzenie"]) != zdarzenie:
		return
	aktywne["postep"] = int(aktywne["postep"]) + ile
	Game.ustaw_zlecenie_hud(_dane_hud())
	zlecenie_postep.emit(aktywne)
	if int(aktywne["postep"]) >= int(aktywne["cel"]):
		_zakoncz(true)
	else:
		Sfx.graj("podnies", -10.0, 1.5)

func _process(delta: float) -> void:
	if not czy_aktywne() or Game.w_menu or not Game.gra_trwa:
		return
	aktywne["pozostalo"] = float(aktywne["pozostalo"]) - delta
	# Ostrzeżenie na 10 sekund przed końcem
	if not aktywne.get("ostrzezono", false) and float(aktywne["pozostalo"]) <= 10.0:
		aktywne["ostrzezono"] = true
		Sfx.graj("blad", -8.0)
		Game.pokaz_komunikat("Zlecenie: zostało 10 sekund!")
	if float(aktywne["pozostalo"]) <= 0.0:
		_zakoncz(false)
	else:
		Game.ustaw_zlecenie_hud(_dane_hud())

## Zamknięcie zlecenia: wypłata i komunikaty albo pocieszenie.
func _zakoncz(sukces: bool) -> void:
	var dane := aktywne.duplicate(true)
	aktywne = {}
	Game.ustaw_zlecenie_hud({})
	if sukces:
		wykonane.append(str(dane["id"]))
		var nagroda := float(dane["nagroda"])
		Game.dodaj_kase(nagroda)
		Game.dodaj_wsiokometr(float(dane.get("prestiz", 15.0)))
		Game.statystyki["zlecenia"] += 1
		Game.postep_wyzwania("zlecenia")
		Sfx.graj("zlota")
		Game.wstrzasnij(0.22)
		Game.pokaz_meme("ZLECENIE WYKONANE! +%s" % Game.zl(nagroda))
		Game.pokaz_komunikat(str(dane.get("sukces", "Zlecenie wykonane!")))
	else:
		Sfx.graj("blad")
		Game.pokaz_komunikat(str(dane.get("porazka", "Czas minął. Zlecenie przepadło.")))
	zlecenie_zakonczone.emit(dane, sukces)

## Paczka danych dla HUD-u.
func _dane_hud() -> Dictionary:
	if aktywne.is_empty():
		return {}
	return {
		"tytul": str(aktywne.get("tytul", "Zlecenie")),
		"opis": opis_aktywnego(),
		"postep": int(aktywne["postep"]),
		"cel": int(aktywne["cel"]),
		"pozostalo": maxf(float(aktywne["pozostalo"]), 0.0),
		"zleceniodawca": str(aktywne.get("zleceniodawca", "Osiedle")),
	}

## Reset przy nowym dniu — nowe kartki na tablicy.
func nowy_dzien() -> void:
	aktywne = {}
	losuj_oferty()
