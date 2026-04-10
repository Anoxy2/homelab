# THRESHOLDS.md – Alarmgrenzen und Zielwerte Growbox

_Alarmgrenzen, Schwellwerte und Zielwerte für Growbox-Temperatur und Luftfeuchtigkeit je Phase (Blütephase, Vegetationsphase, Nacht). Agent liest diese Werte für Alarme und Empfehlungen._

## Temperatur

| Phase       | Optimal   | Warnung   | Kritisch  |
|-------------|-----------|-----------|-----------|
| Vegetation  | 22–28 °C  | <20 / >30 | <18 / >35 |
| Blüte       | 20–26 °C  | <18 / >28 | <16 / >32 |
| Nacht       | 18–22 °C  | <15 / >25 | <12 / >28 |

## Luftfeuchtigkeit (RH)

| Phase       | Optimal   | Warnung      | Kritisch     |
|-------------|-----------|--------------|--------------|
| Keimung     | 70–80 %   | <60 / >85    | <50 / >90    |
| Vegetation  | 50–70 %   | <40 / >75    | <35 / >80    |
| Blüte       | 40–55 %   | <35 / >60    | <30 / >65    |
| Spätblüte   | 35–45 %   | <30 / >50    | <25 / >55    |

## VPD (Vapor Pressure Deficit)

| Phase       | Optimal (kPa) |
|-------------|---------------|
| Keimung     | 0.4–0.8       |
| Vegetation  | 0.8–1.2       |
| Blüte       | 1.0–1.5       |
| Spätblüte   | 1.2–1.6       |

## Lüfter (ESP32 Betriebsmodus)

- **Auto (Temperatur):** Temp-gesteuert, 30–100 % linear (22–35 °C)
- **Nacht:** Feste 30 % (konfigurierbar via `g_nacht_speed` Global)
- **Manuell:** Master-Schieberegler 0–100 %

## Aktuelle Betriebswerte (anpassen!)
- Nacht-Drehzahl: 30 %
- Auto Temp-Min: 22 °C → Min-Drehzahl: 30 %
- Auto Temp-Max: 35 °C → Max-Drehzahl: 100 %
