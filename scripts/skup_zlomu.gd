extends StaticBody3D
## SKUP ZŁOMU "U ZDZIŚKA" — buda z blachy falistej za działkami.
## Tu (i tylko tu) sprzedasz kabel, blachę, felgę i akumulator.
## Kurs zmienia się codziennie, a Zdzisiek zamyka przed końcem dnia —
## kto nie zdąży, ten wraca do domu z felgą w plecaku i pustym portfelem.

const TEKSTY_ZDZISKA: Array[String] = [
	"Zdzisiek: \"Miedź? Miedź zawsze wezmę.\"",
	"Zdzisiek: \"Waga legalizowana. Prawie.\"",
	"Zdzisiek: \"Chłopie, akumulatory to jest przyszłość.\"",
	"Zdzisiek: \"Bez dowodu nie skupuję. Żartowałem, dawaj.\"",
	"Zdzisiek: \"Konkurencja płaci mniej. Sprawdzałem.\"",
]

var _tabliczka: Label3D          # kurs dnia nad budą
var _lampa: MeshInstance3D       # świeci gdy otwarte, gaśnie po zamknięciu
var _material_lampy: StandardMaterial3D
var _waga: Node3D                # platforma wagi — ugina się przy ważeniu
var _zajety := false
var _odliczanie_gadania := 0.0

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("cel_nawigacji")   # radar w HUD pokazuje skup jako punkt
	_zbuduj_bryle()
	_odswiez_tabliczke()
	Game.skup_zmiana.connect(_na_zmiane_statusu)

## Identyfikator dla strzałki nawigacji (patrz ui/nawigacja.gd).
func nazwa_celu() -> String:
	return "skup"

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

