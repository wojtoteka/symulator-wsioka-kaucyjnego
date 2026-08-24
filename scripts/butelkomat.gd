extends StaticBody3D
## BUTELKOMAT - tu gracz oddaje plecak i dostaje kaucję.
##
## Na mapie stoją TRZY: przy Biedronce, pod małym blokiem i przy garażach.
## Jeden był wąskim gardłem - automat zapycha się w ponad jednej trzeciej
## prób, więc gracz z pełnym plecakiem nie miał dokąd pójść.
##
## Do tego dochodzi KOLEJKA: co jakiś czas przy automacie staje babcia
## z siatą puszek i przez kilka sekund nie ma podejścia. Pytanie brzmi:
## stoję osiem sekund czy biegnę czterdzieści metrów do następnego?
##
## Żeby to pytanie miało dwie odpowiedzi, potrzebne były dwie rzeczy:
##   - kolejka ROŚNIE, gdy w niej stoisz (dochodzą kolejni) - patrz
##     _dokladaj_do_kolejki(). Bez tego przeczekanie było zawsze tańsze.
##   - automat się MĘCZY: świeżo użyty zapycha się chętniej (_zmeczenie).
##     Bez tego trzy niezależnie losujące punkty gwarantowały, że zawsze
##     któryś działa, i wąskie gardło zniknęło za bardzo.

## Nazwa punktu do komunikatów i podpowiedzi ("przy Biedronce").
var nazwa_punktu := "przy Biedronce"

## Kto dochodzi do kolejki, gdy w niej stoisz. Kolejka, która rośnie, zamienia
## "przeczekam" z darmowej opcji w decyzję - patrz Balans.KOLEJKA_DOKLADKA_CO.
const TEKSTY_DOKLADKI: Array[String] = [
	"Za tobą stanął pan Mietek. Z reklamówką. Pełną.",
	"Doszła sąsiadka z drugiej klatki. \"Ja tylko zapytam\".",
	"Kolejka się wydłuża. Ktoś przyniósł skrzynkę.",
	"Babcia zawołała koleżankę. Koleżanka też ma puszki.",
]

var _ekran: MeshInstance3D
var _material_ekranu: StandardMaterial3D
var _babcia: Node3D          # wizualna kolejka - pokazuje się, gdy ktoś stoi
var _kolejka := 0.0          # ile sekund jeszcze potrwa obsługa babci
var _do_nowej_babci := 0.0   # odliczanie do kolejnego "gościa"
var _do_dokladki := 0.0      # odliczanie do kolejnego gościa DOŁĄCZAJĄCEGO do kolejki
var _zmeczenie := 0.0        # dodatek do szansy zapchania po świeżej transakcji

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")   # bicie automatu: nie zalecane, ale możliwe
	add_to_group("cel_nawigacji")
	add_to_group("butelkomat")   # nawigacja szuka NAJBLIŻSZEGO z tej grupy
	_zbuduj_bryle()
	_zbuduj_babcie()
	_do_nowej_babci = randf_range(Balans.KOLEJKA_PRZERWA_MIN, Balans.KOLEJKA_PRZERWA_MAX)
	# Część automatów ma kolejkę już od rana - inaczej pierwsza minuta dnia
	# byłaby zawsze bezproblemowa i mechanika ujawniałaby się dopiero później
	if randf() < Balans.SZANSA_KOLEJKI:
		_ustaw_kolejke(randf_range(Balans.KOLEJKA_MIN, Balans.KOLEJKA_MAX))

## Identyfikator dla strzałki nawigacji (patrz ui/nawigacja.gd).
func nazwa_celu() -> String:
	return "butelkomat"

## Czy przy tym automacie ktoś już stoi (pyta o to nawigacja, żeby prowadzić
## do wolnego punktu, a nie do tego, przy którym i tak się poczeka).
func czy_kolejka() -> bool:
	return _kolejka > 0.0

func _process(delta: float) -> void:
	if Game.w_menu or not Game.gra_trwa:
		return
	# Automat "odpoczywa" - zmęczenie po transakcji schodzi z czasem
	_zmeczenie = maxf(_zmeczenie - Balans.ZMECZENIE_SPADEK * delta, 0.0)
	if _kolejka > 0.0:
		_kolejka -= delta
		_dokladaj_do_kolejki(delta)
		if _kolejka <= 0.0:
			_ustaw_kolejke(0.0)
			_do_nowej_babci = randf_range(Balans.KOLEJKA_PRZERWA_MIN, Balans.KOLEJKA_PRZERWA_MAX)
		return
	# Nowa babcia losuje się co kilkadziesiąt sekund, ale nigdy w trakcie
	# transakcji gracza - przerwanie liczenia bębnów byłoby zwykłą złośliwością
	_do_nowej_babci -= delta
	if _do_nowej_babci <= 0.0 and not _liczy:
		_do_nowej_babci = randf_range(Balans.KOLEJKA_PRZERWA_MIN, Balans.KOLEJKA_PRZERWA_MAX)
		if randf() < Balans.SZANSA_KOLEJKI:
			_ustaw_kolejke(randf_range(Balans.KOLEJKA_MIN, Balans.KOLEJKA_MAX))

