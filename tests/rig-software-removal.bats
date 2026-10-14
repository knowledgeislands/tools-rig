#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
  rig_test_provider brew
}

write_config() {
  cat >"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[rig]
default-profile = "default"
[profile.default]
name = "Fixture"
[remove.obsolete]
name = "Obsolete"
provider = "homebrew"
kind = "cask"
locator = "obsolete"
platforms = ["macos"]
TOML
  rig_test_provider_response brew 'list --cask --versions obsolete' 0 'obsolete 1.0'
}

@test "removal defaults to preview and ordinary apply never uninstalls" {
  write_config
  run "$RIG" remove
  [ "$status" -eq 0 ]
  [[ "$output" == *'planned'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep 'uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "removal requires confirmation and refuses EOF or another answer" {
  write_config
  run "$RIG" remove --apply </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'nothing removed'* ]] || false
  run bash -c 'printf "no\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 1 ]
  ! /usr/bin/grep 'uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "confirmed removal previews before native cask uninstall" {
  write_config
  rig_test_provider_response brew 'uninstall --cask obsolete' 0 -
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Removal preview'* ]] || false
  [[ "$output" == *'completed'* ]] || false
  [[ "$(cat "$RIG_TEST_PROVIDER_LOG")" == *'brew|uninstall --cask obsolete'* ]] || false
  ! /usr/bin/grep -E 'zap|force|sudo' "$RIG_TEST_PROVIDER_LOG"
}

@test "undeclared target and contradictory retained installation fail before observations" {
  write_config
  run "$RIG" remove --target stranger --apply
  [ "$status" -eq 2 ]
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[category.core]
name = "Core"
purpose = "Fixture"
[tool.retained]
name = "Retained"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "obsolete"
TOML
  run "$RIG" remove
  [ "$status" -eq 2 ]
  [[ "$output" == *'still declared'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "missing removal is healthy while present removal is a doctor finding" {
  write_config
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'removal-pending'* ]] || false
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --cask --versions obsolete' 1 -
  run "$RIG" doctor --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"healthy":true'* ]] || false
  run "$RIG" remove --apply </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'already-absent'* ]] || false
}

@test "doctor undeclared inventory is opt-in information and excludes removal identities" {
  write_config
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --cask --versions obsolete' 1 -
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'foreign'
  rig_test_provider_response brew 'list --cask --full-name' 0 'obsolete'
  run "$RIG" doctor --unmanaged --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'undeclared: formula:foreign'* ]] || false
  [[ "$output" != *'undeclared: cask:obsolete'* ]] || false
}

@test "unsupported provider arguments, duplicate removals and option locators fail closed" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[remove.duplicate]
name = "Duplicate"
provider = "homebrew"
kind = "cask"
locator = "obsolete"
platforms = ["macos"]
TOML
  run "$RIG" remove
  [ "$status" -eq 2 ]
  [[ "$output" == *'duplicates removal'* ]] || false
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[provider.homebrew]
adapter = "homebrew"
arguments = ["--force"]
TOML
  run "$RIG" remove
  [ "$status" -eq 2 ]
  [[ "$output" == *'does not permit provider arguments'* ]] || false
  write_config
  /usr/bin/sed -i.bak 's/locator = "obsolete"/locator = "--force"/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" remove
  [ "$status" -eq 2 ]
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "profile and platform exclusions never invoke native removal" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
profiles = ["other"]
[profile.other]
name = "Other"
TOML
  run "$RIG" remove --apply
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  run env RIG_PLATFORM=linux "$RIG" remove --profile other --apply
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "failed native removal reports failure and continues independent declarations" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[remove.second]
name = "Second"
provider = "homebrew"
kind = "formula"
locator = "second"
platforms = ["macos"]
TOML
  rig_test_provider_response brew 'list --formula --versions second' 0 'second 1.0'
  rig_test_provider_response brew 'uninstall --cask obsolete' 4 -
  rig_test_provider_response brew 'uninstall --formula second' 0 -
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 1 ]
  [[ "$output" == *'exit:4'* ]] || false
  [[ "$(cat "$RIG_TEST_PROVIDER_LOG")" == *'brew|uninstall --formula second'* ]] || false
}

