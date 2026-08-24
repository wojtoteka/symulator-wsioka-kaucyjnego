extends Node
## SFX (autoload "Sfx")
## Proceduralne dźwięki-placeholdery - generowane w kodzie przy starcie,
## więc projekt nie potrzebuje żadnych plików audio.
## Użycie: Sfx.graj("podnies")  albo z wyższym tonem: Sfx.graj("podnies", 0.0, 1.3)

const CZESTOTLIWOSC_PROBKOWANIA := 22050

var _dzwieki := {}                            # nazwa -> AudioStreamWAV
var _gracze: Array[AudioStreamPlayer] = []    # pula odtwarzaczy
var _petla_disco: AudioStreamWAV = null       # generowana leniwie

# --- KLASYKI DISCO POLO (music/*.mp3) - odpalają się przy wielkich momentach ---
# Wrzuć do folderu music/ dowolną liczbę piosenek - gra losuje raz tę, raz tę.
#
# A jeśli w music/ NIC nie ma (świeży klon repozytorium - pliki są objęte
# prawami autorskimi i nie mogą tam leżeć), gra nie zostaje w ciszy: wchodzi
# WŁASNY, generowany w kodzie kawałek disco polo. Ktoś, kto sklonuje projekt,
# od razu słyszy grę taką, jaką miała być.
const KLASYK_START := 30.0  # od której sekundy utworu grać (refren!)
const KLASYK_CZAS := 15.0   # ile sekund klasyka leci, zanim się wyciszy
var _klasyk: AudioStreamPlayer
var _klasyki: Array[AudioStream] = []
var _petla_deszczu: AudioStreamWAV = null   # generowana leniwie
var _petla_dachu: AudioStreamWAV = null     # bębnienie deszczu o blachę wiaty

# --- SYNTETYCZNY KLASYK (fallback, gdy nie ma plików w music/) ---
const KLASYK_BPM := 132.0
const KLASYK_TAKTY := 8            # 8 taktów po 4 ćwiartki ≈ 15 s
## Bas: A - F - C - G, czyli progresja, na której stoi połowa gatunku.
const KLASYK_BAS: Array[float] = [110.0, 87.31, 130.81, 98.0]
## Przygrywka - osiem ósemek na takt, cztery takty, potem powtórka.
const KLASYK_MELODIA: Array = [
	[440.0, 523.25, 659.25, 523.25, 587.33, 523.25, 493.88, 440.0],
	[349.23, 440.0, 523.25, 440.0, 523.25, 587.33, 523.25, 440.0],
	[523.25, 659.25, 783.99, 659.25, 587.33, 523.25, 493.88, 523.25],
	[392.0, 493.88, 587.33, 493.88, 587.33, 659.25, 587.33, 493.88],
]

func _ready() -> void:
	# Pula 10 odtwarzaczy, żeby dźwięki mogły się nakładać
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_gracze.append(p)
	_generuj_dzwieki()
	# Osobny odtwarzacz na klasyka (nie zajmuje puli efektów)
	_klasyk = AudioStreamPlayer.new()
	add_child(_klasyk)
	_wczytaj_klasyk()

## Wczytuje WSZYSTKIE pliki muzyczne z res://music/.
## (W wyeksportowanej grze pliki widnieją jako .import/.remap - obcinamy.)
func _wczytaj_klasyk() -> void:
	var katalog := DirAccess.open("res://music")
	if katalog == null:
		return
	var wczytane: Array[String] = []
	for plik in katalog.get_files():
		var nazwa := plik.trim_suffix(".import").trim_suffix(".remap")
		if nazwa.get_extension().to_lower() in ["mp3", "ogg", "wav"] and not nazwa in wczytane:
			wczytane.append(nazwa)
			var strumien: AudioStream = load("res://music/" + nazwa)
			if strumien:
				_klasyki.append(strumien)

