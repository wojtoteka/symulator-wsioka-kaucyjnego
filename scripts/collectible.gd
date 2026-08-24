extends Area3D
## PRZEDMIOT DO ZEBRANIA - butelka plastikowa, szklana, puszka,
## ZŁOTA butelka albo ZŁOTA PUSZKA (bardzo rzadka, 5 zł!).
## Tworzony w kodzie przez world.gd i trash_bin.gd:
##   var c = preload("res://scripts/collectible.gd").new()
##   c.typ = c.losowy_typ(); c.position = ...; add_child(c)

enum Typ {
	PLASTIK, SZKLO, PUSZKA, ZLOTA, ZLOTA_PUSZKA,
	KABEL, BLACHA, FELGA, AKUMULATOR,   # ZŁOM - oddawany na skupie u Zdziśka
}

## Dane typów: nazwa, wartość (zł), kolor bryły, kategoria i zajmowane miejsca.
## kategoria "kaucja" -> butelkomat przy Biedronce
## kategoria "zlom"   -> Skup Złomu (czynny do godziny zamknięcia!)
const DANE := {
	Typ.PLASTIK:      {"nazwa": "butelka plastikowa", "kaucja": Balans.KAUCJA_PLASTIK, "kolor": Color(0.3, 0.75, 0.9, 1.0)},
	Typ.SZKLO:        {"nazwa": "butelka szklana",    "kaucja": Balans.KAUCJA_SZKLO, "kolor": Color(0.25, 0.5, 0.2)},
	Typ.PUSZKA:       {"nazwa": "puszka",             "kaucja": Balans.KAUCJA_PUSZKA, "kolor": Color(0.75, 0.78, 0.8)},
	Typ.ZLOTA:        {"nazwa": "ZŁOTA butelka po piwie", "kaucja": Balans.KAUCJA_ZLOTA_BUTELKA, "kolor": Color(1.0, 0.84, 0.1)},
	Typ.ZLOTA_PUSZKA: {"nazwa": "ZŁOTA PUSZKA",       "kaucja": Balans.KAUCJA_ZLOTA_PUSZKA, "kolor": Color(1.0, 0.7, 0.05)},
	Typ.KABEL:        {"nazwa": "zwój kabla (miedź!)", "kaucja": Balans.CENA_ZLOMU_KABEL, "kolor": Color(0.72, 0.4, 0.15), "kategoria": "zlom"},
	Typ.BLACHA:       {"nazwa": "kawał blachy",       "kaucja": Balans.CENA_ZLOMU_BLACHA, "kolor": Color(0.55, 0.57, 0.6), "kategoria": "zlom"},
	Typ.FELGA:        {"nazwa": "felga stalowa",      "kaucja": Balans.CENA_ZLOMU_FELGA, "kolor": Color(0.62, 0.63, 0.66), "kategoria": "zlom", "miejsca": Balans.MIEJSCA_FELGA},
	Typ.AKUMULATOR:   {"nazwa": "AKUMULATOR",         "kaucja": Balans.CENA_ZLOMU_AKUMULATOR, "kolor": Color(0.14, 0.16, 0.2), "kategoria": "zlom", "miejsca": Balans.MIEJSCA_AKUMULATOR},
}

## Kategoria typu: "kaucja" (butelkomat) albo "zlom" (skup).
static func kategoria(t: Typ) -> String:
	return DANE[t].get("kategoria", "kaucja")

## Ile slotów plecaka zajmuje dany fant (akumulator aż 4).
static func miejsca(t: Typ) -> int:
	return DANE[t].get("miejsca", 1)

var typ: Typ = Typ.PLASTIK
var _mesh: MeshInstance3D
var _zebrane := false   # blokada podwójnego zebrania (gracz vs konkurent)

## Czy typ jest "złoty" (fanfara, bonusy).
static func czy_zloty(t: Typ) -> bool:
	return t == Typ.ZLOTA or t == Typ.ZLOTA_PUSZKA

## Ile ten fant jest dziś wart w złotówkach - BEZ combo i trybu wsioka,
## czyli sama cena z cennika plus promocje dnia (czwartek = akumulatory).
## Pyta o to Heniek, żeby wiedzieć, ile ci właśnie zwinął.
func wartosc() -> float:
	return float(DANE[typ]["kaucja"]) * (
		Game.mnoznik_akumulatora() if typ == Typ.AKUMULATOR else 1.0
	)

## Losowanie typu z wagami (progi w scripts/balans.gd).
## "szczescie" > 1.0 (Czapka szczęścia) zwiększa szansę na złote fanty.
static func losowy_typ(szczescie := 1.0) -> Typ:
	var los := randf()
	if los < Balans.PROG_ZLOTA_PUSZKA * szczescie:
		return Typ.ZLOTA_PUSZKA
	elif los < Balans.PROG_ZLOTA_BUTELKA * szczescie:
		return Typ.ZLOTA
	elif los < Balans.PROG_PUSZKA:
		return Typ.PUSZKA
	elif los < Balans.PROG_SZKLO:
		return Typ.SZKLO
	return Typ.PLASTIK

