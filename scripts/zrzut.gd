extends Node
## TRYB ZRZUTÓW (narzędzie deweloperskie) - uruchamiany przez:
##   godot -- --autostart --zrzut
## Obchodzi kolejne lokacje, zapisuje PNG do user://zrzuty/ i zamyka grę.
## Służy do sprawdzenia, czy świat i HUD faktycznie wyglądają jak trzeba -
## headless tego nie pokaże, bo nie renderuje obrazu.

const KATALOG := "user://zrzuty"

## Kolejne ujęcia: nazwa pliku, pozycja gracza, obrót w stopniach.
const UJECIA: Array = [
	{"nazwa": "1_osiedle", "gdzie": Vector3(0, 0.2, 16), "obrot": 180.0},
	{"nazwa": "2_biedronka", "gdzie": Vector3(0, 0.2, -18), "obrot": 180.0},
	{"nazwa": "3_tablica", "gdzie": Vector3(1.5, 0.2, 14), "obrot": 90.0},
	{"nazwa": "4_garaze", "gdzie": Vector3(36, 0.2, 0), "obrot": 270.0},
	{"nazwa": "5_rampa", "gdzie": Vector3(38, 0.2, -14), "obrot": 180.0},
	{"nazwa": "6_dzialki", "gdzie": Vector3(0, 0.2, 36), "obrot": 0.0},
	{"nazwa": "7_skup", "gdzie": Vector3(0, 0.2, 46), "obrot": 180.0},
	{"nazwa": "8_obwodnica", "gdzie": Vector3(24, 0.2, 30), "obrot": 135.0},
	# Obwodnica z bliska - sylwetka aut i odstępy w kolumnie
	{"nazwa": "13_ruch", "gdzie": Vector3(24, 0.2, 36), "obrot": 200.0},
	# Automat z napojami przy wejściu do Biedronki
	{"nazwa": "12_automat", "gdzie": Vector3(4.6, 0.2, -24.2), "obrot": 0.0},
	# Styk działek z obwodnicą - tu płotki wchodziły na asfalt
	{"nazwa": "11_dzialki_ulica", "gdzie": Vector3(-14, 0.2, 44), "obrot": 250.0},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(KATALOG)
	await get_tree().process_frame
	var gracz: Node3D = null
	var gracze := get_tree().get_nodes_in_group("gracz")
	if gracze.size() > 0:
		gracz = gracze[0]
	if gracz == null:
		printerr("ZRZUT: nie znalazłem gracza")
		get_tree().quit(1)
		return
	# Chwila na złożenie świata i rozjaśnienie ekranu z czerni
	await get_tree().create_timer(1.2).timeout
	for ujecie in UJECIA:
		gracz.global_position = ujecie["gdzie"]
		gracz.rotation.y = deg_to_rad(float(ujecie["obrot"]))
		gracz.velocity = Vector3.ZERO
		# Dwie klatki na przerysowanie + chwila na doczytanie cieni
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var obraz := get_viewport().get_texture().get_image()
		var sciezka := "%s/%s.png" % [KATALOG, ujecie["nazwa"]]
		obraz.save_png(sciezka)
		print("ZRZUT: %s -> %s" % [ujecie["nazwa"], ProjectSettings.globalize_path(sciezka)])
	# Osobne ujęcie z wymuszonymi kreskami pędu (bez tego gracz musiałby jechać)
	_wymus_motion_lines()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/9_motion_lines.png" % KATALOG)
	print("ZRZUT: 9_motion_lines")
	# Ekran podsumowania z MELINĄ - sprawdzamy, czy sześć ulepszeń się mieści
	Game.kasa = 87.5
	Game.statystyki["zlom"] = 6
	Game.statystyki["oddany_zlom"] = 6
	Game.statystyki["zlecenia"] = 2
	Game.statystyki["loty"] = 3
	Game.koniec_dnia()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/10_podsumowanie.png" % KATALOG)
	print("ZRZUT: 10_podsumowanie")
	# Pomiar płynności - kontury (drugi przebieg rysowania) podwajają liczbę
	# wywołań, więc warto wiedzieć, ile to realnie kosztuje
	await _zmierz_plynnosc()
	print("ZRZUTY GOTOWE: %s" % ProjectSettings.globalize_path(KATALOG))
	get_tree().quit(0)

## Średni FPS z kilku sekund stania w najgęstszym miejscu mapy.
func _zmierz_plynnosc() -> void:
	var gracze := get_tree().get_nodes_in_group("gracz")
	if gracze.is_empty():
		return
	# Pozycja I OBRÓT muszą być ustalone na sztywno, inaczej pomiar dziedziczy
	# kierunek po ostatnim ujęciu i wynik zmienia się przy każdej zmianie listy
	# zdjęć - wtedy nie da się porównać dwóch przebiegów.
	gracze[0].global_position = Vector3(0, 0.2, 20)   # widok na całe osiedle
	gracze[0].rotation.y = deg_to_rad(180.0)          # patrzymy na Biedronkę
	await get_tree().create_timer(1.0).timeout
	var probki: Array[float] = []
	for i in 60:
		await get_tree().process_frame
		probki.append(Engine.get_frames_per_second())
	var suma := 0.0
	for p in probki:
		suma += p
	print("PLYNNOSC: srednio %.0f FPS (probek: %d)" % [suma / probki.size(), probki.size()])

## Podkręca efekt pędu na sztywno, żeby dało się go obejrzeć na stojąco.
## Trzeba wyłączyć _process, bo inaczej natychmiast wygasi wymuszoną wartość.
func _wymus_motion_lines() -> void:
	for wezel in get_tree().root.find_children("*", "Control", true, false):
		if wezel.get_script() != null and str(wezel.get_script().resource_path).ends_with("motion_lines.gd"):
			wezel.set_process(false)
			wezel.set("_sila", 0.9)
			wezel.queue_redraw()
