class_name Plan
## PLAN OSIEDLA - jedno źródło prawdy o tym, GDZIE co stoi.
##
## Prostokąty [x_min, x_max, z_min, z_max]. Powstaje z nich asfalt i tor aut,
## a przede wszystkim: sprawdzenie, czy dane miejsce jest wolne.
##
## Dlaczego to musi być DANE, a nie liczby rozsypane po kodzie: gdy pozycje
## drzew, śmietników i jezdni żyją osobno, prędzej czy później drzewo wyrasta
## na środku ulicy, a kontener ląduje w ścianie bloku. Tak właśnie było -
## pięć drzew stało na obwodnicy, jedno w małym bloku, dwa kontenery na
## jezdni, a sama obwodnica przechodziła przez Biedronkę (auta dosłownie
## wyjeżdżały ze sklepu). Teraz pilnuje tego test [9] w autotest.gd.
##
## Plan siedzi w osobnym pliku (a nie w world.gd), bo pytają o niego zarówno
## budowniczowie świata (SwiatBudynki, SwiatZielen, SwiatNpc), jak i testy.
## Gdyby mieszkał w world.gd, każdy z nich musiałby preloadować cały świat.

# Wnętrze Biedronki jest zbudowane POD ZIEMIĄ (niewidoczne z mapy) -
# drzwi teleportują do środka i z powrotem
const WNETRZE := Vector3(60, -50, -60)            # środek podziemnego sklepu
const WEJSCIE_SKLEPU := WNETRZE + Vector3(0, 0.1, 3.2)   # lądowanie w środku
const WYJSCIE_SKLEPU := Vector3(0, 0.1, -25.5)    # lądowanie na osiedlu

## DACHY - miejsca, w których nad głową gracza coś jest. Prostokąty jak wyżej.
##
## Trzymamy je TUTAJ, a nie w skrypcie budynku, bo pytają o nie dwie zupełnie
## różne warstwy: SwiatNpc (gdzie w deszczu chowają się butelki) i Pogoda
## (kiedy przygasić szum deszczu i włączyć bębnienie o blachę). Gdyby każda
## liczyła to sama, po pierwszym przesunięciu daszku jedna z nich by kłamała.
##
## Został JEDEN: podcień nad wejściem do Biedronki. Dwie blaszane wiaty
## (pod małym blokiem i na placu garażowym) postawiono pod dodatkowe
## butelkomaty, a gdy automat wrócił do jednego, zostały tam stać bez powodu.
## Teraz jedyne miejsce, gdzie da się schować przed deszczem, jest dokładnie
## tam, gdzie i tak trzeba dojść z pełnym plecakiem.
const DACHY: Array = [
	[-5.5, 8.5, -28.4, -25.4],    # podcień przed wejściem do Biedronki
]

const JEZDNIE: Array = [
	[-33.0, 33.0, -49.0, -43.0],   # północ - ZA Biedronką, nie przez nią
	[-33.0, 33.0, 35.0, 41.0],     # południe
	[-33.0, -27.0, -49.0, 41.0],   # zachód
	[27.0, 33.0, -49.0, 41.0],     # wschód
]

# Obrysy budynków POWIĘKSZONE o to, co z nich wystaje (balkony sięgają
# 1,1 m poza ścianę) - inaczej "wolne" miejsce okazuje się być pod balkonem.
const BUDYNKI: Array = [
	[-11.0, 11.0, -40.0, -28.0],     # Biedronka
	[-24.0, -14.8, -6.0, 14.0],      # blok lewy (balkony od wschodu)
	[14.8, 24.0, -6.0, 14.0],        # blok prawy (balkony od zachodu)
	[-21.0, -11.0, 20.0, 28.0],      # blok mały na południu
	[44.8, 51.5, -17.5, 17.5],       # garaże
	[-2.6, 2.6, 50.5, 56.5],         # skup złomu u Zdziśka (z wagą z przodu)
]

