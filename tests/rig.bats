#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
  source "$BATS_TEST_DIRNAME/helpers/large-catalogue-fixture.bash"
}

write_minimal_config() {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Essential tools' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = Test parsing' \
    'rationale = A dependable test tool' \
    'platform = any' \
    '[profile.default]' \
    'tool = alpha' \
    '[provider.native]' \
    'adapter = homebrew' \
    '[binding.alpha.native]' \
    'kind = formula' \
    'locator = alpha' >"$CONFIG_HOME/rig.conf"
}

write_recording_provider() {
  ORCHESTRATION_LOG=$BATS_TEST_TMPDIR/provider-log-$BATS_TEST_NUMBER
  ORCHESTRATION_PROVIDER=$BATS_TEST_TMPDIR/provider-$BATS_TEST_NUMBER
  ORCHESTRATION_MARKER=$BATS_TEST_TMPDIR/provider-marker-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "BEGIN\\n" >>"$RIG_TEST_LOG"' \
    'for argument in "$@"; do printf "ARG=%s\\n" "$argument" >>"$RIG_TEST_LOG"; done' \
    'while [ "$#" -gt 0 ] && [ "$1" != rig-provider-v1 ]; do shift; done' \
    '[ "$#" -ge 6 ] || exit 64' \
    'verb=$2' \
    'tool=$4' \
    'locator=$6' \
    'printf "CALL=%s:%s:%s\\n" "$verb" "$tool" "$locator" >>"$RIG_TEST_LOG"' \
    'case "$verb:$locator" in' \
    '  observe:exit-7) exit 7 ;;' \
    '  observe:exit-126) exit 126 ;;' \
    '  observe:empty) exit 0 ;;' \
    '  observe:invalid-response) printf "%s\\n" surprise ;;' \
    '  observe:multiline) printf "%s\\n" present extra ;;' \
    '  observe:diagnostics) printf "%s\\n" observation-diagnostic >&2; printf "%s\\n" present ;;' \
    '  observe:*) printf "%s\\n" "$locator" ;;' \
    '  apply:fail) exit 7 ;;' \
    '  apply:exit-126) exit 126 ;;' \
    '  apply:diagnostics) printf "%s\\n" application-stdout; printf "%s\\n" application-stderr >&2; exit 0 ;;' \
    '  apply:*) exit 0 ;;' \
    '  *) exit 65 ;;' \
    'esac' >"$ORCHESTRATION_PROVIDER"
  chmod +x "$ORCHESTRATION_PROVIDER"
}

write_orchestration_config() {
  write_recording_provider
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Orchestration fixtures' \
    '[tool.app]' \
    'name = App' \
    'category = core' \
    'purpose = Exercise a dependent tool' \
    'rationale = It verifies dependency ordering' \
    'platform = any' \
    'requires = base' \
    '[tool.base]' \
    'name = Base' \
    'category = core' \
    'purpose = Exercise a prerequisite' \
    'rationale = It must run before app' \
    'platform = any' \
    '[tool.independent]' \
    'name = Independent' \
    'category = core' \
    'purpose = Exercise an independent branch' \
    'rationale = It still runs after another branch fails' \
    'platform = any' \
    '[tool.notes]' \
    'name = Notes' \
    'category = core' \
    'purpose = Exercise catalogue-only state' \
    'rationale = It is descriptive rather than materialised' \
    'platform = any' \
    '[profile.default]' \
    'tool = app' \
    'tool = independent' \
    'tool = notes' \
    '[provider.runner]' \
    'adapter = custom' \
    "executable = $ORCHESTRATION_PROVIDER" \
    "argument = provider value;\$(touch $ORCHESTRATION_MARKER)" \
    'capability = observe' \
    'capability = apply' \
    '[binding.app.runner]' \
    'kind = executable' \
    'locator = present' \
    'argument = binding * value' \
    '[binding.base.runner]' \
    'kind = executable' \
    'locator = present' \
    '[binding.independent.runner]' \
    'kind = executable' \
    'locator = present' >"$CONFIG_HOME/rig.conf"
}

run_loader() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    bash -c '. "$1"; rig_load_config' _ "$RIG"
}

