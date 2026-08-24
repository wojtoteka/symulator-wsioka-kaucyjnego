extends AudioStreamPlayer3D
## OKNO Z DISCO POLO - głośnik w oknie prawego bloku plus strefa morale.
##
## Osobny węzeł, a nie kilka linijek w world.gd, z jednego powodu: podpina
## się pod sygnał Game.tryb_wsioka_changed. Gdy gracz wpada w TRYB WSIOKA,
## sąsiad robi głośniej - a sygnał podpięty do węzła rozłącza się sam,
## gdy scena znika. Podpięty do zwykłego obiektu zostawiłby wiszące
## połączenie przy każdym nowym dniu.

const GLOSNOSC_ZWYKLA := -4.0
const GLOSNOSC_TRYBU := 5.0     # w TRYBIE WSIOKA sąsiad kręci gałkę w prawo
const PRZERWA_MORALE := 30.0    # cooldown bonusu za wejście w zasięg

var _ostatnie_disco := -999.0

func _ready() -> void:
	stream = Sfx.petla_disco()
	unit_size = 5.0
	max_distance = 28.0
	volume_db = GLOSNOSC_ZWYKLA
	autoplay = true
	Game.tryb_wsioka_changed.connect(_na_tryb_wsioka)
	# Strefa morale wokół okna - wejście w zasięg podbija Wsiokometr
	var strefa := Area3D.new()
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = 8.0
	ksztalt.shape = kula
	strefa.add_child(ksztalt)
	strefa.position = Vector3(-1.8, -4.5, 0)   # na wysokości chodnika pod oknem
	add_child(strefa)
	strefa.body_entered.connect(_wejscie_w_zasieg)

## TRYB WSIOKA: disco polo głośniej i słychać je z drugiego końca osiedla.
func _na_tryb_wsioka(aktywny: bool, _pozostalo: float) -> void:
	var docelowa := GLOSNOSC_TRYBU if aktywny else GLOSNOSC_ZWYKLA
	max_distance = 55.0 if aktywny else 28.0
	create_tween().tween_property(self, "volume_db", docelowa, 0.6)

## Wejście w zasięg disco polo: morale (Wsiokometr) rośnie.
func _wejscie_w_zasieg(cialo: Node3D) -> void:
	if not (cialo is CharacterBody3D and cialo.is_in_group("gracz")):
		return
	var teraz := Time.get_ticks_msec() / 1000.0
	if teraz - _ostatnie_disco < PRZERWA_MORALE:
		return
	_ostatnie_disco = teraz
	Game.dodaj_wsiokometr(5.0)
	Game.pokaz_komunikat("Z okna leci disco polo. Morale rośnie! Wsiokometr +5.")
