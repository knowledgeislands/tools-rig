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

write_bootstrap_config() {
  write_orchestration_config
  sed '/^default-profile = default$/a\
bootstrap-profile = bootstrap' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bootstrap.conf"
  printf '%s\n' \
    '[profile.bootstrap]' \
    'tool = app' >>"$CONFIG_HOME/bootstrap.conf"
  mv "$CONFIG_HOME/bootstrap.conf" "$CONFIG_HOME/rig.conf"
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
  [[ "$output" == $'Profile:  default\nPlatform: macos\nTools:    100\n\nID'* ]] || false
  [[ "$output" == *'tool-100  Tool 100  category-1  Exercise deterministic catalogue query 100' ]] || false

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
  [[ "$output" == *"bootstrap [--profile NAME] [--dry-run]"* ]] || false
  [[ "$output" == *"run TOOL OPERATION [-- ARGUMENT...]"* ]] || false
  [[ "$output" == *"export PUBLICATION --output DIRECTORY"* ]] || false
  [[ "$output" == *"publish PUBLICATION"* ]] || false
  [[ "$output" == *"diag"* ]]
  [[ "$output" != *"paths"* ]]
  [[ "$output" == *"completion bash|zsh"* ]]
}

@test "completion and help provide command-local help" {
  for flag in -h --help; do
    run "$RIG" completion "$flag"

    [ "$status" -eq 0 ]
    [ "$output" = "Usage: rig completion bash|zsh" ]

    run "$RIG" help "$flag"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: rig [options] [command]"* ]]
  done
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
  [[ "$output" == *"-h --help -V --version show list explain status doctor apply bootstrap run export publish diag completion help"* ]] || false
  [[ "$output" == *'show) COMPREPLY=($(compgen -W "-h --help --profile"'* ]]
  [[ "$output" == *'explain) COMPREPLY=($(compgen -W "-h --help"'* ]]
  [[ "$output" == *'status) COMPREPLY=($(compgen -W "-h --help --profile"'* ]] || false
  [[ "$output" == *'doctor) COMPREPLY=($(compgen -W "-h --help --profile"'* ]] || false
  [[ "$output" == *'apply) COMPREPLY=($(compgen -W "-h --help --profile --dry-run"'* ]] || false
  [[ "$output" == *'bootstrap) COMPREPLY=($(compgen -W "-h --help --profile --dry-run"'* ]] || false
  [[ "$output" == *'run) COMPREPLY=($(compgen -W "-h --help --"'* ]] || false
  [[ "$output" == *'export) COMPREPLY=($(compgen -W "-h --help --output"'* ]] || false
  [[ "$output" == *'publish) COMPREPLY=($(compgen -W "-h --help"'* ]] || false
  [[ "$output" == *'completion) COMPREPLY=($(compgen -W "-h --help bash zsh"'* ]] || false
  [[ "$output" == *'help) COMPREPLY=($(compgen -W "-h --help"'* ]] || false
  [[ "$output" == *"show list explain status doctor apply bootstrap run export publish diag completion help"* ]] || false
  [[ "$output" != *" paths "* ]]

  run "$RIG" completion zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#compdef rig"* ]]
  [[ "$output" == *"compdef _rig rig"* ]]
  [[ "$output" == *"show:describe a resolved profile"* ]]
  [[ "$output" == *"diag:print runtime and configuration diagnostics"* ]]
  [[ "$output" == *"doctor:check whether a rig can operate"* ]]
  [[ "$output" == *"bootstrap:materialise the bootstrap profile"* ]] || false
  [[ "$output" == *"export:generate a static public rig"* ]] || false
  [[ "$output" == *"publish:deploy a static public rig"* ]] || false
  [[ "$output" == *"run:invoke a declared operation"* ]] || false
  [[ "$output" == *"run) _arguments"*"'3:separator:(--)'"* ]] || false
  [[ "$output" == *"'(-V --version)'{-V,--version}"* ]]
  [[ "$output" == *"explain) _arguments '(-h --help)'"* ]]
  [[ "$output" == *"completion) _arguments '(-h --help)'"* ]]
  [[ "$output" == *"help) _arguments '(-h --help)'"* ]]
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
      COMP_WORDS=(rig doctor --)
      COMP_CWORD=2
      _rig
      printf "doctor:%s\n" "${COMPREPLY[*]}"
      COMP_WORDS=(rig apply --)
      COMP_CWORD=2
      _rig
      printf "apply:%s\n" "${COMPREPLY[*]}"
      COMP_WORDS=(rig bootstrap --)
      COMP_CWORD=2
      _rig
      printf "bootstrap:%s\n" "${COMPREPLY[*]}"
      COMP_WORDS=(rig run --)
      COMP_CWORD=2
      _rig
      printf "run:%s\n" "${COMPREPLY[*]}"
 COMP_WORDS=(rig publish --)
 COMP_CWORD=2
 _rig
 printf "publish:%s\n" "${COMPREPLY[*]}"
 COMP_WORDS=(rig completion --)
 COMP_CWORD=2
 _rig
 printf "completion:%s\n" "${COMPREPLY[*]}"
 COMP_WORDS=(rig help --)
 COMP_CWORD=2
 _rig
 printf "help:%s\n" "${COMPREPLY[*]}"
 ' bash "$RIG"

  [ "$status" -eq 0 ]
  [[ "$output" == *"root:--help --version"* ]]
  [[ "$output" == *"show:--help --profile"* ]]
  [[ "$output" == *"explain:--help"* ]]
  [[ "$output" == *"status:--help --profile"* ]] || false
  [[ "$output" == *"doctor:--help --profile"* ]] || false
  [[ "$output" == *"apply:--help --profile --dry-run"* ]] || false
  [[ "$output" == *"bootstrap:--help --profile --dry-run"* ]] || false
 [[ "$output" == *"run:--help --"* ]] || false
 [[ "$output" == *"publish:--help"* ]] || false
 [[ "$output" == *"completion:--help"* ]] || false
 [[ "$output" == *"help:--help"* ]] || false

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
  [ "$output" = $'Profile:  default\nPlatform: macos\nTools:    3\n\nID    NAME  CATEGORY    PURPOSE\n----  ----  ----------  --------------------------\nfzf   fzf   navigation  Select entries quickly\ngit   Git   foundation  Track source history\nmgit  MGit  navigation  Navigate many repositories' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" show --profile minimal
  [ "$status" -eq 0 ]
  [ "$output" = $'Profile:  minimal\nPlatform: macos\nTools:    1\n\nID    NAME  CATEGORY    PURPOSE\n----  ----  ----------  --------------------\ngit   Git   foundation  Track source history' ]
}

@test "show bounds wide table rows and marks abbreviated values" {
  write_minimal_config
  long_purpose='Summarise a deliberately long purpose that would otherwise force the profile table beyond its stable terminal width and make the selected rig difficult to scan quickly'
  sed "s|purpose = Test parsing|purpose = $long_purpose|" \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/wide.conf"
  mv "$CONFIG_HOME/wide.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" show

  [ "$status" -eq 0 ]
  [ "${#lines[5]}" -eq 120 ]
  [[ "${lines[5]}" == *... ]]
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

@test "release installer validates both artifacts before installing either" {
  fake_bin=$BATS_TEST_TMPDIR/installer-bin-$BATS_TEST_NUMBER
  install_bin=$BATS_TEST_TMPDIR/installed-bin-$BATS_TEST_NUMBER
  install_man=$BATS_TEST_TMPDIR/installed-man-$BATS_TEST_NUMBER
  downloaded_bin=$BATS_TEST_TMPDIR/downloaded-rig-$BATS_TEST_NUMBER
  downloaded_man=$BATS_TEST_TMPDIR/downloaded-rig-man-$BATS_TEST_NUMBER
  mkdir -p "$fake_bin" "$install_bin" "$install_man"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" downloaded-rig' >"$downloaded_bin"
  printf '%s\n' 'not a Rig manual' >"$downloaded_man"
  printf '%s\n' old-rig >"$install_bin/rig"
  printf '%s\n' old-man >"$install_man/rig.1"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'case "$2" in' \
    '  */bin/rig) cp "$RIG_TEST_DOWNLOAD_BIN" "$4" ;;' \
    '  */man/rig.1)' \
    '    [ "${RIG_TEST_MANUAL_MODE:-fail}" = fail ] && exit 22' \
    '    cp "$RIG_TEST_DOWNLOAD_MAN" "$4"' \
    '    ;;' \
    '  *) exit 64 ;;' \
    'esac' >"$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  run env \
    PATH="$fake_bin:$PATH" \
    RIG_VERSION=v-test \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    RIG_TEST_DOWNLOAD_BIN=$downloaded_bin \
    RIG_TEST_DOWNLOAD_MAN=$downloaded_man \
    "$BATS_TEST_DIRNAME/../install.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"download failed: "*"/man/rig.1"* ]]
  [ "$(cat "$install_bin/rig")" = old-rig ]
  [ "$(cat "$install_man/rig.1")" = old-man ]

  run env \
    PATH="$fake_bin:$PATH" \
    RIG_VERSION=v-test \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    RIG_TEST_DOWNLOAD_BIN=$downloaded_bin \
    RIG_TEST_DOWNLOAD_MAN=$downloaded_man \
    RIG_TEST_MANUAL_MODE=invalid \
    "$BATS_TEST_DIRNAME/../install.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"downloaded file is not the Rig manual"* ]]
  [ "$(cat "$install_bin/rig")" = old-rig ]
  [ "$(cat "$install_man/rig.1")" = old-man ]

  printf '%s\n' '.TH RIG 1 "test" "Rig" "User Commands"' >"$downloaded_man"
  run env \
    PATH="$fake_bin:$PATH" \
    RIG_VERSION=v-test \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    RIG_TEST_DOWNLOAD_BIN=$downloaded_bin \
    RIG_TEST_DOWNLOAD_MAN=$downloaded_man \
    RIG_TEST_MANUAL_MODE=valid \
    "$BATS_TEST_DIRNAME/../install.sh"

  [ "$status" -eq 0 ]
  cmp "$downloaded_bin" "$install_bin/rig"
  cmp "$downloaded_man" "$install_man/rig.1"
  [ -x "$install_bin/rig" ]
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

@test "doctor gives a compact healthy synthesis using observation capabilities only" {
  write_orchestration_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor

  [ "$status" -eq 0 ]
  [ "$output" = $'Rig doctor: healthy\nProfile: default\nPlatform: macos\nSummary: findings=0 present=3 catalogue-only=1 incompatible-platform=0' ]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=observe:base:present\nCALL=observe:app:present\nCALL=observe:independent:present' ]
  ! grep -q '^CALL=apply:' "$ORCHESTRATION_LOG"
}

@test "doctor groups actionable findings while preserving shared state treatment" {
  write_orchestration_config
  sed \
    -e '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = missing/' \
    -e '/\[binding.app.runner\]/,/\[binding.base.runner\]/ s/locator = present/locator = drifted/' \
    -e '/\[binding.independent.runner\]/,/^$/ s/locator = present/locator = invalid-response/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/doctor-findings.conf"
  mv "$CONFIG_HOME/doctor-findings.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor

  [ "$status" -eq 1 ]
  [ "$output" = $'Rig doctor: findings\nProfile: default\nPlatform: macos\nTool findings:\n  base: missing via runner (-); owner=runner; action=run-rig-apply\n  app: drifted via runner (-); owner=runner; action=review-then-run-rig-apply\n  independent: unknown via runner (invalid-response); owner=runner; action=inspect-provider-diagnostics\nSummary: findings=3 present=0 catalogue-only=1 incompatible-platform=0' ]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=observe:base:missing\nCALL=observe:app:drifted\nCALL=observe:independent:invalid-response' ]
}

@test "doctor reports unavailable providers without invoking mutation" {
  write_orchestration_config
  sed "s#executable = .*#executable = $BATS_TEST_TMPDIR/missing-doctor-provider#" \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/doctor-unavailable.conf"
  mv "$CONFIG_HOME/doctor-unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor --profile default

  [ "$status" -eq 1 ]
  [[ "$output" == *'base: unavailable via runner (executable-unavailable); owner=runner; action=install-or-configure-provider'* ]] || false
  [[ "$output" == *'Summary: findings=3 present=0 catalogue-only=1 incompatible-platform=0'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "doctor reports inaccessible XDG application paths as configuration-owned findings" {
  write_orchestration_config
  data_path=$BATS_TEST_TMPDIR/doctor-data-file-$BATS_TEST_NUMBER
  touch "$data_path"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_path" \
    RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor

  [ "$status" -eq 1 ]
  [[ "$output" == *"data: $data_path; owner=configuration; action=replace-with-directory"* ]] || false
  [[ "$output" == *'Summary: findings=1 present=3 catalogue-only=1 incompatible-platform=0'* ]] || false
  ! grep -q '^CALL=apply:' "$ORCHESTRATION_LOG"
}

@test "doctor treats incompatible profile tools as information" {
  write_orchestration_config
  printf '%s\n' \
    '[tool.linux-only]' \
    'name = Linux only' \
    'category = core' \
    'purpose = Exercise incompatible doctor information' \
    'rationale = It is intentionally absent on macOS' \
    'platform = linux' >>"$CONFIG_HOME/rig.conf"
  awk '{ print; if ($0 == "tool = notes") print "tool = linux-only" }' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/doctor-platform.conf"
  mv "$CONFIG_HOME/doctor-platform.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *'linux-only: incompatible-platform; owner=catalogue; action=none'* ]] || false
  [[ "$output" == *'Summary: findings=0 present=3 catalogue-only=1 incompatible-platform=1'* ]] || false
}

@test "doctor reserves status 2 for syntax configuration and resolution failures" {
  missing_config=$BATS_TEST_TMPDIR/missing-doctor-config-$BATS_TEST_NUMBER

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" doctor
  [ "$status" -eq 2 ]
  [[ "$output" == *"cannot read configuration file: $missing_config/rig.conf"* ]] || false

  write_orchestration_config
  printf '%s\n' '[profile.broken]' 'tool = absent' >>"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  run "$RIG" doctor --profile
  [ "$status" -eq 2 ]
  [[ "$output" == *'rig: error: usage: rig doctor [--profile NAME]'* ]] || false

  run "$RIG" doctor --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig doctor [--profile NAME]' ]
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
  sed 's/adapter = custom/adapter = future/' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unavailable.conf"
  mv "$CONFIG_HOME/unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\tunsupported-adapter:future'* ]] || false
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

@test "bootstrap selects its declared profile with explicit and default fallbacks" {
  local bootstrap_output apply_output

  write_bootstrap_config
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap --dry-run
  [ "$status" -eq 0 ]
  bootstrap_output=$output
  [[ "$output" == $'Profile: bootstrap\nPlatform: macos'* ]] || false
  [[ "$output" == *$'base\trunner\tplanned\t-'* ]] || false
  [[ "$output" == *$'app\trunner\tplanned\t-'* ]] || false
  [[ "$output" != *$'independent\trunner'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply --profile bootstrap --dry-run
  [ "$status" -eq 0 ]
  apply_output=$output
  [ "$bootstrap_output" = "$apply_output" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap --profile default --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == $'Profile: default\nPlatform: macos'* ]] || false

  write_orchestration_config
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap --dry-run
  [ "$status" -eq 0 ]
  bootstrap_output=$output
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ "$bootstrap_output" = "$output" ]
}

@test "bootstrap and apply execute the same dependency-ordered provider plan" {
  local bootstrap_output bootstrap_log

  write_bootstrap_config
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap
  [ "$status" -eq 0 ]
  bootstrap_output=$output
  bootstrap_log=$(cat "$ORCHESTRATION_LOG")
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=apply:base:present\nCALL=apply:app:present' ]

  rm "$ORCHESTRATION_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply --profile bootstrap
  [ "$status" -eq 0 ]
  [ "$bootstrap_output" = "$output" ]
  [ "$bootstrap_log" = "$(cat "$ORCHESTRATION_LOG")" ]
}

@test "bootstrap preserves apply preflight and dependency failure boundaries" {
  write_bootstrap_config
  sed '/\[binding.base.runner\]/,/\[binding.independent.runner\]/ s/locator = present/locator = fail/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/failure.conf"
  mv "$CONFIG_HOME/failure.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tfailed\texit:7'* ]] || false
  [[ "$output" == *$'app\trunner\tskipped\tblocked-by:base'* ]] || false
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = 'CALL=apply:base:fail' ]

  write_bootstrap_config
  sed '/capability = apply/d' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/capability.conf"
  mv "$CONFIG_HOME/capability.conf" "$CONFIG_HOME/rig.conf"
  rm -f "$ORCHESTRATION_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'apply'"* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "bootstrap profile is an optional unique validated profile reference" {
  write_bootstrap_config
  sed '/^bootstrap-profile = bootstrap$/a\
bootstrap-profile = bootstrap' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bootstrap.conf"
  mv "$CONFIG_HOME/bootstrap.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate scalar field 'bootstrap-profile'"* ]] || false

  write_orchestration_config
  sed '/^default-profile = default$/a\
bootstrap-profile = absent' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bootstrap.conf"
  mv "$CONFIG_HOME/bootstrap.conf" "$CONFIG_HOME/rig.conf"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown bootstrap profile 'absent'"* ]] || false
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

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" bootstrap --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig bootstrap [--profile NAME] [--dry-run]' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" apply --dry-run --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig apply [--profile NAME] [--dry-run]'* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$missing_config" "$RIG" bootstrap --profile
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig bootstrap [--profile NAME] [--dry-run]'* ]] || false
}

@test "built-in adapters observe dry-run and apply with exact native commands" {
  local native_bin native_log executable
  native_bin=$BATS_TEST_TMPDIR/native-bin-$BATS_TEST_NUMBER
  native_log=$BATS_TEST_TMPDIR/native-log-$BATS_TEST_NUMBER
  mkdir -p "$native_bin"

  for executable in brew mas uv chezmoi; do
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'printf "%s" "${0##*/}" >>"$RIG_NATIVE_LOG"' \
      'for argument in "$@"; do printf "|%s" "$argument" >>"$RIG_NATIVE_LOG"; done' \
      'printf "\n" >>"$RIG_NATIVE_LOG"' \
      'case "${0##*/}:$*" in' \
      '  brew:*list*--formula*jq*) printf "jq 1.0\n" ;;' \
      '  brew:*list*--cask*visual-studio-code*) printf "visual-studio-code 1.0\n" ;;' \
      '  mas:*list*) printf "12345 Example\n" ;;' \
      '  uv:*tool*list*) printf "ruff v1.0\n" ;;' \
      'esac' >"$native_bin/$executable"
    chmod +x "$native_bin/$executable"
  done

  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = default' \
    '[category.core]' 'name = Core' 'purpose = Core tools' \
    '[tool.formula]' 'name = Formula' 'category = core' 'purpose = Formula test' \
    'rationale = Formula rationale' 'platform = any' \
    '[tool.cask]' 'name = Cask' 'category = core' 'purpose = Cask test' \
    'rationale = Cask rationale' 'platform = any' \
    '[tool.store]' 'name = Store' 'category = core' 'purpose = Store test' \
    'rationale = Store rationale' 'platform = any' \
    '[tool.python]' 'name = Python' 'category = core' 'purpose = Python test' \
    'rationale = Python rationale' 'platform = any' \
    '[tool.dotfile]' 'name = Dotfile' 'category = core' 'purpose = Dotfile test' \
    'rationale = Dotfile rationale' 'platform = any' \
    '[profile.default]' 'tool = formula' 'tool = cask' 'tool = store' \
    'tool = python' 'tool = dotfile' \
    '[provider.brew]' 'adapter = homebrew' "executable = $native_bin/brew" \
    'argument = --global value' 'capability = observe' 'capability = apply' \
    '[provider.store]' 'adapter = homebrew' \
    'capability = observe' 'capability = apply' \
    '[provider.python]' 'adapter = uv' \
    'capability = observe' 'capability = apply' \
    '[provider.dotfiles]' 'adapter = chezmoi' \
    'capability = observe' 'capability = apply' \
    '[provider.unselected]' 'adapter = uv' \
    "executable = $BATS_TEST_TMPDIR/missing-unselected" 'capability = observe' \
    '[binding.formula.brew]' 'kind = formula' 'locator = jq' 'argument = --formula value' \
    '[binding.cask.brew]' 'kind = cask' 'locator = visual-studio-code' \
    '[binding.store.store]' 'kind = mas' 'locator = 12345' \
    '[binding.python.python]' 'kind = tool' 'locator = ruff' \
    '[binding.dotfile.dotfiles]' 'kind = target' 'locator = /tmp/example target' \
    >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'formula\tbrew\tpresent\t-'* ]] || false
  [[ "$output" == *$'cask\tbrew\tpresent\t-'* ]] || false
  [[ "$output" == *$'store\tstore\tpresent\t-'* ]] || false
  [[ "$output" == *$'python\tpython\tpresent\t-'* ]] || false
  [[ "$output" == *$'dotfile\tdotfiles\tpresent\t-'* ]] || false
  [ "$(wc -l <"$native_log" | tr -d ' ')" -eq 5 ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$native_log" | tr -d ' ')" -eq 5 ]

  : >"$native_log"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$native_log")" = "$(printf '%s\n' \
    'brew|--global value|install|--cask|visual-studio-code' \
    'chezmoi|apply|--|/tmp/example target' \
    'brew|--global value|install|--formula|--formula value|jq' \
    'uv|tool|install|ruff' \
    'mas|install|12345')" ]
}

@test "built-in adapter native failures suppress only dependants" {
  local native native_log
  native=$BATS_TEST_TMPDIR/failing-brew-$BATS_TEST_NUMBER
  native_log=$BATS_TEST_TMPDIR/failing-brew-log-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >>"$RIG_NATIVE_LOG"' \
    'case "$*" in *broken*) exit 7 ;; esac' >"$native"
  chmod +x "$native"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = default' \
    '[category.core]' 'name = Core' 'purpose = Core tools' \
    '[tool.base]' 'name = Base' 'category = core' 'purpose = Base' \
    'rationale = Base' 'platform = any' \
    '[tool.app]' 'name = App' 'category = core' 'purpose = App' \
    'rationale = App' 'platform = any' 'requires = base' \
    '[tool.other]' 'name = Other' 'category = core' 'purpose = Other' \
    'rationale = Other' 'platform = any' \
    '[profile.default]' 'tool = app' 'tool = other' \
    '[provider.brew]' 'adapter = homebrew' "executable = $native" 'capability = apply' \
    '[binding.base.brew]' 'kind = formula' 'locator = broken' \
    '[binding.app.brew]' 'kind = formula' 'locator = app' \
    '[binding.other.brew]' 'kind = formula' 'locator = other' >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\tbrew\tfailed\texit:7'* ]] || false
  [[ "$output" == *$'app\tbrew\tskipped\tblocked-by:base'* ]] || false
  [[ "$output" == *$'other\tbrew\tcompleted\t-'* ]] || false
  [ "$(cat "$native_log")" = "$(printf '%s\n' 'install --formula broken' 'install --formula other')" ]
}