func _ustaw_kolejke(sekundy: float) -> void:
	_kolejka = sekundy
	_do_dokladki = Balans.KOLEJKA_DOKLADKA_CO
	if is_instance_valid(_babcia):
		_babcia.visible = sekundy > 0.0

## KOLEJKA ROŚNIE, GDY W NIEJ STOISZ.
##
## Wcześniej kolejka leciała sama, niezależnie od gracza - i to był błąd
## projektowy: skoro czekanie nic nie kosztowało, a drugi automat leżał
## czterdzieści metrów dalej, "stoję" było ZAWSZE lepsze. Wybór z jedną dobrą
## odpowiedzią to nie wybór. Teraz stanie pod automatem dokłada kolejnych
## gości (do sufitu KOLEJKA_MAKS), więc przeczekanie ma swoją cenę - a bieg
## do sąsiedniego punktu przestaje być karą za niecierpliwość.
func _dokladaj_do_kolejki(delta: float) -> void:
	if _kolejka >= Balans.KOLEJKA_MAKS or not _gracz_w_poblizu():
		return
	_do_dokladki -= delta
	if _do_dokladki > 0.0:
		return
	_do_dokladki = Balans.KOLEJKA_DOKLADKA_CO
	if randf() >= Balans.KOLEJKA_SZANSA_DOKLADKI:
		return
	_kolejka = minf(_kolejka + randf_range(
		Balans.KOLEJKA_DOKLADKA_MIN, Balans.KOLEJKA_DOKLADKA_MAX), Balans.KOLEJKA_MAKS)
	Sfx.graj("blad", -16.0)
	Game.pokaz_komunikat("%s (jeszcze %d s)" % [TEKSTY_DOKLADKI.pick_random(), int(ceilf(_kolejka))])

## Czy gracz stoi na tyle blisko, żeby liczyć się jako czekający w kolejce.
func _gracz_w_poblizu() -> bool:
	for gracz in get_tree().get_nodes_in_group("gracz"):
		if not is_instance_valid(gracz):
			continue
		if global_position.distance_to(gracz.global_position) <= Balans.KOLEJKA_ZASIEG:
			return true
	return false

## Cios pięścią w butelkomat. Zapchany - pomaga. Sprawny - może się zapchać.
func oberwij(_gracz: Node3D) -> void:
	if _zapchany:
		_kopniecie()
		return
	Sfx.graj("brzek", -6.0)
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.04, 0.05)
	tw.tween_property(self, "rotation:z", 0.0, 0.08)
	if randf() < Balans.SZANSA_ZAPCHANIA_OD_BICIA:
		_zapchany = true
		_ustaw_kolor_ekranu(Color(1, 0.2, 0.2))
		Game.pokaz_komunikat("No i się zapchał od bicia. Brawo, mistrzu.")
	else:
		Game.pokaz_komunikat(["Butelkomat: \"Prosimy nie uderzać w urządzenie\".", "Automat wytrzymał. Serwisant by płakał."].pick_random())

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.obiekt(kolor)

func _zbuduj_bryle() -> void:
	# Korpus automatu
	var korpus := MeshInstance3D.new()
	var pudlo := BoxMesh.new()
	pudlo.size = Vector3(1.2, 2.2, 0.9)
	korpus.mesh = pudlo
	korpus.material_override = _material(Color(0.1, 0.35, 0.25))
	korpus.position = Vector3(0, 1.1, 0)
	add_child(korpus)

	# Świecący ekran
	_ekran = MeshInstance3D.new()
	var pudlo_ekranu := BoxMesh.new()
	pudlo_ekranu.size = Vector3(0.7, 0.45, 0.05)
	_ekran.mesh = pudlo_ekranu
	_material_ekranu = StandardMaterial3D.new()
	_material_ekranu.albedo_color = Color(0.1, 0.9, 0.9)
	_material_ekranu.emission_enabled = true
	_material_ekranu.emission = Color(0.1, 0.9, 0.9)
	_material_ekranu.emission_energy_multiplier = 1.2
	_ekran.material_override = _material_ekranu
	_ekran.position = Vector3(0, 1.7, 0.46)
	add_child(_ekran)

	# Czarny otwór na butelki
	var otwor := MeshInstance3D.new()
	var walec := CylinderMesh.new()
	walec.top_radius = 0.14
	walec.bottom_radius = 0.14
	walec.height = 0.1
	otwor.mesh = walec
	otwor.material_override = _material(Color(0.03, 0.03, 0.03))
	otwor.rotation.x = PI / 2
	otwor.position = Vector3(0, 1.15, 0.44)
	add_child(otwor)

	# Napis nad automatem
	var napis := Styl.plakietka("BUTELKOMAT", 96, Color(1, 1, 0.3))
	napis.position = Vector3(0, 2.6, 0)
	add_child(napis)

	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = Vector3(1.2, 2.2, 0.9)
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 1.1, 0)
	add_child(kolizja)

