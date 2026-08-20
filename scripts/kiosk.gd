extends StaticBody3D
## KIOSK "RUCH" — obowiązkowy element polskiego krajobrazu.
## E = zdrapka za 3 zł. Zwykle nic, czasem drobne... a raz na sto —
## JACKPOT 100 zł i sława na całe osiedle.

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color, emisja := false) -> StandardMaterial3D:
	return Styl.bryla(kolor, Styl.KONTUR_OBIEKT, emisja)

func _zbuduj_bryle() -> void:
	# Budka — ciemna zieleń, klasyka
	var budka := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(2.2, 2.5, 1.8)
	budka.mesh = pudlo
	budka.material_override = _material(Color(0.12, 0.32, 0.2))
	budka.position = Vector3(0, 1.25, 0)
	add_child(budka)
	# Daszek wystający
	var daszek := MeshInstance3D.new()
	var pudlo_daszka := BoxMesh.new()
	pudlo_daszka.size = Vector3(2.6, 0.12, 2.2)
	daszek.mesh = pudlo_daszka
	daszek.material_override = _material(Color(0.08, 0.22, 0.14))
	daszek.position = Vector3(0, 2.56, 0)
	add_child(daszek)
	# Podświetlone okienko z gazetami
	var okienko := MeshInstance3D.new()
	var pudlo_okienka := BoxMesh.new()
	pudlo_okienka.size = Vector3(1.4, 1.0, 0.06)
	okienko.mesh = pudlo_okienka
	okienko.material_override = _material(Color(1.0, 0.92, 0.7), true)
	okienko.position = Vector3(0, 1.4, 0.92)
	add_child(okienko)
	# Szyld
	var szyld := Styl.szyld("KIOSK", 96, Color(1.0, 0.9, 0.3))
	szyld.position = Vector3(0, 2.85, 0.92)
	add_child(szyld)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(2.2, 2.5, 1.8)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 1.25, 0)
	add_child(kolizja)

func podpowiedz() -> String:
	return "E — kup zdrapkę (%s)" % Game.zl(Balans.CENA_ZDRAPKI)

func interakcja(_gracz: Node3D) -> void:
	if not Game.wydaj_kase(Balans.CENA_ZDRAPKI):
		Sfx.graj("blad")
		Game.pokaz_komunikat("Kioskarka: \"Bez pieniędzy to jest gazetka za darmo. Ta stara.\"")
		return
	# Drapiemy... (dźwięk grzebania w wyższym tonie brzmi jak drapanie monetą)
	Sfx.graj("grzebanie", -4.0, 1.6)
	Game.pokaz_komunikat("Drapiesz zdrapkę monetą 5 gr...")
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree():
		return
	var los := randf()
	if los < 0.005:
		Game.dodaj_kase(100.0)
		Sfx.odpal_klasyk()   # jackpot bez klasyka to nie jackpot
		Game.wstrzasnij(0.4)
		Game.meme.emit("100 ZŁ ZE ZDRAPKI! TAK SIĘ ŻYJE!")
	elif los < 0.05:
		Game.dodaj_kase(20.0)
		Sfx.graj("zlota")
		Game.pokaz_komunikat("Zdrapka: +20 zł! Dzień uratowany.")
	elif los < 0.15:
		Game.dodaj_kase(5.0)
		Sfx.graj("kasa")
		Game.pokaz_komunikat("Zdrapka: +5 zł. Szału nie ma, ale zawsze.")
	elif los < 0.40:
		Game.dodaj_kase(1.0)
		Game.pokaz_komunikat("Wygrałeś 1 zł. Czyli -2 zł netto. Matematyka boli.")
	else:
		Sfx.graj("blad", -6.0)
		Game.pokaz_komunikat("Nic. \"Następnym razem\" — napisała zdrapka. Kłamie.")

## Cios w kiosk — bez szans.
func oberwij(_gracz: Node3D) -> void:
	Sfx.graj("brzek", -8.0)
	Game.pokaz_komunikat("Szyba pancerna. Kioskarka nawet nie mrugnęła.")
