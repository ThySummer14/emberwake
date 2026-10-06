#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME=/tmp/emberwake-handoff-validation/data
export XDG_CACHE_HOME=/tmp/emberwake-handoff-validation/cache
export XDG_CONFIG_HOME=/tmp/emberwake-handoff-validation/config
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
python3 tests/make_capture.py
timeout 20s godot --headless --path . --quit-after 3 -- --smoke-test
for test in component_test legacy_core_test legacy_ui_test legacy_regressions room_route fairness_test breaker_combat_test carrier_pilot camera_probe full_slice_route ledger_contract ledger_traversal ledger_combat_test foldhammer_component_test foldhammer_pilot ledger_full_tour ledger_map_test ledger_gates_test ledger_review_regressions handoff_ui_test combined_loop; do
 timeout 25s godot --headless --path . --script "res://tests/$test.gd"
done