## WIELKI MOMENT = KLASYK. Losuje utwór z music/, gra refren i sam się wycisza.
##
## Gdy w music/ nie ma ani jednego pliku (a w repozytorium nie ma - to są
## komercyjne kawałki), wchodzi WŁASNY, syntezowany kawałek disco polo.
## Generujemy go leniwie, przy pierwszym wielkim momencie: budowa
## piętnastu sekund dźwięku przy starcie gry byłaby zauważalną zwłoką.
func odpal_klasyk() -> void:
	if _klasyk.playing:
		return   # klasyk już leci - nie przerywamy klasyka
	if _klasyki.is_empty():
		_klasyki.append(_generuj_klasyk())
	Game.pokaz_komunikat("Z osiedlowego głośnika leci KLASYK. Głośniej, sąsiad i tak nie śpi!")
	var strumien: AudioStream = _klasyki.pick_random()
	# Start od refrenu, ale nie poza końcem utworu (dla krótkich plików)
	var start := minf(KLASYK_START, maxf(strumien.get_length() - KLASYK_CZAS, 0.0))
	_klasyk.stream = strumien
	_klasyk.volume_db = 0.0
	_klasyk.play(start)
	var tw := create_tween()
	tw.tween_interval(KLASYK_CZAS)
	tw.tween_property(_klasyk, "volume_db", -40.0, 2.0)
	tw.tween_callback(_klasyk.stop)

## Odtwarza dźwięk o podanej nazwie. "ton" > 1.0 = wyższy dźwięk (np. do combo).
func graj(nazwa: String, glosnosc_db := 0.0, ton := 1.0) -> void:
	if not _dzwieki.has(nazwa):
		return
	_graj_strumien(_dzwieki[nazwa], glosnosc_db, ton)

## Losowy okrzyk wsioka ("hop!", pisk itd.) - przy podnoszeniu butelek.
func graj_okrzyk() -> void:
	graj("okrzyk%d" % (randi_range(1, 3)), -3.0, randf_range(0.9, 1.15))

## Dźwięk butelkomatu jak jednoręki bandyta: seria cyknięć przyspieszających
## w tempie + "jackpot" na końcu. Liczba cyknięć zależy od liczby butelek.
## Generowany dynamicznie, bo za każdym razem jest inny.
func graj_bandyta(ile_butelek: int) -> void:
	var cyknięcia := clampi(ile_butelek, 4, 18)
	var probki := PackedFloat32Array()
	# Cyknięcia: odstępy maleją od 0.14 s do 0.04 s - efekt "kręcących się bębnów"
	for i in cyknięcia:
		var postep := float(i) / cyknięcia
		probki.append_array(_ton(1100 + postep * 500, 1300 + postep * 500, 0.025, 0.3))
		probki.append_array(_cisza(lerpf(0.14, 0.04, postep)))
	# Jackpot: akord + potrójne "ka-ching"
	probki.append_array(_sklej([
		_ton(784, 784, 0.12, 0.3), _ton(988, 988, 0.12, 0.3), _ton(1175, 1175, 0.2, 0.35),
		_cisza(0.05),
		_ton(1568, 1568, 0.07), _cisza(0.02), _ton(2093, 2093, 0.1),
		_cisza(0.02), _ton(2637, 2637, 0.18, 0.4),
	]))
	_graj_strumien(_wav(probki), 2.0)

func _graj_strumien(strumien: AudioStreamWAV, glosnosc_db: float, ton := 1.0) -> void:
	for p in _gracze:
		if not p.playing:
			p.stream = strumien
			p.volume_db = glosnosc_db
			p.pitch_scale = ton
			p.play()
			return

