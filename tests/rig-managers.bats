#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/helpers/isolate.bash"

setup() {
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  MANAGER_EXE=$BATS_TEST_TMPDIR/managers/uv
  mkdir -p "$CONFIG_HOME" "${MANAGER_EXE%/*}"
  export MANAGER_EXE
  rig_test_provider brew
  cat >"$CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "default"
[category.core]
name = "Core"
purpose = "Exercise catalogue managers"
[tool.a-consumer]
name = "Consumer"
category = "core"
purpose = "Use the supplied manager"
rationale = "Keep installation order declarative"
platforms = ["any"]
install.provider = "uv"
install.kind = "tool"
install.locator = "sample"
[tool.z-manager]
name = "Manager"
category = "core"
purpose = "Provide a package manager"
rationale = "Supply the selected consumers"
platforms = ["any"]
provides = "uv"
install.provider = "homebrew"
install.kind = "formula"
install.locator = "alternate-uv"
[profile.default]
tools = ["a-consumer", "z-manager"]
[profile.public]
kind = "view"
tools = ["a-consumer", "z-manager"]
[provider.uv]
executable = "$MANAGER_EXE"
EOF
}

run_rig() {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" "$@"
}

rewrite() {
  sed "$1" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/next"
  mv "$CONFIG_HOME/next" "$CONFIG_HOME/rig.toml"
}

manager_available() {
  rig_test_provider uv
  ln -s "$RIG_TEST_PROVIDER_BIN/uv" "$MANAGER_EXE"
  rig_test_provider_response brew 'list --formula --versions alternate-uv' 0 'alternate-uv 1.0'
  rig_test_provider_response uv 'tool list' 0 'sample v1.0'
}

@test "provides rejects unknown manager names" {
  rewrite 's/provides = "uv"/provides = "other"/'
  run_rig show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"provides unknown manager 'other'"* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "provides rejects two catalogue tools for the same manager" {
  rewrite '/name = "Consumer"/a\
provides = "uv"'
  run_rig show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"duplicates manager 'uv'"* ]] || false
}

@test "provides is a scalar and cannot be declared on a variant" {
  rewrite 's/provides = "uv"/provides = ["uv", "npm"]/'
  run_rig show
  [ "$status" -eq 2 ] || false
  rewrite 's/provides = \["uv", "npm"\]/variant.native.provides = "uv"/'
  run_rig show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *provides* ]] || false
}

@test "derived manager order needs no declared requires and explain labels it" {
  run_rig apply --dry-run
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'z-manager\thomebrew\tplanned' || false
  rig_test_report_contains "$output" $'a-consumer\tuv\tplanned' || false
  [[ "${output%%a-consumer*}" == *z-manager* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
  run_rig show a-consumer
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Manager dependency: z-manager (derived)'* ]] || false
}

@test "duplicate declared and derived edges are silent and labelled declared" {
  rewrite '/name = "Consumer"/a\
requires = ["z-manager"]'
  run_rig apply --dry-run
  [ "$status" -eq 0 ] || false
  [[ "$output" != *warning* ]] || false
  run_rig show a-consumer
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Manager dependency: z-manager (declared)'* ]] || false
  [[ "$output" != *'(derived)'* ]] || false
}

@test "the union of declared and derived dependencies rejects cycles" {
  rewrite '/name = "Manager"/a\
requires = ["a-consumer"]'
  run_rig apply --dry-run
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'dependency-ordered provider plan'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "a manager cannot derive an installation edge to itself" {
  rewrite 's/install.provider = "homebrew"/install.provider = "uv"/; s/install.kind = "formula"/install.kind = "tool"/'
  run_rig apply --dry-run
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'dependency-ordered provider plan'* ]] || false
}

@test "platform resolved variants choose different manager edges" {
  rewrite 's/platforms = \["any"\]/platforms = ["macos", "linux"]/; /install.provider = "uv"/d; /install.kind = "tool"/d; /install.locator = "sample"/d; /name = "Consumer"/a\
variant.mac.platforms = ["macos"]\
variant.mac.install.provider = "uv"\
variant.mac.install.kind = "tool"\
variant.mac.install.locator = "sample"\
variant.linux.platforms = ["linux"]\
variant.linux.install.provider = "npm"\
variant.linux.install.kind = "global"\
variant.linux.install.locator = "sample"'
  cat >>"$CONFIG_HOME/rig.toml" <<'EOF'
[tool.y-npm]
name = "Node manager"
category = "core"
purpose = "Provide npm"
rationale = "Exercise platform specific prerequisites"
platforms = ["any"]
provides = "npm"
EOF
  rewrite 's/"a-consumer", "z-manager"/"a-consumer", "z-manager", "y-npm"/g'
  run_rig show a-consumer
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'z-manager (derived)'* ]] || false
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux "$RIG" show a-consumer
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'y-npm (derived)'* ]] || false
  rewrite '/name = "Node manager"/a\
requires = ["a-consumer"]'
  run_rig apply --dry-run
  [ "$status" -eq 0 ] || false
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux "$RIG" apply --dry-run
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'dependency-ordered provider plan'* ]] || false
}

