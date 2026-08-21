extends StaticBody3D
## AUTOMAT Z NAPOJAMI - stoi przy wejściu do Biedronki, obok butelkomatu.
## Drugie (po lodówce z piwem) miejsce, gdzie można przepuścić zarobioną kaucję,
## tym razem na coś, co realnie pomaga w robocie zamiast utrudniać.
##
## E - kup wybraną pozycję, F - przełącz na następną.
## Każdy napój zostawia PUSTĄ PUSZKĘ w plecaku: automat sam się karmi kaucją.

## Nie "const": stała w GDScript musi dać się policzyć w czasie kompilacji,
## a tu jest formatowanie tekstu i konwersja typu. Zwykłe pole klasy liczy się
## przy tworzeniu obiektu i wszystko działa.
var TOWAR: Array[Dictionary] = [
	{
		"nazwa": "energetyk", "cena": Balans.CENA_ENERGETYKA,
		"opis": "pełny Papieros + kopniak na %d s" % int(Balans.ENERGETYK_CZAS),
		"kolor": Color(0.15, 0.65, 0.3),
		"pusta": "puszka po energetyku", "kaucja": Balans.KAUCJA_PUSZKA,
	},
	{
		"nazwa": "kawa z automatu", "cena": Balans.CENA_KAWY,
		"opis": "budzi i leczy kaca",
		"kolor": Color(0.45, 0.28, 0.16),
		"pusta": "kubek", "kaucja": 0.0,
	},
	{
		"nazwa": "baton", "cena": Balans.CENA_BATONA,
		"opis": "cukier, siły i koniec kaca",
		"kolor": Color(0.72, 0.5, 0.2),
		"pusta": "", "kaucja": 0.0,
	},
	{
		"nazwa": "woda", "cena": Balans.CENA_WODY,
		"opis": "nudna, ale tania",
		"kolor": Color(0.35, 0.6, 0.85),
		"pusta": "butelka po wodzie", "kaucja": Balans.KAUCJA_PLASTIK,
	},
]

var _wybor := 0
var _lampka: MeshInstance3D
var _material_lampki: StandardMaterial3D
var _etykieta: Label3D

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")     # F = przełącz towar (kopniak w automat to klasyk)
	_zbuduj_bryle()
	_odswiez()

func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

func _pudlo(pozycja: Vector3, rozmiar: Vector3, kolor: Color, emisja := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = rozmiar
	mesh.mesh = pudlo
	mesh.material_override = _material(kolor, emisja)
	mesh.position = pozycja
	add_child(mesh)
	return mesh

func _zbuduj_bryle() -> void:
	# Korpus - blaszana szafa w firmowej czerwieni
	_pudlo(Vector3(0, 0.95, 0), Vector3(1.1, 1.9, 0.7), Color(0.7, 0.14, 0.14))
	# Szyba z "towarem": rzędy kolorowych puszek za ciemnym szkłem
	_pudlo(Vector3(-0.16, 1.15, 0.36), Vector3(0.66, 1.0, 0.04), Color(0.1, 0.13, 0.16))
	for rzad in 3:
		for i in 4:
			_pudlo(
				Vector3(-0.42 + i * 0.17, 0.85 + rzad * 0.28, 0.33),
				Vector3(0.11, 0.2, 0.05),
				TOWAR[(rzad + i) % TOWAR.size()]["kolor"])
	# Panel wyboru z lampką
	_pudlo(Vector3(0.36, 1.25, 0.36), Vector3(0.24, 0.7, 0.04), Color(0.18, 0.18, 0.2))
	_lampka = MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.05
	kula.height = 0.1
	_lampka.mesh = kula
	_material_lampki = Styl.bryla(Color(0.4, 1.0, 0.5), 0.0, true, true)
	_lampka.material_override = _material_lampki
	_lampka.position = Vector3(0.36, 1.5, 0.39)
	add_child(_lampka)
	# Otwór na odbiór
	_pudlo(Vector3(0, 0.28, 0.34), Vector3(0.5, 0.16, 0.06), Color(0.08, 0.08, 0.09))
	# Szyld i etykieta z wyborem
	var szyld := Styl.szyld("NAPOJE", 64, Color(1.0, 0.95, 0.7))
	szyld.position = Vector3(0, 1.78, 0.37)
	add_child(szyld)
	_etykieta = Styl.plakietka("", 46, Color(0.95, 1.0, 0.9))
	_etykieta.position = Vector3(0, 2.35, 0)
	add_child(_etykieta)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(1.1, 1.9, 0.7)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 0.95, 0)
	add_child(kolizja)

func _odswiez() -> void:
	var pozycja: Dictionary = TOWAR[_wybor]
	_etykieta.text = "%s - %s" % [pozycja["nazwa"], Game.zl(pozycja["cena"])]
	_material_lampki.albedo_color = pozycja["kolor"]
	_material_lampki.emission = pozycja["kolor"]

func podpowiedz() -> String:
	var pozycja: Dictionary = TOWAR[_wybor]
	return "E - %s (%s, %s)  |  F - następny" % [
		pozycja["nazwa"], Game.zl(pozycja["cena"]), pozycja["opis"],
	]

## F - przełączenie towaru. Automat jest w grupie "bijalne", więc trafia tu
## to samo wciśnięcie, którym gracz "zwraca uwagę" Heńkowi.
func oberwij(_gracz: Node3D) -> void:
	_wybor = (_wybor + 1) % TOWAR.size()
	_odswiez()
	Sfx.graj("krok_beton", -10.0, 1.4)
	Game.ustaw_prompt(podpowiedz())

func interakcja(gracz: Node3D) -> void:
	var pozycja: Dictionary = TOWAR[_wybor]
	if not Game.wydaj_kase(pozycja["cena"]):
		Sfx.graj("blad")
		Game.pokaz_komunikat("Automat mruga na czerwono. Za mało kaucji na %s." % pozycja["nazwa"])
		return
	Sfx.graj("kasa")
	Game.wstrzasnij(0.1)
	match pozycja["nazwa"]:
		"energetyk": gracz.wypij_energetyka()
		"kawa z automatu": gracz.zjedz_batona()   # kawa też stawia na nogi
		"baton": gracz.zjedz_batona()
		"woda": gracz.wypij_wode()
	# Opakowanie zostaje graczowi - to wciąż gra o kaucji
	var pusta := str(pozycja["pusta"])
	if pusta != "" and float(pozycja["kaucja"]) > 0.0:
		if Game.dodaj_przedmiot_bez_combo(pusta, pozycja["kaucja"]):
			Game.pokaz_komunikat("Puste opakowanie do plecaka. Kaucja wraca do właściciela.")
