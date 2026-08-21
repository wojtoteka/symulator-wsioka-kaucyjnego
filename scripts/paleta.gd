class_name Paleta
## PALETA KOLORÓW - spójny, lekko nasycony low-poly look
## "polskiego osiedla o złotej godzinie". Jedno źródło prawdy:
## zmiana tutaj przemalowuje całą scenę.

# --- Teren ---
# Zieleń jest ciemniejsza i cieplejsza niż intuicja podpowiada: przy
# post-processie (saturacja 1.25) jasna zieleń robi się neonowa i zjada
# kontrast z postaciami.
const TRAWA := Color(0.28, 0.5, 0.2)
const TRAWA_CIEMNA := Color(0.22, 0.42, 0.16)
const TRAWA_JASNA := Color(0.34, 0.57, 0.24)
const CHODNIK := Color(0.6, 0.58, 0.54)      # ciemniej niż kiedyś, inaczej świeci bielą
const ASFALT := Color(0.26, 0.27, 0.31)
const LINIA := Color(0.88, 0.88, 0.84)
const KAMIEN := Color(0.44, 0.43, 0.41)

# --- Architektura ---
# Bloki z wielkiej płyty po "termomodernizacji" - brudny beż jako baza,
# a charakteru dodają kolorowe elewacje (PASTELE) losowane per blok.
const BLOK := Color(0.66, 0.62, 0.55)
const OKNO_CIEMNE := Color(0.14, 0.21, 0.32)
const OKNO_JASNE := Color(1.0, 0.9, 0.55)
const PASTELE: Array[Color] = [
	Color(0.93, 0.72, 0.28),   # musztardowy
	Color(0.4, 0.66, 0.82),    # blady błękit
	Color(0.85, 0.5, 0.35),    # łososiowy
	Color(0.55, 0.7, 0.45),    # seledyn
]
const BIEDRONKA_SCIANA := Color(0.93, 0.9, 0.83)
const CZERWIEN := Color(0.8, 0.12, 0.12)   # logo Biedronki, czapka, akcenty
const SZKLO_DRZWI := Color(0.14, 0.2, 0.26)

# --- Zieleń ---
const PIEN := Color(0.45, 0.3, 0.16)
const KORONY: Array[Color] = [
	Color(0.2, 0.45, 0.18), Color(0.25, 0.52, 0.2), Color(0.3, 0.58, 0.24),
]
const KRZAK := Color(0.22, 0.48, 0.2)

# --- Mała architektura ---
const DREWNO := Color(0.52, 0.36, 0.2)
const DREWNO_CIEMNE := Color(0.32, 0.2, 0.1)
const METAL := Color(0.3, 0.3, 0.33)
const METAL_JASNY := Color(0.71, 0.73, 0.77)
const PLOT := Color(0.36, 0.46, 0.4)
const KONTENER := Color(0.15, 0.46, 0.2)
const KONTENER_KLAPA := Color(0.11, 0.36, 0.15)
const KOSZ := Color(0.26, 0.26, 0.29)
const TRZEPAK := Color(0.52, 0.16, 0.15)
const LATARNIA_KLOSZ := Color(1.0, 0.95, 0.72)

# --- Postacie ---
const DRES := Color(0.15, 0.2, 0.46)
const DRES_NOGAWKI := Color(0.12, 0.16, 0.38)
const SKORA := Color(0.9, 0.72, 0.58)
const ADIDAS := Color(0.95, 0.95, 0.95)
const PLECAK := Color(0.46, 0.31, 0.15)

# --- UI ---
const UI_TLO := Color(0.05, 0.08, 0.12, 0.92)
const UI_PANEL := Color(0.05, 0.08, 0.12, 0.6)
const UI_ZLOTY := Color(1.0, 0.85, 0.25)
const UI_ZIELONY := Color(0.6, 1.0, 0.6)
const UI_CZERWONY := Color(1.0, 0.4, 0.4)
