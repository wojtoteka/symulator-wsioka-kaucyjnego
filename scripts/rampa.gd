extends Node3D
## RAMPA — deska na pustakach, wspólne dzieło osiedlowej młodzieży.
## Wjedź z impetem (wózkiem, skuterem albo na własnych nogach), a strefa
## na szczycie wystrzeli cię w powietrze. Im dłuższy lot, tym większy bonus
## (liczy go player.gd w _obsluz_lot).
##
## Ustaw "dlugosc" i "wysokosc" PRZED dodaniem do drzewa:
##   var r := Rampa.new(); r.dlugosc = 4.0; r.wysokosc = 1.1

var dlugosc := 3.6      # jak długi jest najazd
var wysokosc := 1.0     # jak wysoko kończy się deska
var kolor_deski := Color(0.55, 0.38, 0.2)

func _ready() -> void:
	_zbuduj_bryle()
	_zbuduj_wyrzutnie()

## Materiał w stylu gry (toon + kontur) — patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	# Kąt najazdu — łagodny, żeby dało się wjechać, a nie odbić od ściany
	var kat := atan2(wysokosc, dlugosc)
	# Deska (StaticBody3D obrócony o kąt najazdu)
	var cialo := StaticBody3D.new()
	cialo.position = Vector3(0, wysokosc / 2.0, 0)
	cialo.rotation.x = kat
	add_child(cialo)
	var deska := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	var przekatna := sqrt(dlugosc * dlugosc + wysokosc * wysokosc)
	pudlo.size = Vector3(2.2, 0.14, przekatna)
	deska.mesh = pudlo
	deska.material_override = _material(kolor_deski)
	cialo.add_child(deska)
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = pudlo.size
	kolizja.shape = ksztalt
	cialo.add_child(kolizja)
	# Żółto-czarne pasy ostrzegawcze wzdłuż deski — bez nich rampa zlewa się
	# z betonem i gracz jej po prostu nie zauważa
	var ile_pasow := int(przekatna / 0.5)
	for i in ile_pasow:
		var pas := MeshInstance3D.new()
		var pudlo_pasa := BoxMesh.new()
		pudlo_pasa.size = Vector3(2.24, 0.03, 0.25)
		pas.mesh = pudlo_pasa
		pas.material_override = _material(
			Color(0.95, 0.78, 0.1) if i % 2 == 0 else Color(0.12, 0.12, 0.13))
		pas.position = Vector3(0, 0.075, -przekatna / 2.0 + 0.25 + i * 0.5)
		cialo.add_child(pas)
	# Pustaki podpierające szczyt
	for x in [-0.8, 0.8]:
		var pustak := MeshInstance3D.new()
		var pudlo_pustaka := BoxMesh.new()
		pudlo_pustaka.size = Vector3(0.5, wysokosc, 0.4)
		pustak.mesh = pudlo_pustaka
		pustak.material_override = _material(Color(0.62, 0.6, 0.55))
		pustak.position = Vector3(x, wysokosc / 2.0, -dlugosc / 2.0 + 0.25)
		add_child(pustak)
	# Malowidło "SKOK" na deskach — osiedlowa sztuka użytkowa
	var napis := Styl.plakietka("SKOK!", 52, Color(1.0, 0.85, 0.2))
	napis.position = Vector3(0, wysokosc + 0.7, 0)
	add_child(napis)

## Strefa na szczycie rampy — tu następuje wybicie.
func _zbuduj_wyrzutnie() -> void:
	var strefa := Area3D.new()
	strefa.position = Vector3(0, wysokosc + 0.3, -dlugosc / 2.0)
	add_child(strefa)
	var ksztalt_strefy := CollisionShape3D.new()
	var pudlo := BoxShape3D.new()
	pudlo.size = Vector3(2.4, 1.4, 1.2)
	ksztalt_strefy.shape = pudlo
	strefa.add_child(ksztalt_strefy)
	strefa.body_entered.connect(_na_wjazd)

## Wybicie: siła rośnie z prędkością, więc rozpęd naprawdę się opłaca.
func _na_wjazd(cialo: Node3D) -> void:
	if not cialo.is_in_group("gracz") or not Game.gra_trwa:
		return
	var predkosc := Vector2(cialo.velocity.x, cialo.velocity.z).length()
	if predkosc < Balans.RAMPA_MIN_PREDKOSC:
		Game.ustaw_prompt("Za wolno na skok — rozpędź się!")
		return
	# Skala 1.0 przy minimalnej prędkości, ~1.6 przy pełnym gazie skutera
	var skala := clampf(predkosc / Balans.RAMPA_MIN_PREDKOSC, 1.0, 1.6)
	cialo.velocity.y = Balans.RAMPA_WYRZUT * skala
	Sfx.graj("skok", -2.0, 1.3)
	Game.wstrzasnij(0.15)
	Efekty.kurz(get_parent(), global_position + Vector3(0, wysokosc, 0))
