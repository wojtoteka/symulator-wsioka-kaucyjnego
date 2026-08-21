extends Area3D
## DRZWI - teleportują gracza (wejście i wyjście z Biedronki).
## world.gd ustawia: cel, obrot_y, etykieta, komunikat.

var cel := Vector3.ZERO       # dokąd teleportować gracza
var obrot_y := 0.0            # obrót gracza po teleporcie (radiany)
var etykieta := "E - wejdź"
var komunikat := ""

func _ready() -> void:
	add_to_group("interakcja")
	var ksztalt := CollisionShape3D.new()
	var pudlo := BoxShape3D.new()
	pudlo.size = Vector3(2.5, 3.0, 1.4)
	ksztalt.shape = pudlo
	ksztalt.position = Vector3(0, 1.5, 0)
	add_child(ksztalt)

func podpowiedz() -> String:
	return etykieta

func interakcja(gracz: Node3D) -> void:
	Sfx.graj("sklep")
	# Płynne przejście: ekran ściemnia się, teleport dzieje się "za kurtyną"
	Game.popros_przejscie(func() -> void:
		gracz.teleportuj(cel, obrot_y)
		if komunikat != "":
			Game.pokaz_komunikat(komunikat)
	)
