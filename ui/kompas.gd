class_name Kompas
## PRZELICZANIE ŚWIATA NA EKRAN — wspólne dla radaru i strzałki nawigacji.
##
## Oba elementy pokazują to samo ("gdzie to jest względem tego, jak stoję"),
## więc muszą liczyć to jednym wzorem. Gdy każdy liczył po swojemu, radar
## wychodził odwrócony: idąc w stronę celu widziało się kropkę uciekającą
## w przeciwną stronę tarczy.
##
## Układ: w Godocie postać patrzy wzdłuż WŁASNEJ osi -Z, a ekran ma Y
## skierowane W DÓŁ. Dlatego "przód" musi wyjść jako UJEMNY Y.

## Pozycja obiektu w układzie ekranu względem gracza.
## Zwraca metry: x = w prawo od gracza, y = do przodu (ujemny = przed graczem).
static func na_ekran(roznica: Vector3, yaw: float) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(
		roznica.x * c - roznica.z * s,   # w bok
		roznica.x * s + roznica.z * c,   # w głąb (ujemny = przed nami)
	)

## Kąt, o jaki obrócić strzałkę rysowaną domyślnie czubkiem do góry,
## żeby wskazała dany punkt.
static func kat_strzalki(roznica: Vector3, yaw: float) -> float:
	var kierunek := na_ekran(roznica, yaw)
	return atan2(kierunek.x, -kierunek.y)
