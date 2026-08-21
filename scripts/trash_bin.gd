extends StaticBody3D
## ŚMIETNIK - do przeszukiwania (E). Dwa rodzaje:
##  - KONTENER: duży osiedlowy kontener (więcej szans na łup)
##  - KOSZ: mały kosz uliczny przy chodniku
## Po interakcji wypada 0-3 przedmiotów. Każdy śmietnik można
## przeszukać 1-2 razy, potem jest "przegrzebany".

enum Rodzaj { KONTENER, KOSZ }

const Kolekcjonerski := preload("res://scripts/collectible.gd")

const TEKSTY_PUSTO: Array[String] = [
	"Nic tu nie ma, tylko wstyd.",
	"Pusto. Ktoś był szybszy...",
	"Same reklamy z Biedronki. Nic wartego kaucji.",
	"Zero butelek. Kryzys jakiś?",
]

var rodzaj: Rodzaj = Rodzaj.KONTENER
var _przeszukania := 0
var _zajety := false
var _bryla: Node3D  # wizualna część (do animacji trzęsienia)

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")   # kopniak w śmietnik to osiedlowa tradycja
	add_to_group("smietnik")  # test [9] sprawdza, czy nie stoi na jezdni
	_przeszukania = randi_range(1, 2)
	_zbuduj_bryle()

## Cios w śmietnik: trzęsie się, a czasem coś z niego wypada.
func oberwij(_gracz: Node3D) -> void:
	if _zajety:
		return
	_zajety = true
	Sfx.graj("brzek", -4.0)
	_animacja_trzesienia()
	if _przeszukania > 0 and randf() < Balans.SZANSA_KOPNIAKA_W_SMIETNIK:
		_przeszukania -= 1   # wybite siłą liczy się jak przeszukanie
		Game.pokaz_komunikat("Kopniak w śmietnik! Coś wypadło!")
		_wypluj_przedmiot()
	else:
		Game.pokaz_komunikat(["Śmietnik przyjął cios z godnością.", "Au. Blacha twardsza od pięści."].pick_random())
	await get_tree().create_timer(0.6, false).timeout
	_zajety = false

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	_bryla = Node3D.new()
	add_child(_bryla)
	var kolizja := CollisionShape3D.new()
	if rodzaj == Rodzaj.KONTENER:
		# Zielony kontener z klapą
		var korpus := MeshInstance3D.new()
		var pudlo := BoxMesh.new()
		pudlo.size = Vector3(1.6, 1.2, 1.1)
		korpus.mesh = pudlo
		korpus.material_override = _material(Color(0.15, 0.45, 0.2))
		korpus.position = Vector3(0, 0.6, 0)
		_bryla.add_child(korpus)
		var klapa := MeshInstance3D.new()
		var pudlo_klapy := BoxMesh.new()
		pudlo_klapy.size = Vector3(1.7, 0.12, 1.2)
		klapa.mesh = pudlo_klapy
		klapa.material_override = _material(Color(0.1, 0.35, 0.15))
		klapa.position = Vector3(0, 1.26, 0)
		_bryla.add_child(klapa)
		var ksztalt := BoxShape3D.new()
		ksztalt.size = Vector3(1.7, 1.35, 1.2)
		kolizja.shape = ksztalt
		kolizja.position = Vector3(0, 0.675, 0)
	else:
		# Kosz uliczny - ciemny walec
		var korpus := MeshInstance3D.new()
		var walec := CylinderMesh.new()
		walec.top_radius = 0.3
		walec.bottom_radius = 0.24
		walec.height = 0.85
		korpus.mesh = walec
		korpus.material_override = _material(Color(0.25, 0.25, 0.28))
		korpus.position = Vector3(0, 0.425, 0)
		_bryla.add_child(korpus)
		var ksztalt := CylinderShape3D.new()
		ksztalt.radius = 0.32
		ksztalt.height = 0.85
		kolizja.shape = ksztalt
		kolizja.position = Vector3(0, 0.425, 0)
	add_child(kolizja)

func podpowiedz() -> String:
	var nazwa := "kontener" if rodzaj == Rodzaj.KONTENER else "kosz"
	if _przeszukania <= 0:
		return "%s - już przegrzebany" % nazwa.capitalize()
	return "E - przeszukaj %s" % nazwa

func interakcja(_gracz: Node3D) -> void:
	if _zajety:
		return
	if _przeszukania <= 0:
		Game.pokaz_komunikat("Ten śmietnik już przegrzebałeś. Zostaw coś sąsiadom.")
		return
	_przeszukania -= 1
	_zajety = true
	Game.statystyki["przeszukane_smietniki"] += 1
	Game.postep_wyzwania("smietniki")
	Game.postep_zlecenia("smietnik")
	Game.dodaj_wsiokometr(Balans.WSIOKOMETR_SMIETNIK)   # grzebanie buduje reputację
	Sfx.graj("grzebanie")
	_animacja_trzesienia()
	# Chwila grzebania, potem wynik
	await get_tree().create_timer(0.7).timeout
	_zajety = false
	if not is_inside_tree():
		return
	# Straż Miejska nie śpi - grzebanie na oczach patrolu kosztuje,
	# a czasem kończy się regularną pogonią przez całe osiedle
	for straznik in get_tree().get_nodes_in_group("straz"):
		if straznik.global_position.distance_to(global_position) < Balans.ZASIEG_STRAZY:
			if randf() < Balans.SZANSA_POSCIGU and straznik.has_method("rozpocznij_poscig"):
				straznik.rozpocznij_poscig("grzebanie w śmietniku")
			else:
				Game.zaplac_mandat(Balans.MANDAT_GRZEBANIE, "grzebanie w śmietniku")
			break
	# Szansa na szczura (tylko strach, bez szkód)
	if randf() < Balans.SZANSA_SZCZURA:
		Sfx.graj("szczur")
		Game.pokaz_komunikat("Z kontenera wyskoczył SZCZUR! O mało zawał...")
		return
	# Losujemy 0-3 przedmioty (kontener ma lepsze szanse niż kosz)
	var ile := 0
	var los := randf()
	if rodzaj == Rodzaj.KONTENER:
		ile = 0 if los < 0.15 else (1 if los < 0.45 else (2 if los < 0.8 else 3))
	else:
		ile = 0 if los < 0.35 else (1 if los < 0.75 else 2)
	if ile == 0:
		Game.pokaz_komunikat(TEKSTY_PUSTO.pick_random())
		return
	Game.pokaz_komunikat("Jest! Wypadło coś ze śmietnika: %d szt." % ile)
	for i in ile:
		_wypluj_przedmiot()

## Tworzy przedmiot "wypadający" obok śmietnika.
func _wypluj_przedmiot() -> void:
	var przedmiot := Kolekcjonerski.new()
	przedmiot.typ = Kolekcjonerski.losowy_typ(Game.mnoznik_szczescia())
	var kat := randf() * TAU
	var dystans := randf_range(0.9, 1.6)
	przedmiot.position = global_position + Vector3(cos(kat) * dystans, 0, sin(kat) * dystans)
	przedmiot.scale = Vector3.ONE * 0.01
	get_parent().add_child(przedmiot)
	# Animacja "wyskoku" - rośnie z małym odbiciem
	var tw := przedmiot.create_tween()
	tw.tween_property(przedmiot, "scale", Vector3.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Śmietnik trzęsie się podczas grzebania.
func _animacja_trzesienia() -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(_bryla, "rotation:z", 0.06, 0.06)
		tw.tween_property(_bryla, "rotation:z", -0.06, 0.06)
	tw.tween_property(_bryla, "rotation:z", 0.0, 0.05)
