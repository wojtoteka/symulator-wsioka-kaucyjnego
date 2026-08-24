extends CanvasLayer
## HUD - cały interfejs budowany w kodzie:
## menu główne, pauza (Esc), licznik kasy/plecaka, timer, Wsiokometr,
## pasek "Papieros", combo, komunikaty, podpowiedź interakcji,
## intro po starcie i ekran podsumowania na koniec dnia.

var _korzen: Control
var _ety_kasa: Label
var _ety_plecak: Label
var _ety_czas: Label
var _ety_prompt: Label
var _ety_combo: Label
var _ety_papieros: Label
var _pasek_papierosa: ColorRect
var _ety_wsiokometr: Label
var _pasek_wsiokometru: ColorRect
var _ety_meme: Label
var _kanal_komunikatow: VBoxContainer
var _panel_konca: CenterContainer
var _panel_menu: Control
var _panel_pauzy: Control
var _panel_ustawien: Control
var _zaslona: ColorRect        # czarna zasłona do przejść fade
var _nakladka: ColorRect       # kolorowy filtr upojenia/kaca
var _ety_tutorial: Label
var _ety_wyzwanie: Label
var _ety_bank: Label
var _panel_hud: PanelContainer   # panel z kasą (chowany na ekranie podsumowania)
var _radar: Control              # minimapa w prawym dolnym rogu
var _nawigacja: Control          # strzałka do aktualnego celu
var _motion_lines: Control       # kreski pędu przy dużej prędkości
var _panel_zlecenia: PanelContainer   # aktywne zlecenie z tablicy ogłoszeń
var _ety_zlecenie_tytul: Label
var _ety_zlecenie_opis: Label
var _pasek_zlecenia: ColorRect
var _przyciski_sklepu := {}    # id ulepszenia -> Button
var _w_przejsciu := false
var _kasa_wyswietlana := 0.0   # do animowanego naliczania kasy
var _sepia: ColorRect          # filtr TRYBU WSIOKA (mnożenie kolorów)
var _ety_tryb: Label           # wielki licznik "TRYB WSIOKA 12 s"
var _ety_rywal: Label          # tablica wyników: Ty vs Heniek
var _wiersz_czasu: HBoxContainer   # zegar u góry (chowany po dzwonku)
var _sepia_cel := Color.WHITE  # docelowy kolor filtru (żeby nie mnożyć tweenów)

const SZEROKOSC_PASKA := 170.0

func _ready() -> void:
	layer = 10
	# HUD działa też podczas pauzy (żeby przyciski reagowały)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zbuduj()
	# Podpinamy się pod sygnały globalnego stanu gry
	Game.money_changed.connect(_aktualizuj_kase)
	Game.backpack_changed.connect(_aktualizuj_plecak)
	Game.time_changed.connect(_aktualizuj_czas)
	Game.komunikat.connect(_dodaj_komunikat)
	Game.prompt_changed.connect(_aktualizuj_prompt)
	Game.round_ended.connect(_pokaz_podsumowanie)
	Game.stamina_changed.connect(_aktualizuj_papierosa)
	Game.wsiokometr_changed.connect(_aktualizuj_wsiokometr)
	Game.combo_changed.connect(_aktualizuj_combo)
	Game.meme.connect(_pokaz_meme)
	Game.przejscie.connect(_wykonaj_przejscie)
	Game.upojenie.connect(_aktualizuj_upojenie)
	Game.wyzwanie_changed.connect(_aktualizuj_wyzwanie)
	Game.zlecenie_changed.connect(_aktualizuj_zlecenie)
	Game.tryb_wsioka_changed.connect(_aktualizuj_tryb_wsioka)
	Game.rywal_changed.connect(_aktualizuj_rywala)
	# Stan wyzwania na starcie sceny
	if not Game.wyzwanie.is_empty():
		_aktualizuj_wyzwanie(
			Game.opis_wyzwania(), Game.wyzwanie["postep"],
			Game.wyzwanie["cel"], Game.wyzwanie["zrobione"]
		)
	# Wartości startowe
	_kasa_wyswietlana = Game.kasa
	_aktualizuj_kase(Game.kasa)
	_aktualizuj_plecak(Game.plecak.size(), Game.pojemnosc_plecaka())
	_aktualizuj_czas(Game.czas)
	# Menu główne tylko przy pierwszym uruchomieniu (restart pomija)
	if Game.w_menu:
		_panel_menu.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_pokaz_intro()
		_tutorial()
	# Płynne rozjaśnienie z czerni przy każdym wejściu do sceny
	_zaslona.modulate.a = 1.0
	create_tween().tween_property(_zaslona, "modulate:a", 0.0, 0.5)

func _input(zdarzenie: InputEvent) -> void:
	# Po końcu dnia R zaczyna nowy dzień (z płynnym przejściem)
	if not Game.gra_trwa and not Game.w_menu and zdarzenie.is_action_pressed("restart"):
		_nowy_dzien_z_przejsciem()
	# Esc - pauza (tylko w trakcie gry)
	if zdarzenie.is_action_pressed("ui_cancel") and Game.gra_trwa and not Game.w_menu:
		_przelacz_pauze()
	# F11 - pełny ekran
	var klawisz := zdarzenie as InputEventKey
	if klawisz and klawisz.pressed and klawisz.keycode == KEY_F11:
		_przelacz_pelny_ekran()
	# Enter w menu głównym = start
	if Game.w_menu and zdarzenie.is_action_pressed("ui_accept"):
		_start_gry()

# --- Pomocnicze ---

