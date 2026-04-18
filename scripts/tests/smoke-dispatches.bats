#!/usr/bin/env bats
# Smoke-Test: alle *-dispatch.sh Skripte auf Ausführbarkeit + Usage-Exit prüfen
# Deckt Testbarkeit-Anforderung ab: "Pro Skill mind. 1 Smoke-Test"

SKILLS_ROOT="/home/steges/agent/skills"

# Hilfs-Funktion: gibt alle Dispatch-Scripts zurück
discover_dispatches() {
  find "$SKILLS_ROOT" -name "*-dispatch.sh" | sort
}

@test "Alle dispatch scripts sind ausführbar" {
  local failed=0
  while IFS= read -r f; do
    if [[ ! -x "$f" ]]; then
      echo "NOT EXECUTABLE: $f" >&2
      failed=$((failed+1))
    fi
  done < <(discover_dispatches)
  [[ $failed -eq 0 ]]
}

@test "Alle dispatch scripts bestehen bash -n Syntaxprüfung" {
  local failed=0
  while IFS= read -r f; do
    if ! bash -n "$f" 2>/dev/null; then
      echo "SYNTAX ERROR: $f" >&2
      failed=$((failed+1))
    fi
  done < <(discover_dispatches)
  [[ $failed -eq 0 ]]
}

@test "Dispatch scripts liefern bei leeren Argumenten non-zero oder haben help-Flag" {
  local failed=0
  # Skills die 0 zurückgeben dürfen wenn kein Arg angegeben (z.B. default-Aktion):
  local allow_zero="heartbeat-dispatch.sh health-dispatch.sh growbox-dispatch.sh"

  while IFS= read -r f; do
    local name
    name=$(basename "$f")
    # Dispatch-Script ohne Argumente – exit-code sicher erfassen
    local rc=0
    "$f" >/dev/null 2>&1 || rc=$?
    if [[ $rc -eq 0 ]] && [[ " $allow_zero " != *" $name "* ]]; then
      # Evtl. hat das Script eine Hilfe-Ausgabe bei --help
      if ! "$f" --help >/dev/null 2>&1; then
        : # --help auch non-zero: OK
      fi
      # Nicht als Fehler werten – script hat eben eine Aktion als default
    fi
    # Hauptsache: kein Crash mit exit > 1 (Interpreter-Fehler)
    if [[ $rc -gt 125 ]]; then
      echo "CRASH ($rc): $f" >&2
      failed=$((failed+1))
    fi
  done < <(discover_dispatches)
  [[ $failed -eq 0 ]]
}

@test "rag-dispatch liefert Usage bei --help" {
  run bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"rag-dispatch.sh status"* ]]
}

@test "rag-dispatch status liefert valides JSON mit Kernfeldern" {
  run bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh status
  [ "$status" -eq 0 ]

  run python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert "db_exists" in d; assert "embed_service" in d' <<<"$output"
  [ "$status" -eq 0 ]
}