## Losowanie kawałka złomu - akumulatory rzadkie, blacha pospolita.
static func losowy_typ_zlomu() -> Typ:
	var los := randf()
	if los < 0.08:
		return Typ.AKUMULATOR
	elif los < 0.28:
		return Typ.FELGA
	elif los < 0.58:
		return Typ.KABEL
	return Typ.BLACHA

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("kolekcjonerskie")   # po tej grupie szuka konkurent i wózek
	# Kolizja - kula, którą wykrywa zasięg gracza
	var ksztalt := CollisionShape3D.new()
	var kula := SphereShape3D.new()
	kula.radius = 0.5
	ksztalt.shape = kula
	ksztalt.position = Vector3(0, 0.3, 0)
	add_child(ksztalt)
	_zbuduj_bryle()
	# Powolny obrót, żeby przedmioty rzucały się w oczy (złote wirują szybciej)
	var tw := create_tween().set_loops()
	tw.tween_property(_mesh, "rotation:y", TAU, 1.5 if czy_zloty(typ) else 4.0).from(0.0)

func _zbuduj_bryle() -> void:
	_mesh = MeshInstance3D.new()
	var wysokosc := 0.5   # do ustawienia bryły na ziemi
	match typ:
		Typ.KABEL:
			# Zwój kabla - torus leżący płasko
			var torus := TorusMesh.new()
			torus.inner_radius = 0.1
			torus.outer_radius = 0.22
			_mesh.mesh = torus
			_mesh.rotation.x = PI / 2
			wysokosc = 0.24
		Typ.BLACHA:
			# Pognieciony kawał blachy - płaska płyta pod kątem
			var plyta := BoxMesh.new()
			plyta.size = Vector3(0.55, 0.06, 0.4)
			_mesh.mesh = plyta
			_mesh.rotation.z = 0.15
			wysokosc = 0.12
		Typ.FELGA:
			# Felga - gruby torus na sztorc
			var torus := TorusMesh.new()
			torus.inner_radius = 0.13
			torus.outer_radius = 0.3
			torus.ring_segments = 12
			_mesh.mesh = torus
			wysokosc = 0.6
		Typ.AKUMULATOR:
			# Akumulator - solidne czarne pudło
			var pudlo := BoxMesh.new()
			pudlo.size = Vector3(0.42, 0.34, 0.26)
			_mesh.mesh = pudlo
			wysokosc = 0.34
		_:
			var walec := CylinderMesh.new()
			match typ:
				Typ.PUSZKA, Typ.ZLOTA_PUSZKA:
					walec.top_radius = 0.09
					walec.bottom_radius = 0.09
					walec.height = 0.24
				Typ.SZKLO:
					walec.top_radius = 0.05
					walec.bottom_radius = 0.11
					walec.height = 0.42
				_:  # plastik i złota - kształt butelki 0,5 l
					walec.top_radius = 0.045
					walec.bottom_radius = 0.1
					walec.height = 0.5
			_mesh.mesh = walec
			wysokosc = walec.height
	# Fanty dostają najgrubszy kontur w grze - to ich gracz szuka wzrokiem,
	# więc muszą odcinać się od trawy i asfaltu nawet z drugiego końca mapy
	var mat := Styl.bryla(DANE[typ]["kolor"], Styl.KONTUR_POSTAC, czy_zloty(typ), true)
	if czy_zloty(typ):
		# Złote fanty świecą - mają się rzucać w oczy z daleka
		mat.emission = Color(1.0, 0.75, 0.1)
		mat.emission_energy_multiplier = 1.8 if typ == Typ.ZLOTA_PUSZKA else 1.4
		mat.metallic = 0.8
		mat.roughness = 0.2
	elif kategoria(typ) == "zlom":
		# Złom ma być brudno-metaliczny, nie błyszczący jak nowy
		mat.metallic = 0.55
		mat.roughness = 0.65
	_mesh.material_override = mat
	_mesh.position = Vector3(0, wysokosc / 2.0 + 0.02, 0)
	add_child(_mesh)

## Tekst podpowiedzi nad HUD (wywoływane przez gracza).
func podpowiedz() -> String:
	if kategoria(typ) == "zlom":
		var slot := miejsca(typ)
		var promocja := "" if is_equal_approx(wartosc(), float(DANE[typ]["kaucja"])) \
			else " PROMOCJA!"
		return "E - podnieś: %s (skup: %s%s%s)" % [
			DANE[typ]["nazwa"], Game.zl(wartosc()),
			", %d miejsca" % slot if slot > 1 else "", promocja,
		]
	return "E - podnieś: %s (+%s)" % [DANE[typ]["nazwa"], Game.zl(DANE[typ]["kaucja"])]