@test "selected unavailable built-in provider fails safely before mutation" {
  local missing
  missing=$BATS_TEST_TMPDIR/missing-brew-$BATS_TEST_NUMBER
  write_minimal_config
  sed "/adapter = homebrew/a\\
executable = $missing\\
capability = observe\\
capability = apply" "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/native.conf"
  mv "$CONFIG_HOME/native.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'alpha\tnative\tunavailable\texecutable-unavailable'* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'native' executable is unavailable: $missing"* ]] || false
}

@test "direct-download verifies before atomic executable replacement and cleans failures" {
  local downloader source_file destination digest bad_digest native_log
  downloader=$BATS_TEST_TMPDIR/curl-$BATS_TEST_NUMBER
  source_file=$BATS_TEST_TMPDIR/download-source-$BATS_TEST_NUMBER
  destination=$TEST_HOME/bin/downloaded-tool
  native_log=$BATS_TEST_TMPDIR/download-log-$BATS_TEST_NUMBER
  mkdir -p "$TEST_HOME/bin"
  printf '%s\n' 'download payload' >"$source_file"
  digest=$(shasum -a 256 "$source_file")
  digest=${digest%% *}
  bad_digest=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'for argument in "$@"; do printf "ARG=%s\n" "$argument" >>"$RIG_NATIVE_LOG"; done' \
    'destination=' \
    'while [ "$#" -gt 0 ]; do' \
    '  if [ "$1" = --output ]; then destination=$2; shift 2; else shift; fi' \
    'done' \
    'cp "$RIG_DOWNLOAD_SOURCE" "$destination"' \
    'if [ -n "${RIG_UNSAFE_DESTINATION:-}" ]; then' \
    '  rm -f "$RIG_UNSAFE_DESTINATION"' \
    '  mkdir "$RIG_UNSAFE_DESTINATION"' \
    'fi' >"$downloader"
  chmod +x "$downloader"

  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = default' \
    '[category.core]' 'name = Core' 'purpose = Core tools' \
    '[tool.download]' 'name = Download' 'category = core' 'purpose = Download test' \
    'rationale = Download rationale' 'platform = any' \
    '[profile.default]' 'tool = download' \
    '[provider.download]' 'adapter = direct-download' "executable = $downloader" \
    'capability = observe' 'capability = apply' \
    '[binding.download.download]' 'kind = executable' \
    'locator = https://example.invalid/downloaded-tool' \
    'destination = ~/bin/downloaded-tool' "checksum = sha256:$digest" >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'download\tdownload\tmissing\t-'* ]] || false
  [ ! -e "$native_log" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$destination" ]
  [ ! -e "$native_log" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" apply
  [ "$status" -eq 0 ]
  [ -x "$destination" ]
  [ "$(shasum -a 256 "$destination" | sed 's/ .*//')" = "$digest" ]
  [ "$(sed -n '1,8p' "$native_log")" = "$(printf '%s\n' \
    'ARG=--fail' 'ARG=--location' 'ARG=--proto' 'ARG==https' \
    'ARG=--proto-redir' 'ARG==https' 'ARG=--silent' 'ARG=--show-error')" ]
  [ "$(sed -n '9p' "$native_log")" = 'ARG=--output' ]
  [[ "$(sed -n '10p' "$native_log")" == ARG="$destination.rig-tmp."* ]]
  [ "$(sed -n '11p' "$native_log")" = 'ARG=https://example.invalid/downloaded-tool' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'download\tdownload\tpresent\t-'* ]] || false

  printf '%s\n' 'existing destination' >"$destination"
  chmod 0755 "$destination"
  sed "s/sha256:$digest/sha256:$bad_digest/" "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/bad.conf"
  mv "$CONFIG_HOME/bad.conf" "$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" apply
  [ "$status" -eq 1 ]
  [ "$(cat "$destination")" = 'existing destination' ]
  run bash -c 'compgen -G "$1.rig-tmp.*"' _ "$destination"
  [ "$status" -ne 0 ]

  sed "s/sha256:$bad_digest/sha256:$digest/" \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/race.conf"
  mv "$CONFIG_HOME/race.conf" "$CONFIG_HOME/rig.conf"
  printf '%s\n' 'existing destination' >"$destination"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" \
    RIG_UNSAFE_DESTINATION="$destination" "$RIG" apply
  [ "$status" -eq 1 ]
  [ -d "$destination" ]
  [ -z "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

@test "Homebrew mas bindings require numeric application identities" {
  write_minimal_config
  sed -e 's/kind = formula/kind = mas/' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/mas.conf"
  mv "$CONFIG_HOME/mas.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" status

  [ "$status" -eq 2 ]
  [[ "$output" == *'Homebrew mas locator must be a numeric application identity'* ]]
}

@test "direct-download rejects unsafe or incomplete declarations before mutation" {
  local downloader destination
  downloader=$BATS_TEST_TMPDIR/curl-$BATS_TEST_NUMBER
  destination=$TEST_HOME/unsafe-destination
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$downloader"
  chmod +x "$downloader"
  ln -s "$TEST_HOME/target" "$destination"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = default' \
    '[category.core]' 'name = Core' 'purpose = Core tools' \
    '[tool.download]' 'name = Download' 'category = core' 'purpose = Download test' \
    'rationale = Download rationale' 'platform = any' \
    '[profile.default]' 'tool = download' \
    '[provider.download]' 'adapter = direct-download' "executable = $downloader" \
    'capability = apply' \
    '[binding.download.download]' 'kind = executable' \
    'locator = https://example.invalid/downloaded-tool' \
    "destination = $destination" \
    'checksum = sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
    >"$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'refuses unsafe destination'* ]] || false

  sed 's#https://#http://#' "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/http.conf"
  mv "$CONFIG_HOME/http.conf" "$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'direct-download locator must use HTTPS'* ]] || false

  sed -e 's#http://#https://#' -e '/^checksum = /d' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/incomplete.conf"
  mv "$CONFIG_HOME/incomplete.conf" "$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'checksum'"* ]] || false

  printf '%s\n' \
    'checksum = sha256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
    >>"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'checksum must contain 64 lowercase hexadecimal characters'* ]] || false
}