## Label z obrysem - czytelny na każdym tle.
func _etykieta(tekst: String, rozmiar: int, kolor := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = tekst
	l.add_theme_font_size_override("font_size", rozmiar)
	l.add_theme_color_override("font_color", kolor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l

## Malutka piksel-ikona rysowana w kodzie (zero plików graficznych).
func _ikona(rodzaj: String, rozmiar := 22) -> TextureRect:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match rodzaj:
		"moneta":
			_kolo(img, 8, 8, 6, Color(0.85, 0.65, 0.15))
			_kolo(img, 8, 8, 4, Color(1.0, 0.88, 0.4))
		"butelka":
			img.fill_rect(Rect2i(6, 0, 4, 2), Color(0.9, 0.75, 0.2))   # kapsel
			img.fill_rect(Rect2i(6, 2, 4, 4), Color(0.45, 0.8, 0.55))  # szyjka
			img.fill_rect(Rect2i(4, 6, 8, 10), Color(0.3, 0.7, 0.45))  # korpus
		"zegar":
			_kolo(img, 8, 8, 7, Color(0.9, 0.9, 0.9))
			_kolo(img, 8, 8, 5, Color(0.16, 0.2, 0.3))
			img.fill_rect(Rect2i(7, 4, 2, 5), Color(0.95, 0.95, 0.95))  # wskazówka
			img.fill_rect(Rect2i(8, 8, 4, 2), Color(0.95, 0.95, 0.95))
		"czapka":
			img.fill_rect(Rect2i(3, 5, 10, 5), Color(0.8, 0.15, 0.15))  # główka
			img.fill_rect(Rect2i(1, 10, 14, 2), Color(0.65, 0.1, 0.1))  # daszek
		"papieros":
			img.fill_rect(Rect2i(1, 7, 12, 3), Color(0.95, 0.95, 0.9))
			img.fill_rect(Rect2i(13, 7, 2, 3), Color(1.0, 0.5, 0.15))   # żar
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.custom_minimum_size = Vector2(rozmiar, rozmiar)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pikselowy urok
	return tr

## Wypełnione koło na obrazku 16x16 (do ikon).
func _kolo(img: Image, cx: int, cy: int, r: int, kolor: Color) -> void:
	for y in 16:
		for x in 16:
			if Vector2(x - cx, y - cy).length() <= float(r):
				img.set_pixel(x, y, kolor)

## Wiersz HUD: ikona + etykieta obok siebie.
func _wiersz(rodzaj_ikony: String, etykieta: Label) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_ikona(rodzaj_ikony))
	h.add_child(etykieta)
	return h

## Zaokrąglony StyleBox do paneli i przycisków.
func _stylbox(kolor: Color, promien := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kolor
	sb.set_corner_radius_all(promien)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## Przycisk menu w jednolitym stylu (zaokrąglony, z hoverem).
func _przycisk(tekst: String, akcja: Callable) -> Button:
	var b := Button.new()
	b.text = tekst
	b.custom_minimum_size = Vector2(300, 50)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", _stylbox(Color(0.13, 0.2, 0.28, 0.95)))
	b.add_theme_stylebox_override("hover", _stylbox(Color(0.2, 0.32, 0.44, 0.95)))
	b.add_theme_stylebox_override("pressed", _stylbox(Color(0.1, 0.15, 0.2, 0.95)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
	b.pressed.connect(akcja)
	return b

## Pasek postępu (tło + wypełnienie). Zwraca ColorRect wypełnienia.
func _pasek(rodzic: Control, kolor: Color) -> ColorRect:
	var kontener := Control.new()
	kontener.custom_minimum_size = Vector2(SZEROKOSC_PASKA, 14)
	rodzic.add_child(kontener)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.55)
	tlo.size = Vector2(SZEROKOSC_PASKA, 14)
	kontener.add_child(tlo)
	var wypelnienie := ColorRect.new()
	wypelnienie.color = kolor
	wypelnienie.position = Vector2(2, 2)
	wypelnienie.size = Vector2(SZEROKOSC_PASKA - 4, 10)
	kontener.add_child(wypelnienie)
	return wypelnienie

func _zbuduj() -> void:
	_korzen = Control.new()
	_korzen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_korzen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_korzen)

	# TRYB WSIOKA - filtr sepii na samym spodzie, nad obrazem 3D.
	# Blend MNOŻENIA, a nie zwykła półprzezroczysta plama: mnożenie zostawia
	# jasność sceny w spokoju, a tylko wycina błękity. Dzięki temu osiedle
	# robi się rude jak stara fotografia, zamiast po prostu pomarańczowe.
	_sepia = ColorRect.new()
	_sepia.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sepia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sepia.color = Color.WHITE   # biel = neutralny mnożnik, czyli "wyłączone"
	var mat_sepii := CanvasItemMaterial.new()
	mat_sepii.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_sepia.material = mat_sepii
	_korzen.add_child(_sepia)

	# Filtr koloru pod resztą UI: bursztyn po piwie, szarość na kacu
	_nakladka = ColorRect.new()
	_nakladka.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nakladka.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nakladka.color = Color(1, 1, 1, 0)
	_korzen.add_child(_nakladka)

	# Lewy górny róg: półprzezroczysty panel z kasą, plecakiem, celami i paskami
	var panel_lewy := PanelContainer.new()
	panel_lewy.position = Vector2(12, 10)
	panel_lewy.add_theme_stylebox_override("panel", _stylbox(Color(0.05, 0.08, 0.12, 0.6), 12))
	_korzen.add_child(panel_lewy)
	_panel_hud = panel_lewy
	var lewy := VBoxContainer.new()
	lewy.add_theme_constant_override("separation", 4)
	panel_lewy.add_child(lewy)
	_ety_kasa = _etykieta(Game.zl(0.0), 26, Paleta.UI_ZIELONY)
	lewy.add_child(_wiersz("moneta", _ety_kasa))
	_ety_plecak = _etykieta("0/%d" % Game.pojemnosc_plecaka(), 22)
	lewy.add_child(_wiersz("butelka", _ety_plecak))
	# Dzień kariery przestał być samym numerem - ma nazwę i pogodę,
	# bo obie rzeczy zmieniają dziś zasady gry
	lewy.add_child(_etykieta("Dzień %d (%s), %s | Cel: %s" % [
		Game.dzien, Game.nazwa_dnia_tygodnia(), Game.opis_pogody(), Game.zl(Game.cel_dnia),
	], 16, Color(0.8, 0.8, 0.8)))
	# TABLICA WYNIKÓW - Ty kontra Heniek, przez cały dzień na oczach
	_ety_rywal = _etykieta("", 16, Color(0.85, 0.9, 0.85))
	lewy.add_child(_ety_rywal)
	_aktualizuj_rywala(Game.konkurent_kasa, Game.konkurent_sztuk)
	# Wyzwanie dnia (losowane codziennie)
	_ety_wyzwanie = _etykieta("", 15, Color(0.7, 0.9, 1.0))
	lewy.add_child(_ety_wyzwanie)
	# Wsiokometr
	_ety_wsiokometr = _etykieta("Wsiokometr: 0%", 16, Color(1.0, 0.75, 0.4))
	lewy.add_child(_wiersz("czapka", _ety_wsiokometr))
	_pasek_wsiokometru = _pasek(lewy, Color(1.0, 0.6, 0.15))
	_pasek_wsiokometru.size.x = 0
	# Pasek "Papieros" (stamina)
	_ety_papieros = _etykieta("Papieros", 16, Color(0.95, 0.95, 0.9))
	lewy.add_child(_wiersz("papieros", _ety_papieros))
	_pasek_papierosa = _pasek(lewy, Color(0.95, 0.95, 0.9))

	# Lewa krawędź, pod panelem głównym: AKTYWNE ZLECENIE (ukryte, gdy brak)
	_panel_zlecenia = PanelContainer.new()
	_panel_zlecenia.position = Vector2(12, 248)
	_panel_zlecenia.custom_minimum_size = Vector2(300, 0)
	_panel_zlecenia.add_theme_stylebox_override("panel", _stylbox(Color(0.16, 0.09, 0.02, 0.78), 10))
	_panel_zlecenia.visible = false
	_korzen.add_child(_panel_zlecenia)
	var kolumna_zlecenia := VBoxContainer.new()
	kolumna_zlecenia.add_theme_constant_override("separation", 3)
	_panel_zlecenia.add_child(kolumna_zlecenia)
	_ety_zlecenie_tytul = _etykieta("", 18, Color(1.0, 0.82, 0.3))
	kolumna_zlecenia.add_child(_ety_zlecenie_tytul)
	_ety_zlecenie_opis = _etykieta("", 15, Color(0.92, 0.92, 0.88))
	kolumna_zlecenia.add_child(_ety_zlecenie_opis)
	_pasek_zlecenia = _pasek(kolumna_zlecenia, Color(1.0, 0.7, 0.2))

	# Środek góry: timer z ikoną zegara
	_wiersz_czasu = HBoxContainer.new()
	_wiersz_czasu.add_theme_constant_override("separation", 8)
	_wiersz_czasu.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wiersz_czasu.position = Vector2(-55, 10)
	_korzen.add_child(_wiersz_czasu)
	_wiersz_czasu.add_child(_ikona("zegar", 30))
	_ety_czas = _etykieta("5:00", 32)
	_wiersz_czasu.add_child(_ety_czas)

	# Combo - duży napis nad środkiem ekranu
	_ety_combo = _etykieta("", 40, Color(1.0, 0.9, 0.2))
	_ety_combo.set_anchors_preset(Control.PRESET_CENTER)
	_ety_combo.position = Vector2(-300, -160)
	_ety_combo.custom_minimum_size = Vector2(600, 0)
	_ety_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ety_combo.pivot_offset = Vector2(300, 25)
	_korzen.add_child(_ety_combo)

	# TRYB WSIOKA - licznik pod combo, żeby było widać, ile jeszcze trwa szał
	_ety_tryb = _etykieta("", 30, Color(1.0, 0.72, 0.2))
	_ety_tryb.set_anchors_preset(Control.PRESET_CENTER)
	_ety_tryb.position = Vector2(-300, -110)
	_ety_tryb.custom_minimum_size = Vector2(600, 0)
	_ety_tryb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ety_tryb.pivot_offset = Vector2(300, 20)
	_ety_tryb.modulate.a = 0.0
	_korzen.add_child(_ety_tryb)

	# Wielkie memy motywacyjne ("NIECH ŻYJE KAUCJA I BEZROBOCIE!")
	_ety_meme = _etykieta("", 34, Color(1.0, 0.85, 0.25))
	_ety_meme.set_anchors_preset(Control.PRESET_CENTER)
	_ety_meme.position = Vector2(-400, 140)
	_ety_meme.custom_minimum_size = Vector2(800, 0)
	_ety_meme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ety_meme.pivot_offset = Vector2(400, 25)
	_ety_meme.modulate.a = 0.0
	_korzen.add_child(_ety_meme)

	# Prawy górny róg: kanał komunikatów
	_kanal_komunikatow = VBoxContainer.new()
	_kanal_komunikatow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kanal_komunikatow.position = Vector2(-520, 12)
	_kanal_komunikatow.custom_minimum_size = Vector2(500, 0)
	_kanal_komunikatow.alignment = BoxContainer.ALIGNMENT_BEGIN
	_korzen.add_child(_kanal_komunikatow)

	# Dół: podpowiedź interakcji
	_ety_prompt = _etykieta("", 24, Color(1.0, 0.95, 0.5))
	_ety_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ety_prompt.position = Vector2(-200, -70)
	_ety_prompt.custom_minimum_size = Vector2(400, 0)
	_ety_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_korzen.add_child(_ety_prompt)

	# Prawy dolny róg: RADAR + strzałka nawigacji nad nim
	_radar = load("res://ui/radar.gd").new()
	_radar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_radar.position = Vector2(-188, -188)
	_korzen.add_child(_radar)
	_nawigacja = load("res://ui/nawigacja.gd").new()
	_nawigacja.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_nawigacja.position = Vector2(-212, -228)
	_korzen.add_child(_nawigacja)

	# Kreski pędu - pod resztą UI, nad obrazem 3D
	_motion_lines = load("res://ui/motion_lines.gd").new()
	_korzen.add_child(_motion_lines)
	_korzen.move_child(_motion_lines, 2)   # nad sepią i nakładką koloru

	# Lewy dolny róg: podpis (prawy zajmuje radar)
	var wersja := _etykieta("KOCHAM KAUCJĘ", 14, Color(1, 1, 1, 0.5))
	wersja.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	wersja.position = Vector2(14, -30)
	_korzen.add_child(wersja)

	# Panel podsumowania (ukryty do końca dnia)
	_panel_konca = CenterContainer.new()
	_panel_konca.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_konca.visible = false
	_korzen.add_child(_panel_konca)

	# Podpowiedzi tutoriala (nad podpowiedzią interakcji)
	_ety_tutorial = _etykieta("", 20, Color(0.85, 0.95, 1.0))
	_ety_tutorial.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ety_tutorial.position = Vector2(-300, -120)
	_ety_tutorial.custom_minimum_size = Vector2(600, 0)
	_ety_tutorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_korzen.add_child(_ety_tutorial)

	_zbuduj_menu()
	_zbuduj_pauze()
	_zbuduj_ustawienia()

	# Czarna zasłona do przejść - bezpośrednio w CanvasLayer, NAD całym UI
	_zaslona = ColorRect.new()
	_zaslona.color = Color.BLACK
	_zaslona.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zaslona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zaslona.modulate.a = 0.0
	add_child(_zaslona)

## Menu główne - pokazywane przy pierwszym uruchomieniu gry.
func _zbuduj_menu() -> void:
	_panel_menu = Control.new()
	_panel_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_menu.visible = false
	_korzen.add_child(_panel_menu)
	var tlo := ColorRect.new()
	tlo.color = Color(0.05, 0.08, 0.12, 0.92)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_menu.add_child(tlo)
	var srodek := CenterContainer.new()
	srodek.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_menu.add_child(srodek)
	var kolumna := VBoxContainer.new()
	kolumna.add_theme_constant_override("separation", 12)
	kolumna.alignment = BoxContainer.ALIGNMENT_CENTER
	srodek.add_child(kolumna)
	# Logo - wielka pikselowa butelka
	var logo := _ikona("butelka", 96)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolumna.add_child(logo)
	var tytul := _etykieta("SYMULATOR\nWSIOKA KAUCYJNEGO", 52, Color(1.0, 0.85, 0.2))
	tytul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolumna.add_child(tytul)
	var tekst_podtytulu := "SYMULATOR POLAKA - edycja kaucyjna\nOsiedle. Butelki. Chwała."
	if Game.dzien > 1 or Game.bank > 0.0:
		tekst_podtytulu += "\nDzień kariery: %d | Bank: %s" % [Game.dzien, Game.zl(Game.bank)]
	var podtytul := _etykieta(tekst_podtytulu, 20, Color(0.8, 0.8, 0.8))
	podtytul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolumna.add_child(podtytul)
	kolumna.add_child(_etykieta("", 8))
	kolumna.add_child(_przycisk("GRAJ (Enter)", _start_gry))
	kolumna.add_child(_przycisk("USTAWIENIA", _pokaz_ustawienia))
	kolumna.add_child(_przycisk("PEŁNY EKRAN (F11)", _przelacz_pelny_ekran))
	kolumna.add_child(_przycisk("WYJDŹ", _wyjdz))
	kolumna.add_child(_etykieta("", 8))
	var sterowanie := _etykieta(
		"WASD - ruch | Mysz - kamera | E - interakcja | F - nawal komuś | Spacja - skok\n" +
		"Shift - sprint (zużywa Papierosa) | Ctrl - przysiad | V - kamera | Esc - pauza\n" +
		"Głaszcz psa, podciągaj się na trzepaku, kup piwo w Biedronce. Żyj pełnią życia.",
		16, Color(0.7, 0.7, 0.7)
	)
	sterowanie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolumna.add_child(sterowanie)

## Panel pauzy (Esc w trakcie gry).
func _zbuduj_pauze() -> void:
	_panel_pauzy = Control.new()
	_panel_pauzy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_pauzy.visible = false
	_korzen.add_child(_panel_pauzy)
	var tlo := ColorRect.new()
	tlo.color = Color(0, 0, 0, 0.6)
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_pauzy.add_child(tlo)
	var srodek := CenterContainer.new()
	srodek.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_pauzy.add_child(srodek)
	var kolumna := VBoxContainer.new()
	kolumna.add_theme_constant_override("separation", 12)
	srodek.add_child(kolumna)
	var naglowek := _etykieta("PAUZA", 40, Color(1.0, 0.85, 0.2))
	naglowek.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolumna.add_child(naglowek)
	kolumna.add_child(_przycisk("WZNÓW (Esc)", _przelacz_pauze))
	kolumna.add_child(_przycisk("NOWY DZIEŃ", _nowy_dzien_z_przejsciem))
	kolumna.add_child(_przycisk("USTAWIENIA", _pokaz_ustawienia))
	kolumna.add_child(_przycisk("PEŁNY EKRAN (F11)", _przelacz_pelny_ekran))
	kolumna.add_child(_przycisk("WYJDŹ", _wyjdz))

## Panel ustawień: głośność, czułość myszy, pełny ekran.
func _zbuduj_ustawienia() -> void:
	_panel_ustawien = Control.new()
	_panel_ustawien.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_ustawien.visible = false
	_korzen.add_child(_panel_ustawien)
	var tlo := ColorRect.new()
	tlo.color = Paleta.UI_TLO
	tlo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_ustawien.add_child(tlo)
	var srodek := CenterContainer.new()
	srodek.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_ustawien.add_child(srodek)
	var kolumna := VBoxContainer.new()
	kolumna.add_theme_constant_override("separation", 10)
	srodek.add_child(kolumna)
	var naglowek := _etykieta("USTAWIENIA", 36, Paleta.UI_ZLOTY)
	naglowek.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolumna.add_child(naglowek)
	# Głośność
	kolumna.add_child(_etykieta("Głośność", 20))
	var suwak_glosnosci := HSlider.new()
	suwak_glosnosci.min_value = 0.0
	suwak_glosnosci.max_value = 1.0
	suwak_glosnosci.step = 0.05
	suwak_glosnosci.value = Game.glosnosc
	suwak_glosnosci.custom_minimum_size = Vector2(280, 24)
	suwak_glosnosci.value_changed.connect(func(v: float) -> void:
		Game.ustaw_glosnosc(v)
		Game.zapisz_ustawienia()
	)
	kolumna.add_child(suwak_glosnosci)
	# Czułość myszy
	kolumna.add_child(_etykieta("Czułość myszy", 20))
	var suwak_czulosci := HSlider.new()
	suwak_czulosci.min_value = 0.4
	suwak_czulosci.max_value = 2.0
	suwak_czulosci.step = 0.1
	suwak_czulosci.value = Game.czulosc
	suwak_czulosci.custom_minimum_size = Vector2(280, 24)
	suwak_czulosci.value_changed.connect(func(v: float) -> void:
		Game.czulosc = v
		Game.zapisz_ustawienia()
	)
	kolumna.add_child(suwak_czulosci)
	# Pełny ekran
	var przelacznik := CheckButton.new()
	przelacznik.text = "Pełny ekran"
	przelacznik.add_theme_font_size_override("font_size", 20)
	przelacznik.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	przelacznik.toggled.connect(func(_wlaczony: bool) -> void: _przelacz_pelny_ekran())
	kolumna.add_child(przelacznik)
	kolumna.add_child(_etykieta("", 6))
	kolumna.add_child(_przycisk("WRÓĆ", func() -> void: _panel_ustawien.visible = false))

func _pokaz_ustawienia() -> void:
	_panel_ustawien.visible = true

# --- Akcje menu ---

func _start_gry() -> void:
	Game.start_gry()
	_panel_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pokaz_intro()
	_tutorial()

## Fade: ściemnienie → akcja → rozjaśnienie (sygnał Game.przejscie).
func _wykonaj_przejscie(akcja: Callable) -> void:
	if _w_przejsciu:
		return
	_w_przejsciu = true
	var tw := create_tween()
	tw.tween_property(_zaslona, "modulate:a", 1.0, 0.22)
	tw.tween_callback(akcja)
	tw.tween_property(_zaslona, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: _w_przejsciu = false)

func _nowy_dzien_z_przejsciem() -> void:
	_wykonaj_przejscie(Game.nowy_dzien)

## Krótki tutorial przy pierwszej rozgrywce - kolejne podpowiedzi u dołu.
func _tutorial() -> void:
	if not Game.pierwszy_dzien:
		return
	var podpowiedzi: Array[String] = [
		"WASD - poruszanie się | mysz - kamera",
		"E - podnoś butelki i przeszukuj śmietniki",
		"Pełny plecak zanieś do BUTELKOMATU przy Biedronce",
		"Shift - sprint (pilnuj Papierosa) | F - argument siłowy",
		"ZŁOM (kable, felgi, akumulatory) sprzedasz TYLKO na SKUPIE za działkami",
		"Skup zamyka się przed końcem dnia - nie zostań z felgą w plecaku!",
		"Tablica ogłoszeń przy chodniku = ZLECENIA za grubszą kasę (F zmienia kartkę)",
		"Wózek i skuter: Ctrl w zakręcie = DRIFT, a rampy przy garażach dają bonus za lot",
		"Radar w prawym dolnym rogu: zielone = punkty oddania, czerwone = straż",
	]
	await get_tree().create_timer(2.0, false).timeout
	for tekst in podpowiedzi:
		if not is_inside_tree() or not Game.gra_trwa:
			return
		_ety_tutorial.text = tekst
		_ety_tutorial.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(3.6)
		tw.tween_property(_ety_tutorial, "modulate:a", 0.0, 0.6)
		await get_tree().create_timer(4.4, false).timeout

func _przelacz_pauze() -> void:
	var pauza := not get_tree().paused
	get_tree().paused = pauza
	_panel_pauzy.visible = pauza
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pauza else Input.MOUSE_MODE_CAPTURED

func _przelacz_pelny_ekran() -> void:
	var tryb := DisplayServer.window_get_mode()
	if tryb == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _wyjdz() -> void:
	get_tree().quit()

func _pokaz_intro() -> void:
	# Ostatnia linia jest inna każdego dnia: mówi, czym DZIŚ różni się osiedle.
	# Bez tego dzień tygodnia i pogoda byłyby zmianą, o której gracz dowiaduje
	# się dopiero z rachunku na koniec.
	var intro := _etykieta(
		"Zbieraj butelki i puszki (E), przeszukuj śmietniki\n" +
		"i zanieś łup do butelkomatu - są trzy na osiedlu!\n" +
		Game.opis_dnia(),
		22
	)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.set_anchors_preset(Control.PRESET_CENTER)
	intro.position = Vector2(-380, 60)
	intro.custom_minimum_size = Vector2(760, 0)
	_korzen.add_child(intro)
	var tw := intro.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(intro, "modulate:a", 0.0, 1.5)
	tw.tween_callback(intro.queue_free)

# --- Reakcje na sygnały ---

## Kasa nalicza się animowanie - jak wygrana na automacie.
func _aktualizuj_kase(kwota: float) -> void:
	var tw := create_tween()
	tw.tween_method(_ustaw_tekst_kasy, _kasa_wyswietlana, kwota, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kasa_wyswietlana = kwota
	# Tablica wyników pokazuje RÓŻNICĘ, więc musi reagować na obie strony
	_aktualizuj_rywala(Game.konkurent_kasa, Game.konkurent_sztuk)

func _ustaw_tekst_kasy(kwota: float) -> void:
	_ety_kasa.text = Game.zl(kwota)

func _aktualizuj_plecak(ile: int, maks: int) -> void:
	_ety_plecak.text = "%d/%d" % [ile, maks]
	# Czerwony, gdy pełny - sygnał "idź do butelkomatu"
	_ety_plecak.add_theme_color_override(
		"font_color", Color(1.0, 0.4, 0.4) if ile >= maks else Color.WHITE
	)

func _aktualizuj_czas(sekundy: float) -> void:
	var calkowite := int(ceilf(sekundy))
	_ety_czas.text = "%d:%02d" % [calkowite / 60, calkowite % 60]
	# Ostatnie 30 sekund - czerwony timer
	if sekundy < 30.0:
		_ety_czas.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _aktualizuj_prompt(tekst: String) -> void:
	_ety_prompt.text = tekst

func _aktualizuj_papierosa(procent: float, pali: bool) -> void:
	_pasek_papierosa.size.x = (SZEROKOSC_PASKA - 4) * procent / 100.0
	_ety_papieros.text = "Papieros (zapalasz...)" if pali else "Papieros"
	# Żar papierosa: im mniej staminy, tym bardziej pomarańczowy pasek
	_pasek_papierosa.color = Color(0.95, 0.95, 0.9).lerp(Color(1.0, 0.45, 0.1), 1.0 - procent / 100.0)

func _aktualizuj_wsiokometr(wartosc: float) -> void:
	_pasek_wsiokometru.size.x = (SZEROKOSC_PASKA - 4) * wartosc / 100.0
	_ety_wsiokometr.text = "Wsiokometr: %d%%" % int(wartosc)
	if Game.tryb_wsioka_aktywny():
		_ety_wsiokometr.text = "Wsiokometr: TRYB WSIOKA!"
		_pasek_wsiokometru.color = Paleta.UI_ZLOTY
	elif wartosc >= 100.0:
		_ety_wsiokometr.text = "Wsiokometr: LEGENDA OSIEDLA"
	else:
		_pasek_wsiokometru.color = Color(1.0, 0.6, 0.15)

## TRYB WSIOKA: ekran wpada w sepię, a na środku odlicza licznik.
## Sepia jest tu robotą, nie ozdobą - to ona sprawia, że przez piętnaście
## sekund gra WYGLĄDA inaczej, więc gracz czuje, że coś się dzieje,
## nawet nie patrząc na pasek.
func _aktualizuj_tryb_wsioka(aktywny: bool, pozostalo: float) -> void:
	if aktywny:
		_ety_tryb.text = "TRYB WSIOKA - PODWÓJNA KAUCJA (%d s)" % int(ceilf(pozostalo))
		# Ostatnie trzy sekundy pulsują - ostrzeżenie, że szał się kończy
		var koniec_blisko := pozostalo <= 3.0
		_ety_tryb.modulate.a = 1.0 if not koniec_blisko \
			else 0.55 + 0.45 * absf(sin(pozostalo * TAU))
	else:
		_ety_tryb.text = ""
		_ety_tryb.modulate.a = 0.0
	# Kolor mnożenia: biel nic nie zmienia, ruda sepia wycina błękity.
	# Sygnał leci co klatkę, więc tween odpalamy TYLKO przy zmianie celu -
	# inaczej co klatkę powstawałby nowy i wszystkie biłyby się o tę samą wartość.
	var docelowy := Color(1.0, 0.82, 0.52) if aktywny else Color.WHITE
	if _sepia_cel != docelowy:
		_sepia_cel = docelowy
		create_tween().tween_property(_sepia, "color", docelowy, 0.5)
	_aktualizuj_wsiokometr(Game.wsiokometr)

## TABLICA WYNIKÓW: Ty kontra Heniek. Rywal, którego widać w liczbach,
## goni znacznie skuteczniej niż rywal, który po prostu chodzi po mapie.
func _aktualizuj_rywala(kwota: float, sztuk: int) -> void:
	if _ety_rywal == null:
		return
	var przewaga := Game.kasa - kwota
	_ety_rywal.text = "Ty %s | Heniek %s (%d szt.)" % [
		Game.zl(Game.kasa), Game.zl(kwota), sztuk,
	]
	_ety_rywal.add_theme_color_override("font_color",
		Paleta.UI_ZIELONY if przewaga >= 0.0 else Paleta.UI_CZERWONY)

## Combo: napis rośnie i puchnie z każdym poziomem.
func _aktualizuj_combo(poziom: int, mnoznik: int) -> void:
	if poziom < 2:
		var tw := create_tween()
		tw.tween_property(_ety_combo, "modulate:a", 0.0, 0.4)
		return
	var dopisek := ""
	match mnoznik:
		3: dopisek = " JESTEŚ MASZYNĄ!"
		4: dopisek = " KRÓL KAUCJI! (maks)"
	_ety_combo.text = "COMBO x%d!%s" % [mnoznik, dopisek]
	_ety_combo.modulate.a = 1.0
	# Puchnięcie przy każdym podniesieniu
	_ety_combo.scale = Vector2.ONE * 1.35
	var tw := create_tween()
	tw.tween_property(_ety_combo, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Wyzwanie dnia w lewym panelu; złote, gdy zaliczone.
func _aktualizuj_wyzwanie(opis: String, postep: int, cel: int, zrobione: bool) -> void:
	if zrobione:
		_ety_wyzwanie.text = "Wyzwanie: %s [ZALICZONE]" % opis
		_ety_wyzwanie.add_theme_color_override("font_color", Paleta.UI_ZLOTY)
	else:
		_ety_wyzwanie.text = "Wyzwanie: %s (%d/%d)" % [opis, postep, cel]

## Filtr ekranu: ciepły bursztyn po piwach, zgniła szarość na kacu.
## Panel aktywnego zlecenia. Pusty słownik = chowamy panel.
## Pasek zmienia kolor, gdy czas ucieka - ostatnie 10 s pulsuje na czerwono.
func _aktualizuj_zlecenie(dane: Dictionary) -> void:
	if dane.is_empty():
		_panel_zlecenia.visible = false
		return
	_panel_zlecenia.visible = true
	_ety_zlecenie_tytul.text = "ZLECENIE: %s" % dane["tytul"]
	_ety_zlecenie_opis.text = "%s  [%d/%d]  %ds" % [
		dane["opis"], dane["postep"], dane["cel"], int(dane["pozostalo"]),
	]
	# Procent liczymy z postępu celu - to on jest najważniejszy dla gracza
	var procent: float = float(dane["postep"]) / maxf(float(dane["cel"]), 1.0)
	_pasek_zlecenia.size.x = SZEROKOSC_PASKA * clampf(procent, 0.0, 1.0)
	var malo_czasu: bool = float(dane["pozostalo"]) <= 10.0
	_pasek_zlecenia.color = Color(1.0, 0.3, 0.25) if malo_czasu else Color(1.0, 0.7, 0.2)
	_ety_zlecenie_opis.modulate = Color(1.0, 0.6, 0.6) if malo_czasu else Color.WHITE

func _aktualizuj_upojenie(pijanstwo: float, kac: float) -> void:
	if pijanstwo > 0.0:
		_nakladka.color = Color(1.0, 0.72, 0.3, 0.12 * pijanstwo)
	elif kac > 0.0:
		_nakladka.color = Color(0.5, 0.58, 0.48, 0.16 * kac)
	else:
		_nakladka.color.a = 0.0

## Wielki mem wskakuje na środek ekranu i znika po chwili.
func _pokaz_meme(tekst: String) -> void:
	_ety_meme.text = tekst
	_ety_meme.modulate.a = 1.0
	_ety_meme.scale = Vector2.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(_ety_meme, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.8)
	tw.tween_property(_ety_meme, "modulate:a", 0.0, 0.8)

## Komunikat pojawia się w kanale i po chwili znika.
func _dodaj_komunikat(tekst: String) -> void:
	var l := _etykieta(tekst, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(500, 0)
	_kanal_komunikatow.add_child(l)
	# Maksymalnie 5 komunikatów naraz - najstarszy wylatuje
	if _kanal_komunikatow.get_child_count() > 5:
		_kanal_komunikatow.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

## Ekran końca dnia z wynikami.
func _pokaz_podsumowanie(dane: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _stylbox(Color(0.07, 0.1, 0.14, 0.97), 16))
	_panel_konca.add_child(panel)
	var marginesy := MarginContainer.new()
	for strona in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marginesy.add_theme_constant_override(strona, 16)
	panel.add_child(marginesy)
	var kolumna := VBoxContainer.new()
	# Ciasno, bo ekran podsumowania musi zmieścić się w 720p RAZEM z MELINĄ,
	# a MELINA ma teraz dziewięć pozycji
	kolumna.add_theme_constant_override("separation", 2)
	marginesy.add_child(kolumna)

	kolumna.add_child(_etykieta("KONIEC DNIA %d NA OSIEDLU!" % dane["dzien"], 26, Color(1.0, 0.85, 0.3)))
	kolumna.add_child(_etykieta("%s, %s" % [
		str(dane.get("dzien_tygodnia", "")).capitalize(), dane.get("pogoda", ""),
	], 15, Color(0.72, 0.8, 0.88)))
	kolumna.add_child(_etykieta("Zarobiona kaucja: %s" % Game.zl(dane["kasa"]), 22, Color(0.6, 1.0, 0.6)))
	# Żartobliwy komentarz "co możesz kupić"
	var zakupy := _etykieta(dane["zakupy"], 16, Color(1.0, 0.9, 0.6))
	zakupy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zakupy.custom_minimum_size = Vector2(520, 0)
	kolumna.add_child(zakupy)
	if dane["cel"]:
		kolumna.add_child(_etykieta("Cel dnia (%s) osiągnięty! Prawdziwy magnat kaucyjny." % [
			Game.zl(dane.get("cel_kwota", 0.0))], 17, Paleta.UI_ZIELONY))
	else:
		kolumna.add_child(_etykieta("Cel dnia NIEWYKONANY - brakło %s do %s." % [
			Game.zl(maxf(float(dane.get("cel_kwota", 0.0)) - float(dane["kasa"]), 0.0)),
			Game.zl(dane.get("cel_kwota", 0.0)),
		], 17, Paleta.UI_CZERWONY))
	# Statystyki w dwóch gęstych wierszach zamiast czterech - przy dziewięciu
	# ulepszeniach w MELINIE każdy zaoszczędzony wiersz to realne piksele
	kolumna.add_child(_etykieta("Zebrane: %d (złote: %d) | Oddane: %d | Złom: %d" % [
		dane["zebrane"], dane["zlote"], dane["oddane"], dane.get("zlom", 0)], 16))
	kolumna.add_child(_etykieta("Śmietniki: %d | Combo x%d | Gleby: %d | Zlecenia: %d | Loty: %d" % [
		dane["smietniki"], dane["combo_max"], dane["upadki"],
		dane.get("zlecenia", 0), dane.get("loty", 0)], 16))
	if dane["mandaty"] > 0:
		kolumna.add_child(_etykieta(
			"Mandaty od Straży Miejskiej: %d. System cię widzi." % dane["mandaty"],
			15, Color(1.0, 0.6, 0.5)
		))
	if dane["w_plecaku"] > 0:
		kolumna.add_child(_etykieta(
			"W plecaku zostało: %d szt. - przepadły. Trzeba było biec szybciej!" % dane["w_plecaku"],
			15, Color(1.0, 0.6, 0.5)
		))
	# Wyzwanie dnia - zaliczone czy nie?
	if dane["wyzwanie_ok"]:
		kolumna.add_child(_etykieta("Wyzwanie dnia zaliczone: %s" % dane["wyzwanie_opis"], 15, Paleta.UI_ZLOTY))
	else:
		kolumna.add_child(_etykieta("Wyzwanie niezaliczone: %s. Jutro też jest dzień." % dane["wyzwanie_opis"], 15, Color(0.7, 0.7, 0.7)))
	# POJEDYNEK Z HEŃKIEM - osobna tabelka, osobna premia
	var rywal_kasa := float(dane.get("rywal_kasa", 0.0))
	kolumna.add_child(_etykieta("- POJEDYNEK: Ty %s / Heniek %s (%d szt. sprzed nosa) -" % [
		Game.zl(dane["kasa"]), Game.zl(rywal_kasa), int(dane.get("rywal_sztuk", 0)),
	], 18, Color(1.0, 0.8, 0.6)))
	if dane.get("rywal_wygrany", false):
		kolumna.add_child(_etykieta(
			"WYGRANA O %s! Premia %s do banku. Heniek udaje, że go to nie rusza." % [
				Game.zl(float(dane["kasa"]) - rywal_kasa),
				Game.zl(float(dane.get("premia_rywal", 0.0))),
			], 17, Paleta.UI_ZLOTY))
	else:
		kolumna.add_child(_etykieta(
			"Heniek wygrał o %s. Jutro rewanż." % Game.zl(rywal_kasa - float(dane["kasa"])),
			17, Paleta.UI_CZERWONY))
	# KSIĘGA WSIOKA - co odblokowało się dzisiaj
	var nowe_wpisy: Array = dane.get("osiagniecia_dzis", [])
	if not nowe_wpisy.is_empty():
		kolumna.add_child(_etykieta("Księga wsioka [%d/%d] - nowe wpisy: %s" % [
			Osiagniecia.ile_zdobytych(), Osiagniecia.ile_wszystkich(),
			", ".join(PackedStringArray(nowe_wpisy)),
		], 15, Paleta.UI_ZLOTY))
	else:
		kolumna.add_child(_etykieta("Księga wsioka: %d/%d wpisów" % [
			Osiagniecia.ile_zdobytych(), Osiagniecia.ile_wszystkich(),
		], 15, Color(0.75, 0.75, 0.75)))
	# ROZLICZENIE DNIA - dwa zadania naraz: kwota i wyzwanie
	if float(dane.get("premia", 0.0)) > 0.0:
		kolumna.add_child(_etykieta(
			"CHWAŁA OSIEDLA! Cel i wyzwanie zaliczone - premia %s do banku." % Game.zl(dane["premia"]),
			20, Paleta.UI_ZLOTY))
	elif float(dane.get("kara", 0.0)) > 0.0:
		kolumna.add_child(_etykieta(
			"KARA %s (%s). Spółdzielnia nie wybacza." % [
				Game.zl(dane["kara"]), dane.get("powod_kary", "")],
			20, Paleta.UI_CZERWONY))
	else:
		kolumna.add_child(_etykieta(
			"Dzień nierozliczony - bank i tak był pusty. Jutro odbijesz.",
			16, Color(0.8, 0.8, 0.8)))
	if dane["nowy_rekord"]:
		kolumna.add_child(_etykieta("NOWY REKORD OSIEDLA!", 24, Color(1.0, 0.5, 1.0)))
	else:
		kolumna.add_child(_etykieta("Rekord osiedla: %s" % Game.zl(dane["rekord"]), 16, Color(0.8, 0.8, 0.8)))
	# --- MELINA: sklep ulepszeń za bank kariery ---
	kolumna.add_child(_etykieta("- MELINA: ulepszenia na jutro -", 18, Paleta.UI_ZLOTY))
	_ety_bank = _etykieta("Bank kariery: %s" % Game.zl(Game.bank), 15, Paleta.UI_ZIELONY)
	kolumna.add_child(_ety_bank)
	_przyciski_sklepu.clear()
	# DWIE KOLUMNY: przy dziewięciu ulepszeniach jedna kolumna wypychała
	# ekran podsumowania poza 720p. W siatce 2x5 wszystko się mieści,
	# a przyciski nadal da się przeczytać.
	var siatka := GridContainer.new()
	siatka.columns = 2
	siatka.add_theme_constant_override("h_separation", 8)
	siatka.add_theme_constant_override("v_separation", 4)
	kolumna.add_child(siatka)
	for id in Game.ULEPSZENIA_INFO:
		var przycisk := _przycisk("", _kup_ulepszenie.bind(id))
		przycisk.custom_minimum_size = Vector2(310, 24)
		przycisk.add_theme_font_size_override("font_size", 13)
		# Opis wjeżdża do dymka, a nie na przycisk: "Fanty z 3 m same wpadają
		# do plecaka" nie mieści się w 310 px i ucinało się w połowie słowa
		przycisk.tooltip_text = "%s - %s" % [
			Game.ULEPSZENIA_INFO[id]["nazwa"], Game.ULEPSZENIA_INFO[id]["opis"]]
		_przyciski_sklepu[id] = przycisk
		siatka.add_child(przycisk)
	_odswiez_sklep()
	kolumna.add_child(_etykieta("Naciśnij R, aby zacząć dzień %d" % (dane["dzien"] + 1), 19, Color(1.0, 0.95, 0.5)))

	_panel_konca.visible = true
	# Chowamy HUD gry - inaczej podpowiedzi i panel z kasą prześwitują
	# przez ekran podsumowania i robi się nieczytelna sieczka
	_ety_prompt.text = ""
	_ety_tutorial.text = ""
	_panel_zlecenia.visible = false
	_panel_hud.visible = false
	_kanal_komunikatow.visible = false
	# Zegar też znika: dzień się skończył, a tykający licznik nad ekranem
	# podsumowania sugerował, że coś jeszcze trwa
	_wiersz_czasu.visible = false
	_ety_tryb.modulate.a = 0.0

## Zakup w MELINIE - odświeża przyciski i bank.
func _kup_ulepszenie(id: String) -> void:
	if Game.kup_ulepszenie(id):
		Sfx.graj("kasa")
	else:
		Sfx.graj("blad")
	_odswiez_sklep()

func _odswiez_sklep() -> void:
	_ety_bank.text = "Bank kariery: %s" % Game.zl(Game.bank)
	for id in _przyciski_sklepu:
		var przycisk: Button = _przyciski_sklepu[id]
		var info: Dictionary = Game.ULEPSZENIA_INFO[id]
		var poziom: int = Game.ulepszenia[id]
		var maks: int = info["ceny"].size()
		var cena := Game.cena_ulepszenia(id)
		if cena < 0.0:
			przycisk.text = "%s (%d/%d) - MAKS" % [info["nazwa"], poziom, maks]
			przycisk.disabled = true
		else:
			przycisk.text = "%s (%d/%d) - %s" % [info["nazwa"], poziom, maks, Game.zl(cena)]
			# Nie stać? Przycisk zostaje aktywny, ale widać, że to na kiedy indziej
			przycisk.disabled = false
			przycisk.modulate = Color.WHITE if Game.bank >= cena else Color(1, 1, 1, 0.55)
