extends Node3D
## POGODA - deszcz nad osiedlem.
##
## Sama pogoda to jedna zmienna w Game (losowana raz na dzień). Ten węzeł
## odpowiada tylko za to, żeby dało się ją ZOBACZYĆ i USŁYSZEĆ: krople lecące
## nad graczem, kałuże na chodnikach i szum w tle. Kolory nieba, mgłę
## i przygaszone słońce robi PoraDnia, bo to ta sama warstwa.
##
## Krople jadą z graczem (emiter przyczepiony nad jego głową) - deszcz
## symulowany nad całą mapą kosztowałby dziesiątki tysięcy cząsteczek,
## a i tak widać tylko te kilka metrów wokół kamery.

const ILE_KROPLI := 900
const WYSOKOSC_EMITERA := 9.0      # ile metrów nad graczem zaczynają krople
const OBSZAR := 13.0               # bok pudełka, w którym padają

var _krople: CPUParticles3D
var _szum: AudioStreamPlayer
var _gracz: Node3D = null

func _ready() -> void:
	if not Game.deszcz():
		return
	# W trybie headless (autotesty, CI) nie ma czego rysować, a żywy emiter
	# cząsteczek zasypuje log tysiącami błędów pustego renderera na klatkę.
	# Kałuże i szum to zwykłe węzły, więc zostają - deszcz nadal "jest".
	if DisplayServer.get_name() != "headless":
		_zbuduj_krople()
	_zbuduj_kaluze()
	_zbuduj_szum()

func _process(_delta: float) -> void:
	if _krople == null:
		return
	if not is_instance_valid(_gracz):
		var gracze := get_tree().get_nodes_in_group("gracz")
		_gracz = gracze[0] if gracze.size() > 0 else null
		if _gracz == null:
			return
	# Chmura kropli jedzie z graczem, ale nie obraca się razem z nim -
	# deszcz padający "w bok przy skręcie" natychmiast zdradza sztuczkę
	_krople.global_position = _gracz.global_position + Vector3(0, WYSOKOSC_EMITERA, 0)

## Krople: cienkie, wydłużone pudełka lecące w dół z lekkim wiatrem.
func _zbuduj_krople() -> void:
	_krople = CPUParticles3D.new()
	_krople.amount = ILE_KROPLI
	_krople.lifetime = 1.1
	_krople.preprocess = 1.1        # przy wejściu na mapę deszcz już pada
	_krople.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_krople.emission_box_extents = Vector3(OBSZAR, 0.4, OBSZAR)
	_krople.direction = Vector3(0.18, -1, 0.1)   # lekki ukos = wiatr
	_krople.spread = 2.0
	_krople.initial_velocity_min = 13.0
	_krople.initial_velocity_max = 17.0
	_krople.gravity = Vector3(0, -14, 0)
	var kropla := BoxMesh.new()
	kropla.size = Vector3(0.022, 0.34, 0.022)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.82, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	kropla.material = mat
	_krople.mesh = kropla
	add_child(_krople)

## Kałuże - płaskie ciemne placki na chodnikach i asfalcie. Rysowane raz,
## bez fizyki: mają mówić "mokro", a nie spowalniać.
func _zbuduj_kaluze() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.22, 0.28, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.65
	mat.roughness = 0.12          # połysk to jedyne, co odróżnia kałużę od plamy
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	for i in 26:
		var kaluza := MeshInstance3D.new()
		var placek := CylinderMesh.new()
		placek.top_radius = randf_range(0.5, 1.7)
		placek.bottom_radius = placek.top_radius
		placek.height = 0.015
		placek.radial_segments = 10
		kaluza.mesh = placek
		kaluza.material_override = mat
		kaluza.position = Plan.losuj_wolne([-26.0, 26.0, -26.0, 32.0]) + Vector3(0, 0.055, 0)
		kaluza.scale.z = randf_range(0.6, 1.4)   # kałuże nie są okrągłe
		kaluza.rotation.y = randf() * TAU
		add_child(kaluza)

## Szum deszczu - zapętlony, generowany w kodzie (patrz Sfx.petla_deszczu).
func _zbuduj_szum() -> void:
	_szum = AudioStreamPlayer.new()
	_szum.stream = Sfx.petla_deszczu()
	_szum.volume_db = -13.0
	_szum.autoplay = true
	add_child(_szum)
