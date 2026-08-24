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
	# Kiosk RUCH - od teraz sprzedaje też paczkę szlugów
	{"nazwa": "22_kiosk", "gdzie": Vector3(11.5, 0.2, 9.5), "obrot": 90.0},
	# Transparent na bloku - wisiał w poprzek balkonów trzeciego piętra, więc
	# ujęcie musi patrzeć W GÓRĘ: z poziomu chodnika napis jest poza kadrem
	{"nazwa": "23_transparent", "gdzie": Vector3(2, 0.2, 4), "obrot": 90.0, "pion": 26.0},
]

## Ujęcie do przeglądu pór dnia: widok na osiedle spod Biedronki.
const UJECIE_PORY := {"gdzie": Vector3(0, 0.2, 16), "obrot": 180.0}

## Które momenty dnia utrwalić (ułamek rundy: 0.0 = start, 1.0 = dzwonek).
## Słońce, niebo i mgła jadą po tej samej osi - patrz scripts/pora_dnia.gd.
const PORY: Array = [
	{"nazwa": "15_poranek", "postep": 0.0},
	{"nazwa": "16_poludnie", "postep": 0.32},
	{"nazwa": "17_popoludnie", "postep": 0.65},
	{"nazwa": "18_zachod", "postep": 0.97},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(KATALOG)
	# MAGNES włączamy na sztywno, ZANIM zbuduje się HUD: pasek baterii pokazuje
	# się tylko posiadaczom ulepszenia, więc bez tego nie dałoby się sprawdzić,
	# czy w ogóle mieści się w panelu. Zapis kariery jest w trybie narzędziowym
	# zablokowany, więc graczowi nic z tego nie zostaje.
	Game.ulepszenia["magnes"] = 1
	# To samo z PACZKĄ SZLUGÓW: wiersz w HUD-zie pojawia się dopiero po zakupie,
	# więc bez tego nigdy nie trafiłby na zrzut i nikt by nie zobaczył, że się
	# rozjechał. Dokładamy też zapalonego szluga - pasek odliczania to osobny
	# stan i też ma się mieścić w panelu.
	Game.szlugi = Balans.SZLUGI_W_PACZCE
	Game.szlug = Balans.SZLUG_CZAS
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
	# Wysięgnik kamery: część ujęć musi patrzeć w górę (transparent pod gzymsem
	# bloku). Sięgamy po prywatne pole gracza tą samą drogą, co po panele HUD-u -
	# to narzędzie, a nie gra, i nie ma po co dokładać publicznego API dla zrzutów.
	var ramie: Variant = gracz.get("_ramie")
	var wyglad: Variant = gracz.get("_wyglad")
	var pion_domyslny: float = ramie.rotation.x if ramie != null else 0.0
	var dlugosc_domyslna: float = ramie.spring_length if ramie != null else 4.0
	for ujecie in UJECIA:
		gracz.global_position = ujecie["gdzie"]
		gracz.rotation.y = deg_to_rad(float(ujecie["obrot"]))
		gracz.velocity = Vector3.ZERO
		# Ujęcia "do góry" robimy z PIERWSZEJ OSOBY. W trzeciej wysięgnik o długości
		# czterech metrów, zadarty pod 26 stopni, wsadza kamerę pod ziemię - i kadr
		# pokazuje spód trawnika zamiast transparentu.
		var patrzy_w_gore: bool = ujecie.has("pion")
		if ramie != null:
			var pion := deg_to_rad(float(ujecie.get("pion", 0.0)))
			ramie.rotation.x = pion if patrzy_w_gore else pion_domyslny
			ramie.spring_length = 0.05 if patrzy_w_gore else dlugosc_domyslna
		if wyglad != null:
			wyglad.visible = not patrzy_w_gore
		# Dwie klatki na przerysowanie + chwila na doczytanie cieni
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var obraz := get_viewport().get_texture().get_image()
		var sciezka := "%s/%s.png" % [KATALOG, ujecie["nazwa"]]
		obraz.save_png(sciezka)
		print("ZRZUT: %s -> %s" % [ujecie["nazwa"], ProjectSettings.globalize_path(sciezka)])
	# PORY DNIA - to jedyny sposób, żeby obejrzeć zachód słońca bez czekania
	# pięciu minut. Przewijamy zegar rundy i robimy zdjęcie z tego samego miejsca,
	# więc cztery pliki obok siebie pokazują, jak zmienia się światło.
	# MUSI być przed kreskami pędu: te wyłączają sobie _process i zostają
	# na ekranie już do końca przebiegu.
	await _przeglad_por_dnia(gracz)
	# ZIMA. Gdy przebieg wystartował z "--snieg", całe osiedle JEST już zimowe
	# (łącznie z paletą terenu i zieleni, bo te budują się raz) - wtedy robimy
	# zwykłe ujęcie. Bez flagi zostaje podmiana w locie: nieba i opadu tak,
	# ale trawnik pozostanie zielony.
	await _zrzut_zimy(gracz)
	# KSIĘGA WSIOKA - sprawdzamy, czy trzydzieści wpisów mieści się na 720p
	await _zrzut_ksiegi()
	# USTAWIENIA - panel urósł z trzech pozycji do dziewięciu i dwóch kolumn,
	# więc "czy się mieści na 720p" przestało być pytaniem retorycznym
	await _zrzut_ustawien()
	# Osobne ujęcie z wymuszonymi kreskami pędu (bez tego gracz musiałby jechać)
	_wymus_motion_lines()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/9_motion_lines.png" % KATALOG)
	print("ZRZUT: 9_motion_lines")
	# Ekran podsumowania z MELINĄ - sprawdzamy, czy dziewięć ulepszeń się mieści
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

## Przewija czas rundy i zapisuje ten sam kadr o różnych porach dnia.
## Na koniec przywraca poranek, żeby dalsze zrzuty wyglądały jak zwykle.
func _przeglad_por_dnia(gracz: Node3D) -> void:
	gracz.global_position = UJECIE_PORY["gdzie"]
	gracz.rotation.y = deg_to_rad(float(UJECIE_PORY["obrot"]))
	gracz.velocity = Vector3.ZERO
	for pora in PORY:
		Game.czas = Balans.CZAS_RUNDY * (1.0 - float(pora["postep"]))
		# PoraDnia odświeża się dziesięć razy na sekundę i dochodzi płynnie -
		# pół sekundy wystarczy, żeby światło zdążyło dojechać na miejsce
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var sciezka := "%s/%s.png" % [KATALOG, pora["nazwa"]]
		get_viewport().get_texture().get_image().save_png(sciezka)
		print("ZRZUT: %s (postęp dnia %.0f%%)" % [pora["nazwa"], float(pora["postep"]) * 100.0])
	Game.czas = Balans.CZAS_RUNDY

## ZIMA NA ŻĄDANIE. Pogoda jest losowana raz na dzień, a śnieg wchodzi dopiero
## od dnia ZIMA_OD_DNIA - czekanie na niego w trybie zrzutów nie ma sensu.
## Przestawiamy zmienną i dokładamy ŚWIEŻY węzeł Pogody: ten w scenie zbudował
## już swoje kałuże i nie zamieni ich w zaspy.
func _zrzut_zimy(gracz: Node3D) -> void:
	if not Game.snieg():
		Game.dzien = maxi(Game.dzien, Balans.ZIMA_OD_DNIA)
		Game.pogoda = "snieg"
		get_tree().current_scene.add_child(load("res://scripts/pogoda.gd").new())
	gracz.global_position = UJECIE_PORY["gdzie"]
	gracz.rotation.y = deg_to_rad(float(UJECIE_PORY["obrot"]))
	gracz.velocity = Vector3.ZERO
	# PoraDnia dochodzi do bieli płynnie (move_toward co 0,1 s) - dajemy jej czas
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/19_zima.png" % KATALOG)
	print("ZRZUT: 19_zima")

## Ekran Księgi wsioka. Panel żyje w HUD-zie, więc szukamy go po skrypcie -
## HUD nie jest w żadnej grupie, a dokładanie jej tylko dla zrzutów byłoby
## dokładaniem stanu do gry na potrzeby narzędzia.
func _zrzut_ksiegi() -> void:
	var hud := _znajdz_hud()
	if hud == null:
		printerr("ZRZUT: nie znalazłem HUD-u - pomijam Księgę")
		return
	hud.call("_pokaz_ksiege")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/20_ksiega.png" % KATALOG)
	print("ZRZUT: 20_ksiega")
	# Chowamy panel, żeby nie został na kolejnych ujęciach
	var panel: Variant = hud.get("_panel_ksiegi")
	if panel != null:
		panel.visible = false

## Panel ustawień - ta sama sztuczka, co przy Księdze.
func _zrzut_ustawien() -> void:
	var hud := _znajdz_hud()
	if hud == null:
		printerr("ZRZUT: nie znalazłem HUD-u - pomijam ustawienia")
		return
	hud.call("_pokaz_ustawienia")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/21_ustawienia.png" % KATALOG)
	print("ZRZUT: 21_ustawienia")
	var panel: Variant = hud.get("_panel_ustawien")
	if panel != null:
		panel.visible = false

func _znajdz_hud() -> Node:
	for wezel in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if wezel.get_script() != null and str(wezel.get_script().resource_path).ends_with("hud.gd"):
			return wezel
	return null

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
	# Pogoda W WYNIKU, bo bez niej dwa przebiegi są nieporównywalne: zamieć
	# kosztuje kilka razy więcej niż słońce i bez tej informacji spadek FPS
	# wygląda jak regresja kodu (raz już tak było).
	print("PLYNNOSC: srednio %.0f FPS (probek: %d, pogoda: %s)" % [
		suma / probki.size(), probki.size(), Game.pogoda])

## Podkręca efekt pędu na sztywno, żeby dało się go obejrzeć na stojąco.
## Trzeba wyłączyć _process, bo inaczej natychmiast wygasi wymuszoną wartość.
func _wymus_motion_lines() -> void:
	for wezel in get_tree().root.find_children("*", "Control", true, false):
		if wezel.get_script() != null and str(wezel.get_script().resource_path).ends_with("motion_lines.gd"):
			wezel.set_process(false)
			wezel.set("_sila", 0.9)
			wezel.queue_redraw()