write_publication_config() {
  PUBLICATION_PROVIDER=$BATS_TEST_TMPDIR/publication-provider-$BATS_TEST_NUMBER
  PUBLICATION_MARKER=$BATS_TEST_TMPDIR/publication-provider-marker-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf invoked >"$RIG_PUBLICATION_MARKER"' >"$PUBLICATION_PROVIDER"
  chmod +x "$PUBLICATION_PROVIDER"
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = private' \
    '[category.navigation]' \
    'name = Navigation & Search' \
    'purpose = Find <things> safely' \
    '[category.private]' \
    'name = Private category' \
    'purpose = Never disclose this category' \
    '[tool.alpha]' \
    'name = Alpha <One>' \
    'category = navigation' \
    'purpose = Find & select' \
    'rationale = Safer "choice" for public work' \
    'platform = any' \
    'related = beta' \
    'alternative = secret' \
    '[tool.beta]' \
    'name = Beta' \
    'category = navigation' \
    'purpose = Browse public material' \
    'rationale = Complements Alpha' \
    'platform = macos' \
    '[tool.secret]' \
    'name = Secret Tool' \
    'category = private' \
    'purpose = private-purpose-token' \
    'rationale = private-rationale-token' \
    'platform = any' \
    '[profile.public]' \
    'tool = alpha' \
    'tool = beta' \
    '[profile.private]' \
    'profile = public' \
    'tool = secret' \
    '[provider.publisher]' \
    'adapter = custom' \
    "executable = $PUBLICATION_PROVIDER" \
    'capability = publish' \
    'manifest = /private/provider-manifest-token' \
    'argument = provider-argument-token' \
    '[binding.alpha.publisher]' \
    'kind = executable' \
    'locator = private-locator-token' \
    'argument = binding-argument-token' \
    '[publication.site]' \
    'profile = public' \
    'title = Kris & Rig' \
    'base-url = https://example.test/rig/' \
    'publisher = publisher' >"$CONFIG_HOME/rig.conf"
}

