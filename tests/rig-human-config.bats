#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
}

run_loader() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    bash -c '. "$1"; rig_load_config' _ "$RIG"
}

write_variant_config() {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Variant fixtures"' \
    '[tool.subject]' \
    'name = "Subject"' \
    'category = "core"' \
    'purpose = "Use one identity across platforms"' \
    'rationale = "Avoid duplicate catalogue entries"' \
    'platforms = [' \
    '  "macos", # comments remain inert' \
    '  "linux",' \
    ']' \
    'variant.macos.platforms = ["macos"]' \
    'variant.macos.artifacts = ["~/private-macos-artifact"]' \
    'variant.macos.install.provider = "homebrew"' \
    'variant.macos.install.kind = "formula"' \
    'variant.macos.install.locator = "subject-macos"' \
    'variant.linux.platforms = ["linux"]' \
    'variant.linux.artifacts = ["~/private-linux-artifact"]' \
    'variant.linux.install.provider = "uv"' \
    'variant.linux.install.kind = "tool"' \
    'variant.linux.install.locator = "subject-linux"' \
    '[profile.default]' \
    'name = "Default"' \
    'purpose = "Default machine"' >"$CONFIG_HOME/rig.toml"
}

write_resource_graph_config() {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[profile.default]' \
    'name = "Default"' \
    'purpose = "Resource dependency fixture"' \
    '[setting.base]' \
    'name = "Base"' \
    'purpose = "Prepare a setting"' \
    'rationale = "The service needs it"' \
    'provider = "macos-defaults"' \
    'platforms = ["macos"]' \
    'domain = "example.rig"' \
    'key = "Ready"' \
    'value-type = "bool"' \
    'value = "true"' \
    '[service.worker]' \
    'name = "Worker"' \
    'purpose = "Run after the setting"' \
    'rationale = "It consumes prepared state"' \
    'provider = "launchd"' \
    'platforms = ["macos"]' \
    'locator = "example.rig.worker"' \
    'desired-state = "running"' \
    'program = ["/usr/bin/true"]' \
    'depends-on = ["setting:base"]' \
    '[scheduled-job.report]' \
    'name = "Report"' \
    'purpose = "Run after the worker"' \
    'rationale = "It reports completed work"' \
    'provider = "launchd"' \
    'platforms = ["macos"]' \
    'locator = "example.rig.report"' \
    'desired-state = "enabled"' \
    'program = ["/usr/bin/true"]' \
    'schedule.interval = "3600"' \
    'depends-on = ["service:worker"]' >"$CONFIG_HOME/rig.toml"
}

@test "bounded multiline arrays preserve string boundaries comments and trailing commas" {
  write_variant_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_get_value tool.subject platform 1; printf "one=%s\n" "$RIG_VALUE"
    rig_get_value tool.subject platform 2; printf "two=%s\n" "$RIG_VALUE"
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'one=macos\ntwo=linux' ]
}

@test "multiline arrays reject split strings and unterminated files" {
  write_variant_config
  sed 's/  "macos",/  "macos/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'TOML basic strings must not span lines'* ]] || false

  write_variant_config
  sed '/^]$/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'TOML arrays must contain basic strings'* ]] || false
}

@test "one logical tool selects exactly one platform installation and artifact variant" {
  write_variant_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    rig_resolve_bindings || exit
    rig_dump_resolution
    rig_collect_tool_artifacts subject macos || exit
    printf "artifact=%s\n" "${RIG_QUERY_ITEMS[0]}"
    rig_binding_declares_locator homebrew "$HOME/private-macos-artifact" || exit
    printf "inventory=declared\n"
  ' _ "$RIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'binding=subject:homebrew'* ]] || false
  [[ "$output" == *$'artifact=~/private-macos-artifact'* ]] || false
  [[ "$output" == *$'inventory=declared'* ]] || false
  [[ "$output" != *'private-linux-artifact'* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default linux || exit
    rig_resolve_bindings || exit
    rig_dump_resolution
  ' _ "$RIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'binding=subject:uv'* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain subject
  [ "$status" -eq 0 ]
  [[ "$output" == *'Installation: homebrew (formula: subject-macos)'* ]] || false
  [[ "$output" == *'Artifacts: ~/private-macos-artifact'* ]] || false
  [[ "$output" != *'private-linux-artifact'* ]] || false
}

@test "diagnostics summarise human model shape without provider work" {
  write_variant_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" diag

  [ "$status" -eq 0 ]
  [[ "$output" == *$'  Selection mode: item'* ]] || false
  [[ "$output" == *$'  Profiles: 1'* ]] || false
  [[ "$output" == *$'  Tools: 1'* ]] || false
  [[ "$output" == *$'  Managed resources: 0'* ]] || false
  [[ "$output" == *$'  Tool variants: 2'* ]] || false
}

@test "variant coverage rejects zero and multiple platform matches" {
  write_variant_config
  sed '/variant.linux\./d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"no variant for declared platform 'linux'"* ]] || false

  write_variant_config
  sed 's/variant.linux.platforms = \["linux"\]/variant.linux.platforms = ["macos", "linux"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"ambiguous variants for declared platform 'macos'"* ]] || false
}

@test "public projection never includes installation or artifact variant data" {
  write_variant_config
  awk '{
    print
    if ($0 == "rationale = \"Avoid duplicate catalogue entries\"") print "profiles = [\"public\"]"
  }' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/public.toml"
  mv "$CONFIG_HOME/public.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[profile.public]' \
    'name = "Public"' \
    'purpose = "Publication view"' \
    'kind = "view"' >>"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export --profile public --output "$BATS_TEST_TMPDIR/export"

  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/export/rig.json" ]
  ! grep -q 'subject-macos\|subject-linux\|private-macos\|private-linux' \
    "$BATS_TEST_TMPDIR/export/rig.json"
}

@test "qualified resource dependencies resolve in deterministic topological order" {
  write_resource_graph_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    printf "%s\n" "${RIG_SELECTED_RESOURCE_SECTIONS[@]}"
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'setting.base\nservice.worker\nscheduled-job.report' ]
}

@test "resource dependency validation rejects missing references and cycles" {
  write_resource_graph_config
  sed 's/setting:base/setting:missing/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"depends-on references unknown resource 'setting:missing'"* ]] || false

  write_resource_graph_config
  awk '{ print; if ($0 == "value = \"true\"") print "depends-on = [\"scheduled-job:report\"]" }' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'resource dependency cycle includes'* ]] || false
}

@test "resource dependency failures block only transitive dependants" {
  write_resource_graph_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    RIG_RESOURCE_PLAN_SECTIONS=("${RIG_SELECTED_RESOURCE_SECTIONS[@]}")
    RIG_RESOURCE_PLAN_RESULTS=(failed "" "")
    rig_resource_blocker service.worker || exit
    printf "worker=%s\n" "$RIG_VALUE"
    RIG_RESOURCE_PLAN_RESULTS=(completed failed "")
    rig_resource_blocker scheduled-job.report || exit
    printf "report=%s\n" "$RIG_VALUE"
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'worker=setting:base\nreport=service:worker' ]
}