@test "large catalogue queries preserve deterministic results without provider execution" {
  write_large_catalogue_fixture "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" diag
  [ "$status" -eq 0 ]
  [[ "$output" == *"  Status: valid"* ]] || false
  [[ "$output" == *"  Default profile: default"* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list --category category-1
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 21 ]
  [ "${lines[1]}" = $'  tool-005\tTool 005\tcategory-1\tExercise deterministic catalogue query 005' ]
  [ "${lines[20]}" = $'  tool-100\tTool 100\tcategory-1\tExercise deterministic catalogue query 100' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" show
  [ "$status" -eq 0 ]
  [[ "$output" == $'Profile: default\nPlatform: macos\nTools (100):'* ]] || false
  [[ "$output" == *$'tool-100\tTool 100\tcategory-1\tExercise deterministic catalogue query 100' ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain tool-100
  [ "$status" -eq 0 ]
  [[ "$output" == *"Requires: tool-099"* ]] || false
  [[ "$output" == *"Profiles: default (inherited), developer (direct)"* ]] || false
  [[ "$output" == *"Binding: fixture (formula: fixture/tool-100)"* ]] || false
}

@test "sourceable model indexes every large catalogue field within its section span" {
  write_large_catalogue_fixture "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    section_index=0
    field_total=0
    while [ "$section_index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
      field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
      field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
      while [ "$field_index" -lt "$field_end" ]; do
        [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] || exit 3
        field_total=$((field_total + 1))
        field_index=$((field_index + 1))
      done
      section_index=$((section_index + 1))
    done
    rig_section_index tool.tool-100 || exit
    printf "sections=%s fields=%s lookup=%s\n" \
      "${#RIG_SECTION_NAMES[@]}" "$field_total" "${RIG_SECTION_NAMES[$RIG_INDEX]}"
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = "sections=211 fields=1216 lookup=tool.tool-100" ]
}

write_query_config() {
  QUERY_MARKER=$BATS_TEST_TMPDIR/provider-invoked-$BATS_TEST_NUMBER
  QUERY_PROVIDER=$BATS_TEST_TMPDIR/provider-$BATS_TEST_NUMBER
  printf '#!/usr/bin/env bash\nprintf invoked >"%s"\n' "$QUERY_MARKER" >"$QUERY_PROVIDER"
  chmod +x "$QUERY_PROVIDER"

  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.foundation]' \
    'name = Foundation' \
    'purpose = Core command-line foundations' \
    '[category.navigation]' \
    'name = Navigation' \
    'purpose = Move through Knowledge Islands' \
    '[profile.minimal]' \
    'tool = git' \
    '[profile.knowledge-islands]' \
    'profile = minimal' \
    'tool = mgit' \
    '[profile.focused]' \
    'tool = mgit' \
    '[profile.default]' \
    'profile = knowledge-islands' \
    'tool = fzf' \
    '[provider.marker]' \
    'adapter = custom' \
    "executable = $QUERY_PROVIDER" \
    '[binding.mgit.marker]' \
    'kind = executable' \
    'locator = mgit' \
    'platform = macos' >"$CONFIG_HOME/rig.conf"

  printf '%s\n' \
    '[tool.lazygit]' \
    'name = LazyGit' \
    'category = navigation' \
    'purpose = Browse Git interactively' \
    'rationale = It is a visual alternative' \
    'platform = any' >"$CONFIG_HOME/conf.d/10-lazygit.conf"
  printf '%s\n' \
    '[tool.git]' \
    'name = Git' \
    'category = foundation' \
    'purpose = Track source history' \
    'rationale = Other navigation tools depend on it' \
    'platform = any' >"$CONFIG_HOME/conf.d/20-git.conf"
  printf '%s\n' \
    '[tool.mgit]' \
    'name = MGit' \
    'category = navigation' \
    'purpose = Navigate many repositories' \
    'rationale = It presents the Knowledge Islands estate' \
    'platform = macos' \
    'platform = linux' \
    'requires = git' \
    'related = fzf' \
    'alternative = lazygit' >"$CONFIG_HOME/conf.d/30-mgit.conf"
  printf '%s\n' \
    '[tool.fzf]' \
    'name = fzf' \
    'category = navigation' \
    'purpose = Select entries quickly' \
    'rationale = It makes navigation concise' \
    'platform = any' >"$CONFIG_HOME/conf.d/40-fzf.conf"
}

@test "help describes the current command surface" {
  run "$RIG" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rig [options] [command]"* ]]
  [[ "$output" == *"Describe and manage a person's working setup."* ]]
  [[ "$output" == *"show [--profile NAME]"* ]]
  [[ "$output" == *"list [--category ID] [--profile NAME]"* ]]
  [[ "$output" == *"explain TOOL"* ]]
  [[ "$output" == *"status [--profile NAME]"* ]] || false
  [[ "$output" == *"apply [--profile NAME] [--dry-run]"* ]] || false
  [[ "$output" == *"diag"* ]]
  [[ "$output" != *"paths"* ]]
  [[ "$output" == *"completion bash|zsh"* ]]
}

@test "version comes from the executable marker" {
  run "$RIG" --version

  [ "$status" -eq 0 ]
  [ "$output" = "rig 0.1.0" ]
}

@test "diag reports stable runtime, default paths, and missing configuration" {
  run env \
    HOME="$TEST_HOME" \
    RIG_CONFIG_HOME= RIG_DATA_HOME= RIG_STATE_HOME= RIG_CACHE_HOME= \
    XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_STATE_HOME= XDG_CACHE_HOME= \
    RIG_PLATFORM=fixture \
    "$RIG" diag

  [ "$status" -eq 1 ]
  [ "$output" = "$(printf 'Runtime:\n  Rig version: 0.1.0\n  Executable: %s\n  Bash version: %s\n  Platform: fixture\nPaths:\n  Config home: %s/.config/rig\n  Data home: %s/.local/share/rig\n  State home: %s/.local/state/rig\n  Cache home: %s/.cache/rig\nConfiguration:\n  Root config: %s/.config/rig/rig.conf\n  Fragment count: 0\n  Status: missing' "$RIG" "$BASH_VERSION" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME")" ]
}

@test "diag follows XDG base directories" {
  run env \
    HOME=/tmp/rig-home \
    XDG_CONFIG_HOME=/tmp/rig-config \
    XDG_DATA_HOME=/tmp/rig-data \
    XDG_STATE_HOME=/tmp/rig-state \
    XDG_CACHE_HOME=/tmp/rig-cache \
    "$RIG" diag

  [ "$status" -eq 1 ]
  [[ "$output" == *"  Config home: /tmp/rig-config/rig"* ]]
  [[ "$output" == *"  Data home: /tmp/rig-data/rig"* ]]
  [[ "$output" == *"  State home: /tmp/rig-state/rig"* ]]
  [[ "$output" == *"  Cache home: /tmp/rig-cache/rig"* ]]
  [[ "$output" == *"  Root config: /tmp/rig-config/rig/rig.conf"* ]]
}

@test "Rig diagnostic path overrides take precedence" {
  run env \
    HOME=/tmp/rig-home \
    RIG_CONFIG_HOME=/tmp/custom-config \
    RIG_DATA_HOME=/tmp/custom-data \
    RIG_STATE_HOME=/tmp/custom-state \
    RIG_CACHE_HOME=/tmp/custom-cache \
    "$RIG" diag

  [ "$status" -eq 1 ]
  [[ "$output" == *"  Config home: /tmp/custom-config"* ]]
  [[ "$output" == *"  Data home: /tmp/custom-data"* ]]
  [[ "$output" == *"  State home: /tmp/custom-state"* ]]
  [[ "$output" == *"  Cache home: /tmp/custom-cache"* ]]
  [[ "$output" == *"  Root config: /tmp/custom-config/rig.conf"* ]]
}

@test "completion emits shell registration" {
  run "$RIG" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"complete -F _rig rig"* ]]
  [[ "$output" == *"-h --help -V --version show list explain status apply diag completion help"* ]] || false
  [[ "$output" == *'show) COMPREPLY=($(compgen -W "-h --help --profile"'* ]]
  [[ "$output" == *'explain) COMPREPLY=($(compgen -W "-h --help"'* ]]
  [[ "$output" == *'status) COMPREPLY=($(compgen -W "-h --help --profile"'* ]] || false
  [[ "$output" == *'apply) COMPREPLY=($(compgen -W "-h --help --profile --dry-run"'* ]] || false
  [[ "$output" == *"show list explain status apply diag completion help"* ]] || false
  [[ "$output" != *" paths "* ]]

  run "$RIG" completion zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#compdef rig"* ]]
  [[ "$output" == *"compdef _rig rig"* ]]
  [[ "$output" == *"show:describe a resolved profile"* ]]
  [[ "$output" == *"diag:print runtime and configuration diagnostics"* ]]
  [[ "$output" == *"'(-V --version)'{-V,--version}"* ]]
  [[ "$output" == *"explain) _arguments '(-h --help)'"* ]]
}

@test "completion definitions evaluate and expose accepted options" {
  run bash -c '
    eval "$("$1" completion bash)"
    COMP_WORDS=(rig --)
    COMP_CWORD=1
    _rig
    printf "root:%s\n" "${COMPREPLY[*]}"
    COMP_WORDS=(rig show --)
    COMP_CWORD=2
    _rig
    printf "show:%s\n" "${COMPREPLY[*]}"
    COMP_WORDS=(rig explain --)
    COMP_CWORD=2
    _rig
    printf "explain:%s\n" "${COMPREPLY[*]}"
    COMP_WORDS=(rig status --)
    COMP_CWORD=2
    _rig
    printf "status:%s\n" "${COMPREPLY[*]}"
    COMP_WORDS=(rig apply --)
    COMP_CWORD=2
    _rig
    printf "apply:%s\n" "${COMPREPLY[*]}"
  ' bash "$RIG"

  [ "$status" -eq 0 ]
  [[ "$output" == *"root:--help --version"* ]]
  [[ "$output" == *"show:--help --profile"* ]]
  [[ "$output" == *"explain:--help"* ]]
  [[ "$output" == *"status:--help --profile"* ]] || false
  [[ "$output" == *"apply:--help --profile --dry-run"* ]] || false

  run zsh -f -c '
    autoload -Uz compinit && compinit -C
    eval "$("$1" completion zsh)"
    [[ ${_comps[rig]} == _rig ]]
  ' zsh "$RIG"

  [ "$status" -eq 0 ]
}

@test "diag reports valid configuration metadata and fragment count" {
  write_minimal_config
  printf '%s\n' '# first fragment' >"$CONFIG_HOME/conf.d/10-first.conf"
  printf '%s\n' '# second fragment' >"$CONFIG_HOME/conf.d/20-second.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    XDG_DATA_HOME= XDG_STATE_HOME= XDG_CACHE_HOME= RIG_PLATFORM=fixture "$RIG" diag

  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'Runtime:\n  Rig version: 0.1.0\n  Executable: %s\n  Bash version: %s\n  Platform: fixture\nPaths:\n  Config home: %s\n  Data home: %s/.local/share/rig\n  State home: %s/.local/state/rig\n  Cache home: %s/.cache/rig\nConfiguration:\n  Root config: %s/rig.conf\n  Fragment count: 2\n  Status: valid\n  Schema: 1\n  Default profile: default' "$RIG" "$BASH_VERSION" "$CONFIG_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$CONFIG_HOME")" ]
}

