#!/usr/bin/env bats

setup() {
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  PROVIDER=$BATS_TEST_TMPDIR/provider-$BATS_TEST_NUMBER
  LSOF=$BATS_TEST_TMPDIR/lsof-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '[ "$1" = rig-provider-v1 ] || exit 64' \
    '[ "$2" = observe ] || exit 65' \
    'printf "%s\n" present' >"$PROVIDER"
  chmod +x "$PROVIDER"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$LSOF"
  chmod +x "$LSOF"
  export RIG_LSOF_COMMAND=$LSOF
}

write_projection_config() {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Projection fixtures"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' \
    'purpose = "Report a healthy observation"' \
    'rationale = "A present tool anchors the payload"' \
    'platforms = ["any"]' \
    'install.provider = "fixture"' 'install.kind = "package"' \
    'install.locator = "alpha"' \
    '[tool.beta]' 'name = "Beta"' 'category = "core"' \
    'purpose = "Report a missing artifact"' \
    'rationale = "A finding proves the verdict travels"' \
    'platforms = ["any"]' \
    'install.provider = "fixture"' 'install.kind = "package"' \
    'install.locator = "beta"' \
    'artifacts = ["~/quote\"and\\backslash"]' \
    '[port.api]' 'name = "API"' 'purpose = "Expose a private endpoint"' \
    'rationale = "A declared port keeps local planning honest"' \
    'protocol = "tcp"' 'port = 4301' 'scope = "loopback"' 'mode = "required"' \
    'owner = "tool:alpha"' \
    '[profile.default]' 'tools = ["alpha", "beta"]' 'ports = ["api"]' \
    '[provider.fixture]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["observe"]' \
    >"$CONFIG_HOME/rig.toml"
}

run_rig() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" "$@"
}

@test "status projects a versioned payload carrying every observed kind" {
  write_projection_config

  run_rig status --format json

  [ "$status" -eq 1 ]
  run python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["schema"] == 1, data["schema"]
assert data["command"] == "status"
assert data["rig"]
assert data["profile"] == "default"
assert data["platform"] == "macos"
assert data["observed_at"].endswith("Z")
assert data["healthy"] is False
assert data["summary"]["present"] == 1
assert data["summary"]["missing"] == 1
assert data["summary"]["unhealthy"] == 2
tools = {tool["id"]: tool for tool in data["tools"]}
assert tools["alpha"] == {
    "id": "alpha", "provider": "fixture", "state": "present", "detail": "-"
}
assert tools["beta"]["state"] == "missing"
assert data["skills"] == []
assert data["resources"] == []
assert data["ports"] == [{
    "id": "api", "number": 4301, "protocol": "tcp", "mode": "required",
    "owner": "tool:alpha", "state": "missing", "detail": "not-listening",
}]
assert data["unmanaged"] is None
assert data["unmanaged_problems"] is None
' "$output"
  [ "$status" -eq 0 ]
}

@test "the projected detail escapes a quote and a backslash losslessly" {
  write_projection_config

  run_rig status --format json

  [ "$status" -eq 1 ]
  run python3 -c '
import json, sys
tools = {tool["id"]: tool for tool in json.loads(sys.argv[1])["tools"]}
assert tools["beta"]["detail"] == "artifact-missing:~/quote\"and\\backslash", tools["beta"]
' "$output"
  [ "$status" -eq 0 ]
}

@test "the text and structured renderings agree about state and exit status" {
  write_projection_config

  run_rig status
  local text_status=$status
  [[ "$output" == *'Summary: present=1 missing=1 drifted=0 unavailable=0 unknown=0 catalogue-only=0'* ]]

  run_rig status --format json
  [ "$status" -eq "$text_status" ]
  run python3 -c '
import json, sys
summary = json.loads(sys.argv[1])["summary"]
assert summary == {
    "present": 1, "missing": 1, "drifted": 0, "unavailable": 0,
    "unknown": 0, "catalogue_only": 0, "unhealthy": 2,
}, summary
' "$output"
  [ "$status" -eq 0 ]
}

@test "a healthy rig projects a true verdict beside a zero exit status" {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Projection fixtures"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' \
    'purpose = "Report a healthy observation"' \
    'rationale = "A present tool anchors the payload"' \
    'platforms = ["any"]' \
    'install.provider = "fixture"' 'install.kind = "package"' \
    'install.locator = "alpha"' \
    '[profile.default]' 'tools = ["alpha"]' \
    '[provider.fixture]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["observe"]' \
    >"$CONFIG_HOME/rig.toml"

  run_rig status --format json

  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["healthy"] is True
assert data["summary"]["unhealthy"] == 0
' "$output"
  [ "$status" -eq 0 ]
}

@test "unmanaged is null until it is asked for and an array once it is" {
  write_projection_config

  run_rig status --unmanaged --format json

  [ "$status" -eq 1 ]
  run python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert isinstance(data["unmanaged"], list), data["unmanaged"]
assert isinstance(data["unmanaged_problems"], list), data["unmanaged_problems"]
' "$output"
  [ "$status" -eq 0 ]
}

@test "doctor projects its findings and verdict in the same envelope" {
  write_projection_config

  run_rig doctor --format json

  [ "$status" -eq 1 ]
  run python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["schema"] == 1
assert data["command"] == "doctor"
assert data["healthy"] is False
assert data["summary"]["findings"] >= 2
findings = data["findings"]
assert set(findings) == {"xdg", "tools", "resources", "ports", "skills"}
assert any(line.startswith("beta:") for line in findings["tools"]), findings["tools"]
assert any(line.startswith("port.api:") for line in findings["ports"]), findings["ports"]
assert isinstance(data["information"], list)
' "$output"
  [ "$status" -eq 0 ]
}

@test "an unsupported format is rejected before any observation" {
  write_projection_config

  run_rig status --format yaml
  [ "$status" -eq 2 ]
  [[ "$output" == *'rig: error: usage: rig status'* ]]
  [[ "$output" != *'{'* ]]

  run_rig doctor --format yaml
  [ "$status" -eq 2 ]
  [[ "$output" == *'rig: error: usage: rig doctor'* ]]

  run_rig status --format
  [ "$status" -eq 2 ]
}

@test "the structured rendering is the only thing on stdout" {
  write_projection_config

  local payload progress code
  payload=$BATS_TEST_TMPDIR/payload-$BATS_TEST_NUMBER
  progress=$BATS_TEST_TMPDIR/progress-$BATS_TEST_NUMBER

  code=0
  env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PROGRESS=always "$RIG" status --format json >"$payload" 2>"$progress" || code=$?
  [ "$code" -eq 1 ]

  [ "$(wc -l <"$payload" | tr -d ' ')" -eq 1 ]
  [ -s "$progress" ]
  run python3 -c 'import json, sys; json.loads(open(sys.argv[1]).read())' "$payload"
  [ "$status" -eq 0 ]
}