func _generuj_dzwieki() -> void:
	# Podniesienie butelki: wesoły, rosnący "blip"
	_dzwieki["podnies"] = _wav(_sklej([_ton(500, 900, 0.09), _ton(900, 1250, 0.07)]))
	# Złota butelka/puszka: mała fanfara (arpeggio C-E-G-C)
	_dzwieki["zlota"] = _wav(_sklej([
		_ton(523, 523, 0.09), _ton(659, 659, 0.09),
		_ton(784, 784, 0.09), _ton(1047, 1047, 0.22),
	]))
	# Grzebanie w śmietniku: seria szumów
	_dzwieki["grzebanie"] = _wav(_sklej([
		_szum(0.12, 0.35), _cisza(0.05), _szum(0.10, 0.28),
		_cisza(0.06), _szum(0.16, 0.4),
	]))
	# Kasa: klasyczne "ka-ching" (zostaje do drobnych rzeczy)
	_dzwieki["kasa"] = _wav(_sklej([
		_ton(1568, 1568, 0.07), _cisza(0.03), _ton(2093, 2093, 0.16),
	]))
	# Błąd / pełny plecak: niski bzyk
	_dzwieki["blad"] = _wav(_ton(110, 95, 0.2, 0.3, "kwadrat"))
	# Skok: krótki świst w górę
	_dzwieki["skok"] = _wav(_ton(300, 520, 0.08, 0.2))
	# Koniec dnia: opadająca melodyjka
	_dzwieki["koniec"] = _wav(_sklej([
		_ton(784, 784, 0.16), _ton(659, 659, 0.16),
		_ton(523, 523, 0.16), _ton(392, 392, 0.34),
	]))
	# Szczur: piski
	_dzwieki["szczur"] = _wav(_sklej([
		_ton(1600, 1900, 0.06, 0.25), _cisza(0.03),
		_ton(1500, 1800, 0.07, 0.25),
	]))
	# Okrzyki wsioka przy podnoszeniu ("hop!", pisk, "hyhy")
	_dzwieki["okrzyk1"] = _wav(_sklej([_ton(350, 550, 0.08, 0.3), _ton(550, 320, 0.07, 0.3)]))
	_dzwieki["okrzyk2"] = _wav(_ton(900, 1400, 0.11, 0.22))
	_dzwieki["okrzyk3"] = _wav(_sklej([
		_ton(420, 480, 0.06, 0.28), _cisza(0.03), _ton(390, 450, 0.06, 0.28),
	]))
	# Upadek: opadający gwizdek + głuche "łup" o glebę
	_dzwieki["upadek"] = _wav(_sklej([
		_ton(900, 180, 0.45, 0.3),
		_ton(70, 55, 0.1, 0.55), _szum(0.12, 0.5),
	]))
	# Szczekanie psa: dwa szorstkie "HAU"
	_dzwieki["szczek"] = _wav(_sklej([
		_szum(0.04, 0.5), _ton(260, 150, 0.09, 0.45, "kwadrat"), _cisza(0.09),
		_szum(0.04, 0.5), _ton(240, 140, 0.09, 0.45, "kwadrat"),
	]))
	# Wsiokometr 100% - wielka fanfara legendy osiedla
	_dzwieki["legenda"] = _wav(_sklej([
		_ton(523, 523, 0.11), _ton(659, 659, 0.11), _ton(784, 784, 0.11),
		_ton(1047, 1047, 0.11), _ton(784, 784, 0.11), _ton(1047, 1047, 0.4, 0.45),
	]))
	# Cios: świst powietrza + głuche pacnięcie
	_dzwieki["cios"] = _wav(_sklej([_szum(0.06, 0.25), _ton(120, 80, 0.08, 0.5)]))
	# Dzwonek sklepowy przy drzwiach Biedronki (dzyń-dzyń)
	_dzwieki["sklep"] = _wav(_sklej([_ton(659, 659, 0.14), _cisza(0.04), _ton(523, 523, 0.2)]))
	# Pies zadowolony: miękkie, wesołe piski
	_dzwieki["pies_lubi"] = _wav(_sklej([
		_ton(700, 950, 0.09, 0.22), _cisza(0.05), _ton(800, 1100, 0.12, 0.2),
	]))
	# Furkot gołębich skrzydeł
	_dzwieki["furkot"] = _wav(_sklej([
		_szum(0.05, 0.3), _cisza(0.02), _szum(0.05, 0.28), _cisza(0.02),
		_szum(0.05, 0.25), _cisza(0.02), _szum(0.04, 0.2),
	]))
	# Czkawka pijanego wsioka
	_dzwieki["czkawka"] = _wav(_sklej([_ton(400, 850, 0.07, 0.25), _ton(850, 500, 0.04, 0.15)]))
	# Jęk kacowy - niski, cierpiący
	_dzwieki["jek"] = _wav(_sklej([_ton(220, 150, 0.35, 0.22), _ton(150, 120, 0.25, 0.15)]))
	# Kroki: miękki na trawie, twardszy "klik" na betonie
	_dzwieki["krok_trawa"] = _wav(_szum(0.05, 0.2))
	_dzwieki["krok_beton"] = _wav(_sklej([
		_ton(700, 500, 0.02, 0.16, "kwadrat"), _szum(0.03, 0.13),
	]))
	# Brzęk metalu (wywrotka wózkiem)
	_dzwieki["brzek"] = _wav(_sklej([
		_szum(0.06, 0.5), _ton(1800, 1200, 0.08, 0.3), _szum(0.1, 0.35),
		_cisza(0.05), _szum(0.08, 0.25),
	]))