@test "export writes escaped allow-listed public profile as complete static tree" {
  local destination file_count
  destination=$BATS_TEST_TMPDIR/public-site-$BATS_TEST_NUMBER
  write_publication_config
  mkdir -p "$destination/obsolete"
  printf '%s\n' stale >"$destination/obsolete/stale.txt"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PUBLICATION_MARKER="$PUBLICATION_MARKER" "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  [ "$output" = "Exported site to $destination" ]
  [ -f "$destination/index.html" ]
  [ -f "$destination/assets/rig.css" ]
  [ ! -e "$destination/obsolete/stale.txt" ]
  file_count=$(find "$destination" -type f | wc -l | tr -d ' ')
  [ "$file_count" -eq 2 ]
  grep -F 'Kris &amp; Rig' "$destination/index.html"
  grep -F 'Alpha &lt;One&gt;' "$destination/index.html"
  grep -F 'Find &amp; select' "$destination/index.html"
  grep -F 'Safer &quot;choice&quot; for public work' "$destination/index.html"
  grep -F 'Navigation &amp; Search' "$destination/index.html"
  grep -F 'href="https://example.test/rig/#tool-beta"' "$destination/index.html"
  ! grep -R -E 'Secret Tool|private-purpose-token|private-rationale-token|provider-manifest-token|provider-argument-token|private-locator-token|binding-argument-token' "$destination"
  [ ! -e "$PUBLICATION_MARKER" ]
}

