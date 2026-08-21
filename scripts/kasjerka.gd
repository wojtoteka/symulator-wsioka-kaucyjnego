extends StaticBody3D
## PANI GRAŻYNKA - kasjerka w Biedronce. Można zagadać (E).
## Bicie kasjerki kończy się natychmiastową glebą (ochrona nie śpi).

const TEKSTY: Array[String] = [
	"Kasjerka: \"Znowu pan po piwo?\"",
	"Kasjerka: \"Kaucja to przy butelkomacie, nie u mnie.\"",
	"Kasjerka: \"Promocja na parówki przy trzeciej alejce.\"",
	"Kasjerka: \"Następny!\" (jesteś jedynym klientem)",
	"Kasjerka: \"Reklamówkę? 70 groszy.\"",
]

func _ready() -> void:
	add_to_group("interakcja")
	add_to_group("bijalne")
	_zbuduj_bryle()

## Materiał w stylu gry (toon + kontur) - patrz scripts/styl.gd.
func _material(kolor: Color) -> StandardMaterial3D:
	return Styl.postac(kolor)

func _zbuduj_bryle() -> void:
	# Czerwona kamizelka służbowa
	var cialo := MeshInstance3D.new()
	var kapsula := CapsuleMesh.new()
	kapsula.radius = 0.35
	kapsula.height = 1.15
	cialo.mesh = kapsula
	cialo.material_override = _material(Color(0.75, 0.12, 0.12))
	cialo.position = Vector3(0, 0.75, 0)
	add_child(cialo)
	var glowa := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 0.24
	kula.height = 0.48
	glowa.mesh = kula
	glowa.material_override = _material(Color(0.9, 0.74, 0.6))
	glowa.position = Vector3(0, 1.5, 0)
	add_child(glowa)
	# Kok na głowie (fryzura służbowa)
	var kok := MeshInstance3D.new()
	var kulka := SphereMesh.new()
	kulka.radius = 0.12
	kulka.height = 0.24
	kok.mesh = kulka
	kok.material_override = _material(Color(0.35, 0.25, 0.15))
	kok.position = Vector3(0, 1.75, 0.08)
	add_child(kok)
	# Imię
	var imie := Styl.plakietka("Pani Grażynka", 52, Color(1.0, 0.8, 0.8))
	imie.position = Vector3(0, 2.1, 0)
	add_child(imie)
	# Kolizja
	var kolizja := CollisionShape3D.new()
	var ksztalt := CapsuleShape3D.new()
	ksztalt.radius = 0.4
	ksztalt.height = 1.7
	kolizja.shape = ksztalt
	kolizja.position = Vector3(0, 0.85, 0)
	add_child(kolizja)

func podpowiedz() -> String:
	return "E - zagadaj do kasjerki"

func interakcja(_gracz: Node3D) -> void:
	Game.pokaz_komunikat(TEKSTY.pick_random())

## Podniesienie ręki na Panią Grażynkę = błąd życiowy.
func oberwij(gracz: Node3D) -> void:
	Game.pokaz_komunikat("OCHRONA! Pan Mietek ci przypomniał, gdzie są drzwi. GLEBA.")
	Game.dodaj_wsiokometr(-10.0)
	gracz.gleba()