@test "diag summarizes invalid configuration without parser diagnostics" {
  printf '%s\n' '[rig]' 'schema = 2' 'default-profile = default' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=fixture "$RIG" diag

  [ "$status" -eq 1 ]
  [[ "$output" == *"  Status: invalid"* ]]
  [[ "$output" != *"  Schema:"* ]]
  [[ "$output" != *"  Default profile:"* ]]
  [[ "$output" != *"rig: error:"* ]]
}

@test "diag validates configuration without invoking providers" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" diag

  [ "$status" -eq 0 ]
  [[ "$output" == *"  Status: valid"* ]]
  [ ! -e "$QUERY_MARKER" ]
}

@test "diag reports the invoked linked executable path" {
  write_minimal_config
  link_dir=$BATS_TEST_TMPDIR/linked-bin-$BATS_TEST_NUMBER
  mkdir -p "$link_dir"
  ln -s "$RIG" "$link_dir/rig"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=fixture "$link_dir/rig" diag

  [ "$status" -eq 0 ]
  [[ "$output" == *"  Executable: $link_dir/rig"* ]]
}

@test "diag help succeeds without configuration and paths is removed" {
  missing_config=$BATS_TEST_TMPDIR/missing-diag-config-$BATS_TEST_NUMBER

  for flag in -h --help; do
    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" diag "$flag"
    [ "$status" -eq 0 ]
    [ "$output" = "Usage: rig diag" ]
  done

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" diag extra
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig diag"* ]]
  [[ "$output" != *"cannot read configuration file"* ]]

  run "$RIG" paths
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown command: paths"* ]]
}

@test "show describes default and named resolved profiles deterministically" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" OSTYPE=unrecognised RIG_PLATFORM=macos \
    "$RIG" show
  [ "$status" -eq 0 ]
  [ "$output" = $'Profile: default\nPlatform: macos\nTools (3):\n  fzf\tfzf\tnavigation\tSelect entries quickly\n  git\tGit\tfoundation\tTrack source history\n  mgit\tMGit\tnavigation\tNavigate many repositories' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" show --profile minimal
  [ "$status" -eq 0 ]
  [ "$output" = $'Profile: minimal\nPlatform: macos\nTools (1):\n  git\tGit\tfoundation\tTrack source history' ]
}

@test "queries reject an unknown detected platform unless explicitly overridden" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" OSTYPE=unrecognised RIG_PLATFORM= \
    "$RIG" show

  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unsupported platform 'unrecognised'"* ]]
}