@test "export closes relationships over selected public tools" {
  local destination
  destination=$BATS_TEST_TMPDIR/relationship-site-$BATS_TEST_NUMBER
  write_publication_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  grep -F '<dt>Related</dt>' "$destination/index.html"
  grep -F '>Beta <span class="identity">(beta)</span></a>' "$destination/index.html"
  ! grep -F '<dt>Alternatives</dt>' "$destination/index.html"
  ! grep -F '#tool-secret' "$destination/index.html"
}

@test "export is deterministic across equivalent declaration order" {
  local second_config first_output second_output
  second_config=$BATS_TEST_TMPDIR/config-reordered-$BATS_TEST_NUMBER
  first_output=$BATS_TEST_TMPDIR/site-first-$BATS_TEST_NUMBER
  second_output=$BATS_TEST_TMPDIR/site-second-$BATS_TEST_NUMBER
  write_publication_config
  mkdir -p "$second_config/conf.d"
  sed -e 's/tool = alpha/tool = temporary/' \
    -e 's/tool = beta/tool = alpha/' \
    -e 's/tool = temporary/tool = beta/' \
    "$CONFIG_HOME/rig.conf" >"$second_config/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$first_output"
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$second_config" RIG_PLATFORM=macos \
    "$RIG" export site --output "$second_output"
  [ "$status" -eq 0 ]
  diff -r "$first_output" "$second_output"
}