@test "missing provided manager is one finding and its consumers are blocked" {
  cat >>"$CONFIG_HOME/rig.toml" <<'EOF'
[tool.b-consumer]
name = "Second consumer"
category = "core"
purpose = "Share the provided manager"
rationale = "Avoid repeated missing manager findings"
platforms = ["any"]
install.provider = "uv"
install.kind = "tool"
install.locator = "second"
EOF
  rewrite 's/"a-consumer", "z-manager"/"a-consumer", "z-manager", "b-consumer"/g'
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'z-manager: unavailable via homebrew (manager-missing)'* ]] || false
  [[ "$output" == *'a-consumer: unknown via uv (blocked-by:z-manager)'* ]] || false
  [[ "$output" == *'b-consumer: unknown via uv (blocked-by:z-manager)'* ]] || false
  [[ "$output" == *'action=run-rig-apply'* ]] || false
  [[ "$output" == *'uv: unavailable; owner=z-manager; action=run-rig-apply'* ]] || false
  [ "$(printf '%s\n' "$output" | grep -c '(manager-missing)')" -eq 1 ] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "doctor reports built in availability and opts in undeclared manager warnings" {
  manager_available
  run_rig doctor --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"managers":['* ]] || false
  [[ "$output" == *'uv: available; owner=z-manager; action=none'* ]] || false
  [[ "$output" == *'manager-not-declared:homebrew'* ]] || false
  rewrite '/provides = /d'
  run_rig doctor
  [ "$status" -eq 0 ] || false
  [[ "$output" != *'manager-not-declared:'* ]] || false
  [[ "$output" == *'uv: available; owner=provider:uv; action=none'* ]] || false
}

@test "a manager outside the selected plan does not suppress the warning" {
  rewrite 's/tools = \["a-consumer", "z-manager"\]/tools = ["a-consumer"]/'
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'manager-not-declared:uv'* ]] || false
  [[ "$output" == *'(executable-unavailable)'* ]] || false
  [[ "$output" != *'(blocked-by:z-manager)'* ]] || false
}

@test "Homebrew is observed without any installation dispatch" {
  rewrite 's/provides = "uv"/provides = "homebrew"/; s/install.provider = "uv"/install.provider = "homebrew"/; s/install.kind = "tool"/install.kind = "formula"/'
  rig_test_provider_response brew 'list --formula --versions sample' 0 'sample 1.0'
  run_rig status
  [ "$status" -eq 0 ] || false
  rig_test_report_contains "$output" $'z-manager\thomebrew\tpresent\tmanager-available' || false
  run_rig apply --dry-run
  [ "$status" -eq 0 ] || false
  [[ "$output" != *'alternate-uv'* ]] || false
  rig_test_provider_response brew 'install --formula sample' 0 -
  run_rig apply
  [ "$status" -eq 0 ] || false
  ! grep -q 'alternate-uv' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "missing Homebrew is never deferred and has one actionable finding" {
  rewrite 's/provides = "uv"/provides = "homebrew"/; s/install.provider = "uv"/install.provider = "homebrew"/; s/install.kind = "tool"/install.kind = "formula"/'
  cat >>"$CONFIG_HOME/rig.toml" <<EOF
[provider.homebrew]
executable = "$BATS_TEST_TMPDIR/missing-brew"
EOF
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'(manager-missing)'*'action=install-homebrew'* ]] || false
  [[ "$output" == *'(blocked-by:z-manager)'* ]] || false
  run_rig apply --dry-run
  [ "$status" -eq 2 ] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "derived deferral supports arbitrary manager installations and targeted closure" {
  rig_test_provider uv
  rewrite 's/install.provider = "homebrew"/install.provider = "seed"/; s/install.kind = "formula"/install.kind = "package"/'
  cat >"$BATS_TEST_TMPDIR/seed" <<'SCRIPT'
#!/usr/bin/env bash
case "$2" in
  observe) printf 'present\n' ;;
  apply) ln -s "$RIG_TEST_PROVIDER_BIN/uv" "$MANAGER_EXE" ;;
  *) exit 99 ;;
