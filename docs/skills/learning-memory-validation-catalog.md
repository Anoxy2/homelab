# Learning Memory Validierungskatalog

Stand: 2026-04-10

Ziel: einheitliche Mindestpruefungen fuer lokale Learn+RAG-Integration.

## 1) Basis-Smoke (Pflicht)

```bash
~/scripts/skills learn weekly --json
bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh status
bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh retrieve "openclaw heartbeat" --limit 1
```

Erwartung:
- Learn gibt `ok` oder `skipped` aus.
- RAG-Status liefert gueltige Kernfelder inkl. `search_mode`/Coverage-Informationen.

## 2) RAG-Fallback (Pflicht)

```bash
bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh retrieve "zzzxxyyqq_learning_probe" --limit 3
```

Erwartung:
- Kein Hard-Fail.
- Ergebnisherkunft nachvollziehbar (`search_mode`, `source`, `section`).

## 3) Learn-Distill (Pflicht)

```bash
~/scripts/skills learn weekly --json
```

Erwartung:
- Weekly-Lauf bleibt erfolgreich/skipped-faehig.
- Neue Learning-Eintraege haben stabile IDs (`learn-YYYYMMDD-xx`).

## 4) Heartbeat-Verhalten (Pflicht)

Pruefung ueber Script-Lauf und Logs:
- Weekly Learnings laufen als nicht-blockierender Task.
- Fehler duerfen Heartbeat nicht hart stoppen.

## 5) Dispatcher-Regression (Pflicht)

```bash
bats /home/steges/scripts/tests/smoke-dispatches.bats
```

Erwartung:
- Testlauf gruen.
- Keine Dispatch-Syntax- oder Ausfuehrbarkeitsregression.

## 6) Recall/Latenz Baseline (Pflicht)

```bash
python3 /home/steges/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500 --disable-rewrite-ab
```

Baseline-Referenz:
- `docs/decisions/rag-ausbau-plan.md` (Metriken-Verlauf)
- Stand 2026-04-10: `Precision@5=0.2625`, `Recall@5=0.7188`, `p95=397.76ms`, `P=0/R=0: 2/48`

## Bestehensregel

Eine Aenderung gilt als release-faehig, wenn:
- Pflicht-Smokes ohne Hard-Fail durchlaufen,
- Dispatcher-Regression gruen ist,
- RAG-Fallback keine unmarkierten Quellen liefert,
- Baseline-Werte dokumentiert und gegen Referenz eingeordnet sind.