@test "list narrows stable catalogue output by category and resolved profile" {
  write_query_config
  expected=$'ID\tNAME\tCATEGORY\tPURPOSE\n  fzf\tfzf\tnavigation\tSelect entries quickly\n  git\tGit\tfoundation\tTrack source history\n  lazygit\tLazyGit\tnavigation\tBrowse Git interactively\n  mgit\tMGit\tnavigation\tNavigate many repositories'

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]

  mv "$CONFIG_HOME/conf.d/10-lazygit.conf" "$CONFIG_HOME/conf.d/swap.conf"
  mv "$CONFIG_HOME/conf.d/40-fzf.conf" "$CONFIG_HOME/conf.d/10-lazygit.conf"
  mv "$CONFIG_HOME/conf.d/swap.conf" "$CONFIG_HOME/conf.d/40-fzf.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list --category navigation
  [ "$status" -eq 0 ]
  [ "$output" = $'ID\tNAME\tCATEGORY\tPURPOSE\n  fzf\tfzf\tnavigation\tSelect entries quickly\n  lazygit\tLazyGit\tnavigation\tBrowse Git interactively\n  mgit\tMGit\tnavigation\tNavigate many repositories' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list --profile knowledge-islands
  [ "$status" -eq 0 ]
  [ "$output" = $'ID\tNAME\tCATEGORY\tPURPOSE\n  git\tGit\tfoundation\tTrack source history\n  mgit\tMGit\tnavigation\tNavigate many repositories' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" list --profile knowledge-islands --category navigation
  [ "$status" -eq 0 ]
  [ "$output" = $'ID\tNAME\tCATEGORY\tPURPOSE\n  mgit\tMGit\tnavigation\tNavigate many repositories' ]
}

@test "explain reports declared and derived tool metadata" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain mgit

  [ "$status" -eq 0 ]
  [ "$output" = $'Tool: mgit\nName: MGit\nCategory: navigation (Navigation)\nPurpose: Navigate many repositories\nRationale: It presents the Knowledge Islands estate\nPlatforms: linux, macos\nRequires: git\nRelated: fzf\nAlternatives: lazygit\nProfiles: default (inherited), focused (direct), knowledge-islands (direct)\nBinding: marker (executable: mgit)' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain git
  [ "$status" -eq 0 ]
  [[ "$output" == *"Profiles: default (inherited), focused (required), knowledge-islands (inherited), minimal (direct)"* ]]
}

@test "explain validates binding ambiguity before writing stdout" {
  write_query_config
  printf '%s\n' \
    '[provider.second]' \
    'adapter = homebrew' \
    '[binding.mgit.second]' \
    'kind = formula' \
    'locator = other-mgit' \
    'platform = macos' >>"$CONFIG_HOME/rig.conf"

  error_file=$BATS_TEST_TMPDIR/explain-error-$BATS_TEST_NUMBER
  run bash -c 'error_file=$1; shift; "$@" 2>"$error_file"' _ "$error_file" \
    env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain mgit

  [ "$status" -eq 2 ]
  [ "$output" = "" ]
  error_output=$(<"$error_file")
  [[ "$error_output" == *"rig: error: tool 'mgit' has ambiguous bindings for platform 'macos'"* ]]
}

@test "catalogue queries never invoke a configured provider" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" show
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" list --profile default
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" explain mgit
  [ "$status" -eq 0 ]
  [ ! -e "$QUERY_MARKER" ]
}

@test "catalogue queries reject unknown identities with status two" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" list --category absent
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown category 'absent'"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" show --profile absent
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown profile 'absent'"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" explain absent
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown tool 'absent'"* ]]
  [ ! -e "$QUERY_MARKER" ]
}

@test "catalogue query syntax is strict and exits two" {
  write_query_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" show --profile
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig show [--profile NAME]"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" list --category navigation --category foundation
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig list [--category ID] [--profile NAME]"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" explain mgit extra
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig explain TOOL"* ]]

  missing_config=$BATS_TEST_TMPDIR/missing-config-$BATS_TEST_NUMBER
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" show --profile ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig show [--profile NAME]"* ]]
  [[ "$output" != *"cannot read configuration file"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" list --category ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig list [--category ID] [--profile NAME]"* ]]
  [[ "$output" != *"cannot read configuration file"* ]]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" list --profile ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: usage: rig list [--category ID] [--profile NAME]"* ]]
  [[ "$output" != *"cannot read configuration file"* ]]
}

@test "catalogue commands provide local help without loading configuration" {
  missing_config=$BATS_TEST_TMPDIR/missing-help-config-$BATS_TEST_NUMBER

  for flag in -h --help; do
    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" show "$flag"
    [ "$status" -eq 0 ]
    [ "$output" = "Usage: rig show [--profile NAME]" ]

    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" list "$flag"
    [ "$status" -eq 0 ]
    [ "$output" = "Usage: rig list [--category ID] [--profile NAME]" ]

    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" explain "$flag"
    [ "$status" -eq 0 ]
    [ "$output" = "Usage: rig explain TOOL" ]
  done
}

@test "installer links into overridden executable and manual directories" {
  install_bin=$BATS_TEST_TMPDIR/bin
  install_man=$BATS_TEST_TMPDIR/man/man1

  run env \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    "$BATS_TEST_DIRNAME/../install.sh" --link

  [ "$status" -eq 0 ]
  [ -L "$install_bin/rig" ]
  [ -L "$install_man/rig.1" ]
}

@test "invalid syntax is namespaced and exits two" {
  run "$RIG" unknown --help

  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown command: unknown"* ]]
}

@test "the executable is sourceable without dispatching the public CLI" {
  run bash -c '. "$1"; printf "sourced:%s\n" "$RIG_VERSION"' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = "sourced:0.1.0" ]
}