## Podniesienie przedmiotu (wywoływane przez gracza po E lub najechaniu wózkiem).
func interakcja(_gracz: Node3D) -> void:
	if _zebrane:
		return
	var dane: Dictionary = DANE[typ].duplicate()
	dane["kategoria"] = kategoria(typ)
	dane["miejsca"] = miejsca(typ)
	# Cena z uwzględnieniem promocji dnia (czwartek = akumulatory u Zdziśka)
	dane["kaucja"] = wartosc()
	# Złote fanty mocniej pompują Wsiokometr
	var wynik: Dictionary = Game.podnies_przedmiot(
		dane, Balans.WSIOKOMETR_ZLOTO if czy_zloty(typ) else Balans.WSIOKOMETR_BUTELKA
	)
	if not wynik["ok"]:
		Sfx.graj("blad")  # plecak pełny
		return
	_zebrane = true
	# Zgłoszenie do systemu zleceń - pasujące zlecenie samo złapie swoje
	# zdarzenie, reszta zgłoszeń jest po prostu ignorowana.
	if kategoria(typ) == "zlom":
		Game.postep_zlecenia("zebrano_zlom")
	else:
		Game.postep_zlecenia("zebrano_kaucja")
		match typ:
			Typ.SZKLO: Game.postep_zlecenia("zebrano_szklo")
			Typ.PUSZKA, Typ.ZLOTA_PUSZKA: Game.postep_zlecenia("zebrano_puszka")
		if czy_zloty(typ):
			Game.postep_zlecenia("zebrano_zloty")
	Sfx.graj_okrzyk()   # losowe "hop!" wsioka
	# Iskierki przy podnoszeniu (złote fanty sypią złotem)
	Efekty.blysk(get_parent(), global_position + Vector3(0, 0.3, 0),
		Color(1.0, 0.85, 0.2) if czy_zloty(typ) else Color(0.7, 1.0, 0.75))
	if czy_zloty(typ):
		Game.wstrzasnij(0.2)   # złoto aż trzęsie ekranem z wrażenia
		Game.postep_wyzwania("zlote")
	if typ == Typ.ZLOTA_PUSZKA:
		Game.statystyki["zlote"] += 1
		Osiagniecia.przyznaj("zlota_puszka")
		Sfx.graj("zlota", 2.0, 1.3)
		Sfx.odpal_klasyk()   # taki fart zasługuje na KLASYKA
		Game.pokaz_komunikat("ZŁOTA PUSZKA! +%s! Taki fart raz na miesiąc!" % Game.zl(wynik["kaucja"]))
	elif typ == Typ.ZLOTA:
		Game.statystyki["zlote"] += 1
		Sfx.graj("zlota")
		Game.pokaz_komunikat("ZŁOTA BUTELKA PO PIWIE! Warta aż %s kaucji!" % Game.zl(wynik["kaucja"]))
	elif kategoria(typ) == "zlom":
		# Złom leci na skup do Zdziśka - butelkomat go nie przyjmie
		Game.statystyki["zlom"] += 1
		Game.postep_wyzwania("zlom")
		Sfx.graj("brzek", -8.0, 1.1)
		if typ == Typ.AKUMULATOR:
			Game.wstrzasnij(0.12)
			Game.pokaz_komunikat("AKUMULATOR! Ciężki jak sumienie sąsiada. Zdzisiek da za niego %s!" % Game.zl(wynik["kaucja"]))
		else:
			Game.pokaz_komunikat("%s - prosto na skup (%s). %s" % [
				DANE[typ]["nazwa"].capitalize(), Game.zl(wynik["kaucja"]),
				["Miedź to pewniak.", "Zdzisiek to weźmie.", "Kilogramy się liczą.", "Złom nie śmierdzi."].pick_random(),
			])
	else:
		# Wysokość "blipa" rośnie z combo - im dłuższa seria, tym wyższy ton
		Sfx.graj("podnies", 0.0, 1.0 + 0.1 * minf(wynik["combo"], 8))
		Game.pokaz_komunikat("%s (+%s) - %s" % [
			dane["nazwa"].capitalize(), Game.zl(wynik["kaucja"]), Game.losowy_tekst_podnoszenia()
		])
	_znikaj()

## Konkurent-wsiok zabiera przedmiot (bez kasy dla gracza).
func zabierz_przez_konkurenta() -> bool:
	if _zebrane:
		return false
	_zebrane = true
	_znikaj()
	return true

## Animacja "pyk" i usunięcie z mapy.
func _znikaj() -> void:
	set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.4, 0.08)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.1)
	tw.tween_callback(queue_free)
