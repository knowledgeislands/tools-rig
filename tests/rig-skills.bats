#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  BIN=$BATS_TEST_TMPDIR/bin-$BATS_TEST_NUMBER
  SKILLS_LOG=$BATS_TEST_TMPDIR/skills-log-$BATS_TEST_NUMBER
  SKILLS_JSON=$BATS_TEST_TMPDIR/skills-json-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME/.agents/skills" "$TEST_HOME/.claude/skills" \
    "$TEST_HOME/.codex/skills" "$TEST_HOME/state" "$TEST_HOME/data" "$TEST_HOME/cache" "$BIN"
  printf '%s\n' '[]' >"$SKILLS_JSON"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [ "${1:-}" = --version ]; then printf "%s\n" "1.7.0"; exit 0; fi' \
    'printf "%s\n" "$*" >>"$RIG_TEST_SKILLS_LOG"' \
    'if [ "${1:-}" = list ]; then cat "$RIG_TEST_SKILLS_JSON"; exit "${RIG_TEST_SKILLS_EXIT:-0}"; fi' \
    'exit "${RIG_TEST_SKILLS_EXIT:-0}"' >"$BIN/skills"
  chmod +x "$BIN/skills"
  export HOME="$TEST_HOME"
  export RIG_CONFIG_HOME="$CONFIG_HOME"
  export RIG_STATE_HOME="$TEST_HOME/state"
  export RIG_DATA_HOME="$TEST_HOME/data"
  export RIG_CACHE_HOME="$TEST_HOME/cache"
  export RIG_PLATFORM=macos
  export RIG_TEST_SKILLS_LOG="$SKILLS_LOG"
  export RIG_TEST_SKILLS_JSON="$SKILLS_JSON"
  export PATH="$BIN:$PATH"
}

output_has_table_row() {
  local expected

  expected=$1
  printf '%s\n' "$output" | awk -v expected="$expected" '
    { gsub(/  +/, "\t"); if ($0 == expected) found = 1 }
    END { exit !found }
  '
}

write_skill_config() {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Core tools"' \
    '[tool.skills-cli]' \
    'name = "Skills CLI"' \
    'category = "core"' \
    'purpose = "Manage global agent skills"' \
    'rationale = "Keeps native skill state authoritative"' \
    'platforms = ["any"]' \
    'profiles = []' \
    '[skill.caveman]' \
    'name = "Caveman"' \
    'purpose = "Compress communication"' \
    'rationale = "Reduces token use when requested"' \
    'authority = "skills-cli"' \
    'source = "JuliusBrussee/caveman"' \
    'trust = "reviewed"' \
    'platforms = ["macos"]' \
    'runtimes = ["claude-code", "codex"]' \
    'profiles = ["default", "public"]' \
    'public-source = "https://github.com/JuliusBrussee/caveman"' \
    '[profile.default]' \
    'name = "Default"' \
    'purpose = "Everyday setup"' \
    '[profile.public]' \
    'name = "Public"' \
    'purpose = "Public view"' \
    'kind = "view"' \
    >"$CONFIG_HOME/rig.toml"
}

@test "skills are selected queried explained counted without native invocation" {
  write_skill_config
  run "$RIG" show
  [ "$status" -eq 0 ]
  [[ "$output" == *'Skills: 1'* ]]
  [[ "$output" == *$'caveman\tCaveman\tskills-cli\tclaude-code, codex'* ]]
  [ ! -e "$SKILLS_LOG" ]

  run "$RIG" explain skill:caveman
  [ "$status" -eq 0 ]
  [[ "$output" == *'Authority: skills-cli'* ]]
  [[ "$output" == *'Profiles: default, public'* ]]
  [[ "$output" == *'Public source: https://github.com/JuliusBrussee/caveman'* ]]
  [ ! -e "$SKILLS_LOG" ]

  run "$RIG" diag
  [ "$status" -eq 0 ]
  [[ "$output" == *'Skills: 1'* ]]
}

@test "skill schema rejects unsafe authority trust and mixed profile models" {
  write_skill_config
  sed 's/trust = "reviewed"/trust = "authority-owned"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires trust 'reviewed'"* ]]

  write_skill_config
  printf '%s\n' 'skills = ["caveman"]' >>"$CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'cannot mix central profile members with item profiles'* ]]
}