@test "configuration loads only the XDG root and bytewise ordered fragments" {
  mkdir -p "$TEST_HOME/.config/rig"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = elsewhere' \
    >"$TEST_HOME/.config/rig/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot read configuration file: $CONFIG_HOME/rig.conf"* ]]

  write_minimal_config
  printf '%s\n' \
    '[category.shared]' \
    'name = First' \
    'purpose = First declaration' >"$CONFIG_HOME/conf.d/B.conf"
  printf '%s\n' \
    '[category.shared]' \
    'name = Second' \
    'purpose = Second declaration' >"$CONFIG_HOME/conf.d/a.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" LC_ALL=C \
    bash -c '. "$1"; rig_load_config' _ "$RIG"

  [ "$status" -eq 2 ]
  [[ "$output" == *"a.conf:1: duplicate section [category.shared]"* ]]

  rm "$CONFIG_HOME/conf.d/a.conf"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = default' \
    >"$CONFIG_HOME/conf.d/root-again.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"root-again.conf:1: duplicate section [rig]"* ]]
}

@test "literal values are inert and only declared path fields expand leading tilde" {
  marker=$BATS_TEST_TMPDIR/executed
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Literals' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = Keep = and # literally' \
    "rationale = \$(touch $marker) # stays literal" \
    'platform = mac os' \
    'platform = linux,bsd' \
    '[profile.default]' \
    'tool = alpha' \
    '[provider.custom]' \
    'adapter = custom' \
    'executable = ~/bin/provider' \
    'manifest = ~/manifests/tools = private' \
    'command = ~/literal-command' \
    'argument = two words' \
    'argument = comma,kept' \
    '[binding.alpha.custom]' \
    'kind = executable' \
    'locator = ~/literal # locator = value' \
    '[publication.site]' \
    'profile = default' \
    'title = My # Rig' \
    'base-url = ~/literal-url' \
    'publisher = custom' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_get_value tool.alpha rationale; printf "rationale=%s\n" "$RIG_VALUE"
    rig_get_value tool.alpha platform 1; printf "platform-1=%s\n" "$RIG_VALUE"
    rig_get_value tool.alpha platform 2; printf "platform-2=%s\n" "$RIG_VALUE"
    rig_get_value provider.custom executable; printf "executable=%s\n" "$RIG_VALUE"
    rig_get_value provider.custom manifest; printf "manifest=%s\n" "$RIG_VALUE"
    rig_get_value provider.custom command; printf "command=%s\n" "$RIG_VALUE"
    rig_get_value provider.custom argument 1; printf "argument-1=%s\n" "$RIG_VALUE"
    rig_get_value provider.custom argument 2; printf "argument-2=%s\n" "$RIG_VALUE"
    rig_get_value binding.alpha.custom locator; printf "locator=%s\n" "$RIG_VALUE"
    rig_get_value publication.site base-url; printf "base-url=%s\n" "$RIG_VALUE"
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ ! -e "$marker" ]
  [[ "$output" == *"rationale=\$(touch $marker) # stays literal"* ]]
  [[ "$output" == *"platform-1=mac os"* ]]
  [[ "$output" == *"platform-2=linux,bsd"* ]]
  [[ "$output" == *"executable=$TEST_HOME/bin/provider"* ]]
  [[ "$output" == *"manifest=$TEST_HOME/manifests/tools = private"* ]]
  [[ "$output" == *"command=~/literal-command"* ]]
  [[ "$output" == *"argument-1=two words"* ]]
  [[ "$output" == *"argument-2=comma,kept"* ]]
  [[ "$output" == *"locator=~/literal # locator = value"* ]]
  [[ "$output" == *"base-url=~/literal-url"* ]]
}

@test "schema list fields preserve each declared item boundary" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Repeated fields' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = Exercise relationships' \
    'rationale = Keep relationship types distinct' \
    'platform = any' \
    'requires = beta' \
    'related = gamma' \
    'alternative = beta' \
    '[tool.beta]' \
    'name = Beta' \
    'category = core' \
    'purpose = Dependency' \
    'rationale = Required fixture' \
    'platform = any' \
    '[tool.gamma]' \
    'name = Gamma' \
    'category = core' \
    'purpose = Related tool' \
    'rationale = Related fixture' \
    'platform = any' \
    '[profile.base]' \
    'tool = gamma' \
    '[profile.default]' \
    'profile = base' \
    'profile = base' \
    'tool = alpha' \
    'tool = beta' \
    '[provider.native]' \
    'adapter = homebrew' \
    'command = brew' \
    'manifest = ~/Brewfile' \
    'argument = --file with spaces' \
    'capability = observe' \
    'capability = install,update' \
    '[binding.alpha.native]' \
    'kind = formula' \
    'locator = alpha' \
    'platform = any' \
    'argument = --binding value' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    for record in \
      "tool.alpha requires 1" \
      "tool.alpha related 1" \
      "tool.alpha alternative 1" \
      "profile.default profile 1" \
      "profile.default profile 2" \
      "profile.default tool 1" \
      "profile.default tool 2" \
      "provider.native capability 1" \
      "provider.native capability 2" \
      "binding.alpha.native argument 1"
    do
      set -- $record
      rig_get_value "$1" "$2" "$3" || exit
      printf "%s.%s.%s=%s\n" "$1" "$2" "$3" "$RIG_VALUE"
    done
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [[ "$output" == *"tool.alpha.requires.1=beta"* ]]
  [[ "$output" == *"tool.alpha.related.1=gamma"* ]]
  [[ "$output" == *"tool.alpha.alternative.1=beta"* ]]
  [[ "$output" == *"profile.default.profile.1=base"* ]]
  [[ "$output" == *"profile.default.profile.2=base"* ]]
  [[ "$output" == *"profile.default.tool.1=alpha"* ]]
  [[ "$output" == *"profile.default.tool.2=beta"* ]]
  [[ "$output" == *"provider.native.capability.1=observe"* ]]
  [[ "$output" == *"provider.native.capability.2=install,update"* ]]
  [[ "$output" == *"binding.alpha.native.argument.1=--binding value"* ]]
}

