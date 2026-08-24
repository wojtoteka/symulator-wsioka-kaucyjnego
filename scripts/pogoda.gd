extends Node3D
## POGODA - deszcz i śnieg nad osiedlem.
##
## Sama pogoda to jedna zmienna w Game (losowana raz na dzień). Ten węzeł
## odpowiada tylko za to, żeby dało się ją ZOBACZYĆ i USŁYSZEĆ: krople (albo
## płatki) lecące nad graczem, kałuże i zaspy na chodnikach, szum w tle.
## Kolory nieba, mgłę i przygaszone słońce robi PoraDnia, bo to ta sama warstwa.
##
## Cząstki jadą z graczem (emiter przyczepiony nad jego głową) - opad
## symulowany nad całą mapą kosztowałby dziesiątki tysięcy cząsteczek,
## a i tak widać tylko te kilka metrów wokół kamery.
##
## POD DACHEM jest inaczej. Szum deszczu grał wszędzie tak samo, więc wiaty
## były tylko bryłą - a schowanie się przed deszczem to jedna z tych rzeczy,
## które sprzedają pogodę lepiej niż same cząsteczki. Teraz pod blachą szum
## przygasa i wchodzi bębnienie. Przy śniegu nic nie bębni - i to też jest
## informacja: cisza pod dachem brzmi jak zima.

const ILE_KROPLI := 900
const ILE_PLATKOW := 700
const WYSOKOSC_EMITERA := 9.0      # ile metrów nad graczem zaczyna się opad
const OBSZAR := 13.0               # bok pudełka, w którym pada
const ODSWIEZANIE_DACHU := 0.15    # co ile sekund sprawdzamy, czy jest dach
const TEMPO_MIKSU := 6.0           # jak szybko przechodzi miks deszcz <-> blacha
const SZUM_NA_OTWARTYM := -13.0
const CISZA_DB := -60.0

var _krople: CPUParticles3D
var _szum: AudioStreamPlayer       # opad na otwartym
var _blacha: AudioStreamPlayer     # bębnienie o daszek (tylko deszcz)
var _gracz: Node3D = null
var _do_sprawdzenia := 0.0
var _pod_dachem := 0.0             # 0..1, płynnie goni stan faktyczny
var _pod_dachem_cel := 0.0

func _ready() -> void:
	if not Game.mokro():
		return
	# W trybie headless (autotesty, CI) nie ma czego rysować, a żywy emiter
	# cząsteczek zasypuje log tysiącami błędów pustego renderera na klatkę.
	# Zaspy i szum to zwykłe węzły, więc zostają - pogoda nadal "jest".
	if DisplayServer.get_name() != "headless":
		_zbuduj_opad()
	_zbuduj_grunt()
	_zbuduj_dzwiek()

func _process(delta: float) -> void:
	_znajdz_gracza()
	if _gracz == null:
		return
	if _krople != null:
		# Chmura opadu jedzie z graczem, ale nie obraca się razem z nim -
		# deszcz padający "w bok przy skręcie" natychmiast zdradza sztuczkę
		_krople.global_position = _gracz.global_position + Vector3(0, WYSOKOSC_EMITERA, 0)
	_miks_dachu(delta)

func _znajdz_gracza() -> void:
	if is_instance_valid(_gracz):
		return
	var gracze := get_tree().get_nodes_in_group("gracz")
	_gracz = gracze[0] if gracze.size() > 0 else null

# =============================================================================
#  OPAD
# =============================================================================

func _zbuduj_opad() -> void:
	_krople = CPUParticles3D.new()
	_krople.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_krople.emission_box_extents = Vector3(OBSZAR, 0.4, OBSZAR)
	if Game.snieg():
		_ustaw_snieg()
	else:
		_ustaw_deszcz()
	add_child(_krople)

## Deszcz: cienkie, wydłużone pudełka lecące w dół z lekkim wiatrem.
func _ustaw_deszcz() -> void:
	_krople.amount = ILE_KROPLI
	_krople.lifetime = 1.1
	_krople.preprocess = 1.1        # przy wejściu na mapę deszcz już pada
	_krople.direction = Vector3(0.18, -1, 0.1)   # lekki ukos = wiatr
	_krople.spread = 2.0
	_krople.initial_velocity_min = 13.0
	_krople.initial_velocity_max = 17.0
	_krople.gravity = Vector3(0, -14, 0)
	var kropla := BoxMesh.new()
	kropla.size = Vector3(0.022, 0.34, 0.022)
	kropla.material = _material_opadu(Color(0.72, 0.82, 0.95, 0.55))
	_krople.mesh = kropla