## Zapętlona "kompozycja" disco polo (do okna bloku). Stopa, hi-hat,
## bas na kwadracie i wpadająca w ucho przygrywka - 100% syntezy.
func petla_disco() -> AudioStreamWAV:
	if _petla_disco == null:
		_petla_disco = _generuj_disco()
	return _petla_disco

func _generuj_disco() -> AudioStreamWAV:
	var beat := 60.0 / 130.0   # 130 BPM
	var n := int(beat * 8.0 * CZESTOTLIWOSC_PROBKOWANIA)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for b in 8:
		# Stopa na każdą ćwiartkę + hi-hat na "i"
		_wmiksuj(mix, b * beat, _ton(80, 45, 0.12, 0.5))
		_wmiksuj(mix, b * beat + beat / 2, _szum(0.025, 0.12))
	# Bas: A A E E F F G G (klasyka gatunku)
	var basy: Array[float] = [110.0, 110.0, 82.41, 82.41, 87.31, 87.31, 98.0, 98.0]
	for b in 8:
		for pol in 2:
			_wmiksuj(mix, b * beat + pol * beat / 2, _ton(basy[b], basy[b], 0.18, 0.2, "kwadrat"))
	# Przygrywka
	var melodia: Array[float] = [440.0, 523.25, 659.25, 523.25, 587.33, 523.25, 493.88, 440.0]
	for b in 8:
		_wmiksuj(mix, b * beat, _ton(melodia[b], melodia[b], 0.3, 0.13))
	var wav := _wav(mix)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