@test "schema version and root scalar cardinality fail closed" {
  write_minimal_config
  sed 's/schema = 1/schema = 2/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unsupported.conf"
  mv "$CONFIG_HOME/unsupported.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"unsupported schema version '2'"* ]]

  write_minimal_config
  sed '/schema = 1/d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/missing.conf"
  mv "$CONFIG_HOME/missing.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[rig] requires field 'schema'"* ]]

  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'schema = 1' \
    'default-profile = default' >"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate scalar field 'schema'"* ]]
}

@test "unknown grammar and malformed records fail closed" {
  write_minimal_config
  printf '%s\n' '[mystery.nope]' 'name = No' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid section identity [mystery.nope]"* ]]

  write_minimal_config
  printf '%s\n' 'unknown = field' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown field 'unknown'"* ]]

  printf '%s\n' 'schema = 1' >"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"field appears before a section"* ]]

  printf '%s\n' '[rig]' 'not a record' >"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"malformed record"* ]]
}

@test "section identities are strict and unique" {
  invalid_sections=(
    'category.Upper'
    'category.'
    'category.two.parts'
    'category.has space'
    'category.2fast'
    'binding.alpha'
    'binding.alpha.native.extra'
  )

  for section in "${invalid_sections[@]}"; do
    write_minimal_config
    printf '[%s]\n' "$section" >>"$CONFIG_HOME/rig.conf"
    run_loader
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid section identity [$section]"* ]]
  done

  write_minimal_config
  printf '%s\n' '[category.core]' 'name = Again' 'purpose = Duplicate' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate section [category.core]"* ]]
}

@test "required catalogue and custom provider fields are validated" {
  write_minimal_config
  sed '/rationale =/d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/missing.conf"
  mv "$CONFIG_HOME/missing.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[tool.alpha] requires field 'rationale'"* ]]

  write_minimal_config
  sed '/platform =/d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/missing.conf"
  mv "$CONFIG_HOME/missing.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[tool.alpha] requires field 'platform'"* ]]

  write_minimal_config
  printf '%s\n' '[provider.runner]' 'adapter = custom' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[provider.runner] requires field 'executable'"* ]]
}

@test "catalogue profile binding and publication references are validated" {
  write_minimal_config
  sed 's/category = core/category = absent/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown category 'absent'"* ]]

  write_minimal_config
  awk '{ print; if ($0 ~ /^rationale =/) print "requires = absent" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]]

  write_minimal_config
  sed 's/tool = alpha/tool = absent/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]]

  write_minimal_config
  printf '%s\n' \
    '[publication.site]' \
    'profile = absent' \
    'title = Site' \
    'base-url = https://example.test/' \
    'publisher = native' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown profile 'absent'"* ]]

  write_minimal_config
  printf '%s\n' \
    '[publication.site]' \
    'profile = default' \
    'title = Site' \
    'base-url = https://example.test/' \
    'publisher = absent' >>"$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]]

  write_minimal_config
  sed 's/binding.alpha.native/binding.alpha.absent/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]]

  write_minimal_config
  sed 's/binding.alpha.native/binding.absent.native/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]]
}

@test "profile and required-tool cycles fail before resolution" {
  write_minimal_config
  awk '{ print; if ($0 ~ /^\[profile.default\]$/) print "profile = default" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/cycle.conf"
  mv "$CONFIG_HOME/cycle.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile cycle includes 'default'"* ]]

  write_minimal_config
  awk '{ print; if ($0 ~ /^rationale =/) print "requires = alpha" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/cycle.conf"
  mv "$CONFIG_HOME/cycle.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"required-tool cycle includes 'alpha'"* ]]
}

@test "profiles compose and requirements resolve to a sorted platform-specific set" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = developer' \
    '[category.core]' \
    'name = Core' \
    'purpose = Test tools' \
    '[tool.zulu]' \
    'name = Zulu' \
    'category = core' \
    'purpose = Linux only' \
    'rationale = A platform fixture' \
    'platform = linux' \
    '[tool.beta]' \
    'name = Beta' \
    'category = core' \
    'purpose = Required anywhere' \
    'rationale = A dependency fixture' \
    'platform = any' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = macOS tool' \
    'rationale = A selected fixture' \
    'platform = macos' \
    'requires = beta' \
    '[profile.base]' \
    'tool = zulu' \
    'tool = alpha' \
    '[profile.developer]' \
    'tool = alpha' \
    'profile = base' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile "" macos || exit
    rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=developer\nplatform=macos\ntool=alpha\ntool=beta' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile base linux || exit
    rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=base\nplatform=linux\ntool=zulu' ]
}

@test "profile resolution is stable across declaration and fragment order" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[profile.default]' \
    'tool = zulu' \
    'tool = alpha' >"$CONFIG_HOME/rig.conf"
  printf '%s\n' \
    '[tool.zulu]' \
    'rationale = Z' \
    'platform = any' \
    'purpose = Z' \
    'category = core' \
    'name = Zulu' >"$CONFIG_HOME/conf.d/20-zulu.conf"
  printf '%s\n' \
    '[tool.alpha]' \
    'platform = any' \
    'name = Alpha' \
    'category = core' \
    'rationale = A' \
    'purpose = A' \
    '[category.core]' \
    'purpose = Stable output' \
    'name = Core' >"$CONFIG_HOME/conf.d/10-alpha.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default test-platform && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=test-platform\ntool=alpha\ntool=zulu' ]
}

@test "binding selection chooses exactly one compatible binding when requested" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Bindings' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = Select a binding' \
    'rationale = Binding fixture' \
    'platform = macos' \
    'platform = linux' \
    '[profile.default]' \
    'tool = alpha' \
    '[provider.brew]' \
    'adapter = homebrew' \
    '[provider.apt]' \
    'adapter = executable-adapter' \
    'executable = /optional/field/is/accepted' \
    '[binding.alpha.brew]' \
    'kind = formula' \
    'locator = alpha' \
    'platform = macos' \
    '[binding.alpha.apt]' \
    'kind = package' \
    'locator = alpha' \
    'platform = linux' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    rig_resolve_bindings || exit
    rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha\nbinding=alpha:brew' ]

  printf '%s\n' \
    '[provider.other]' \
    'adapter = anything' \
    '[binding.alpha.other]' \
    'kind = package' \
    'locator = other-alpha' >>"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings
  ' _ "$RIG"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ambiguous bindings"* ]]

  sed '/\[binding.alpha.brew\]/,/platform = macos/d' "$CONFIG_HOME/rig.conf" \
    | sed '/\[provider.other\]/,$d' >"$CONFIG_HOME/no-macos.conf"
  mv "$CONFIG_HOME/no-macos.conf" "$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings
  ' _ "$RIG"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no compatible binding"* ]]
}

