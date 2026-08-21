extends StaticBody3D
## LODÓWKA Z PIWEM w Biedronce. E = kupujesz piwo za 4 zł:
## pełny "Papieros", chwilowa odwaga, chwiejna kamera...
## a pusta butelka trafia do plecaka (0,50 zł kaucji - ekonomia!).

const CENA_PIWA := Balans.CENA_PIWA

func _ready() -> void:
	add_to_group("interakcja")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

func _zbuduj_bryle() -> void:
	# Korpus lodówki
	var korpus := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(1.4, 2.1, 0.8)
	korpus.mesh = pudlo
	korpus.material_override = _material(Color(0.85, 0.88, 0.92))
	korpus.position = Vector3(0, 1.05, 0)
	add_child(korpus)
	# Podświetlana "szyba" z piwem
	var szyba := MeshInstance3D.new()
	var pudlo_szyby := BoxMesh.new()
	pudlo_szyby.size = Vector3(1.1, 1.6, 0.06)
	szyba.mesh = pudlo_szyby
	szyba.material_override = _material(Color(0.4, 0.7, 1.0), true)
	szyba.position = Vector3(0, 1.15, 0.42)
	add_child(szyba)
	# Rzędy "butelek" za szybą
	for rzad in 3:
		for kolumna in 4:
			var butelka := MeshInstance3D.new()
			var walec := CylinderMesh.new()
			walec.top_radius = 0.05
			walec.bottom_radius = 0.07
			walec.height = 0.3
			butelka.mesh = walec
			butelka.material_override = _material(Color(0.35, 0.22, 0.1))
			butelka.position = Vector3(-0.4 + kolumna * 0.27, 0.6 + rzad * 0.5, 0.36)
			add_child(butelka)
	# Napis
	var napis := Styl.szyld("PIWO", 84, Color(1.0, 0.9, 0.3))
	napis.position = Vector3(0, 2.35, 0.42)
	add_child(napis)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(1.4, 2.1, 0.8)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 1.05, 0)
	add_child(kolizja)

func podpowiedz() -> String:
	return "E - kup piwo (%s)" % Game.zl(CENA_PIWA)

func interakcja(gracz: Node3D) -> void:
	if not Game.wydaj_kase(CENA_PIWA):
		Sfx.graj("blad")
		Game.pokaz_komunikat("Za mało kasy! Wróć z butelkami, to pogadamy.")
		return
	Sfx.graj("kasa")
	gracz.wypij_piwo()
	# Butelka po piwie od razu do plecaka - obieg zamknięty
	if Game.dodaj_przedmiot_bez_combo("butelka po piwie", Balans.KAUCJA_PO_PIWIE):
		Game.pokaz_komunikat("Butelka po piwie do plecaka. Gospodarka obiegu zamkniętego!")
	else:
		Game.pokaz_komunikat("Plecak pełny - butelka po piwie została na półce. Ktoś się ucieszy.")