## SYNTETYCZNY KLASYK - piętnastosekundowy kawałek disco polo złożony
## z tych samych klocków, co reszta dźwięków w grze.
##
## To nie jest zapętlona przygrywka z okna bloku (patrz petla_disco): ta ma
## budowę utworu - wejście na samym bicie i basie, potem refren z przygrywką
## i "trąbką" na górze. Chodzi o to, żeby wielki moment brzmiał jak wielki
## moment, a nie jak dzwonek do drzwi.
func _generuj_klasyk() -> AudioStreamWAV:
	var beat := 60.0 / KLASYK_BPM
	var takt := beat * 4.0
	var n := int(takt * KLASYK_TAKTY * CZESTOTLIWOSC_PROBKOWANIA)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for t in KLASYK_TAKTY:
		var start := t * takt
		var bas: float = KLASYK_BAS[t % KLASYK_BAS.size()]
		# Stopa na każdą ćwiartkę, hi-hat na "i", klaśnięcie na 2 i 4
		for c in 4:
			_wmiksuj(mix, start + c * beat, _ton(85, 45, 0.13, 0.55))
			_wmiksuj(mix, start + c * beat + beat / 2.0, _szum(0.028, 0.14))
			if c % 2 == 1:
				_wmiksuj(mix, start + c * beat, _szum(0.07, 0.24))
		# Bas ósemkami - motoryka gatunku
		for o in 8:
			_wmiksuj(mix, start + o * beat / 2.0, _ton(bas, bas, 0.17, 0.24, "kwadrat"))
		# Pierwsze dwa takty to samo wejście - przygrywka wchodzi od trzeciego,
		# dzięki czemu utwór ma moment, w którym "się zaczyna"
		if t < 2:
			continue
		var fraza: Array = KLASYK_MELODIA[t % KLASYK_MELODIA.size()]
		for o in 8:
			var nuta: float = fraza[o]
			_wmiksuj(mix, start + o * beat / 2.0, _ton(nuta, nuta, 0.26, 0.15))
			# Oktawa wyżej i ciszej - syntetyczna "trąbka" nad melodią
			if t >= 4:
				_wmiksuj(mix, start + o * beat / 2.0, _ton(nuta * 2.0, nuta * 2.0, 0.2, 0.06))
	return _wav(mix)

## Szum deszczu - cztery sekundy filtrowanego szumu w pętli.
## Bez obwiedni (w przeciwieństwie do _szum), bo deszcz nie ma wybrzmiewać;
## powolna modulacja głośności robi za podmuchy wiatru.
func petla_deszczu() -> AudioStreamWAV:
	if _petla_deszczu != null:
		return _petla_deszczu
	var n := 4 * CZESTOTLIWOSC_PROBKOWANIA
	var probki := PackedFloat32Array()
	probki.resize(n)
	var poprzednia := 0.0
	for i in n:
		var t := float(i) / n
		# Mocne filtrowanie dolnoprzepustowe - biały szum brzmi jak zakłócenia,
		# dopiero przytłumiony zaczyna brzmieć jak woda
		poprzednia = lerpf(poprzednia, randf_range(-1.0, 1.0), 0.22)
		# Dwie fale o różnych okresach = podmuchy bez słyszalnego rytmu
		var podmuch := 0.75 + 0.15 * sin(t * TAU) + 0.1 * sin(t * TAU * 2.7)
		# Wygładzenie na złączeniu pętli, żeby nie strzelało co cztery sekundy
		var szew := minf(minf(t, 1.0 - t) * 40.0, 1.0)
		probki[i] = poprzednia * 0.42 * podmuch * szew
	var wav := _wav(probki)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_petla_deszczu = wav
	return wav

## BĘBNIENIE DESZCZU O BLACHĘ - pętla puszczana pod wiatami.
##
## Deszcz na otwartym to szum; deszcz na blaszanym daszku to POJEDYNCZE
## uderzenia z krótkim dzwonieniem metalu. Dlatego nie da się tego zrobić
## przez samo podbicie basu na szumie: potrzebne są transjenty. Sypiemy
## kilkaset losowych stuknięć na cztery sekundy, każde z własną wysokością.
func petla_dachu() -> AudioStreamWAV:
	if _petla_dachu != null:
		return _petla_dachu
	var n := 4 * CZESTOTLIWOSC_PROBKOWANIA
	var probki := PackedFloat32Array()
	probki.resize(n)
	# Podkład: bardzo przytłumiony szum, żeby między stuknięciami nie było
	# martwej ciszy (na daszku zawsze coś kapie)
	var poprzednia := 0.0
	for i in n:
		poprzednia = lerpf(poprzednia, randf_range(-1.0, 1.0), 0.12)
		probki[i] = poprzednia * 0.1
	# Stuknięcia: tłumione sinusoidy o częstotliwości blachy (1-3 kHz)
	for i in 520:
		var start := randi() % n
		var f := randf_range(950.0, 3100.0)
		var glosnosc := randf_range(0.12, 0.4)
		var dlugosc := int(0.02 * CZESTOTLIWOSC_PROBKOWANIA)
		for j in dlugosc:
			var indeks := start + j
			if indeks >= n:
				break
			var t := float(j) / dlugosc
			probki[indeks] += sin(TAU * f * float(j) / CZESTOTLIWOSC_PROBKOWANIA) 				* glosnosc * pow(1.0 - t, 3.0)
	# Wygładzenie na złączeniu pętli - bez tego strzela co cztery sekundy
	for i in n:
		var t := float(i) / n
		probki[i] = clampf(probki[i] * minf(minf(t, 1.0 - t) * 40.0, 1.0), -1.0, 1.0)
	var wav := _wav(probki)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_petla_dachu = wav
	return wav

