extends StaticBody3D
## SKUTER "ROMET" - stoi przy garażach. Szybszy i zwrotniejszy od wózka,
## ale nie zbiera butelek za ciebie: na skuterze trzeba zsiąść po fant.
## Fizyka (drift, skoki z ramp) siedzi w player.gd - patrz Balans.POJAZDY.

var _kolizja: CollisionShape3D

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("cel_nawigacji")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

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
	# Podłoga, siedzisko, owiewka - ten sam kształt co wersja "w ruchu"
	_pudlo(Vector3(0, 0.34, 0), Vector3(0.42, 0.12, 1.35), Color(0.75, 0.18, 0.16))
	_pudlo(Vector3(0, 0.55, 0.28), Vector3(0.36, 0.18, 0.55), Color(0.12, 0.12, 0.14))
	_pudlo(Vector3(0, 0.68, -0.55), Vector3(0.34, 0.5, 0.22), Color(0.8, 0.2, 0.18))
	_pudlo(Vector3(0, 0.98, -0.52), Vector3(0.62, 0.05, 0.05), Color(0.2, 0.2, 0.22))
	_pudlo(Vector3(0.3, 1.16, -0.5), Vector3(0.12, 0.08, 0.03), Color(0.6, 0.65, 0.7))
	# Lampa
	var lampa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.11
	kula.height = 0.22
	lampa.mesh = kula
	lampa.material_override = _material(Color(1.0, 0.96, 0.78), true)
	lampa.position = Vector3(0, 0.72, -0.66)
	add_child(lampa)
	# Koła
	for przesuniecie in [Vector3(0, 0.24, -0.58), Vector3(0, 0.24, 0.58)]:
		var kolo := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.24
		walec.bottom_radius = 0.24
		walec.height = 0.1
		kolo.mesh = walec
		kolo.material_override = _material(Color(0.1, 0.1, 0.11))
		kolo.rotation.z = PI / 2
		kolo.position = przesuniecie
		add_child(kolo)
	# Podpis, żeby było widać z daleka, że tu stoi maszyna
	var napis := Styl.plakietka("SKUTER", 40, Color(1.0, 0.8, 0.4))
	napis.position = Vector3(0, 1.5, 0)
	add_child(napis)
	# Kolizja
	_kolizja = CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(0.6, 1.0, 1.5)
	_kolizja.shape = ksztalt
	_kolizja.position = Vector3(0, 0.5, 0)
	add_child(_kolizja)

## Identyfikator dla strzałki nawigacji (patrz ui/nawigacja.gd).
func nazwa_celu() -> String:
	return "skuter"

func podpowiedz() -> String:
	if not Game.ma_kluczyki():
		return "Skuter zamknięty - kluczyki kupisz w MELINIE (koniec dnia)"
	return "E - odpal skuter (Ctrl = drift, szukaj ramp!)"

## Gracz wsiada - skuter znika z mapy, gracz "przejmuje" jego wygląd.
func interakcja(gracz: Node3D) -> void:
	if not gracz.is_in_group("gracz"):
		return
	# Bez kluczyków ani rusz - to jest ulepszenie kupowane za kaucję
	if not Game.ma_kluczyki():
		Sfx.graj("blad")
		Game.pokaz_komunikat("Zamknięty na kluczyk. Rysiek sprzeda ci zapasowy... za 90 zł.")
		return
	gracz.wsiadz_do_wozka(self, "skuter")
	visible = false
	_kolizja.set_deferred("disabled", true)

## Gracz zsiada - skuter wraca na mapę we wskazanym miejscu.
func odstaw(pozycja: Vector3) -> void:
	global_position = Vector3(pozycja.x, 0, pozycja.z)
	visible = true
	_kolizja.set_deferred("disabled", false)