@test "fixed native removal commands cover uv npm mise and noninteractive App Store" {
  for fixture in uv npm mise mas; do
    : >"$RIG_TEST_PROVIDER_TABLE"
    : >"$RIG_TEST_PROVIDER_LOG"
    rig_test_provider "$fixture"
    case "$fixture" in
      uv) provider=uv; kind=tool; locator=subject; observe='tool list'; observed='subject v1.0'; uninstall='tool uninstall subject' ;;
      npm) provider=npm; kind=global; locator=subject; observe='list --global --depth=0 subject'; observed='/fixture/subject'; uninstall='uninstall --global subject' ;;
      mise) provider=mise; kind=tool; locator=subject; observe='which subject'; observed='/fixture/subject'; uninstall='uninstall subject' ;;
      mas) provider=homebrew; kind=mas; locator=123; observe=list; observed='123 Subject (1.0)'; uninstall='uninstall 123' ;;
    esac
    cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
name = "Fixture"
[remove.obsolete]
name = "Obsolete"
provider = "$provider"
kind = "$kind"
locator = "$locator"
platforms = ["macos"]
TOML
    rig_test_provider_response "$fixture" "$observe" 0 "$observed"
    rig_test_provider_response "$fixture" "$uninstall" 0 -
    if [ "$fixture" = mas ]; then
      cat >"$RIG_SUDO" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$0.log"
[ "$1" = -n ] && [ "$2" = -- ] || exit 99
shift 2
exec "$@"
SH
      chmod +x "$RIG_SUDO"
    fi
    run bash -c 'printf "remove\n" | "$1" remove --apply --format json' _ "$RIG"
    [ "$status" -eq 0 ]
    [[ "$(cat "$RIG_TEST_PROVIDER_LOG")" == *"$fixture|$uninstall"* ]] || false
    [[ "$output" == *'"command":"remove"'* ]] || false
  done
}

@test "unknown observation refuses deletion and sudo denial remains a native failure" {
  write_config
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --cask --versions obsolete' 99 -
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 1 ]
  ! /usr/bin/grep 'uninstall' "$RIG_TEST_PROVIDER_LOG"
  /usr/bin/sed -i.bak 's/kind = "cask"/kind = "mas"/;s/locator = "obsolete"/locator = "123"/' "$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider mas
  rig_test_provider_response mas list 0 '123 Subject (1.0)'
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 1 ]
  [[ "$output" == *'exit:1'* ]] || false
  [[ "$(cat "$RIG_SUDO.log")" == '-n -- '* ]] || false
  ! /usr/bin/grep 'mas|uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "changed observation after confirmation never becomes deletion authority" {
  write_config
  rm "$RIG_TEST_PROVIDER_BIN/brew"
  cat >"$RIG_TEST_PROVIDER_BIN/brew" <<'SH'
#!/usr/bin/env bash
printf 'brew|%s\n' "$*" >>"$RIG_TEST_PROVIDER_LOG"
[ "$*" = 'list --cask --versions obsolete' ] || exit 99
if [ -f "$0.seen" ]; then exit 99; fi
: >"$0.seen"
printf 'obsolete 1.0\n'
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/brew"
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 1 ]
  [[ "$output" == *'observation-changed'* ]] || false
  ! /usr/bin/grep 'uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "retired traces never approve removals or create deletion work" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<TOML
[retired-application.traces]
name = "Retained data"
bundle-id = "org.fixture.old"
application-paths = ["$HOME/Applications/Old.app"]
data-paths = ["$HOME/Library/Old"]
TOML
  mkdir -p "$HOME/Library/Old"
  printf 'keep\n' >"$HOME/Library/Old/retained"
  run "$RIG" remove
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/Library/Old/retained")" = keep ]
  [[ "$output" != *'retired-application.traces'* ]] || false
  ! /usr/bin/grep 'uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "version selectors cannot bypass retained npm and mise package protection" {
  for provider in npm mise; do
    cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
