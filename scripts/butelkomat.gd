extends StaticBody3D
## BUTELKOMAT przy Biedronce - tu gracz oddaje plecak i dostaje kaucję.

var _ekran: MeshInstance3D
var _material_ekranu: StandardMaterial3D

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")   # bicie automatu: nie zalecane, ale możliwe
	add_to_group("cel_nawigacji")
	_zbuduj_bryle()

## Identyfikator dla strzałki nawigacji (patrz ui/nawigacja.gd).
func nazwa_celu() -> String:
	return "butelkomat"

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

func podpowiedz() -> String:
	if _zapchany:
		return "E - KOPNIJ zapchany butelkomat"
	var butelki := Game.ile_w_plecaku("kaucja")
	if butelki == 0:
		if Game.ile_w_plecaku("zlom") > 0:
			return "Butelkomat nie bierze złomu - to na skup do Zdziśka"
		return "Butelkomat - plecak pusty"
	return "E - oddaj butelki (%d szt.)" % butelki

var _liczy := false      # blokada podwójnego uruchomienia "bębnów"
var _zapchany := false   # czasem się zapycha - celowo wnerwia

func interakcja(_gracz: Node3D) -> void:
	if _liczy:
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
	# Losowe zapchanie - bo prawdziwy butelkomat też tak robi
	if randf() < Balans.SZANSA_ZAPCHANIA:
		_zapchany = true
		Sfx.graj("blad")
		Game.pokaz_komunikat("BUTELKOMAT ZAPCHANY! Ktoś wepchnął słoik po ogórkach. Kopnij go (E).")
		_ustaw_kolor_ekranu(Color(1, 0.2, 0.2))
		return
	# Jednoręki bandyta: kasa nalicza się od razu, ale dźwięk i komunikat
	# celebrują wygraną - seria cyknięć przyspiesza aż do "jackpotu"
	_liczy = true
	var wynik: Dictionary = Game.oddaj_wszystko()
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