@test "export uses root subdomain and subpath base URLs for navigation" {
  local destination
  destination=$BATS_TEST_TMPDIR/url-site-$BATS_TEST_NUMBER
  write_publication_config
  sed 's#https://example.test/rig/#https://rig.example.test#' \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/root.conf"
  mv "$CONFIG_HOME/root.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  grep -F 'href="https://rig.example.test/assets/rig.css"' "$destination/index.html"
  grep -F 'href="https://rig.example.test/#catalogue"' "$destination/index.html"
  grep -F 'href="https://rig.example.test/#tool-beta"' "$destination/index.html"
}

@test "export invokes neither publisher provider nor network command" {
  local destination fake_bin network_marker network_command
  destination=$BATS_TEST_TMPDIR/offline-site-$BATS_TEST_NUMBER
  fake_bin=$BATS_TEST_TMPDIR/offline-bin-$BATS_TEST_NUMBER
  network_marker=$BATS_TEST_TMPDIR/network-marker-$BATS_TEST_NUMBER
  write_publication_config
  mkdir -p "$fake_bin"
  for network_command in curl wget ssh git; do
    printf '%s\n' '#!/usr/bin/env bash' 'printf invoked >"$RIG_NETWORK_MARKER"' 'exit 97' >"$fake_bin/$network_command"
    chmod +x "$fake_bin/$network_command"
  done

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PUBLICATION_MARKER="$PUBLICATION_MARKER" RIG_NETWORK_MARKER="$network_marker" \
    PATH="$fake_bin:$PATH" "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  [ ! -e "$PUBLICATION_MARKER" ]
  [ ! -e "$network_marker" ]
}

@test "export rejects malformed publication URL authorities" {
  local destination invalid_url

  destination=$BATS_TEST_TMPDIR/invalid-url-site-$BATS_TEST_NUMBER
  for invalid_url in 'https://:/' 'https://:bad/' 'https://user@example.test/' 'https://example.test:bad/'; do
    write_publication_config
    sed "s#https://example.test/rig/#$invalid_url#" \
      "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/invalid.conf"
    mv "$CONFIG_HOME/invalid.conf" "$CONFIG_HOME/rig.conf"

    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
      "$RIG" export site --output "$destination"

    [ "$status" -eq 2 ]
    [ ! -e "$destination" ]
  done
}

