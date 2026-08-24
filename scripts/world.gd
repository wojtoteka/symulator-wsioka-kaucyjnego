extends Node3D
## ŚWIAT - składa całe osiedle z prostych brył.
##
## Ten plik NIE buduje już wszystkiego sam. Miał 1180 linii i dodanie
## czegokolwiek zaczynało się od scrollowania. Teraz zostaje tu tylko to,
## co dotyczy całej sceny (teren, mała architektura, neon) plus KOLEJNOŚĆ
## budowania, a robotę wykonują trzej budowniczowie:
##
##   scripts/world_budynki.gd  - Biedronka, bloki, garaże, działki, płot
##   scripts/world_zielen.gd   - drzewa, krzaki, kamienie, chmury
##   scripts/world_npc.gd      - mieszkańcy, ruch uliczny, śmietniki, łup
##
## Wspólne klocki (pudlo/walec/przeszkoda) siedzą w scripts/world_bryly.gd,
## a plan osiedla - czyli GDZIE co stoi - w scripts/plan_osiedla.gd.
##
## Układ mapy: gracz startuje na południu (z=22), Biedronka na północy (z=-34).

const HUD := preload("res://ui/hud.gd")
const Trzepak := preload("res://scripts/trzepak.gd")
const Lawka := preload("res://scripts/lawka.gd")
const PoraDnia := preload("res://scripts/pora_dnia.gd")
const Pogoda := preload("res://scripts/pogoda.gd")

var _bryly: Bryly                  # klocki do budowania (teren, latarnie)
var _budynki: SwiatBudynki
var _neon_napis: Label3D           # szyld "BIEDRONKA" - miga jak zepsuty neon

func _ready() -> void:
	_bryly = Bryly.new(self)
	# Pora dnia i pogoda idą pierwsze: reszta świata pyta Game o pogodę
	# (np. ilu przechodniów wypuścić), a te węzły muszą już wisieć w scenie,
	# żeby oświetlenie zdążyło się ustawić przed pierwszą klatką.
	add_child(PoraDnia.new())
	add_child(Pogoda.new())
	_teren()
	var zielen := SwiatZielen.new(self)
	_budynki = SwiatBudynki.new(self)
	_budynki.zielen = zielen        # drzewka owocowe na działkach
	_budynki.zbuduj()
	zielen.zbuduj()
	_mala_architektura()
	_detale_drogi()
	SwiatNpc.new(self).zbuduj()
	_neon_napis = _budynki.neon_napis
	add_child(HUD.new())
	_neon_petla()

# --- Teren i mała architektura ---

func _teren() -> void:
	# Trawnik - wielka zielona płyta (jej wierzch to y=0).
	# 120x120: mieści osiedle, obwodnicę, garaże na wschodzie i działki na południu.
	#
	# To był najbardziej "plastikowy" element całej gry: 120 metrów jednego
	# koloru czyta się jak arkusz papieru, bo w naturze nie ma płaszczyzny bez
	# ani jednej plamy. Szum daje przetarcia i wydeptane placki - nadal
	# stylizowane, ale teren wygląda jak teren.
	# Zimą cała paleta terenu blednie. Same zaspy na jaskrawej zieleni czytają
	# się jak dziury w teksturze - dopiero wyprany trawnik robi z tego śnieg.
	var trawa := Styl.zimowo(Paleta.TRAWA) if Game.snieg() else Paleta.TRAWA
	_bryly.pudlo(Vector3(0, -0.5, 0), Vector3(120, 1, 120), trawa, true, false,
		Styl.teren_szum(trawa, 0.6, 0.15))
	# Główny chodnik (północ-południe, do Biedronki) - cienki, bez kolizji
	_bryly.pudlo(Vector3(0, 0.02, -1), Vector3(4, 0.04, 52), Paleta.CHODNIK, false, false,
		Styl.teren_szum(Paleta.CHODNIK, 1.1, 0.07))
	# Chodnik poprzeczny (wschód-zachód)
	_bryly.pudlo(Vector3(0, 0.02, 6), Vector3(36, 0.04, 3), Paleta.CHODNIK, false, false,
		Styl.teren_szum(Paleta.CHODNIK, 1.1, 0.07))
	# Parking/asfalt przed Biedronką
	_bryly.pudlo(Vector3(0, 0.015, -24), Vector3(26, 0.03, 8), Paleta.ASFALT, false, false,
		Styl.teren_szum(Paleta.ASFALT, 0.9, 0.1))

func _mala_architektura() -> void:
	# Ławki przy chodniku
	_lawka(Vector3(3.2, 0, 12), PI)
	_lawka(Vector3(-3.2, 0, 0), 0.0)
	_lawka(Vector3(3.2, 0, -12), PI)
	# Trzepak - klasyk osiedla, a od teraz też SIŁOWNIA (E = podciąganie)
	var trzepak := Trzepak.new()
	trzepak.position = Vector3(-10, 0, 14)
	add_child(trzepak)
	# Latarnie wzdłuż chodnika - słup jest metalowy i ma kolizję
	for z in [16, 2, -12]:
		_bryly.walec(Vector3(2.6, 2.0, z), 0.09, 4.0, Color(0.34, 0.34, 0.37), false, true, true)
		var klosz := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = 0.22
		kula.height = 0.44
		klosz.mesh = kula
		klosz.material_override = _bryly.material(Color(1.0, 0.95, 0.75), true)
		klosz.position = Vector3(2.6, 4.1, z)
		add_child(klosz)

func _lawka(pozycja: Vector3, obrot: float) -> void:
	# Ławka to interaktywny obiekt (siadanie) - patrz scripts/lawka.gd
	var lawka := Lawka.new()
	lawka.position = pozycja
	lawka.rotation.y = obrot
	add_child(lawka)

## Linie parkingowe i pasy - asfalt przestaje być gołą płytą.
func _detale_drogi() -> void:
	# Miejsca parkingowe przed Biedronką
	for i in 6:
		_bryly.pudlo(Vector3(-10.0 + i * 4.0, 0.045, -24), Vector3(0.15, 0.02, 6),
			Color(0.9, 0.9, 0.9), false)
	# Pasy przed wejściem do sklepu
	for i in 5:
		_bryly.pudlo(Vector3(-2.4 + i * 1.2, 0.05, -20.5), Vector3(0.8, 0.02, 3.2),
			Color(0.9, 0.9, 0.9), false)

## Neon Biedronki miga w losowych odstępach - czasem seria "zwarć".
func _neon_petla() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.0, 6.0), false).timeout
		if not is_instance_valid(_neon_napis):
			return
		if randf() < 0.35:
			# Seria szybkich mrugnięć - klasyczne zwarcie
			for i in randi_range(2, 5):
				_neon_napis.visible = false
				await get_tree().create_timer(randf_range(0.04, 0.12), false).timeout
				_neon_napis.visible = true
				await get_tree().create_timer(randf_range(0.05, 0.15), false).timeout
		else:
			# Pojedyncze dłuższe mrugnięcie
			_neon_napis.visible = false
			await get_tree().create_timer(randf_range(0.15, 0.5), false).timeout
			_neon_napis.visible = true