## BABCIA W KOLEJCE - prosta sylwetka z siatą, budowana raz i chowana,
## gdy nikt nie stoi. Kolejka musi być WIDOCZNA z daleka: gracz ma podjąć
## decyzję "biegnę czy stoję", zanim tam dobiegnie.
func _zbuduj_babcie() -> void:
	_babcia = Node3D.new()
	_babcia.position = Vector3(0, 0, 1.05)   # przed automatem, tyłem do gracza
	_babcia.visible = false
	add_child(_babcia)
	var plaszcz := MeshInstance3D.new()
	var stozek := CylinderMesh.new()
	stozek.top_radius = 0.2
	stozek.bottom_radius = 0.42
	stozek.height = 1.15
	plaszcz.mesh = stozek
	plaszcz.material_override = _material(Color(0.42, 0.3, 0.45))   # płaszcz w kwiaty
	plaszcz.position = Vector3(0, 0.58, 0)
	_babcia.add_child(plaszcz)
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.2
	kula.height = 0.4
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.9, 0.76, 0.66))
	glowa.position = Vector3(0, 1.32, 0)
	_babcia.add_child(glowa)
	# Chustka na głowie - bez niej to po prostu stożek
	var chustka := MeshInstance3D.new()
	var czasza := SphereMesh.new()
	czasza.radius = 0.22
	czasza.height = 0.3
	chustka.mesh = czasza
	chustka.material_override = _material(Color(0.8, 0.25, 0.3))
	chustka.position = Vector3(0, 1.4, -0.02)
	_babcia.add_child(chustka)
	# Siata z puszkami - powód, dla którego to potrwa
	var siata := MeshInstance3D.new()
	var pudlo_siaty := BoxMesh.new()
	pudlo_siaty.size = Vector3(0.34, 0.5, 0.28)
	siata.mesh = pudlo_siaty
	siata.material_override = _material(Color(0.88, 0.86, 0.55))
	siata.position = Vector3(0.42, 0.42, 0.1)
	_babcia.add_child(siata)
	var podpis := Styl.plakietka("KOLEJKA", 40, Color(1.0, 0.65, 0.6))
	podpis.position = Vector3(0, 1.78, 0)
	_babcia.add_child(podpis)

func podpowiedz() -> String:
	if _zapchany:
		return "E - KOPNIJ zapchany butelkomat"
	if _kolejka > 0.0:
		return "Kolejka (%s): babcia oddaje puszki - jeszcze %d s" % [
			nazwa_punktu, int(ceilf(_kolejka))]
	var butelki := Game.ile_w_plecaku("kaucja")
	if butelki == 0:
		if Game.ile_w_plecaku("zlom") > 0:
			return "Butelkomat nie bierze złomu - to na skup do Zdziśka"
		return "Butelkomat %s - plecak pusty" % nazwa_punktu
	return "E - oddaj butelki (%d szt.)" % butelki

var _liczy := false      # blokada podwójnego uruchomienia "bębnów"
var _zapchany := false   # czasem się zapycha - celowo wnerwia