func _pudlo(rodzic: Node3D, pozycja: Vector3, rozmiar: Vector3, kolor: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = rozmiar
	mesh.mesh = pudlo
	mesh.material_override = _material(kolor)
	mesh.position = pozycja
	rodzic.add_child(mesh)
	return mesh

func _zbuduj_bryle() -> void:
	# --- Buda z blachy falistej (żebra z cienkich pudeł) ---
	_pudlo(self, Vector3(0, 1.4, 0), Vector3(5.0, 2.8, 3.6), Color(0.55, 0.5, 0.42))
	for i in 9:
		_pudlo(self, Vector3(-2.2 + i * 0.55, 1.4, 1.83), Vector3(0.12, 2.8, 0.1), Color(0.44, 0.4, 0.34))
	# Dach ze spadkiem — rdzawa blacha
	var dach := _pudlo(self, Vector3(0, 2.95, 0), Vector3(5.4, 0.16, 4.0), Color(0.48, 0.28, 0.16))
	dach.rotation.x = -0.06

	# --- Okienko obsługi (ciemna dziura, w niej Zdzisiek) ---
	_pudlo(self, Vector3(0, 1.5, 1.84), Vector3(1.8, 1.0, 0.08), Color(0.08, 0.09, 0.1))

	# --- ZDZIŚEK wychylony przez okienko: tors, głowa, wąs, czapka ---
	# (musi stać PRZED ciemną płytą okna, inaczej buda go zasłania)
	var zdzisiek := Node3D.new()
	zdzisiek.position = Vector3(0, 0, 2.05)
	add_child(zdzisiek)
	var tors := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.34
	kapsula.height = 1.1
	tors.mesh = kapsula
	tors.material_override = _material(Color(0.35, 0.4, 0.3))   # roboczy sweter
	tors.position = Vector3(0, 1.15, 0)
	zdzisiek.add_child(tors)
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.24
	kula.height = 0.48
	glowa.mesh = kula
	glowa.material_override = _material(Paleta.SKORA)
	glowa.position = Vector3(0, 1.85, 0)
	zdzisiek.add_child(glowa)
	# Wąs — znak rozpoznawczy branży
	_pudlo(zdzisiek, Vector3(0, 1.78, 0.2), Vector3(0.26, 0.06, 0.06), Color(0.3, 0.25, 0.2))
	# Czapka z daszkiem
	var czapka := _pudlo(zdzisiek, Vector3(0, 2.03, 0), Vector3(0.5, 0.14, 0.5), Color(0.2, 0.3, 0.22))
	_pudlo(zdzisiek, Vector3(0, 1.99, 0.32), Vector3(0.5, 0.06, 0.22), Color(0.16, 0.25, 0.18))
	czapka.rotation.y = 0.1
	# Plakietka, nie szyld: Zdzisiek stoi w okienku, więc tuż za napisem
	# jest ściana budy. Zwykły billboard obracał się rogami w tę ścianę
	# i tekst dało się przeczytać tylko stojąc dokładnie na wprost.
	var podpis := Styl.plakietka("ZDZISIEK", 56, Color(1.0, 0.9, 0.6))
	podpis.position = Vector3(0, 2.42, 0)
	zdzisiek.add_child(podpis)

	# --- Waga pomostowa przed okienkiem ---
	_waga = Node3D.new()
	_waga.position = Vector3(0, 0, 2.6)
	add_child(_waga)
	_pudlo(_waga, Vector3(0, 0.09, 0), Vector3(2.2, 0.18, 1.6), Color(0.42, 0.44, 0.47))
	_pudlo(_waga, Vector3(0, 0.2, -0.7), Vector3(2.2, 0.06, 0.1), Color(0.6, 0.62, 0.65))

	# --- Szyld ---
	var szyld := _pudlo(self, Vector3(0, 3.55, 1.6), Vector3(4.6, 1.0, 0.12), Color(0.75, 0.15, 0.12))
	szyld.rotation.x = -0.04
	# Ten napis jest namalowany na szyldzie, więc ma się chować za budą,
	# gdy patrzymy od tyłu — inaczej przenikałby przez blachę.
	var napis := Styl.szyld("SKUP ZŁOMU", 110, Color(1, 0.95, 0.5))
	napis.position = Vector3(0, 3.62, 1.72)
	add_child(napis)

	# --- Tabliczka z kursem dnia (aktualizowana z Game) ---
	# Kurs to informacja dla gracza, nie element budynku — musi być czytelny
	# z dowolnego miejsca placu, także zza sterty złomu.
	# Wisi Z BOKU okienka, nie nad nim: nad okienkiem wpadała dokładnie na
	# plakietkę "ZDZISIEK" i oba napisy nakładały się na siebie.
	_tabliczka = Styl.plakietka("", 40, Color(0.85, 1.0, 0.85))
	_tabliczka.position = Vector3(-1.72, 1.72, 1.95)
	_tabliczka.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Kurs to zdanie ("CZYNNE — kurs 107% — dziś płacą przyzwoicie"), a nie
	# jedno słowo: bez łamania rozlewał się na kilka metrów w bok, daleko
	# poza deskę, na której niby wisi. 320 * pixel_size ≈ 1,3 m — czyli tyle,
	# ile ma deska.
	_tabliczka.width = 320
	_tabliczka.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tabliczka)
	# Deska, na której tabliczka "wisi" — bez niej napis dyndałby w powietrzu
	_pudlo(self, Vector3(-1.72, 1.72, 1.86), Vector3(1.5, 0.85, 0.08), Color(0.3, 0.29, 0.26))

	# --- Lampa nad okienkiem: świeci = otwarte ---
	_lampa = MeshInstance3D.new()
	var kula_lampy := SphereMesh.new()
	kula_lampy.radius = 0.16
	kula_lampy.height = 0.32
	_lampa.mesh = kula_lampy
	_material_lampy = _material(Color(0.4, 1.0, 0.45), true)
	_lampa.material_override = _material_lampy
	_lampa.position = Vector3(1.2, 2.2, 1.85)
	add_child(_lampa)

	# --- Sterta złomu obok budy (dekoracja: felgi i blachy) ---
	for i in 7:
		var kat := randf() * TAU
		var element := _pudlo(self,
			Vector3(-3.4 + cos(kat) * 0.9, 0.15 + i * 0.13, -1.2 + sin(kat) * 0.9),
			Vector3(randf_range(0.4, 1.0), 0.14, randf_range(0.3, 0.8)),
			Color(0.45, 0.42, 0.4).lerp(Color(0.5, 0.28, 0.16), randf()))
		element.rotation.y = kat
		element.rotation.z = randf_range(-0.2, 0.2)

	# --- Kolizja budy (waga i sterta są przechodnie — mniej zaczepiania) ---
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(5.0, 2.8, 3.6)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 1.4, 0)
	add_child(kolizja)