@test "export rejects unsafe output targets without altering them" {
  local regular target symlink
  regular=$BATS_TEST_TMPDIR/export-file-$BATS_TEST_NUMBER
  target=$BATS_TEST_TMPDIR/export-target-$BATS_TEST_NUMBER
  symlink=$BATS_TEST_TMPDIR/export-link-$BATS_TEST_NUMBER
  write_publication_config
  printf '%s\n' keep >"$regular"
  mkdir -p "$target"
  printf '%s\n' keep >"$target/keep.txt"
  ln -s "$target" "$symlink"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output /
  [ "$status" -eq 2 ]
  [[ "$output" == *'unsafe export output directory'* ]] || false
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output .
  [ "$status" -eq 2 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output ..
  [ "$status" -eq 2 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$regular"
  [ "$status" -eq 2 ]
  [ "$(cat "$regular")" = keep ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$symlink"
  [ "$status" -eq 2 ]
  [ "$(cat "$target/keep.txt")" = keep ]
}

@test "export help and syntax are local and explicit" {
  run "$RIG" export --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig export PUBLICATION --output DIRECTORY' ]

  run "$RIG" export site
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig export PUBLICATION --output DIRECTORY'* ]] || false
}

write_publish_config() {
  write_publication_config
  PUBLISH_LOG=$BATS_TEST_TMPDIR/publish-log-$BATS_TEST_NUMBER
  OTHER_PUBLISH_LOG=$BATS_TEST_TMPDIR/other-publish-log-$BATS_TEST_NUMBER
  OTHER_PUBLISHER=$BATS_TEST_TMPDIR/other-publisher-$BATS_TEST_NUMBER

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "BEGIN\n" >>"$RIG_PUBLISH_LOG"' \
    'for argument in "$@"; do printf "ARG=<%s>\n" "$argument" >>"$RIG_PUBLISH_LOG"; done' \
    'if [ -n "${RIG_PUBLISH_SWAP_TARGET:-}" ]; then' \
    '  for argument in "$@"; do stage=$argument; done' \
    '  root=${stage%/*}' \
    '  stage_name=${stage##*/}' \
    '  mv -- "$root" "$RIG_PUBLISH_SWAP_MOVED"' \
    '  ln -s -- "$RIG_PUBLISH_SWAP_TARGET" "$root"' \
    '  mkdir -p -- "$RIG_PUBLISH_SWAP_TARGET/$stage_name/assets"' \
    '  printf victim >"$RIG_PUBLISH_SWAP_TARGET/$stage_name/index.html"' \
    '  printf victim >"$RIG_PUBLISH_SWAP_TARGET/$stage_name/assets/rig.css"' \
    'fi' \
    'if [ "${RIG_PUBLISH_SIGNAL:-}" = term ]; then kill -TERM "$PPID"; exit 0; fi' \
    '[ -z "${RIG_PUBLISH_STDOUT:-}" ] || printf "%s\n" "$RIG_PUBLISH_STDOUT"' \
    '[ -z "${RIG_PUBLISH_STDERR:-}" ] || printf "%s\n" "$RIG_PUBLISH_STDERR" >&2' \
    'exit "${RIG_PUBLISH_EXIT:-0}"' >"$PUBLICATION_PROVIDER"
  chmod +x "$PUBLICATION_PROVIDER"

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf invoked >"$RIG_OTHER_PUBLISH_LOG"' >"$OTHER_PUBLISHER"
  chmod +x "$OTHER_PUBLISHER"
  printf '%s\n' \
    '[provider.other-publisher]' \
    'adapter = custom' \
    "executable = $OTHER_PUBLISHER" \
    'capability = publish' >>"$CONFIG_HOME/rig.conf"
}

@test "publish renders one isolated export and invokes only the selected publisher" {
  local cache cache_real stage expected
  cache=$BATS_TEST_TMPDIR/publish-cache-$BATS_TEST_NUMBER
  write_publish_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" \
    RIG_OTHER_PUBLISH_LOG="$OTHER_PUBLISH_LOG" RIG_PUBLISH_STDOUT='publisher stdout' \
    "$RIG" publish site

  [ "$status" -eq 0 ]
  [[ "$output" == *'publisher stdout'* ]] || false
  [[ "$output" == *'Published site via publisher'* ]] || false
  stage=$(sed -n '8p' "$PUBLISH_LOG")
  stage=${stage#ARG=<}
  stage=${stage%>}
  cache_real=$(cd "$cache/publish" && pwd -P)
  case "$stage" in
    "$cache_real"/site.rig-publish.*) ;;
    *) false ;;
  esac
  [ "${stage#/}" != "$stage" ]
  [ ! -e "$stage" ]
  [ ! -e "$OTHER_PUBLISH_LOG" ]
  expected=$(printf '%s\n' \
    'BEGIN' \
    'ARG=<provider-argument-token>' \
    'ARG=<rig-provider-v1>' \
    'ARG=<publish>' \
    'ARG=<publisher>' \
    'ARG=<site>' \
    'ARG=<directory>' \
    "ARG=<$stage>")
  [ "$(cat "$PUBLISH_LOG")" = "$expected" ]
  [ -z "$(find "$cache/publish" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

@test "publish preserves native failure and complete staging tree for diagnosis" {
  local cache native_exit stage file_count
  cache=$BATS_TEST_TMPDIR/publish-failure-cache-$BATS_TEST_NUMBER
  write_publish_config

  for native_exit in 7 126; do
    rm -f "$PUBLISH_LOG"
    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
      RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" \
      RIG_OTHER_PUBLISH_LOG="$OTHER_PUBLISH_LOG" RIG_PUBLISH_EXIT="$native_exit" \
      RIG_PUBLISH_STDERR='publisher stderr' \
      "$RIG" publish site

    [ "$status" -eq "$native_exit" ]
    [[ "$output" == *'publisher stderr'* ]] || false
    stage=$(printf '%s\n' "$output" | sed -n 's/^rig: publish failed; retained export: //p')
    [ -d "$stage" ]
    [ -f "$stage/index.html" ]
    [ -f "$stage/assets/rig.css" ]
    file_count=$(find "$stage" -type f | wc -l | tr -d ' ')
    [ "$file_count" -eq 2 ]
    [ ! -e "$OTHER_PUBLISH_LOG" ]
    rm -rf -- "$stage"
  done
}

@test "publish interruption retains complete staging tree and returns signal status" {
  local cache stage
  cache=$BATS_TEST_TMPDIR/publish-interrupt-cache-$BATS_TEST_NUMBER
  write_publish_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" \
    RIG_OTHER_PUBLISH_LOG="$OTHER_PUBLISH_LOG" RIG_PUBLISH_SIGNAL=term \
    "$RIG" publish site

  [ "$status" -eq 143 ]
  stage=$(printf '%s\n' "$output" | sed -n 's/^rig: publish interrupted; retained export: //p')
  [ -f "$stage/index.html" ]
  [ -f "$stage/assets/rig.css" ]
  [ ! -e "$OTHER_PUBLISH_LOG" ]
  rm -rf -- "$stage"
}

@test "publish interruption before handoff removes incomplete staging" {
  local cache root stage

  cache=$BATS_TEST_TMPDIR/publish-pre-dispatch-interrupt-$BATS_TEST_NUMBER
  mkdir -p "$cache/publish"
  root=$(cd "$cache/publish" && pwd -P)
  stage=$root/site.rig-publish.partial
  mkdir -p "$stage/assets"
  printf partial >"$stage/index.html"

  run env RIG_TEST_ROOT="$root" RIG_TEST_STAGE="$stage" /bin/bash -c '
    . "$1"
    RIG_PUBLISH_ROOT=$RIG_TEST_ROOT
    RIG_PUBLISH_STAGE=$RIG_TEST_STAGE
    RIG_PUBLISH_COMPLETE=0
    rig_publish_interrupted 143
  ' bash "$RIG"

  [ "$status" -eq 143 ]
  [[ "$output" == *'publish interrupted before publisher handoff'* ]] || false
  [[ "$output" != *'retained export'* ]] || false
  [ ! -e "$stage" ]
}

@test "publish staging failure invokes no publisher" {
  local cache

  cache=$BATS_TEST_TMPDIR/publish-staging-failure-$BATS_TEST_NUMBER
  write_publish_config
  mkdir -p "$cache"
  printf blocked >"$cache/publish"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" \
    "$RIG" publish site

  [ "$status" -eq 2 ]
  [[ "$output" == *'cannot create publication cache directory'* ]] || false
  [ ! -e "$PUBLISH_LOG" ]
  [ "$(cat "$cache/publish")" = blocked ]
}

@test "publish cleanup refuses a swapped cache parent without traversing it" {
  local cache cache_real moved stage stage_name victim

  cache=$BATS_TEST_TMPDIR/publish-parent-swap-$BATS_TEST_NUMBER
  victim=$cache/victim
  mkdir -p "$cache" "$victim"
  cache_real=$(cd "$cache" && pwd -P)
  moved=$cache_real/publish-moved
  victim=$cache_real/victim
  write_publish_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache_real" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" \
    RIG_PUBLISH_SWAP_TARGET="$victim" RIG_PUBLISH_SWAP_MOVED="$moved" \
    "$RIG" publish site

  [ "$status" -eq 2 ]
  [[ "$output" == *'cannot safely remove publication staging directory'* ]] || false
  [[ "$output" == *'publisher succeeded but publication staging cleanup failed'* ]] || false
  stage=$(sed -n '8p' "$PUBLISH_LOG")
  stage=${stage#ARG=<}
  stage=${stage%>}
  stage_name=${stage##*/}
  [ -L "$cache_real/publish" ]
  [ "$(cat "$victim/$stage_name/index.html")" = victim ]
  [ "$(cat "$victim/$stage_name/assets/rig.css")" = victim ]
  [ -f "$moved/$stage_name/index.html" ]
  [ -f "$moved/$stage_name/assets/rig.css" ]

  rm -- "$cache_real/publish"
  rm -rf -- "$moved" "$victim"
}

@test "publish rejects invalid selection and capability boundaries before export or invocation" {
  local cache original
  cache=$BATS_TEST_TMPDIR/publish-reject-cache-$BATS_TEST_NUMBER
  write_publish_config
  original=$BATS_TEST_TMPDIR/publish-original-$BATS_TEST_NUMBER
  cp "$CONFIG_HOME/rig.conf" "$original"

  sed '/^capability = publish$/d' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'publish'"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]
  [ ! -e "$cache/publish" ]

  sed -e 's/adapter = custom/adapter = homebrew/' \
    -e 's/kind = executable/kind = formula/' \
    "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires a custom publisher"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  sed "s#executable = $PUBLICATION_PROVIDER#executable = $BATS_TEST_TMPDIR/missing-publisher#" \
    "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"publisher 'publisher' executable unavailable"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  sed 's#base-url = https://example.test/rig/#base-url = https://user@example.test/#' \
    "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *'must not contain user information'* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  cp "$original" "$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish absent
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown publication 'absent'"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]
}

@test "publish help and syntax are local and explicit" {
  run "$RIG" publish --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig publish PUBLICATION' ]

  run "$RIG" publish
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig publish PUBLICATION'* ]] || false
}

write_operation_config() {
  OPERATION_LOG=$BATS_TEST_TMPDIR/operation-log-$BATS_TEST_NUMBER
  OPERATION_PROVIDER=$BATS_TEST_TMPDIR/operation-provider-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "BEGIN\n" >>"$RIG_OPERATION_LOG"' \
    'for argument in "$@"; do printf "ARG=<%s>\n" "$argument" >>"$RIG_OPERATION_LOG"; done' \
    '[ -z "${RIG_OPERATION_STDOUT:-}" ] || printf "%s\n" "$RIG_OPERATION_STDOUT"' \
    '[ -z "${RIG_OPERATION_STDERR:-}" ] || printf "%s\n" "$RIG_OPERATION_STDERR" >&2' \
    'exit "${RIG_OPERATION_EXIT:-0}"' >"$OPERATION_PROVIDER"
  chmod +x "$OPERATION_PROVIDER"

  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = default' \
    '[category.core]' \
    'name = Core' \
    'purpose = Core tools' \
    '[tool.alpha]' \
    'name = Alpha' \
    'category = core' \
    'purpose = Exercise declared operations' \
    'rationale = Keeps host actions configuration-led' \
    'platform = macos' \
    'platform = linux' \
    '[profile.default]' \
    'tool = alpha' \
    '[provider.runner]' \
    'adapter = custom' \
    "executable = $OPERATION_PROVIDER" \
    'argument = provider value;$(touch provider-marker)' \
    'capability = audit' \
    'capability = restart' \
    '[operation.alpha.audit]' \
    'provider = runner' \
    'capability = audit' \
    'mode = observe' \
    'description = Inspect Alpha' \
    'platform = macos' \
    'argument = configured value' \
    'argument = configured * literal' \
    'allow-argument = --verbose' \
    'allow-argument = value with spaces' \
    'allow-argument = semi;$(touch caller-marker)' \
    '[operation.alpha.restart]' \
    'provider = runner' \
    'capability = restart' \
    'mode = mutate' \
    'description = Restart Alpha' \
    'argument = restart now' >"$CONFIG_HOME/rig.conf"
}

@test "run dispatches declared observe and mutate operations with literal arguments" {
  local expected
  write_operation_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" RIG_OPERATION_STDOUT='operation stdout' \
    RIG_OPERATION_STDERR='operation stderr' RIG_OPERATION_EXIT=7 \
    "$RIG" run alpha audit -- --verbose 'value with spaces' --verbose 'semi;$(touch caller-marker)'

  [ "$status" -eq 7 ]
  [[ "$output" == *'operation stdout'* ]] || false
  [[ "$output" == *'operation stderr'* ]] || false
  expected=$(printf '%s\n' \
    'BEGIN' \
    'ARG=<provider value;$(touch provider-marker)>' \
    'ARG=<rig-provider-v1>' \
    'ARG=<observe>' \
    'ARG=<runner>' \
    'ARG=<alpha>' \
    'ARG=<operation>' \
    'ARG=<audit>' \
    'ARG=<configured value>' \
    'ARG=<configured * literal>' \
    'ARG=<--verbose>' \
    'ARG=<value with spaces>' \
    'ARG=<--verbose>' \
    'ARG=<semi;$(touch caller-marker)>')
  [ "$(cat "$OPERATION_LOG")" = "$expected" ]

  rm -f "$OPERATION_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha restart

  [ "$status" -eq 0 ]
  expected=$(printf '%s\n' \
    'BEGIN' \
    'ARG=<provider value;$(touch provider-marker)>' \
    'ARG=<rig-provider-v1>' \
    'ARG=<apply>' \
    'ARG=<runner>' \
    'ARG=<alpha>' \
    'ARG=<operation>' \
    'ARG=<restart>' \
    'ARG=<restart now>')
  [ "$(cat "$OPERATION_LOG")" = "$expected" ]
}

@test "run rejects undeclared caller arguments and unsupported platforms before invocation" {
  local argument
  write_operation_config

  for argument in '' verbose '--verbose=yes' 'VALUE WITH SPACES'; do
    rm -f "$OPERATION_LOG"
    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
      RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit -- "$argument"
    [ "$status" -eq 2 ]
    [[ "$output" == *'argument is not allowed'* ]] || false
    [ ! -e "$OPERATION_LOG" ]
  done

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"operation 'alpha audit' is not supported on platform 'linux'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha restart -- --verbose
  [ "$status" -eq 2 ]
  [ ! -e "$OPERATION_LOG" ]
}

@test "operation schema rejects invalid trust declarations before invocation" {
  local original
  write_operation_config
  original=$BATS_TEST_TMPDIR/operation-original-$BATS_TEST_NUMBER
  cp "$CONFIG_HOME/rig.conf" "$original"

  sed 's/mode = observe/mode = execute/' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"mode must be 'observe' or 'mutate'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed '/\[operation.alpha.audit\]/,$ s/capability = audit/capability = undeclared/' \
    "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'undeclared'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/provider = runner/provider = absent/' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/adapter = custom/adapter = homebrew/' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *'operations require a custom provider'* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed '/description = Inspect Alpha/d' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'description'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/\[operation.alpha.audit\]/[operation.ghost.audit]/' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'ghost'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/\[operation.alpha.audit\]/[operation.alpha.audit.extra]/' "$original" >"$CONFIG_HOME/rig.conf"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *'invalid section identity [operation.alpha.audit.extra]'* ]] || false
  [ ! -e "$OPERATION_LOG" ]
}

@test "run rejects unavailable provider and exposes local help" {
  write_operation_config
  sed "s#executable = $OPERATION_PROVIDER#executable = $BATS_TEST_TMPDIR/missing-operation-provider#" \
    "$CONFIG_HOME/rig.conf" >"$CONFIG_HOME/unavailable.conf"
  mv "$CONFIG_HOME/unavailable.conf" "$CONFIG_HOME/rig.conf"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run alpha audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'runner' executable unavailable"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  run "$RIG" run --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig run TOOL OPERATION [-- ARGUMENT...]' ]

  run "$RIG" run alpha
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig run TOOL OPERATION [-- ARGUMENT...]'* ]] || false
}