## Dokłada fragment do miksu w podanym punkcie czasu (sekundy).
func _wmiksuj(mix: PackedFloat32Array, start_s: float, fragment: PackedFloat32Array) -> void:
	var start := int(start_s * CZESTOTLIWOSC_PROBKOWANIA)
	for i in fragment.size():
		var indeks := start + i
		if indeks < mix.size():
			mix[indeks] += fragment[i]

# --- Generatory próbek (float -1..1) ---

## Ton o częstotliwości płynącej od f0 do f1, z wyciszeniem na końcu.
func _ton(f0: float, f1: float, czas: float, glosnosc := 0.35, ksztalt := "sin") -> PackedFloat32Array:
	var n := int(czas * CZESTOTLIWOSC_PROBKOWANIA)
	var probki := PackedFloat32Array()
	probki.resize(n)
	var faza := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		faza += TAU * f / CZESTOTLIWOSC_PROBKOWANIA
		var s := sin(faza)
		if ksztalt == "kwadrat":
			s = signf(s) * 0.6
		# Obwiednia: szybki atak, wyciszenie na końcu
		var obw := minf(t * 20.0, 1.0) * (1.0 - t * t)
		probki[i] = s * glosnosc * obw
	return probki

## Biały szum (grzebanie, uderzenia, szczekanie).
func _szum(czas: float, glosnosc := 0.3) -> PackedFloat32Array:
	var n := int(czas * CZESTOTLIWOSC_PROBKOWANIA)
	var probki := PackedFloat32Array()
	probki.resize(n)
	var poprzednia := 0.0
	for i in n:
		var t := float(i) / n
		# Lekko filtrowany szum brzmi bardziej "papierowo"
		poprzednia = lerpf(poprzednia, randf_range(-1.0, 1.0), 0.5)
		probki[i] = poprzednia * glosnosc * (1.0 - t)
	return probki

func _cisza(czas: float) -> PackedFloat32Array:
	var probki := PackedFloat32Array()
	probki.resize(int(czas * CZESTOTLIWOSC_PROBKOWANIA))
	return probki

## Skleja kilka fragmentów w jeden.
func _sklej(fragmenty: Array) -> PackedFloat32Array:
	var wynik := PackedFloat32Array()
	for f in fragmenty:
		wynik.append_array(f)
	return wynik

## Konwersja próbek float na AudioStreamWAV (16-bit mono).
func _wav(probki: PackedFloat32Array) -> AudioStreamWAV:
	var bajty := PackedByteArray()
	bajty.resize(probki.size() * 2)
	for i in probki.size():
		var v := int(clampf(probki[i], -1.0, 1.0) * 32767.0)
		bajty.encode_s16(i * 2, v)
	var strumien := AudioStreamWAV.new()
	strumien.format = AudioStreamWAV.FORMAT_16_BITS
	strumien.mix_rate = CZESTOTLIWOSC_PROBKOWANIA
	strumien.stereo = false
	strumien.data = bajty
	return strumien