func _process(delta: float) -> void:
	if Game.w_menu or not Game.gra_trwa:
		return
	# Zdzisiek zagaduje przechodzących obok
	_odliczanie_gadania -= delta
	if _odliczanie_gadania <= 0.0 and Game.skup_otwarty:
		var gracze := get_tree().get_nodes_in_group("gracz")
		if gracze.size() > 0 and gracze[0].global_position.distance_to(global_position) < 9.0:
			_odliczanie_gadania = 16.0
			Game.pokaz_komunikat(TEKSTY_ZDZISKA.pick_random())

func _odswiez_tabliczke() -> void:
	if Game.skup_otwarty:
		_tabliczka.text = "CZYNNE — %s" % Game.opis_kursu()
		_tabliczka.modulate = Color(0.8, 1.0, 0.8)
	else:
		_tabliczka.text = "ZAMKNIĘTE\n(Zdzisiek poszedł na piwo)"
		_tabliczka.modulate = Color(1.0, 0.6, 0.6)

## Reakcja na zamknięcie skupu — gaśnie lampa, zmienia się tabliczka.
func _na_zmiane_statusu(otwarty: bool) -> void:
	_odswiez_tabliczke()
	var kolor := Color(0.4, 1.0, 0.45) if otwarty else Color(0.35, 0.1, 0.1)
	_material_lampy.albedo_color = kolor
	_material_lampy.emission = kolor
	_material_lampy.emission_energy_multiplier = 1.4 if otwarty else 0.1

func podpowiedz() -> String:
	var zlom := Game.ile_w_plecaku("zlom")
	if not Game.skup_otwarty:
		return "SKUP ZAMKNIĘTY — Zdzisiek skończył na dziś"
	if zlom == 0:
		return "Skup Złomu — %s (przynieś złom!)" % Game.opis_kursu()
	return "E — sprzedaj złom (%d szt., kurs %d%%)" % [zlom, roundi(Game.kurs_zlomu * 100)]

func interakcja(_gracz: Node3D) -> void:
	if _zajety:
		return
	if not Game.skup_otwarty:
		Sfx.graj("blad")
		Game.pokaz_komunikat("Zamknięte. Zdzisiek pracuje do 17:00 i ani minuty dłużej.")
		return
	if Game.ile_w_plecaku("zlom") == 0:
		Sfx.graj("blad")
		Game.pokaz_komunikat("Zdzisiek: \"Butelki to do automatu. Ja biorę METAL.\"")
		return
	_zajety = true
	_animacja_wagi()
	Sfx.graj("brzek", -4.0, 0.8)
	Game.pokaz_komunikat("Zdzisiek rzuca złom na wagę. Wskazówka lata jak szalona...")
	await get_tree().create_timer(1.1, false).timeout
	if not is_inside_tree():
		_zajety = false
		return
	# Płacimy wg kursu dnia — czasem żniwa, czasem kryzys
	var wynik: Dictionary = Game.oddaj_kategorie("zlom", Game.kurs_zlomu)
	_zajety = false
	Sfx.graj("kasa")
	Game.wstrzasnij(0.18)
	Game.postep_zlecenia("zlom_oddany", wynik["ile"])
	var komentarz := "Kurs dziś dobry, masz szczęście." if Game.kurs_zlomu >= 1.15 \
		else ("Kryzys w branży, wybacz." if Game.kurs_zlomu < 0.95 else "Uczciwie, jak zawsze.")
	Game.pokaz_komunikat("Zdzisiek odlicza %s za %d szt. \"%s\"" % [
		Game.zl(wynik["kwota"]), wynik["ile"], komentarz,
	])

## Waga ugina się pod ciężarem złomu.
func _animacja_wagi() -> void:
	var tw := create_tween()
	tw.tween_property(_waga, "position:y", -0.07, 0.12)
	tw.tween_property(_waga, "position:y", 0.02, 0.18)
	tw.tween_property(_waga, "position:y", 0.0, 0.15)