## Śnieg: drobne płatki lecące WOLNO i szeroko wirujące. Cała różnica między
## deszczem a śniegiem siedzi w prędkości i rozrzucie - te same cząsteczki
## z parametrami deszczu wyglądają po prostu jak biały deszcz.
func _ustaw_snieg() -> void:
	_krople.amount = ILE_PLATKOW
	_krople.lifetime = 5.0
	_krople.preprocess = 5.0
	_krople.direction = Vector3(0.3, -1, 0.15)
	_krople.spread = 22.0           # płatki nie lecą równo w dół
	_krople.initial_velocity_min = 0.8
	_krople.initial_velocity_max = 1.9
	_krople.gravity = Vector3(0.4, -1.1, 0.2)
	# Opór powietrza - bez niego śnieg opada jak kurz w tunelu aerodynamicznym
	_krople.damping_min = 0.2
	_krople.damping_max = 0.6
	_krople.scale_amount_min = 0.7
	_krople.scale_amount_max = 1.5
	var platek := QuadMesh.new()
	platek.size = Vector2(0.09, 0.09)
	platek.material = _material_opadu(Color(1.0, 1.0, 1.0, 0.9))
	_krople.mesh = platek

func _material_opadu(kolor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kolor
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Płatek ma być widoczny z każdej strony; kropla ma zostać kreską
	if Game.snieg():
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return mat

# =============================================================================
#  GRUNT: kałuże albo zaspy
# =============================================================================

func _zbuduj_grunt() -> void:
	if Game.snieg():
		_zbuduj_zaspy()
	else:
		_zbuduj_kaluze()

## Kałuże - płaskie ciemne placki na chodnikach i asfalcie. Rysowane raz,
## bez fizyki: mają mówić "mokro", a nie spowalniać.
func _zbuduj_kaluze() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.22, 0.28, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.65
	mat.roughness = 0.12          # połysk to jedyne, co odróżnia kałużę od plamy
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_rozsyp_placki(mat, 26, 0.5, 1.7, 0.055)

## Zaspy - białe płachty tam, gdzie kałuże byłyby w deszczu. Większe
## i jaśniejsze, bo śnieg nie zbiera się w kropki, tylko przykrywa.
func _zbuduj_zaspy() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.95, 0.99, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.85          # śnieg nie błyszczy, tylko rozprasza
	_rozsyp_placki(mat, 44, 1.4, 4.2, 0.05)

## Wspólne rozsypanie płaskich placków po wolnych miejscach mapy.
func _rozsyp_placki(mat: StandardMaterial3D, ile: int, r_min: float, r_maks: float,
		wysokosc: float) -> void:
	for i in ile:
		var placek_mesh := MeshInstance3D.new()
		var placek := CylinderMesh.new()
		placek.top_radius = randf_range(r_min, r_maks)
		placek.bottom_radius = placek.top_radius
		placek.height = 0.015
		placek.radial_segments = 10
		placek_mesh.mesh = placek
		placek_mesh.material_override = mat
		placek_mesh.position = Plan.losuj_wolne([-26.0, 26.0, -26.0, 32.0]) \
			+ Vector3(0, wysokosc, 0)
		placek_mesh.scale.z = randf_range(0.6, 1.4)   # ani kałuże, ani zaspy nie są okrągłe
		placek_mesh.rotation.y = randf() * TAU
		add_child(placek_mesh)

# =============================================================================
#  DŹWIĘK: opad na otwartym vs pod dachem
# =============================================================================

func _zbuduj_dzwiek() -> void:
	_szum = AudioStreamPlayer.new()
	_szum.stream = Sfx.petla_deszczu()
	_szum.autoplay = true
	if Game.snieg():
		# Zamieć to nie szum wody, tylko wiatr - ten sam materiał puszczony
		# wolniej i ciszej brzmi dokładnie tak, jak trzeba
		_szum.pitch_scale = 0.55
		_szum.volume_db = -21.0
	else:
		_szum.volume_db = SZUM_NA_OTWARTYM
	add_child(_szum)
	# Bębnienie o blachę ma sens tylko przy deszczu. Śnieg pada bezgłośnie
	# i cisza pod wiatą jest wtedy własną informacją.
	if Game.snieg():
		return
	_blacha = AudioStreamPlayer.new()
	_blacha.stream = Sfx.petla_dachu()
	_blacha.autoplay = true
	_blacha.volume_db = CISZA_DB     # startujemy na otwartym
	add_child(_blacha)

## Płynne przejście między "leje na głowę" a "bębni nad głową".
func _miks_dachu(delta: float) -> void:
	if _blacha == null:
		return
	_do_sprawdzenia -= delta
	if _do_sprawdzenia <= 0.0:
		_do_sprawdzenia = ODSWIEZANIE_DACHU
		var p := _gracz.global_position
		_pod_dachem_cel = 1.0 if Plan.pod_dachem(p.x, p.z) else 0.0
	_pod_dachem = move_toward(_pod_dachem, _pod_dachem_cel, TEMPO_MIKSU * delta)
	_szum.volume_db = lerpf(SZUM_NA_OTWARTYM, Balans.DACH_SZUM_DB, _pod_dachem)
	_blacha.volume_db = lerpf(CISZA_DB, Balans.DACH_BEBNIENIE_DB, _pod_dachem)