@test "descriptive tools resolve without selecting materialisation bindings" {
  write_minimal_config
  sed '/\[binding.alpha.native\]/,$d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/descriptive.conf"
  mv "$CONFIG_HOME/descriptive.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha' ]
}

@test "binding resolution skips catalogue-only tools in a mixed profile" {
  write_minimal_config
  awk '{ print; if ($0 == "tool = alpha") print "tool = notes" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/mixed.conf"
  mv "$CONFIG_HOME/mixed.conf" "$CONFIG_HOME/rig.conf"
  printf '%s\n' \
    '[tool.notes]' \
    'name = Notes' \
    'category = core' \
    'purpose = Descriptive catalogue entry' \
    'rationale = It documents an unmaterialised choice' \
    'platform = any' >>"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha\nbinding=alpha:native\ntool=notes' ]
}

@test "supported tools reject unavailable required tools" {
  write_minimal_config
  awk '{ print; if ($0 == "rationale = A dependable test tool") print "requires = linux-only" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/required.conf"
  mv "$CONFIG_HOME/required.conf" "$CONFIG_HOME/rig.conf"
  printf '%s\n' \
    '[tool.linux-only]' \
    'name = Linux only' \
    'category = core' \
    'purpose = Incompatible required tool' \
    'rationale = It exercises the platform failure boundary' \
    'platform = linux' >>"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos
  ' _ "$RIG"

  [ "$status" -eq 2 ]
  [[ "$output" == *"requires 'linux-only', which does not support platform 'macos'"* ]]
}

@test "failed profile resolution clears prior resolved state" {
  write_minimal_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1" || exit
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    rig_resolve_profile absent macos >/dev/null 2>&1
    rig_resolve_bindings
  ' _ "$RIG"

  [ "$status" -eq 2 ]
  [[ "$output" == *"a profile must be resolved before bindings"* ]]
}

@test "binding platform any is universally compatible" {
  write_minimal_config
  printf '%s\n' 'platform = any' >>"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha\nbinding=alpha:native' ]
}

@test "status observes custom providers in stable dependency order with neutral catalogue-only tools" {
  write_orchestration_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 0 ]
  [ "$output" = $'Profile: default\nPlatform: macos\nTOOL\tPROVIDER\tSTATE\tDETAIL\nbase\trunner\tpresent\t-\napp\trunner\tpresent\t-\nindependent\trunner\tpresent\t-\nnotes\t-\tunavailable\tcatalogue-only\nSummary: present=3 missing=0 drifted=0 unavailable=1 unknown=0 catalogue-only=1' ]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=observe:base:present\nCALL=observe:app:present\nCALL=observe:independent:present' ]
}

@test "custom provider ABI preserves versioned literal argument boundaries" {
  write_orchestration_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 0 ]
  [ ! -e "$ORCHESTRATION_MARKER" ]
  run sed -n '1,9p' "$ORCHESTRATION_LOG"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' \
    BEGIN \
    "ARG=provider value;\$(touch $ORCHESTRATION_MARKER)" \
    ARG=rig-provider-v1 \
    ARG=observe \
    ARG=runner \
    ARG=base \
    ARG=executable \
    ARG=present \
    CALL=observe:base:present)" ]
  grep -F 'ARG=binding * value' "$ORCHESTRATION_LOG" >/dev/null
}

@test "apply custom provider ABI preserves versioned literal argument boundaries" {
  write_orchestration_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 0 ]
  [ ! -e "$ORCHESTRATION_MARKER" ]
  run sed -n '1,9p' "$ORCHESTRATION_LOG"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' \
    BEGIN \
    "ARG=provider value;\$(touch $ORCHESTRATION_MARKER)" \
    ARG=rig-provider-v1 \
    ARG=apply \
    ARG=runner \
    ARG=base \
    ARG=executable \
    ARG=present \
    CALL=apply:base:present)" ]
  grep -F 'ARG=binding * value' "$ORCHESTRATION_LOG" >/dev/null
}

@test "operational commands honour explicit profiles and ignore unselected providers" {
  write_orchestration_config
  printf '%s\n' \
    '[profile.focused]' \
    'tool = base' \
    '[provider.unselected]' \
    'adapter = custom' \
    "executable = $BATS_TEST_TMPDIR/missing-unselected-provider" \
    'capability = observe' \
    'capability = apply' >>"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status --profile focused
  [ "$status" -eq 0 ]
  [[ "$output" == $'Profile: focused\nPlatform: macos\nTOOL\tPROVIDER\tSTATE\tDETAIL\nbase\trunner\tpresent\t-'* ]] || false
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = 'CALL=observe:base:present' ]

  rm -f "$ORCHESTRATION_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply --profile focused
  [ "$status" -eq 0 ]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = 'CALL=apply:base:present' ]
}

@test "status accepts provider states and treats non-present bound tools as findings" {
  write_orchestration_config
  sed \
    -e '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = missing/' \
    -e '/\[binding.app.runner\]/,/\[binding.base.runner\]/ s/locator = present/locator = drifted/' \
    -e '/\[binding.independent.runner\]/,/^$/ s/locator = present/locator = unknown/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/states.conf"
  mv "$CONFIG_HOME/states.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tmissing\t-'* ]] || false
  [[ "$output" == *$'app\trunner\tdrifted\t-'* ]] || false
  [[ "$output" == *$'independent\trunner\tunknown\t-'* ]] || false
  [[ "$output" == *'Summary: present=0 missing=1 drifted=1 unavailable=1 unknown=1 catalogue-only=1'* ]] || false
}

