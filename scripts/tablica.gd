extends StaticBody3D
## TABLICA OGŁOSZEŃ - osiedlowy urząd pracy. Wiszą tu kartki ze zleceniami
## (dane z data/zlecenia.json). E przyjmuje ofertę, F przewija na następną
## kartkę - bo tablicę na osiedlu obsługuje się pięścią.

var _kartka: Label3D          # treść bieżącej oferty
var _naglowek: Label3D
var _papiery: Array[MeshInstance3D] = []   # kartki do animacji "furkotania"

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")        # F = przewiń kartkę
	add_to_group("cel_nawigacji")  # radar pokazuje tablicę
	_zbuduj_bryle()
	Zlecenia.oferta_zmieniona.connect(_odswiez)
	Zlecenia.zlecenie_przyjete.connect(_na_przyjecie)
	Zlecenia.zlecenie_zakonczone.connect(_na_zakonczenie)
	_odswiez(Zlecenia.biezaca_oferta())

## Identyfikator dla strzałki nawigacji (patrz ui/nawigacja.gd).
func nazwa_celu() -> String:
	return "tablica"

func _na_przyjecie(_dane: Dictionary) -> void:
	_odswiez(Zlecenia.biezaca_oferta())

func _na_zakonczenie(_dane: Dictionary, _sukces: bool) -> void:
	_odswiez(Zlecenia.biezaca_oferta())

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _pudlo(pozycja: Vector3, rozmiar: Vector3, kolor: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = rozmiar
	mesh.mesh = pudlo
	mesh.material_override = _material(kolor)
	mesh.position = pozycja
	add_child(mesh)
	return mesh

func _zbuduj_bryle() -> void:
	# Dwa słupki + korpus tablicy
	_pudlo(Vector3(-1.1, 0.9, 0), Vector3(0.12, 1.8, 0.12), Paleta.DREWNO_CIEMNE)
	_pudlo(Vector3(1.1, 0.9, 0), Vector3(0.12, 1.8, 0.12), Paleta.DREWNO_CIEMNE)
	_pudlo(Vector3(0, 1.75, 0), Vector3(2.5, 1.5, 0.1), Paleta.DREWNO)
	# Daszek, żeby ogłoszeń nie zmyło (i tak zmywa)
	var daszek := _pudlo(Vector3(0, 2.55, 0.12), Vector3(2.7, 0.08, 0.45), Paleta.DREWNO_CIEMNE)
	daszek.rotation.x = 0.22
	# Kartki - cztery pożółkłe papiery przypięte krzywo
	for i in 4:
		var kartka := _pudlo(
			Vector3(-0.75 + i * 0.5, 1.55 + randf_range(-0.12, 0.12), 0.06),
			Vector3(0.42, 0.56, 0.01),
			Color(0.95, 0.93, 0.82).lerp(Color(0.85, 0.8, 0.62), randf()))
		kartka.rotation.z = randf_range(-0.12, 0.12)
		_papiery.append(kartka)
	# Nagłówek
	_naglowek = Styl.szyld("OGŁOSZENIA", 64, Color(1.0, 0.92, 0.6))
	_naglowek.pixel_size = 0.0035
	_naglowek.position = Vector3(0, 2.32, 0.09)
	add_child(_naglowek)
	# Treść bieżącej oferty
	_kartka = Label3D.new()
	_kartka.font_size = 40
	_kartka.pixel_size = 0.0035
	_kartka.width = 620
	_kartka.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kartka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kartka.modulate = Color(0.15, 0.12, 0.1)
	_kartka.outline_size = 0
	_kartka.position = Vector3(0, 1.75, 0.1)
	add_child(_kartka)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(2.5, 1.6, 0.3)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 1.75, 0)
	add_child(kolizja)

## Przepisanie treści kartki po zmianie oferty.
func _odswiez(dane: Dictionary) -> void:
	if Zlecenia.czy_aktywne():
		_kartka.text = "ZLECENIE W TOKU:\n%s\n(wróć po zaliczeniu)" % Zlecenia.opis_aktywnego()
		_kartka.modulate = Color(0.4, 0.3, 0.1)
		return
	_kartka.modulate = Color(0.15, 0.12, 0.1)
	if dane.is_empty():
		_kartka.text = "Brak ogłoszeń.\nOsiedle śpi."
		return
	if Zlecenia.czy_wykonane(str(dane["id"])):
		_kartka.text = "%s\n- WYKONANE -\n(F: następna kartka)" % str(dane.get("tytul", "Zlecenie"))
		return
	_kartka.text = "%s\nZleca: %s\n%s\nNagroda: %s | czas: %ds" % [
		str(dane.get("tytul", "Zlecenie")),
		str(dane.get("zleceniodawca", "Anonim")),
		str(dane["opis"]) % int(dane["cel"]),
		Game.zl(float(dane["nagroda"])),
		int(dane["czas"]),
	]

func podpowiedz() -> String:
	if Zlecenia.czy_aktywne():
		return "Zlecenie w toku: %s (F - zrezygnuj)" % Zlecenia.opis_aktywnego()
	var oferta := Zlecenia.biezaca_oferta()
	if oferta.is_empty():
		return "Tablica ogłoszeń - pusto"
	if Zlecenia.czy_wykonane(str(oferta["id"])):
		return "To zlecenie masz z głowy - F: następna kartka"
	return "E - przyjmij zlecenie: %s | F - inna kartka" % str(oferta.get("tytul", "?"))

func interakcja(_gracz: Node3D) -> void:
	if Zlecenia.czy_aktywne():
		Sfx.graj("blad")
		Game.pokaz_komunikat("Najpierw skończ to, co zacząłeś. Osiedle nie lubi wielozadaniowców.")
		return
	var oferta := Zlecenia.biezaca_oferta()
	if oferta.is_empty():
		Sfx.graj("blad")
		return
	if Zlecenia.czy_wykonane(str(oferta["id"])):
		Sfx.graj("blad")
		Game.pokaz_komunikat("To już zrobiłeś. Zmień kartkę (F).")
		return
	if Zlecenia.przyjmij(oferta):
		_furkot()
		_odswiez(oferta)

## Cios w tablicę = przewinięcie kartki (albo rezygnacja ze zlecenia).
func oberwij(_gracz: Node3D) -> void:
	Sfx.graj("furkot")
	_furkot()
	if Zlecenia.czy_aktywne():
		Zlecenia.porzuc()
		_odswiez(Zlecenia.biezaca_oferta())
		return
	Zlecenia.nastepna_oferta()

## Kartki furkoczą po uderzeniu.
func _furkot() -> void:
	for papier in _papiery:
		var tw := create_tween()
		var bazowy: float = papier.rotation.z
		tw.tween_property(papier, "rotation:z", bazowy + randf_range(0.2, 0.5), 0.08)
		tw.tween_property(papier, "rotation:z", bazowy, 0.3).set_trans(Tween.TRANS_ELASTIC)