@test "Skills CLI observation verifies source and runtimes and handles unavailable inventory" {
  write_skill_config
  printf '%s\n' '[{"name":"caveman","scope":"global","source":"JuliusBrussee/caveman","agents":["Claude Code","Codex"]}]' >"$SKILLS_JSON"
  run "$RIG" status
  [ "$status" -eq 0 ]
  output_has_table_row $'caveman\tskills-cli\tpresent\tverified-source-and-runtimes'

  printf '%s\n' '{not-json' >"$SKILLS_JSON"
  run "$RIG" status
  [ "$status" -eq 1 ]
  output_has_table_row $'caveman\tskills-cli\tunavailable\tmalformed-json'

  export RIG_TEST_SKILLS_EXIT=7
  printf '%s\n' '[]' >"$SKILLS_JSON"
  run "$RIG" status
  [ "$status" -eq 1 ]
  output_has_table_row $'caveman\tskills-cli\tunavailable\texit:7'

  unset RIG_TEST_SKILLS_EXIT
  rm "$BIN/skills"
  printf '%s\n' '[provider.skills-cli]' "executable = \"$BIN/skills\"" >>"$CONFIG_HOME/rig.toml"
  run "$RIG" status
  [ "$status" -eq 1 ]
  output_has_table_row $'caveman\tskills-cli\tunavailable\texecutable-unavailable'
}

@test "KI authority is reported unavailable and never invoked" {
  write_skill_config
  sed \
    -e 's/authority = "skills-cli"/authority = "ki"/' \
    -e 's#source = "JuliusBrussee/caveman"#source = "knowledgeislands/ki-agentic-harness:caveman"#' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/ki.toml"
  mv "$CONFIG_HOME/ki.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' '#!/usr/bin/env bash' 'printf invoked >"$RIG_TEST_KI_LOG"' >"$BIN/ki"
  chmod +x "$BIN/ki"
  export RIG_TEST_KI_LOG=$BATS_TEST_TMPDIR/ki-log

  run "$RIG" status
  [ "$status" -eq 1 ]
  output_has_table_row $'caveman\tki\tunavailable\tinventory-unavailable'
  [ ! -e "$RIG_TEST_KI_LOG" ]

  run "$RIG" apply --scope skills --dry-run
  [ "$status" -eq 1 ]
  [ ! -e "$RIG_TEST_KI_LOG" ]
}

@test "local authority creates only missing leaf symlinks and refuses collisions" {
  write_skill_config
  source_root=$TEST_HOME/source/caveman
  mkdir -p "$source_root"
  printf '%s\n' '# Caveman' >"$source_root/SKILL.md"
  sed \
    -e 's/authority = "skills-cli"/authority = "local"/' \
    -e "s#source = \"JuliusBrussee/caveman\"#source = \"$source_root\"#" \
    -e '/public-source =/d' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/local.toml"
  mv "$CONFIG_HOME/local.toml" "$CONFIG_HOME/rig.toml"

  run "$RIG" apply --scope skills
  [ "$status" -eq 0 ]
  canonical_source=$(cd "$source_root" && pwd -P)
  [ "$(readlink "$TEST_HOME/.claude/skills/caveman")" = "$canonical_source" ]
  [ "$(readlink "$TEST_HOME/.codex/skills/caveman")" = "$canonical_source" ]

  rm "$TEST_HOME/.claude/skills/caveman"
  printf '%s\n' foreign >"$TEST_HOME/.claude/skills/caveman"
  run "$RIG" apply --scope skills
  [ "$status" -eq 1 ]
  [ "$(cat "$TEST_HOME/.claude/skills/caveman")" = foreign ]
}

@test "apply and update use literal Skills CLI operations without removal" {
  write_skill_config
  run "$RIG" apply --scope skills
  [ "$status" -eq 0 ]
  grep -F 'add JuliusBrussee/caveman --global --skill caveman --agent claude-code --agent codex --yes --json' "$SKILLS_LOG"

  : >"$SKILLS_LOG"
  run "$RIG" update
  [ "$status" -eq 0 ]
  grep -F 'update caveman --global --yes' "$SKILLS_LOG"
  ! grep -E 'remove|rm|clean' "$SKILLS_LOG"
}

@test "apply orders tools skills resources and no lifecycle removes deselected skills" {
  write_skill_config
  printf '%s\n' \
    '[service.sample]' \
    'name = "Sample service"' \
    'purpose = "Prove lifecycle ordering"' \
    'rationale = "A resource must follow tools and skills"' \
    'provider = "launchd"' \
    'locator = "example.rig.sample"' \
    'platforms = ["macos"]' \
    'desired-state = "running"' \
    'program = ["/usr/bin/true"]' \
    'profiles = ["default"]' \
    '[profile.minimal]' \
    'name = "Minimal"' \
    'purpose = "Deselected skill proof"' \
    'kind = "complete"' >>"$CONFIG_HOME/rig.toml"

  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'TOOL\tPROVIDER\tRESULT\tDETAIL\tSCOPE'*$'SKILL\tAUTHORITY\tRESULT\tDETAIL\tSCOPE'*$'RESOURCE\tKIND\tPROVIDER\tRESULT\tDETAIL\tSCOPE'* ]]

  : >"$SKILLS_LOG"
  run "$RIG" apply --profile minimal --dry-run
  [ "$status" -eq 0 ]
  run "$RIG" maintain --profile minimal --dry-run
  [ "$status" -eq 0 ]
  run "$RIG" clean --dry-run
  [ "$status" -eq 0 ]
  ! grep -E 'remove|uninstall|delete' "$SKILLS_LOG"
}

