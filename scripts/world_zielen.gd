class_name SwiatZielen
extends Bryly
## BUDOWNICZY ZIELENI I DROBIAZGÓW - wszystko, co rośnie albo leży:
## drzewa, krzaki, łaty trawy, kamienie do potykania, chmury nad osiedlem.
##
## Wołane raz z world.gd:  SwiatZielen.new(self).zbuduj()
##
## drzewo() jest publiczne, bo działki (SwiatBudynki) sadzą własne
## drzewka owocowe tym samym kodem.

const ILE_KAMIENI := Balans.ILE_KAMIENI

func zbuduj() -> void:
	_zielen()
	_kamienie()
	_chmury()

## Zieleń: drzewa, krzaki i łaty trawy - osiedle przestaje być gołe.
func _zielen() -> void:
	# Drzewa rozstawione po obrzeżach i między blokami.
	# Uwaga: wszystkie muszą omijać pas jezdni (x od ±27 do ±33) - wcześniej
	# pięć z nich rosło dokładnie na obwodnicy, a jedno w środku małego bloku.
	for pozycja in [
		Vector3(-25, 0, 16), Vector3(-36, 0, 4), Vector3(-36, 0, -8), Vector3(-25, 0, -18),
		Vector3(25, 0, 18), Vector3(36, 0, 6), Vector3(25, 0, -6), Vector3(36, 0, -16),
		Vector3(-26, 0, 26), Vector3(26, 0, 28), Vector3(-8, 0, 30), Vector3(10, 0, 32),
		Vector3(-24, 0, -24), Vector3(24, 0, -22), Vector3(6, 0, 26), Vector3(-4.5, 0, 25),
	]:
		drzewo(pozycja)
	# Krzaki pod blokami i przy Biedronce (odsunięte od ścian, bo balkony
	# wychodzą 1,1 m poza elewację)
	for pozycja in [
		Vector3(-13.5, 0, 16), Vector3(-13.5, 0, 0), Vector3(13.5, 0, 16), Vector3(13.5, 0, 1),
		Vector3(-12.5, 0, -26), Vector3(12.5, 0, -26.5), Vector3(4, 0, 20), Vector3(-4, 0, 14),
		Vector3(-12.5, 0, 16.5), Vector3(11, 0, 22),
	]:
		krzak(pozycja)
	# Łaty ciemniejszej trawy - łamią jednolitą zieleń trawnika
	for i in 16:
		var laty := MeshInstance3D.new()
		var plyta := BoxMesh.new()
		plyta.size = Vector3(randf_range(1.5, 3.5), 0.02, randf_range(1.5, 3.5))
		laty.mesh = plyta
		laty.material_override = material(Paleta.TRAWA_CIEMNA if randf() < 0.5 else Paleta.TRAWA_JASNA)
		laty.position = Vector3(
			signf(randf() - 0.5) * randf_range(3.5, 26.0), 0.012, randf_range(-26.0, 30.0)
		)
		swiat.add_child(laty)

func drzewo(pozycja: Vector3) -> void:
	var skala := randf_range(0.85, 1.3)
	# Pień - kolizję dokładamy niżej osobno (szerszą niż sam pień, żeby
	# gracz nie wchodził twarzą w koronę), więc walec zostaje wizualny
	walec(pozycja + Vector3(0, 1.1 * skala, 0), 0.18 * skala, 2.2 * skala, Paleta.PIEN, false, false)
	var cialo := StaticBody3D.new()
	cialo.add_to_group("drzewo")   # test [9] sprawdza, gdzie stoją drzewa
	cialo.position = pozycja + Vector3(0, 1.1 * skala, 0)
	var kolizja := CollisionShape3D.new()
	var ksztalt := CylinderShape3D.new()
	ksztalt.radius = 0.2 * skala
	ksztalt.height = 2.2 * skala
	kolizja.shape = ksztalt
	cialo.add_child(kolizja)
	swiat.add_child(cialo)
	# Korona - trzy zielone kule w różnych odcieniach
	for dane in [
		[Vector3(0, 2.7, 0), 0.95, Paleta.KORONY[0]],
		[Vector3(0.5, 2.3, 0.3), 0.7, Paleta.KORONY[1]],
		[Vector3(-0.45, 2.4, -0.25), 0.65, Paleta.KORONY[2]],
	]:
		var kula_mesh := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = dane[1] * skala
		kula.height = dane[1] * 2.0 * skala
		kula_mesh.mesh = kula
		# Odcień per kula, nie per gatunek - inaczej wszystkie drzewa na mapie
		# mają dokładnie te same trzy zielenie i widać, że to jeden prefab
		kula_mesh.material_override = material(Styl.wariant(dane[2], 0.08), false, Styl.KONTUR_OBIEKT)
		kula_mesh.position = pozycja + dane[0] * skala
		kula_mesh.rotation.y = randf() * TAU
		swiat.add_child(kula_mesh)
	# Korona zatrzymuje WYŁĄCZNIE wysięgnik kamery (patrz Balans.WARSTWA_KAMERY).
	# Gracz przez liście nadal przechodzi - blokuje go tylko pień - ale kamera
	# TPP nie wjeżdża już w środek korony, gdzie widać sam czarny kontur.
	var korona := StaticBody3D.new()
	korona.collision_layer = Balans.WARSTWA_KAMERY
	korona.collision_mask = 0
	korona.position = pozycja + Vector3(0, 2.55 * skala, 0)
	var oslona := CollisionShape3D.new()
	var kula_oslony := SphereShape3D.new()
	kula_oslony.radius = 1.15 * skala
	oslona.shape = kula_oslony
	korona.add_child(oslona)
	swiat.add_child(korona)

