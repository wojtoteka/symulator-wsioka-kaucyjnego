class_name Bryly
extends RefCounted
## PODSTAWOWE KLOCKI ŚWIATA - wspólna baza budowniczych osiedla.
##
## Cały świat powstaje z pudełek i walców. Zamiast przepisywać te dziesięć
## linijek w każdym pliku, budowniczowie (SwiatBudynki, SwiatZielen, SwiatNpc)
## dziedziczą po tej klasie i wołają pudlo() / walec() / przeszkoda().
##
## Użycie:
##     var budynki := SwiatBudynki.new(self)   # "self" to węzeł świata
##     budynki.zbuduj()
##
## Wszystko, co powstaje, ląduje jako dziecko węzła przekazanego w _init.

## Węzeł, do którego trafiają zbudowane bryły (zwykle scena świata).
var swiat: Node3D

func _init(rodzic: Node3D) -> void:
	swiat = rodzic

## Materiał świata - cały styl (toon, nasycenie, kontur) siedzi w Styl.
## Domyślnie BEZ konturu - bo tę funkcję wołają też płaskie detale
## (pasy na jezdni, linie parkingowe), którym obwódka zjadłaby całą bryłę.
## Kontur dokładają pudlo() i walec(), które znają wymiary obiektu.
func material(kolor: Color, emisja := false, kontur := 0.0) -> StandardMaterial3D:
	return Styl.bryla(kolor, kontur, emisja)

## Pudełko: z kolizją (StaticBody3D) albo czysto wizualne (MeshInstance3D).
## "mat" pozwala podstawić gotowy materiał (np. teren z szumem)
## zamiast płaskiego koloru.
func pudlo(pozycja: Vector3, rozmiar: Vector3, kolor: Color, kolizja := true,
		emisja := false, mat: StandardMaterial3D = null) -> Node3D:
	var mesh := MeshInstance3D.new()
	var ksztalt_pudla := BoxMesh.new()
	ksztalt_pudla.size = rozmiar
	mesh.mesh = ksztalt_pudla
	mesh.material_override = mat if mat != null \
		else material(kolor, emisja, Styl.kontur_dla(rozmiar))
	if not kolizja:
		mesh.position = pozycja
		swiat.add_child(mesh)
		return mesh
	var cialo := StaticBody3D.new()
	cialo.position = pozycja
	cialo.add_child(mesh)
	var ksztalt_kolizji := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = rozmiar
	ksztalt_kolizji.shape = ksztalt
	cialo.add_child(ksztalt_kolizji)
	swiat.add_child(cialo)
	return cialo

## Walec (słupek latarni, filar altanki, beczka).
## Domyślnie Z KOLIZJĄ - wcześniej walce były czysto wizualne i dało się
## przejść na wylot przez latarnię czy filar, co od razu psuło wrażenie
## realnego miejsca. "kolizja = false" zostaje dla drobiazgów na dachu
## (anteny) i tam, gdzie ciało fizyczne dokłada się osobno (pnie drzew).
func walec(pozycja: Vector3, promien: float, wysokosc: float, kolor: Color,
		emisja := false, kolizja := true, metaliczny := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var ksztalt_walca := CylinderMesh.new()
	ksztalt_walca.top_radius = promien
	ksztalt_walca.bottom_radius = promien
	ksztalt_walca.height = wysokosc
	mesh.mesh = ksztalt_walca
	var kreska := Styl.kontur_dla(Vector3(promien * 2.0, wysokosc, promien * 2.0))
	mesh.material_override = Styl.metal(kolor, kreska) if metaliczny \
		else material(kolor, emisja, kreska)
	mesh.position = pozycja
	swiat.add_child(mesh)
	if kolizja:
		var cialo := StaticBody3D.new()
		cialo.position = pozycja
		var ksztalt_kolizji := CollisionShape3D.new()
		var ksztalt := CylinderShape3D.new()
		ksztalt.radius = promien
		ksztalt.height = wysokosc
		ksztalt_kolizji.shape = ksztalt
		cialo.add_child(ksztalt_kolizji)
		swiat.add_child(cialo)
	return mesh

## Niewidzialna przeszkoda - dla obiektów, których bryła jest zbyt
## poszarpana, żeby opisać ją kształtem 1:1 (płotki ze sztachet, sterty).
func przeszkoda(pozycja: Vector3, rozmiar: Vector3) -> StaticBody3D:
	var cialo := StaticBody3D.new()
	cialo.position = pozycja
	var kolizja := CollisionShape3D.new()
	var ksztalt := BoxShape3D.new()
	ksztalt.size = rozmiar
	kolizja.shape = ksztalt
	cialo.add_child(kolizja)
	swiat.add_child(cialo)
	return cialo

## Składa zebrane transformacje w jeden MultiMeshInstance3D.
## Zamiast setek osobnych węzłów (i setek wywołań rysowania) mamy JEDEN
## obiekt na wszystkie sztachety wszystkich działek. "znikaj_od" to LOD:
## z większej odległości drobiazg przestaje się rysować.
func multi(mesh: Mesh, transformy: Array, kolory: Array, znikaj_od := 0.0) -> MultiMeshInstance3D:
	var siatka := MultiMesh.new()
	siatka.transform_format = MultiMesh.TRANSFORM_3D
	siatka.use_colors = true
	siatka.mesh = mesh
	siatka.instance_count = transformy.size()
	for i in transformy.size():
		siatka.set_instance_transform(i, transformy[i])
		siatka.set_instance_color(i, kolory[i])
	var wezel := MultiMeshInstance3D.new()
	wezel.multimesh = siatka
	# Materiał musi czytać kolor instancji, inaczej wszystko byłoby białe
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	wezel.material_override = mat
	if znikaj_od > 0.0:
		wezel.visibility_range_end = znikaj_od
		wezel.visibility_range_end_margin = 6.0
		wezel.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	swiat.add_child(wezel)
	return wezel