# Ogródki działkowe. Też muszą być DANYMI, bo płotek to obiekt jak każdy inny:
# przy poprzednim rozstawieniu (co 13 m od x=-33, środek z=46) wszystkie cztery
# wchodziły metrem na jezdnię południową, a skrajne dodatkowo pięcioma metrami
# na jezdnie boczne. Teraz mieszczą się w całości między obwodnicą a płotem,
# a test [9] pilnuje, żeby żadna nie dotknęła asfaltu ani budy Zdziśka.
const DZIALKI_X: Array = [-21.5, -9.5, 9.5, 21.5]
const DZIALKA_Z := 47.5
const DZIALKA_SZEROKOSC := 10.0
const DZIALKA_GLEBOKOSC := 12.0

## Prostokąt jednej działki [x_min, x_max, z_min, z_max].
static func obrys_dzialki(srodek_x: float) -> Array:
	return [
		srodek_x - DZIALKA_SZEROKOSC / 2.0, srodek_x + DZIALKA_SZEROKOSC / 2.0,
		DZIALKA_Z - DZIALKA_GLEBOKOSC / 2.0, DZIALKA_Z + DZIALKA_GLEBOKOSC / 2.0,
	]

## Czy w danym punkcie stoi jezdnia albo budynek - czyli miejsce, w którym
## NIC nie powinno stać. "margines" poszerza strefę: drzewo o koronie metrowej
## nie może rosnąć dokładnie na krawędzi asfaltu, bo i tak będzie nad nim wisieć.
##
## Działki celowo NIE liczą się jako zajęte: w środku ogródka stoi altanka
## i rośnie drzewko owocowe i tak ma być. Do rozrzutu fantów służy osobne
## sprawdzenie niżej, bo tam ogrodzony teren wypada omijać.
## Czy punkt (x, z) jest pod jakimś dachem - patrz DACHY.
static func pod_dachem(x: float, z: float) -> bool:
	for d: Array in DACHY:
		if x >= d[0] and x <= d[1] and z >= d[2] and z <= d[3]:
			return true
	return false

## Środek dachu numer "i" - używane przy rozrzucaniu łupu pod zadaszenie.
static func srodek_dachu(i: int) -> Vector3:
	var d: Array = DACHY[i % DACHY.size()]
	return Vector3((d[0] + d[1]) * 0.5, 0.0, (d[2] + d[3]) * 0.5)

static func czy_zajete(x: float, z: float, margines := 0.0) -> bool:
	return _w_strefach(JEZDNIE + BUDYNKI, x, z, margines)

## Jak wyżej, ale dolicza ogrodzone działki - używane przy losowaniu miejsc
## dla butelek i złomu, żeby łup nie lądował za cudzym płotem.
static func czy_zajete_lub_dzialka(x: float, z: float, margines := 0.0) -> bool:
	if czy_zajete(x, z, margines):
		return true
	for srodek_x in DZIALKI_X:
		if _w_strefach([obrys_dzialki(srodek_x)], x, z, margines):
			return true
	return false

static func _w_strefach(strefy: Array, x: float, z: float, margines: float) -> bool:
	for strefa in strefy:
		if x >= strefa[0] - margines and x <= strefa[1] + margines \
				and z >= strefa[2] - margines and z <= strefa[3] + margines:
			return true
	return false

## Losuje punkt w zadanej strefie [x_min, x_max, z_min, z_max], omijając
## jezdnie, budynki i ogrodzone działki. Ręcznie dobierane strefy zawsze
## w końcu zahaczą o coś, co ktoś później przesunie - tu odrzucamy trafienia
## i losujemy ponownie. Po wyczerpaniu prób oddajemy ostatni punkt: lepiej
## jedna butelka w złym miejscu niż zawieszona gra.
static func losuj_wolne(strefa: Array, proby := 24) -> Vector3:
	var punkt := Vector3.ZERO
	for i in proby:
		punkt = Vector3(randf_range(strefa[0], strefa[1]), 0, randf_range(strefa[2], strefa[3]))
		if not czy_zajete_lub_dzialka(punkt.x, punkt.z, 0.6):
			return punkt
	return punkt