func krzak(pozycja: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = randf_range(0.5, 0.8)
	kula.height = kula.radius * 1.3
	mesh.mesh = kula
	# Każdy krzak w swoim odcieniu - rząd identycznych zielonych kul
	# natychmiast zdradza, że to kopie jednego obiektu
	mesh.material_override = material(Styl.wariant(Paleta.KRZAK, 0.09), false, Styl.KONTUR_OBIEKT)
	mesh.position = pozycja + Vector3(0, kula.height * 0.35, 0)
	mesh.rotation.y = randf() * TAU
	swiat.add_child(mesh)
	# Krzak jest przeszkodą - niższą niż wygląda, żeby dało się go przeskoczyć
	przeszkoda(pozycja + Vector3(0, kula.radius * 0.5, 0),
		Vector3(kula.radius * 1.6, kula.radius, kula.radius * 1.6)).add_to_group("krzak")

## Kamienie na trawnikach - sprint po nich kończy się glebą.
func _kamienie() -> void:
	for i in ILE_KAMIENI:
		# Nie kładziemy kamieni na chodniku ani przy spawnie gracza
		var pozycja := Vector3(randf_range(-13, 13), 0, randf_range(-24, 18))
		if absf(pozycja.x) < 2.5 or pozycja.distance_to(Vector3(0, 0, 22)) < 5.0:
			pozycja.x = signf(pozycja.x) * randf_range(3.5, 13.0)
		# Widoczny kamień (spłaszczona kula)
		var kamien := MeshInstance3D.new()
		var kula := SphereMesh.new()
		kula.radius = randf_range(0.2, 0.35)
		kula.height = kula.radius
		kamien.mesh = kula
		kamien.material_override = material(Paleta.KAMIEN, false, Styl.KONTUR_OBIEKT)
		kamien.position = pozycja
		kamien.rotation.y = randf() * TAU
		swiat.add_child(kamien)
		# Strefa potknięcia (Area3D w grupie "przeszkoda")
		var strefa := Area3D.new()
		strefa.add_to_group("przeszkoda")
		var ksztalt := CollisionShape3D.new()
		var kula_strefy := SphereShape3D.new()
		kula_strefy.radius = 0.45
		ksztalt.shape = kula_strefy
		strefa.add_child(ksztalt)
		strefa.position = pozycja + Vector3(0, 0.2, 0)
		swiat.add_child(strefa)

## Kreskówkowe chmury sunące po niebie. Zbierane do listy, bo PoraDnia
## przemalowuje je razem z niebem (o zachodzie robią się różowe).
func _chmury() -> void:
	for i in 7:
		var chmura := Node3D.new()
		chmura.add_to_group("chmura")
		chmura.position = Vector3(randf_range(-40, 40), randf_range(22, 32), randf_range(-40, 40))
		swiat.add_child(chmura)
		for j in 3:
			var klab := MeshInstance3D.new()
			var kula := SphereMesh.new()
			kula.radius = randf_range(1.8, 3.2)
			kula.height = kula.radius * 1.2
			klab.mesh = kula
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1, 1, 1, 0.95)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			klab.material_override = mat
			klab.position = Vector3(j * 2.4 - 2.4, randf_range(-0.4, 0.4), randf_range(-1, 1))
			chmura.add_child(klab)
		# Powolny dryf tam i z powrotem
		var tw := chmura.create_tween().set_loops()
		tw.tween_property(chmura, "position:x", chmura.position.x + 18.0, randf_range(35.0, 55.0))
		tw.tween_property(chmura, "position:x", chmura.position.x, randf_range(35.0, 55.0))