@test "status converts protocol failure to unknown suppresses dependants and continues independent work" {
  write_orchestration_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = invalid-response/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/protocol.conf"
  mv "$CONFIG_HOME/protocol.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunknown\tinvalid-response'* ]] || false
  [[ "$output" == *$'app\trunner\tunknown\tblocked-by:base'* ]] || false
  [[ "$output" == *$'independent\trunner\tpresent\t-'* ]]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=observe:base:invalid-response\nCALL=observe:independent:present' ]
}

@test "status reports native observation failure without exposing provider exit as command status" {
  write_orchestration_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = exit-7/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/native-failure.conf"
  mv "$CONFIG_HOME/native-failure.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunknown\texit:7'* ]] || false
  [[ "$output" == *$'app\trunner\tunknown\tblocked-by:base'* ]] || false
  [[ "$output" == *$'independent\trunner\tpresent\t-'* ]] || false
}

@test "status rejects empty and multiline provider responses" {
  local response

  for response in empty multiline; do
    write_orchestration_config
    sed "/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = $response/" \
      "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/protocol-$response.conf"
    mv "$CONFIG_HOME/protocol-$response.conf" "$CONFIG_HOME/rig.conf"
    rm -f "$ORCHESTRATION_LOG"

    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
      RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

    [ "$status" -eq 1 ]
    [[ "$output" == *$'base\trunner\tunknown\tinvalid-response'* ]] || false
  done
}

@test "status reports unavailable operational provider boundaries without invocation" {
  write_orchestration_config
  sed 's/adapter = custom/adapter = homebrew/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unavailable.conf"
  mv "$CONFIG_HOME/unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\tunsupported-adapter:homebrew'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  write_orchestration_config
  sed '/capability = observe/d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unavailable.conf"
  mv "$CONFIG_HOME/unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\tunsupported-capability:observe'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  write_orchestration_config
  sed "s#executable = .*#executable = $BATS_TEST_TMPDIR/missing-provider#" \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unavailable.conf"
  mv "$CONFIG_HOME/unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\texecutable-unavailable'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "provider diagnostics remain on diagnostic channels" {
  local stdout_file stderr_file

  write_orchestration_config
  stdout_file=$BATS_TEST_TMPDIR/orchestration-stdout-$BATS_TEST_NUMBER
  stderr_file=$BATS_TEST_TMPDIR/orchestration-stderr-$BATS_TEST_NUMBER
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = diagnostics/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/diagnostics.conf"
  mv "$CONFIG_HOME/diagnostics.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" bash -c '"$1" status >"$2" 2>"$3"' \
    _ "$RIG" "$stdout_file" "$stderr_file"
  [ "$status" -eq 0 ]
  run cat "$stdout_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'base\trunner\tpresent\t-'* ]] || false
  [[ "$output" != *'observation-diagnostic'* ]] || false
  run cat "$stderr_file"
  [ "$status" -eq 0 ]
  [ "$output" = observation-diagnostic ]

  write_orchestration_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = diagnostics/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/diagnostics.conf"
  mv "$CONFIG_HOME/diagnostics.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" bash -c '"$1" apply >"$2" 2>"$3"' \
    _ "$RIG" "$stdout_file" "$stderr_file"
  [ "$status" -eq 0 ]
  run cat "$stdout_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'base\trunner\tcompleted\t-'* ]] || false
  [[ "$output" != *'application-stdout'* ]] || false
  [[ "$output" != *'application-stderr'* ]] || false
  run cat "$stderr_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *'application-stdout'* ]] || false
  [[ "$output" == *'application-stderr'* ]] || false
}

@test "apply preserves native exit detail while returning aggregate failure" {
  write_orchestration_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = exit-126/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/native-exit.conf"
  mv "$CONFIG_HOME/native-exit.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tfailed\texit:126'* ]] || false
}

@test "apply dry-run prints complete plan without invoking providers" {
  write_orchestration_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply --dry-run

  [ "$status" -eq 0 ]
  [ ! -e "$ORCHESTRATION_LOG" ]
  [ "$output" = $'Profile: default\nPlatform: macos\nTOOL\tPROVIDER\tRESULT\tDETAIL\nbase\trunner\tplanned\t-\napp\trunner\tplanned\t-\nindependent\trunner\tplanned\t-\nnotes\t-\tskipped\tcatalogue-only\nSummary: planned=3 completed=0 failed=0 skipped=1' ]
}

@test "apply suppresses failed dependants while continuing independent work" {
  write_orchestration_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = fail/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/failure.conf"
  mv "$CONFIG_HOME/failure.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tfailed\texit:7'* ]] || false
  [[ "$output" == *$'app\trunner\tskipped\tblocked-by:base'* ]] || false
  [[ "$output" == *$'independent\trunner\tcompleted\t-'* ]] || false
  [[ "$output" == *'Summary: planned=3 completed=1 failed=1 skipped=2'* ]] || false
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=apply:base:fail\nCALL=apply:independent:present' ]
}

@test "apply preflights every selected provider before mutation" {
  write_orchestration_config
  sed 's/\[binding.independent.runner\]/[binding.independent.bad]/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/preflight.conf"
  printf '%s\n' \
    '[provider.bad]' \
    'adapter = custom' \
    "executable = $BATS_TEST_TMPDIR/missing-provider" \
    'capability = apply' >>"$CONFIG_HOME/preflight.conf"
  mv "$CONFIG_HOME/preflight.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'bad' executable is unavailable"* ]]
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "apply capabilities are exact atomic literals" {
  write_orchestration_config
  sed \
    -e 's/capability = observe/capability = observe,apply/' \
    -e '/capability = apply/d' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/capability.conf"
  mv "$CONFIG_HOME/capability.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'apply'"* ]]
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "operational command help and syntax do not require configuration" {
  missing_config=$BATS_TEST_TMPDIR/missing-operational-help-$BATS_TEST_NUMBER

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" status --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig status [--profile NAME]' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" apply --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig apply [--profile NAME] [--dry-run]' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" apply --dry-run --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig apply [--profile NAME] [--dry-run]'* ]] || false
}
