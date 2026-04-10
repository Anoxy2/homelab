# Skill-Install Retry-Strategie

## Ziel

Installationen sollen bei transienten Fehlern robust sein, ohne Policy- oder Sicherheitsgates zu umgehen.

## Fehlertypen und Verhalten

1. `network` (timeout, DNS, remote API temporär down)
- Retry erlaubt
- Backoff: 5s -> 15s -> 45s (max 3 Versuche)
- danach: `pending-review` mit Audit-Hinweis

2. `policy` (policy lint fail, contract violation, blacklist/freeze)
- Kein Retry
- Sofort abbrechen
- Betreiber muss Ursache beheben

3. `hash-mismatch` / Integritätsfehler
- Kein automatischer Retry gegen dieselbe Quelle
- Quelle/Version erneut prüfen, dann manueller Neustart mit neuer Referenz

## Operative Regeln

- Retry nur für klar transiente Netzwerkfehler.
- Keine Retries bei Governance-/Integritätsfehlern.
- Jeder fehlgeschlagene Versuch muss im Audit nachvollziehbar sein.

## Metrik

Install-Success-Rate wird über Skill-Manager-Metriken geführt.

Abfrage:

```bash
~/scripts/skill-forge metrics install-success
```

Enthält:
- `latest_install_success_rate`
- `weekly_avg_install_success_rate`
- `latest_run_id`
- `weekly_runs`