@test "publication format two escapes JSON and excludes private skill metadata" {
  run bash -c '. "$1"; rig_json_escape "$2"; printf "\"%s\"\n" "$RIG_VALUE"' \
    _ "$RIG" $'Line one\nÉlan\tcontrol'
  [ "$status" -eq 0 ]
  run python3 -c 'import json, sys; assert json.loads(sys.argv[1]) == "Line one\nÉlan\tcontrol"' "$output"
  [ "$status" -eq 0 ]

  write_skill_config
  sed \
    -e 's/name = "Caveman"/name = "Caveman \\"compact\\" \\\\ mode"/' \
    -e 's/rationale = "Reduces token use when requested"/rationale = "Élan with control"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/escaped.toml"
  mv "$CONFIG_HOME/escaped.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[publication.site]' \
    'profile = "public"' \
    'title = "Public"' \
    'base-url = "https://rig.example"' \
    'publisher = "publisher"' \
    '[provider.publisher]' \
    'adapter = "custom"' \
    'executable = "/usr/bin/false"' \
    'capabilities = ["publish"]' >>"$CONFIG_HOME/rig.toml"

  export_dir=$BATS_TEST_TMPDIR/escaped-export
  run "$RIG" export site --output "$export_dir"
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    data = json.load(source)
skill = data["profile"]["skills"][0]
assert skill["name"] == "Caveman \"compact\" \\ mode"
assert skill["purpose"] == "Compress communication"
assert skill["rationale"] == "Élan with control"
assert set(skill) == {"id", "name", "purpose", "rationale", "source"}
' "$export_dir/rig.json"
  [ "$status" -eq 0 ]
  ! grep -E 'skills-cli|claude-code|codex|\.agents|paths?|roots?|runtime|locks?|argv|state|unmanaged|1675' "$export_dir/rig.json"
}

@test "publication format two emits reviewed opt-in metadata and deterministic empty skills" {
  write_skill_config
  printf '%s\n' \
    '[publication.site]' \
    'profile = "public"' \
    'title = "Public Rig"' \
    'base-url = "https://rig.example"' \
    'publisher = "publisher"' \
    '[provider.publisher]' \
    'adapter = "custom"' \
    'executable = "/usr/bin/false"' \
    'capabilities = ["publish"]' >>"$CONFIG_HOME/rig.toml"

  export_dir=$BATS_TEST_TMPDIR/export
  run "$RIG" export site --output "$export_dir"
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    data = json.load(source)
assert data["format"] == "rig-publication"
assert data["version"] == 2
assert data["profile"]["skills"] == [{
    "id": "caveman",
    "name": "Caveman",
    "purpose": "Compress communication",
    "rationale": "Reduces token use when requested",
    "source": "https://github.com/JuliusBrussee/caveman",
}]
' "$export_dir/rig.json"
  [ "$status" -eq 0 ]
  ! grep -E 'skills-cli|claude-code|codex|\.agents|\.local/state|runtime|lock|argv|observ' "$export_dir/rig.json"

  sed '/profiles = \["default", "public"\]/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/private.toml"
  mv "$CONFIG_HOME/private.toml" "$CONFIG_HOME/rig.toml"
  run "$RIG" export site --output "$export_dir"
  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    data = json.load(source)
assert data["profile"]["skills"] == []
' "$export_dir/rig.json"
  [ "$status" -eq 0 ]
}

@test "update reports an unavailable Skills CLI skill without blocking other work" {
  write_skill_config
  printf '%s\n' '[provider.skills-cli]' "executable = \"$BIN/absent-skills\"" >>"$CONFIG_HOME/rig.toml"

  run "$RIG" update

  [ "$status" -eq 1 ]
  [[ "$output" == *$'skill:caveman\tskills-cli\tunavailable\texecutable-unavailable'* ]]
  [[ "$output" == *'unavailable=1'* ]]
  [ ! -s "$SKILLS_LOG" ]
}