esac
SCRIPT
  chmod +x "$BATS_TEST_TMPDIR/seed"
  cat >>"$CONFIG_HOME/rig.toml" <<EOF
[provider.seed]
adapter = "custom"
executable = "$BATS_TEST_TMPDIR/seed"
capabilities = ["observe", "apply"]
EOF
  rig_test_provider_response uv 'tool install sample' 0 -
  run_rig apply --target a-consumer
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'z-manager\tseed\tcompleted' || false
  rig_test_report_contains "$output" $'a-consumer\tuv\tcompleted' || false
  [ -L "$MANAGER_EXE" ] || false
  grep -Fqx 'uv|tool install sample' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "fixed matrix remains the deferral fallback without provides" {
  rig_test_provider mise
  rewrite '/provides = /d; s/install.provider = "homebrew"/install.provider = "mise"/; s/install.kind = "formula"/install.kind = "tool"/; s/install.locator = "alternate-uv"/install.locator = "uv"/; /name = "Consumer"/a\
requires = ["z-manager"]'
  run_rig apply --dry-run
  [ "$status" -eq 0 ] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "custom doctor managers use configured executable availability" {
  rewrite 's/install.provider = "uv"/install.provider = "extension"/; s/install.kind = "tool"/install.kind = "package"/; s/tools = \["a-consumer", "z-manager"\]/tools = ["a-consumer"]/g'
  cat >>"$CONFIG_HOME/rig.toml" <<EOF
[provider.extension]
adapter = "custom"
executable = "$BATS_TEST_TMPDIR/extension"
capabilities = ["apply"]
EOF
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'provider:extension: unavailable; owner=provider:extension; action=install-or-configure-provider'* ]] || false
  printf '#!/bin/sh\nexit 99\n' >"$BATS_TEST_TMPDIR/extension"
  chmod +x "$BATS_TEST_TMPDIR/extension"
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'provider:extension: available; owner=provider:extension; action=none'* ]] || false
  [[ "$output" != *'manager-not-declared:extension'* ]] || false
}

@test "a configuration without provides keeps per tool manager findings" {
  rewrite '/provides = /d'
  rig_test_provider_response brew 'list --formula --versions alternate-uv' 0 'alternate-uv 1.0'
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'a-consumer: unavailable via uv (executable-unavailable)'* ]] || false
  [[ "$output" != *'manager-not-declared:'* ]] || false
  [[ "$output" != *'(manager-missing)'* ]] || false
}

@test "derived manager edges and provides never enter the public projection" {
  run_rig export --profile public --output "$BATS_TEST_TMPDIR/with"
  [ "$status" -eq 0 ] || false
  rewrite '/provides = /d'
  run_rig export --profile public --output "$BATS_TEST_TMPDIR/without"
  [ "$status" -eq 0 ] || false
  diff -r "$BATS_TEST_TMPDIR/with" "$BATS_TEST_TMPDIR/without" || false
}


@test "every built in manager accepts a catalogue tool without installation metadata" {
  local manager
  for manager in homebrew mas mise npm uv chezmoi; do
    rewrite "s/provides = .*/provides = \"$manager\"/"
    rewrite '/^\[tool.z-manager\]/,/^\[profile.default\]/{/install\./d;}'
    run_rig show
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  done
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "broken configuration fallback includes mas availability" {
  printf 'not valid configuration\n' >"$CONFIG_HOME/rig.toml"
  run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'mas: unavailable; owner=environment; action=none'* ]] || false
}