func interakcja(_gracz: Node3D) -> void:
	if _liczy:
		return
	if _kolejka > 0.0:
		Sfx.graj("blad", -8.0)
		Game.pokaz_komunikat([
			"Babcia: \"Młody, ja tu pierwsza! Mam jeszcze pół siaty.\"",
			"Kolejka. Babcia liczy puszki po jednej. Zostało %d s." % int(ceilf(_kolejka)),
			"\"Za mną pan stoi?\" Stoisz. Albo biegniesz do innego automatu.",
		].pick_random())
		return
	if _zapchany:
		_kopniecie()
		return
	if Game.ile_w_plecaku("kaucja") == 0:
		Sfx.graj("blad")
		if Game.ile_w_plecaku("zlom") > 0:
			Game.pokaz_komunikat("Automat wypluł felgę. \"NIEZNANY KOD KRESKOWY\". Złom leci na SKUP, nie tutaj.")
		else:
			Game.pokaz_komunikat("Plecak pusty. Butelkomat patrzy na Ciebie z politowaniem.")
		return
	# Losowe zapchanie - bo prawdziwy butelkomat też tak robi.
	# Do bazowej szansy dochodzi ZMĘCZENIE tego konkretnego automatu: trzy
	# punkty losujące niezależnie sprawiały, że statystycznie zawsze któryś
	# działał, i wąskie gardło zniknęło za bardzo. Teraz automat, do którego
	# właśnie wrzuciłeś plecak, jest bardziej kapryśny - opłaca się krążyć.
	if randf() < Balans.SZANSA_ZAPCHANIA + _zmeczenie:
		_zapchany = true
		Sfx.graj("blad")
		if _zmeczenie > 0.05:
			Game.pokaz_komunikat("ZAPCHANY. Ten automat ma dziś przepracowane - spróbuj innego punktu.")
		else:
			Game.pokaz_komunikat("BUTELKOMAT ZAPCHANY! Ktoś wepchnął słoik po ogórkach. Kopnij go (E).")
		_ustaw_kolor_ekranu(Color(1, 0.2, 0.2))
		return
	# Jednoręki bandyta: kasa nalicza się od razu, ale dźwięk i komunikat
	# celebrują wygraną - seria cyknięć przyspiesza aż do "jackpotu"
	_liczy = true
	var wynik: Dictionary = Game.oddaj_wszystko()
	_zmeczenie = minf(_zmeczenie + Balans.ZMECZENIE_ZA_KURS, Balans.ZMECZENIE_MAKS)
	Game.zanotuj_punkt(nazwa_punktu)
	# Gniazdko serwisowe butelkomatu - jedyne miejsce na osiedlu, gdzie magnes
	# z bazaru łapie prąd. Ładowanie leży dokładnie tam, gdzie i tak trzeba
	# dojść, więc dzień domyka się w pętlę zamiast rozjeżdżać.
	Game.doladuj_magnes()
	Game.postep_zlecenia("butelki_oddane", wynik["ile"])
	Sfx.graj_bandyta(wynik["ile"])
	Game.pokaz_komunikat("Butelkomat mieli %d szt. Bębny się kręcą..." % wynik["ile"])
	_migaj_jak_bandyta()
	await get_tree().create_timer(1.5, false).timeout
	_liczy = false
	if not is_inside_tree():
		return
	Game.wstrzasnij(0.25)   # jackpot musi być czuć
	Game.pokaz_komunikat("JACKPOT! Kaucja +%s! Biznes się kręci." % Game.zl(wynik["kwota"]))
	_mrugnij_ekranem()

## Kopniak w zapchany automat - metoda serwisowa znana od pokoleń.
func _kopniecie() -> void:
	Sfx.graj("brzek")
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.05, 0.06)
	tw.tween_property(self, "rotation:z", -0.04, 0.06)
	tw.tween_property(self, "rotation:z", 0.0, 0.06)
	if randf() < Balans.SZANSA_ODETKANIA:
		_zapchany = false
		Game.pokaz_komunikat("Odetkany metodą osiedlową. Serwis by wziął 200 zł.")
		_ustaw_kolor_ekranu(Color(0.1, 0.9, 0.9))
	else:
		Game.pokaz_komunikat("Nadal zapchany. Butelkomat drwi z ciebie.")

## Ekran mruga kolorami jak automat w kasynie podczas "mielenia".
func _migaj_jak_bandyta() -> void:
	var kolory := [Color(1, 0.2, 0.2), Color(1, 1, 0.2), Color(0.2, 1, 0.2), Color(0.4, 0.4, 1)]
	var tw := create_tween()
	for i in 6:
		var kolor: Color = kolory[i % kolory.size()]
		tw.tween_callback(_ustaw_kolor_ekranu.bind(kolor))
		tw.tween_interval(0.22)

## Ekran mruga na zielono po udanej transakcji.
func _mrugnij_ekranem() -> void:
	var tw := create_tween()
	tw.tween_method(_ustaw_kolor_ekranu, Color(0.2, 1.0, 0.2), Color(0.1, 0.9, 0.9), 1.2)

func _ustaw_kolor_ekranu(kolor: Color) -> void:
	_material_ekranu.albedo_color = kolor
	_material_ekranu.emission = kolor
