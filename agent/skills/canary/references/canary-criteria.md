# Canary-Kriterien

Referenz für `canary-evaluator` — was gilt als unauffälliger Canary-Verlauf.

## Bewertungs-Kategorien

### 1. Zeitfenster (window)

| Zustand | Bewertung |
|---------|-----------|
| < 25 % des Fensters verstrichen | `extend` — zu früh für Entscheidung |
| 25–99 % verstrichen, keine Alarme | `promote` (confidence je nach Events) |
| 100 % verstrichen, keine Alarme | `promote` mit hoher Confidence |
| Fenster abgelaufen + Alarme | Alarm-Regel entscheidet |

Standardfenster: 24 h (`rollout-policy.yaml: window_hours`)

### 2. Trigger-Events

| Anzahl binnen Fenster | Bewertung |
|-----------------------|-----------|
| 0 | Kein Malus |
| 1–4 | Schwach negativ; confidence−10 |
| ≥ 5 (`max_triggers_per_day`) | `fail` |

Erkannte Audit-Actions: `TRIGGER`, `ERROR`, `FAIL`

### 3. Severity-Events

| Event-Typ | Bewertung |
|-----------|-----------|
| `EXTREME` | Sofort `fail` (policy: `require_no_high_or_extreme_events`) |
| `HIGH` | Sofort `fail` |
| `MEDIUM` | Confidence−15, aber kein Auto-Fail |
| `LOW` | Kein Malus |

### 4. Konflikt-Events

| Event-Typ | Bewertung |
|-----------|-----------|
| `CONFLICT` | `fail` (policy: `require_no_trigger_conflict`) |

## Confidence-Gewichtung

| Faktor | Confidence-Effekt |
|--------|-------------------|
| Kein Alarm-Event, Fenster ≥ 50 % | Basis 85 |
| Fenster 25–49 % | Basis 75 |
| Fenster < 25 % | Basis 60 → extend |
| Audit-Log fehlt | Malus −35 |
| MEDIUM-Events | Malus −15 |
| Nur Trigger 1–4 | Malus −10 |

## Beispiel-Urteile

| Situation | Recommendation | Confidence | Verdict |
|-----------|---------------|------------|---------|
| 20 h von 24 h, 0 Events | promote | 90 | Go |
| 4 h von 24 h, 0 Events | extend | 70 | Extend |
| 10 h von 24 h, 5 TRIGGER | fail | 88 | No-Go |
| 10 h von 24 h, 1 ERROR | promote | 75 | Go |
| 10 h von 24 h, 1 HIGH | fail | 95 | No-Go |
| kein Audit-Log | extend | 50 | Extend |