name = "Fixture"
[remove.obsolete]
name = "Obsolete"
provider = "$provider"
kind = "$([ "$provider" = npm ] && printf global || printf tool)"
locator = "subject"
platforms = ["macos"]
[category.core]
name = "Core"
purpose = "Fixture"
[tool.retained]
name = "Retained"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
install.provider = "$provider"
install.kind = "$([ "$provider" = npm ] && printf global || printf tool)"
install.locator = "subject@1"
TOML
    run "$RIG" remove
    [ "$status" -eq 2 ]
    [[ "$output" == *'still declared'* ]] || false
    [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  done
}

write_uv_config() {
  local removal retained
  removal=$1; retained=$2
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
name = "Fixture"
[profile.other]
name = "Unselected"
[remove.obsolete]
name = "Obsolete"
provider = "uv"
kind = "tool"
locator = "$removal"
platforms = ["macos"]
[category.core]
name = "Core"
purpose = "Fixture"
[tool.retained]
name = "Retained"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["linux"]
profiles = ["other"]
install.provider = "uv"
install.kind = "tool"
install.locator = "$retained"
TOML
}

@test "retained uv requirements reject preview and confirmed apply before provider observations" {
  rig_test_provider uv
  local retained command expected_status
  for retained in 'subject==1.0' 'subject[cli]' 'subject[cli]==1.0' \
    'subject [cli, test] >= 1.0, != 2.*, < 3' 'subject (~=1.0)' \
    'SUBJECT===1.0+local' 'subject!=1.0' 'subject>1.0' 'subject<=2.0'; do
    write_uv_config subject "$retained"
    for command in preview apply doctor; do
      expected_status=2
      case "$command" in
        preview) run "$RIG" remove --dry-run ;;
        apply) run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG" ;;
        doctor) expected_status=1; run "$RIG" doctor ;;
      esac
      [ "$status" -eq "$expected_status" ] || { printf '%s %s: status=%s\n%s\n' "$retained" "$command" "$status" "$output"; false; }
      [[ "$output" == *'still declared'* ]] || false
      [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
    done
  done
}

@test "uv case separator and extras aliases protect retained and duplicate native identities" {
  rig_test_provider uv
  local retained
  for retained in 'Subject_Name[cli]==1.0' 'SUBJECT..__--NAME >= 1.0' 'subject.name'; do
    write_uv_config subject-name "$retained"
    run "$RIG" remove --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *'still declared'* ]] || false
    [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  done
  write_uv_config 'Subject_Name[cli]==2.0' 'different==1.0'
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[remove.duplicate]
name = "Duplicate"
provider = "uv"
kind = "tool"
locator = "subject-name"
platforms = ["macos"]
TOML
  run "$RIG" remove --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *'duplicates removal'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "ambiguous uv retained and removal locators fail closed before observation or native mutation" {
  rig_test_provider uv
  local locator placement
  for locator in './subject' '/fixture/subject.whl' 'https://fixture.invalid/subject.whl' \
    'git+https://fixture.invalid/subject' 'subject @ https://fixture.invalid/subject.whl' \
    'subject-1.0-py3-none-any.whl' 'subject-1.0.tar.gz' 'subject-1.0.zip' \
    'subject; python_version > 3' 'subject[cli' 'subject[]' 'subject=='; do
    for placement in retained removal; do
      case "$placement" in
        retained) write_uv_config unrelated "$locator" ;;
        removal) write_uv_config "$locator" different ;;
      esac
      run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
      [ "$status" -eq 2 ]
      [[ "$output" == *'cannot safely establish a distribution identity'* ]] || false
      [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
    done
  done
}

@test "distinct retained uv requirement does not block explicit native removal" {
  rig_test_provider uv
  write_uv_config subject 'different[cli]>=1.0,<2.0'
  rig_test_provider_response uv 'tool list' 0 'subject v1.0'
  rig_test_provider_response uv 'tool uninstall subject' 0 -
  run "$RIG" remove --dry-run
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_TEST_PROVIDER_LOG")" = 'uv|tool list' ]
  : >"$RIG_TEST_PROVIDER_LOG"
  run bash -c 'printf "remove\n" | "$1" remove --apply' _ "$RIG"
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_TEST_PROVIDER_LOG")" = $'uv|tool list\nuv|tool list\nuv|tool uninstall subject' ]
}
