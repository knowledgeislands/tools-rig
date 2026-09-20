#!/usr/bin/env bats

setup() {
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
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
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Essential tools"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "Test parsing"' \
    'rationale = "A dependable test tool"' \
    'platforms = ["any"]' \
    'install.provider = "native"' \
    'install.kind = "formula"' \
    'install.locator = "alpha"' \
    'install.platforms = ["any"]' \
    '[profile.default]' \
    'tools = ["alpha"]' \
    '[provider.native]' \
    'adapter = "homebrew"' >"$CONFIG_HOME/rig.toml"
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
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Orchestration fixtures"' \
    '[tool.app]' \
    'name = "App"' \
    'category = "core"' \
    'purpose = "Exercise a dependent tool"' \
    'rationale = "It verifies dependency ordering"' \
    'platforms = ["any"]' \
    'requires = ["base"]' \
    'install.provider = "runner"' \
    'install.kind = "executable"' \
    'install.locator = "present"' \
    'install.arguments = ["install * value"]' \
    '[tool.base]' \
    'name = "Base"' \
    'category = "core"' \
    'purpose = "Exercise a prerequisite"' \
    'rationale = "It must run before app"' \
    'platforms = ["any"]' \
    'install.provider = "runner"' \
    'install.kind = "executable"' \
    'install.locator = "present"' \
    '[tool.independent]' \
    'name = "Independent"' \
    'category = "core"' \
    'purpose = "Exercise an independent branch"' \
    'rationale = "It still runs after another branch fails"' \
    'platforms = ["any"]' \
    'install.provider = "runner"' \
    'install.kind = "executable"' \
    'install.locator = "present"' \
    '[tool.notes]' \
    'name = "Notes"' \
    'category = "core"' \
    'purpose = "Exercise catalogue-only state"' \
    'rationale = "It is descriptive rather than materialised"' \
    'platforms = ["any"]' \
    '[profile.default]' \
    'tools = ["app", "independent", "notes"]' \
    '[provider.runner]' \
    'adapter = "custom"' \
    "executable = \"$ORCHESTRATION_PROVIDER\"" \
    "arguments = [\"provider value;\$(touch $ORCHESTRATION_MARKER)\"]" \
    'capabilities = ["observe", "apply"]' \
    >"$CONFIG_HOME/rig.toml"
}

write_bootstrap_config() {
  write_orchestration_config
  sed '/^default-profile = "default"$/a\
bootstrap-profile = "bootstrap"' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bootstrap.toml"
  printf '%s\n' \
    '[profile.bootstrap]' \
    'tools = ["app"]' >>"$CONFIG_HOME/bootstrap.toml"
  mv "$CONFIG_HOME/bootstrap.toml" "$CONFIG_HOME/rig.toml"
}

run_loader() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    bash -c '. "$1"; rig_load_config' _ "$RIG"
}

@test "large catalogue queries preserve deterministic results without provider execution" {
  write_large_catalogue_fixture "$CONFIG_HOME/rig.toml"

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
  [[ "$output" == *"Installation: fixture (formula: fixture/tool-100)"* ]] || false
}

@test "sourceable model indexes every large catalogue field within its section span" {
  write_large_catalogue_fixture "$CONFIG_HOME/rig.toml"

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
  [ "$output" = "sections=211 fields=1616 lookup=tool.tool-100" ]
}

write_query_config() {
  QUERY_MARKER=$BATS_TEST_TMPDIR/provider-invoked-$BATS_TEST_NUMBER
  QUERY_PROVIDER=$BATS_TEST_TMPDIR/provider-$BATS_TEST_NUMBER
  printf '#!/usr/bin/env bash\nprintf invoked >"%s"\n' "$QUERY_MARKER" >"$QUERY_PROVIDER"
  chmod +x "$QUERY_PROVIDER"

  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.foundation]' \
    'name = "Foundation"' \
    'purpose = "Core command-line foundations"' \
    '[category.navigation]' \
    'name = "Navigation"' \
    'purpose = "Move through Knowledge Islands"' \
    '[profile.minimal]' \
    'tools = ["git"]' \
    '[profile.knowledge-islands]' \
    'profiles = ["minimal"]' \
    'tools = ["mgit"]' \
    '[profile.focused]' \
    'tools = ["mgit"]' \
    '[profile.default]' \
    'profiles = ["knowledge-islands"]' \
    'tools = ["fzf"]' \
    '[provider.marker]' \
    'adapter = "custom"' \
    "executable = \"$QUERY_PROVIDER\"" >"$CONFIG_HOME/rig.toml"

  printf '%s\n' \
    '[tool.lazygit]' \
    'name = "LazyGit"' \
    'category = "navigation"' \
    'purpose = "Browse Git interactively"' \
    'rationale = "It is a visual alternative"' \
    'platforms = ["any"]' >"$CONFIG_HOME/conf.d/10-lazygit.toml"
  printf '%s\n' \
    '[tool.git]' \
    'name = "Git"' \
    'category = "foundation"' \
    'purpose = "Track source history"' \
    'rationale = "Other navigation tools depend on it"' \
    'platforms = ["any"]' >"$CONFIG_HOME/conf.d/20-git.toml"
  printf '%s\n' \
    '[tool.mgit]' \
    'name = "MGit"' \
    'category = "navigation"' \
    'purpose = "Navigate many repositories"' \
    'rationale = "It presents the Knowledge Islands estate"' \
    'platforms = ["macos", "linux"]' \
    'requires = ["git"]' \
    'related = ["fzf"]' \
    'alternatives = ["lazygit"]' \
    'install.provider = "marker"' \
    'install.kind = "executable"' \
    'install.locator = "mgit"' \
    'install.platforms = ["macos"]' >"$CONFIG_HOME/conf.d/30-mgit.toml"
  printf '%s\n' \
    '[tool.fzf]' \
    'name = "fzf"' \
    'category = "navigation"' \
    'purpose = "Select entries quickly"' \
    'rationale = "It makes navigation concise"' \
    'platforms = ["any"]' >"$CONFIG_HOME/conf.d/40-fzf.toml"
}

@test "help describes the current command surface" {
  run "$RIG" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rig [options] [command]"* ]]
  [[ "$output" == *"Describe and manage a person's working setup."* ]]
  [[ "$output" == *"show [--profile NAME]"* ]]
  [[ "$output" == *"list [--category ID] [--profile NAME]"* ]]
  [[ "$output" == *"explain TOOL"* ]]
  [[ "$output" == *"status [--profile NAME] [--unmanaged]"* ]] || false
  [[ "$output" == *"doctor [--profile NAME]"* ]] || false
  [[ "$output" == *"apply [--profile NAME] [--dry-run]"* ]] || false
  [[ "$output" == *"bootstrap [--profile NAME] [--dry-run]"* ]] || false
  [[ "$output" == *"run PROVIDER ACTION [-- ARGUMENT...]"* ]] || false
  [[ "$output" == *"export PUBLICATION --output DIRECTORY"* ]] || false
  [[ "$output" == *"publish PUBLICATION"* ]] || false
  [[ "$output" == *"clean [--dry-run]"* ]] || false
  [[ "$output" == *"diag"* ]]
  [[ "$output" != *"paths"* ]]
  [[ "$output" == *"completion bash|zsh"* ]]
  [[ "$output" == *"help"* ]]
}

@test "public command inventory stays aligned across documentation" {
  repo_root=$BATS_TEST_DIRNAME/..
  bash_completion=$("$RIG" completion bash)
  zsh_completion=$("$RIG" completion zsh)
  man_synopsis=$(sed -n '/^.SH SYNOPSIS/,/^.SH DESCRIPTION/p' "$repo_root/man/rig.1")

  for command in show list explain status doctor apply bootstrap run export publish clean diag completion help; do
    grep -Fq "\`rig $command" "$repo_root/README.md"
    grep -Fq "\`rig $command" "$repo_root/CHANGELOG.md"
    grep -Fq "\`rig $command" "$repo_root/docs/guides/user/commands.md"
    grep -Fq "rig $command" "$repo_root/man/rig.1"
    [[ "$bash_completion" == *" $command"* ]] || false
    [[ "$zsh_completion" == *"$command:"* ]] || false
  done

  for synopsis in \
    'show [--profile NAME]' \
    'list [--category ID] [--profile NAME]' \
    'explain TOOL|service:ID|scheduled-job:ID' \
    'status [--profile NAME] [--unmanaged]' \
    'doctor [--profile NAME]' \
    'apply [--profile NAME] [--dry-run]' \
    'bootstrap [--profile NAME] [--dry-run]' \
    'run PROVIDER ACTION [-- ARGUMENT...]' \
    'export PUBLICATION --output DIRECTORY' \
    'publish PUBLICATION' \
    'clean [--dry-run]' \
    'diag' \
    'completion bash|zsh' \
    'help [-h|--help]'; do
    grep -Fq "\`rig $synopsis\`" "$repo_root/README.md"
    grep -Fq "\`rig $synopsis\`" "$repo_root/CHANGELOG.md"
    grep -Fq "\`rig $synopsis\`" "$repo_root/docs/guides/user/commands.md"
  done

  grep -Fq 'rig --help' "$repo_root/README.md"
  grep -Fq 'rig --version' "$repo_root/README.md"
  grep -Fq 'rig --help' "$repo_root/CHANGELOG.md"
  grep -Fq 'rig --version' "$repo_root/CHANGELOG.md"
  grep -Fq 'rig --help' "$repo_root/docs/guides/user/commands.md"
  grep -Fq 'rig --version' "$repo_root/docs/guides/user/commands.md"
  [[ "$man_synopsis" == *$'.B rig status\n.RI [ \\-\\-profile " NAME" ]\n.RI [ \\-\\-unmanaged ]'* ]] || false
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
  [ "$output" = "rig 0.2.0" ]
}

@test "diag reports stable runtime, default paths, and missing configuration" {
  run env \
    HOME="$TEST_HOME" \
    RIG_CONFIG_HOME= RIG_DATA_HOME= RIG_STATE_HOME= RIG_CACHE_HOME= \
    XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_STATE_HOME= XDG_CACHE_HOME= \
    RIG_PLATFORM=fixture \
    "$RIG" diag

  [ "$status" -eq 1 ]
  [ "$output" = "$(printf 'Runtime:\n  Rig version: 0.2.0\n  Executable: %s\n  Bash version: %s\n  Platform: fixture\nPaths:\n  Config home: %s/.config/rig\n  Data home: %s/.local/share/rig\n  State home: %s/.local/state/rig\n  Cache home: %s/.cache/rig\nConfiguration:\n  Root config: %s/.config/rig/rig.toml (absent)\n  Fragment count: 0\n  Status: missing' "$RIG" "$BASH_VERSION" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME")" ]
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
  [[ "$output" == *"  Root config: /tmp/rig-config/rig/rig.toml"* ]]
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
  [[ "$output" == *"  Root config: /tmp/custom-config/rig.toml"* ]]
}

@test "completion emits shell registration" {
  run "$RIG" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"complete -F _rig rig"* ]]
  [[ "$output" == *"-h --help -V --version show list explain status doctor apply bootstrap run export publish clean diag completion help"* ]] || false
  [[ "$output" == *'show) COMPREPLY=($(compgen -W "-h --help --profile"'* ]]
  [[ "$output" == *'explain) COMPREPLY=($(compgen -W "-h --help"'* ]]
  [[ "$output" == *'status) COMPREPLY=($(compgen -W "-h --help --profile --unmanaged"'* ]] || false
  [[ "$output" == *'doctor) COMPREPLY=($(compgen -W "-h --help --profile"'* ]] || false
  [[ "$output" == *'apply) COMPREPLY=($(compgen -W "-h --help --profile --dry-run"'* ]] || false
  [[ "$output" == *'bootstrap) COMPREPLY=($(compgen -W "-h --help --profile --dry-run"'* ]] || false
  [[ "$output" == *'run) COMPREPLY=($(compgen -W "-h --help --"'* ]] || false
  [[ "$output" == *'export) COMPREPLY=($(compgen -W "-h --help --output"'* ]] || false
  [[ "$output" == *'publish) COMPREPLY=($(compgen -W "-h --help"'* ]] || false
  [[ "$output" == *'clean) COMPREPLY=($(compgen -W "-h --help --dry-run"'* ]] || false
  [[ "$output" == *'completion) COMPREPLY=($(compgen -W "-h --help bash zsh"'* ]] || false
  [[ "$output" == *'help) COMPREPLY=($(compgen -W "-h --help"'* ]] || false
  [[ "$output" == *"show list explain status doctor apply bootstrap run export publish clean diag completion help"* ]] || false
  [[ "$output" != *" paths "* ]]

  run "$RIG" completion zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#compdef rig"* ]]
  [[ "$output" == *"compdef _rig rig"* ]]
  [[ "$output" == *"show:describe a resolved profile"* ]]
  [[ "$output" == *"diag:print runtime and configuration diagnostics"* ]]
  [[ "$output" == *"doctor:check whether a rig can operate"* ]]
  [[ "$output" == *"bootstrap:materialise the bootstrap profile"* ]] || false
  [[ "$output" == *"export:generate public rig data"* ]] || false
  [[ "$output" == *"publish:publish public rig data"* ]] || false
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
    COMP_WORDS=(rig clean --)
    COMP_CWORD=2
    _rig
    printf "clean:%s\n" "${COMPREPLY[*]}"
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
 [[ "$output" == *"clean:--help --dry-run"* ]] || false
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
  printf '%s\n' '# first fragment' >"$CONFIG_HOME/conf.d/10-first.toml"
  printf '%s\n' '# second fragment' >"$CONFIG_HOME/conf.d/20-second.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    XDG_DATA_HOME= XDG_STATE_HOME= XDG_CACHE_HOME= RIG_PLATFORM=fixture "$RIG" diag

  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'Runtime:\n  Rig version: 0.2.0\n  Executable: %s\n  Bash version: %s\n  Platform: fixture\nPaths:\n  Config home: %s\n  Data home: %s/.local/share/rig\n  State home: %s/.local/state/rig\n  Cache home: %s/.cache/rig\nConfiguration:\n  Root config: %s/rig.toml\n  Fragment count: 2\n  Status: valid\n  Schema: 1\n  Default profile: default' "$RIG" "$BASH_VERSION" "$CONFIG_HOME" "$TEST_HOME" "$TEST_HOME" "$TEST_HOME" "$CONFIG_HOME")" ]
}

@test "diag accepts fragment-only configuration and reports the optional root absent" {
  write_minimal_config
  mv "$CONFIG_HOME/rig.toml" "$CONFIG_HOME/conf.d/20-complete.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=fixture "$RIG" diag

  [ "$status" -eq 0 ]
  [[ "$output" == *"  Root config: $CONFIG_HOME/rig.toml (absent)"* ]] || false
  [[ "$output" == *"  Fragment count: 1"* ]] || false
  [[ "$output" == *"  Status: valid"* ]] || false
  [[ "$output" == *"  Schema: 1"* ]] || false
}

@test "diag summarizes invalid configuration without parser diagnostics" {
  printf '%s\n' '[rig]' 'schema = 2' 'default-profile = "default"' >"$CONFIG_HOME/rig.toml"

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
  sed "s|purpose = \"Test parsing\"|purpose = \"$long_purpose\"|" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/wide.toml"
  mv "$CONFIG_HOME/wide.toml" "$CONFIG_HOME/rig.toml"

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

  mv "$CONFIG_HOME/conf.d/10-lazygit.toml" "$CONFIG_HOME/conf.d/swap.toml"
  mv "$CONFIG_HOME/conf.d/40-fzf.toml" "$CONFIG_HOME/conf.d/10-lazygit.toml"
  mv "$CONFIG_HOME/conf.d/swap.toml" "$CONFIG_HOME/conf.d/40-fzf.toml"
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
  [ "$output" = $'Tool: mgit\nName: MGit\nCategory: navigation (Navigation)\nPurpose: Navigate many repositories\nRationale: It presents the Knowledge Islands estate\nPlatforms: linux, macos\nRequires: git\nRelated: fzf\nAlternatives: lazygit\nProfiles: default (inherited), focused (direct), knowledge-islands (direct)\nInstallation: marker (executable: mgit)' ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain git
  [ "$status" -eq 0 ]
  [[ "$output" == *"Profiles: default (inherited), focused (required), knowledge-islands (inherited), minimal (direct)"* ]]
}

@test "source configuration rejects former binding tables before writing stdout" {
  write_query_config
  printf '%s\n' \
    '[provider.second]' \
    'adapter = "homebrew"' \
    '[binding.mgit.second]' \
    'kind = "formula"' \
    'locator = "other-mgit"' \
    'platforms = ["macos"]' >>"$CONFIG_HOME/rig.toml"

  error_file=$BATS_TEST_TMPDIR/explain-error-$BATS_TEST_NUMBER
  run bash -c 'error_file=$1; shift; "$@" 2>"$error_file"' _ "$error_file" \
    env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain mgit

  [ "$status" -eq 2 ]
  [ "$output" = "" ]
  error_output=$(<"$error_file")
  [[ "$error_output" == *"invalid section identity [binding.mgit.second]"* ]]
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
    [ "$output" = "Usage: rig explain TOOL|service:ID|scheduled-job:ID" ]
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
    RIG_VERSION=v0.1.0 \
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
    RIG_VERSION=v0.1.0 \
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
    RIG_VERSION=v0.1.0 \
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

@test "release installer positional version takes precedence over environment" {
  fake_bin=$BATS_TEST_TMPDIR/pinned-installer-bin-$BATS_TEST_NUMBER
  install_bin=$BATS_TEST_TMPDIR/pinned-installed-bin-$BATS_TEST_NUMBER
  install_man=$BATS_TEST_TMPDIR/pinned-installed-man-$BATS_TEST_NUMBER
  curl_log=$BATS_TEST_TMPDIR/pinned-curl-log-$BATS_TEST_NUMBER
  mkdir -p "$fake_bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$2" >>"$RIG_TEST_CURL_LOG"' \
    'case "$2" in' \
    '  */bin/rig) printf "%s\n" "#!/usr/bin/env bash" "exit 0" >"$4" ;;' \
    '  */man/rig.1) printf "%s\n" ".TH RIG 1 \"test\" \"Rig\" \"User Commands\"" >"$4" ;;' \
    '  *) exit 70 ;;' \
    'esac' >"$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  run env \
    PATH="$fake_bin:$PATH" \
    RIG_VERSION=v9.9.9 \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    RIG_TEST_CURL_LOG=$curl_log \
    "$BATS_TEST_DIRNAME/../install.sh" v0.1.0

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$curl_log")" = \
    "https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.1.0/bin/rig" ]
  [ "$(sed -n '2p' "$curl_log")" = \
    "https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.1.0/man/rig.1" ]
  [ "$(wc -l <"$curl_log" | tr -d ' ')" -eq 2 ]
}

@test "release installer unpinned invocation discovers the latest exact release" {
  fake_bin=$BATS_TEST_TMPDIR/latest-installer-bin-$BATS_TEST_NUMBER
  install_bin=$BATS_TEST_TMPDIR/latest-installed-bin-$BATS_TEST_NUMBER
  install_man=$BATS_TEST_TMPDIR/latest-installed-man-$BATS_TEST_NUMBER
  curl_log=$BATS_TEST_TMPDIR/latest-curl-log-$BATS_TEST_NUMBER
  mkdir -p "$fake_bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$2" >>"$RIG_TEST_CURL_LOG"' \
    'case "$2" in' \
    '  https://api.github.com/*) printf "%s\n" "{\"tag_name\":\"v0.2.3\"}" ;;' \
    '  */bin/rig) printf "%s\n" "#!/usr/bin/env bash" "exit 0" >"$4" ;;' \
    '  */man/rig.1) printf "%s\n" ".TH RIG 1 \"test\" \"Rig\" \"User Commands\"" >"$4" ;;' \
    '  *) exit 70 ;;' \
    'esac' >"$fake_bin/curl"
  chmod +x "$fake_bin/curl"

  run env \
    PATH="$fake_bin:$PATH" \
    RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man \
    RIG_TEST_CURL_LOG=$curl_log \
    "$BATS_TEST_DIRNAME/../install.sh"

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$curl_log")" = \
    "https://api.github.com/repos/knowledgeislands/tools-rig/releases/latest" ]
  [ "$(sed -n '2p' "$curl_log")" = \
    "https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.3/bin/rig" ]
  [ "$(sed -n '3p' "$curl_log")" = \
    "https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.3/man/rig.1" ]
}

@test "release installer rejects invalid versions before download or replacement" {
  fake_bin=$BATS_TEST_TMPDIR/invalid-installer-bin-$BATS_TEST_NUMBER
  install_bin=$BATS_TEST_TMPDIR/invalid-installed-bin-$BATS_TEST_NUMBER
  install_man=$BATS_TEST_TMPDIR/invalid-installed-man-$BATS_TEST_NUMBER
  curl_marker=$BATS_TEST_TMPDIR/invalid-curl-marker-$BATS_TEST_NUMBER
  mkdir -p "$fake_bin" "$install_bin" "$install_man"
  printf '%s\n' '#!/usr/bin/env bash' 'touch "$RIG_TEST_CURL_MARKER"' 'exit 70' \
    >"$fake_bin/curl"
  chmod +x "$fake_bin/curl"
  printf '%s\n' old-rig >"$install_bin/rig"
  printf '%s\n' old-man >"$install_man/rig.1"

  run env PATH="$fake_bin:$PATH" RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man RIG_TEST_CURL_MARKER=$curl_marker \
    "$BATS_TEST_DIRNAME/../install.sh" 1.2.3
  [ "$status" -eq 2 ]
  [[ "$output" == *"version must match vX.Y.Z: 1.2.3"* ]]

  run env PATH="$fake_bin:$PATH" RIG_VERSION=main RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man RIG_TEST_CURL_MARKER=$curl_marker \
    "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"RIG_VERSION must match vX.Y.Z: main"* ]]

  run env PATH="$fake_bin:$PATH" RIG_INSTALL_DIR=$install_bin \
    RIG_MAN_INSTALL_DIR=$install_man RIG_TEST_CURL_MARKER=$curl_marker \
    "$BATS_TEST_DIRNAME/../install.sh" v0.1.0 extra
  [ "$status" -eq 2 ]
  [ ! -e "$curl_marker" ]
  [ "$(cat "$install_bin/rig")" = old-rig ]
  [ "$(cat "$install_man/rig.1")" = old-man ]
}

@test "release installer help is local and documents exact version pinning" {
  run "$BATS_TEST_DIRNAME/../install.sh" --help

  [ "$status" -eq 0 ]
  [ "$output" = "Usage: ./install.sh [vX.Y.Z|--link]

Install the latest released Rig, pin an exact release, or link a local checkout." ]
}

@test "invalid syntax is namespaced and exits two" {
  run "$RIG" unknown --help

  [ "$status" -eq 2 ]
  [[ "$output" == *"rig: error: unknown command: unknown"* ]]
}

@test "the executable is sourceable without dispatching the public CLI" {
  run bash -c '. "$1"; printf "sourced:%s\n" "$RIG_VERSION"' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = "sourced:0.2.0" ]
}

@test "configuration loads only the XDG root and bytewise ordered fragments" {
  mkdir -p "$TEST_HOME/.config/rig"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "elsewhere"' \
    >"$TEST_HOME/.config/rig/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"no configuration sources under: $CONFIG_HOME"* ]]

  write_minimal_config
  mv "$CONFIG_HOME/rig.toml" "$CONFIG_HOME/conf.d/20-complete.toml"
  run_loader
  [ "$status" -eq 0 ]
  rm "$CONFIG_HOME/conf.d/20-complete.toml"

  write_minimal_config
  printf '%s\n' \
    '[category.shared]' \
    'name = "First"' \
    'purpose = "First declaration"' >"$CONFIG_HOME/conf.d/B.toml"
  printf '%s\n' \
    '[category.shared]' \
    'name = "Second"' \
    'purpose = "Second declaration"' >"$CONFIG_HOME/conf.d/a.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" LC_ALL=C \
    bash -c '. "$1"; rig_load_config' _ "$RIG"

  [ "$status" -eq 2 ]
  [[ "$output" == *"a.toml:1: duplicate section [category.shared]"* ]]

  rm "$CONFIG_HOME/conf.d/a.toml"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    >"$CONFIG_HOME/conf.d/root-again.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"root-again.toml:1: duplicate section [rig]"* ]]
}

@test "literal values are inert and only declared path fields expand leading tilde" {
  marker=$BATS_TEST_TMPDIR/executed
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Literals"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "Keep = and # literally"' \
    "rationale = \"\$(touch $marker) # stays literal\"" \
    'platforms = ["mac os", "linux,bsd"]' \
    'install.provider = "custom"' \
    'install.kind = "executable"' \
    'install.locator = "~/literal # locator = value"' \
    '[profile.default]' \
    'tools = ["alpha"]' \
    '[provider.custom]' \
    'adapter = "custom"' \
    'executable = "~/bin/provider"' \
    'manifest = "~/manifests/tools = private"' \
    'command = "~/literal-command"' \
    'arguments = ["two words", "comma,kept"]' \
    '[publication.site]' \
    'profile = "default"' \
    'title = "My # Rig"' \
    'base-url = "~/literal-url"' \
    'publisher = "custom"' >"$CONFIG_HOME/rig.toml"

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
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Repeated fields"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "Exercise relationships"' \
    'rationale = "Keep relationship types distinct"' \
    'platforms = ["any"]' \
    'requires = ["beta"]' \
    'related = ["gamma"]' \
    'alternatives = ["beta"]' \
    'install.provider = "native"' \
    'install.kind = "formula"' \
    'install.locator = "alpha"' \
    'install.platforms = ["any"]' \
    'install.arguments = ["--install value"]' \
    '[tool.beta]' \
    'name = "Beta"' \
    'category = "core"' \
    'purpose = "Dependency"' \
    'rationale = "Required fixture"' \
    'platforms = ["any"]' \
    '[tool.gamma]' \
    'name = "Gamma"' \
    'category = "core"' \
    'purpose = "Related tool"' \
    'rationale = "Related fixture"' \
    'platforms = ["any"]' \
    '[profile.base]' \
    'tools = ["gamma"]' \
    '[profile.default]' \
    'profiles = ["base", "base"]' \
    'tools = ["alpha", "beta"]' \
    '[provider.native]' \
    'adapter = "homebrew"' \
    'command = "brew"' \
    'manifest = "~/Brewfile"' \
    'arguments = ["--file with spaces"]' \
    'capabilities = ["observe", "install,update"]' >"$CONFIG_HOME/rig.toml"

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
  [[ "$output" == *"binding.alpha.native.argument.1=--install value"* ]]
}

@test "configuration sources are interoperable TOML with inert inline comments" {
  write_minimal_config
  sed 's/name = "Alpha"/name = "Alpha # One" # retained hash, discarded comment/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/inline.toml"
  mv "$CONFIG_HOME/inline.toml" "$CONFIG_HOME/rig.toml"

  run python3 -c \
    'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
    "$CONFIG_HOME/rig.toml"
  [ "$status" -eq 0 ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" explain alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *'Name: Alpha # One'* ]] || false
}

@test "bounded TOML rejects valid constructs outside the Rig schema subset" {
  write_minimal_config
  sed "s/name = \"Core\"/name = 'Core'/" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'expected TOML basic string'* ]] || false

  write_minimal_config
  sed 's/schema = 1/schema = 1.0/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"field 'schema' must be a decimal integer"* ]] || false

  write_minimal_config
  sed 's/platforms = \["any"\]/platforms = [1]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'TOML arrays must contain basic strings'* ]] || false

  write_minimal_config
  sed 's/name = "Core"/name = "\\u0043ore"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run python3 -c \
    'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
    "$CONFIG_HOME/rig.toml"
  [ "$status" -eq 0 ]
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"unsupported TOML string escape '\\u'"* ]] || false

  write_minimal_config
  awk '{
    if ($0 == "tools = [\"alpha\"]") {
      print "tools = ["
      print "  \"alpha\","
      print "]"
    } else {
      print
    }
  }' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run python3 -c \
    'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
    "$CONFIG_HOME/rig.toml"
  [ "$status" -eq 0 ]
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *'expected single-line TOML string array'* ]] || false
}

@test "schema version and root scalar cardinality fail closed" {
  write_minimal_config
  sed 's/schema = 1/schema = 2/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsupported.toml"
  mv "$CONFIG_HOME/unsupported.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"unsupported schema version '2'"* ]]

  write_minimal_config
  sed '/schema = 1/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/missing.toml"
  mv "$CONFIG_HOME/missing.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[rig] requires field 'schema'"* ]]

  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'schema = 1' \
    'default-profile = "default"' >"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate field 'schema'"* ]]
}

@test "unknown grammar and malformed records fail closed" {
  write_minimal_config
  printf '%s\n' '[mystery.nope]' 'name = "No"' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid section identity [mystery.nope]"* ]]

  write_minimal_config
  printf '%s\n' 'unknown = field' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown field 'unknown'"* ]]

  printf '%s\n' 'schema = 1' >"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"field appears before a section"* ]]

  printf '%s\n' '[rig]' 'not a record' >"$CONFIG_HOME/rig.toml"
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
    printf '[%s]\n' "$section" >>"$CONFIG_HOME/rig.toml"
    run_loader
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid section identity [$section]"* ]]
  done

  write_minimal_config
  printf '%s\n' '[category.core]' 'name = "Again"' 'purpose = "Duplicate"' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate section [category.core]"* ]]
}

@test "required catalogue and provider adapter fields are validated" {
  write_minimal_config
  sed '/rationale =/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/missing.toml"
  mv "$CONFIG_HOME/missing.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[tool.alpha] requires field 'rationale'"* ]]

  write_minimal_config
  sed '/platforms =/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/missing.toml"
  mv "$CONFIG_HOME/missing.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[tool.alpha] requires field 'platform'"* ]]

  write_minimal_config
  printf '%s\n' '[provider.runner]' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"[provider.runner] requires field 'adapter'"* ]]
}

@test "catalogue, profile, installation, and publication references are validated" {
  write_minimal_config
  sed 's/category = "core"/category = "absent"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown category 'absent'"* ]]

  write_minimal_config
  awk '{ print; if ($0 ~ /^rationale =/) print "requires = [\"absent\"]" }' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]]

  write_minimal_config
  sed 's/tools = \["alpha"\]/tools = ["absent"]/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown tool 'absent'"* ]]

  write_minimal_config
  printf '%s\n' \
    '[publication.site]' \
    'profile = "absent"' \
    'title = "Site"' \
    'base-url = "https://example.test/"' \
    'publisher = "native"' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown profile 'absent'"* ]]

  write_minimal_config
  printf '%s\n' \
    '[publication.site]' \
    'profile = "default"' \
    'title = "Site"' \
    'base-url = "https://example.test/"' \
    'publisher = "absent"' >>"$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]]

  write_minimal_config
  sed 's/install.provider = "native"/install.provider = "absent"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]]

  write_minimal_config
  sed '/install.provider =/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"install metadata requires install.provider"* ]]
}

@test "profile and required-tool cycles fail before resolution" {
  write_minimal_config
  awk '{ print; if ($0 ~ /^\[profile.default\]$/) print "profiles = [\"default\"]" }' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/cycle.toml"
  mv "$CONFIG_HOME/cycle.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile cycle includes 'default'"* ]]

  write_minimal_config
  awk '{ print; if ($0 ~ /^rationale =/) print "requires = [\"alpha\"]" }' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/cycle.toml"
  mv "$CONFIG_HOME/cycle.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"required-tool cycle includes 'alpha'"* ]]
}

@test "profiles compose and requirements resolve to a sorted platform-specific set" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "developer"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Test tools"' \
    '[tool.zulu]' \
    'name = "Zulu"' \
    'category = "core"' \
    'purpose = "Linux only"' \
    'rationale = "A platform fixture"' \
    'platforms = ["linux"]' \
    '[tool.beta]' \
    'name = "Beta"' \
    'category = "core"' \
    'purpose = "Required anywhere"' \
    'rationale = "A dependency fixture"' \
    'platforms = ["any"]' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "macOS tool"' \
    'rationale = "A selected fixture"' \
    'platforms = ["macos"]' \
    'requires = ["beta"]' \
    '[profile.base]' \
    'tools = ["zulu", "alpha"]' \
    '[profile.developer]' \
    'tools = ["alpha"]' \
    'profiles = ["base"]' >"$CONFIG_HOME/rig.toml"

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
    'default-profile = "default"' \
    '[profile.default]' \
    'tools = ["zulu", "alpha"]' >"$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[tool.zulu]' \
    'rationale = "Z"' \
    'platforms = ["any"]' \
    'purpose = "Z"' \
    'category = "core"' \
    'name = "Zulu"' >"$CONFIG_HOME/conf.d/20-zulu.toml"
  printf '%s\n' \
    '[tool.alpha]' \
    'platforms = ["any"]' \
    'name = "Alpha"' \
    'category = "core"' \
    'rationale = "A"' \
    'purpose = "A"' \
    '[category.core]' \
    'purpose = "Stable output"' \
    'name = "Core"' >"$CONFIG_HOME/conf.d/10-alpha.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default test-platform && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=test-platform\ntool=alpha\ntool=zulu' ]
}

@test "tool installation selects its declared provider when compatible" {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Installations"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "Select an installation"' \
    'rationale = "Installation fixture"' \
 'platforms = ["macos", "linux"]' \
 'install.provider = "brew"' \
 'install.kind = "formula"' \
 'install.locator = "alpha"' \
 'install.platforms = ["macos"]' \
    '[profile.default]' \
    'tools = ["alpha"]' \
 '[provider.brew]' \
 'adapter = "homebrew"' >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"
    rig_load_config || exit
    rig_resolve_profile default macos || exit
    rig_resolve_bindings || exit
    rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha\nbinding=alpha:brew' ]

  sed 's/install.platforms = \["macos"\]/install.platforms = ["linux"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/no-macos.toml"
  mv "$CONFIG_HOME/no-macos.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings
  ' _ "$RIG"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no compatible installation"* ]]
}

@test "descriptive tools resolve without installation metadata" {
  write_minimal_config
  sed '/^install\./d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/descriptive.toml"
  mv "$CONFIG_HOME/descriptive.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha' ]
}

@test "installation resolution skips catalogue-only tools in a mixed profile" {
  write_minimal_config
  sed 's/tools = \["alpha"\]/tools = ["alpha", "notes"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/mixed.toml"
  mv "$CONFIG_HOME/mixed.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[tool.notes]' \
    'name = "Notes"' \
    'category = "core"' \
    'purpose = "Descriptive catalogue entry"' \
    'rationale = "It documents an unmaterialised choice"' \
    'platforms = ["any"]' >>"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    . "$1"; rig_load_config && rig_resolve_profile default macos && rig_resolve_bindings && rig_dump_resolution
  ' _ "$RIG"

  [ "$status" -eq 0 ]
  [ "$output" = $'profile=default\nplatform=macos\ntool=alpha\nbinding=alpha:native\ntool=notes' ]
}

@test "supported tools reject unavailable required tools" {
  write_minimal_config
  awk '{ print; if ($0 == "rationale = \"A dependable test tool\"") print "requires = [\"linux-only\"]" }' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/required.toml"
  mv "$CONFIG_HOME/required.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[tool.linux-only]' \
    'name = "Linux only"' \
    'category = "core"' \
    'purpose = "Incompatible required tool"' \
    'rationale = "It exercises the platform failure boundary"' \
    'platforms = ["linux"]' >>"$CONFIG_HOME/rig.toml"

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
  [[ "$output" == *"a profile must be resolved before installations"* ]]
}

@test "installation platform any is universally compatible" {
  write_minimal_config

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

@test "provider-backed work reports progress on stderr without changing stdout" {
  local progress_file progress_output
  write_orchestration_config
  progress_file=$BATS_TEST_TMPDIR/progress-$BATS_TEST_NUMBER

  run bash -c 'progress_file=$1; shift; "$@" 2>"$progress_file"' _ "$progress_file" \
    env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PROGRESS=always RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 0 ]
  [[ "$output" == Profile:* ]]
  [[ "$output" != *'rig: observing'* ]]
  progress_output=$(<"$progress_file")
  [[ "$progress_output" == *'rig: loading configuration 0/1'* ]]
  [[ "$progress_output" == *'rig: loading configuration 1/1: 1 sources'* ]]
  [[ "$progress_output" == *'rig: loading configuration complete (1)'* ]]
  [[ "$progress_output" == *'rig: observing 0/4'* ]]
  [[ "$progress_output" == *'rig: observing 1/4: base via runner'* ]]
  [[ "$progress_output" == *'rig: observing 4/4: notes'* ]]
  [[ "$progress_output" == *'rig: observing complete (4)'* ]]

  : >"$progress_file"
  run bash -c 'progress_file=$1; shift; "$@" 2>"$progress_file"' _ "$progress_file" \
    env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PROGRESS=never RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 0 ]
  [ ! -s "$progress_file" ]
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
    -e '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "missing"/' \
    -e '/\[tool.app\]/,/\[tool.base\]/ s/install.locator = "present"/install.locator = "drifted"/' \
 -e '/\[tool.independent\]/,/\[tool.notes\]/ s/install.locator = "present"/install.locator = "invalid-response"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/doctor-findings.toml"
  mv "$CONFIG_HOME/doctor-findings.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" doctor

  [ "$status" -eq 1 ]
  [ "$output" = $'Rig doctor: findings\nProfile: default\nPlatform: macos\nTool findings:\n  base: missing via runner (-); owner=runner; action=run-rig-apply\n  app: drifted via runner (-); owner=runner; action=review-then-run-rig-apply\n  independent: unknown via runner (invalid-response); owner=runner; action=inspect-provider-diagnostics\nSummary: findings=3 present=0 catalogue-only=1 incompatible-platform=0' ]
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = $'CALL=observe:base:missing\nCALL=observe:app:drifted\nCALL=observe:independent:invalid-response' ]
}

@test "doctor reports unavailable providers without invoking mutation" {
  write_orchestration_config
  sed "s#executable = .*#executable = \"$BATS_TEST_TMPDIR/missing-doctor-provider\"#" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/doctor-unavailable.toml"
  mv "$CONFIG_HOME/doctor-unavailable.toml" "$CONFIG_HOME/rig.toml"

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
    'name = "Linux only"' \
    'category = "core"' \
    'purpose = "Exercise incompatible doctor information"' \
    'rationale = "It is intentionally absent on macOS"' \
    'platforms = ["linux"]' >>"$CONFIG_HOME/rig.toml"
  sed 's/tools = \["app", "independent", "notes"\]/tools = ["app", "independent", "notes", "linux-only"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/doctor-platform.toml"
  mv "$CONFIG_HOME/doctor-platform.toml" "$CONFIG_HOME/rig.toml"

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
  [[ "$output" == *"no configuration sources under: $missing_config"* ]] || false

  write_orchestration_config
  printf '%s\n' '[profile.broken]' 'tools = ["absent"]' >>"$CONFIG_HOME/rig.toml"
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
  grep -F 'ARG=install * value' "$ORCHESTRATION_LOG" >/dev/null
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
  grep -F 'ARG=install * value' "$ORCHESTRATION_LOG" >/dev/null
}

@test "operational commands honour explicit profiles and ignore unselected providers" {
  write_orchestration_config
  printf '%s\n' \
    '[profile.focused]' \
    'tools = ["base"]' \
    '[provider.unselected]' \
    'adapter = "custom"' \
    "executable = \"$BATS_TEST_TMPDIR/missing-unselected-provider\"" \
    'capabilities = ["observe", "apply"]' >>"$CONFIG_HOME/rig.toml"

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
    -e '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "missing"/' \
    -e '/\[tool.app\]/,/\[tool.base\]/ s/install.locator = "present"/install.locator = "drifted"/' \
 -e '/\[tool.independent\]/,/\[tool.notes\]/ s/install.locator = "present"/install.locator = "unknown"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/states.toml"
  mv "$CONFIG_HOME/states.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "invalid-response"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/protocol.toml"
  mv "$CONFIG_HOME/protocol.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "exit-7"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/native-failure.toml"
  mv "$CONFIG_HOME/native-failure.toml" "$CONFIG_HOME/rig.toml"

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
    sed "/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = \"present\"/install.locator = \"$response\"/" \
      "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/protocol-$response.toml"
    mv "$CONFIG_HOME/protocol-$response.toml" "$CONFIG_HOME/rig.toml"
    rm -f "$ORCHESTRATION_LOG"

    run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
      RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

    [ "$status" -eq 1 ]
    [[ "$output" == *$'base\trunner\tunknown\tinvalid-response'* ]] || false
  done
}

@test "status reports unavailable operational provider boundaries without invocation" {
  write_orchestration_config
  sed 's/adapter = "custom"/adapter = "future"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable.toml"
  mv "$CONFIG_HOME/unavailable.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\tunsupported-adapter:future'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  write_orchestration_config
  sed 's/capabilities = \["observe", "apply"\]/capabilities = ["apply"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable.toml"
  mv "$CONFIG_HOME/unavailable.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\tunsupported-capability:observe'* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]

  write_orchestration_config
  sed "s#executable = .*#executable = \"$BATS_TEST_TMPDIR/missing-provider\"#" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable.toml"
  mv "$CONFIG_HOME/unavailable.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "diagnostics"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/diagnostics.toml"
  mv "$CONFIG_HOME/diagnostics.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "diagnostics"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/diagnostics.toml"
  mv "$CONFIG_HOME/diagnostics.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "exit-126"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/native-exit.toml"
  mv "$CONFIG_HOME/native-exit.toml" "$CONFIG_HOME/rig.toml"

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
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "fail"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/failure.toml"
  mv "$CONFIG_HOME/failure.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap
  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tfailed\texit:7'* ]] || false
  [[ "$output" == *$'app\trunner\tskipped\tblocked-by:base'* ]] || false
  [ "$(grep '^CALL=' "$ORCHESTRATION_LOG")" = 'CALL=apply:base:fail' ]

  write_bootstrap_config
  sed 's/capabilities = \["observe", "apply"\]/capabilities = ["observe"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/capability.toml"
  mv "$CONFIG_HOME/capability.toml" "$CONFIG_HOME/rig.toml"
  rm -f "$ORCHESTRATION_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" bootstrap
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'apply'"* ]] || false
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "bootstrap profile is an optional unique validated profile reference" {
  write_bootstrap_config
  sed '/^bootstrap-profile = "bootstrap"$/a\
bootstrap-profile = "bootstrap"' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bootstrap.toml"
  mv "$CONFIG_HOME/bootstrap.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate field 'bootstrap-profile'"* ]] || false

  write_orchestration_config
  sed '/^default-profile = "default"$/a\
bootstrap-profile = "absent"' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bootstrap.toml"
  mv "$CONFIG_HOME/bootstrap.toml" "$CONFIG_HOME/rig.toml"
  run_loader
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown bootstrap profile 'absent'"* ]] || false
}

@test "apply suppresses failed dependants while continuing independent work" {
  write_orchestration_config
  sed '/\[tool.base\]/,/\[tool.independent\]/ s/install.locator = "present"/install.locator = "fail"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/failure.toml"
  mv "$CONFIG_HOME/failure.toml" "$CONFIG_HOME/rig.toml"

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
 sed '/\[tool.independent\]/,/\[tool.notes\]/ s/install.provider = "runner"/install.provider = "bad"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/preflight.toml"
  printf '%s\n' \
    '[provider.bad]' \
    'adapter = "custom"' \
    "executable = \"$BATS_TEST_TMPDIR/missing-provider\"" \
    'capabilities = ["apply"]' >>"$CONFIG_HOME/preflight.toml"
  mv "$CONFIG_HOME/preflight.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'bad' executable is unavailable"* ]]
  [ ! -e "$ORCHESTRATION_LOG" ]
}

@test "apply capabilities are exact atomic literals" {
  write_orchestration_config
  sed 's/capabilities = \["observe", "apply"\]/capabilities = ["observe,apply"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/capability.toml"
  mv "$CONFIG_HOME/capability.toml" "$CONFIG_HOME/rig.toml"

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
  [ "$output" = 'Usage: rig status [--profile NAME] [--unmanaged]' ]

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
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
 '[tool.formula]' 'name = "Formula"' 'category = "core"' 'purpose = "Formula test"' \
 'rationale = "Formula rationale"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "formula"' \
 'install.locator = "homebrew/core/jq"' 'install.arguments = ["--formula value"]' \
 '[tool.cask]' 'name = "Cask"' 'category = "core"' 'purpose = "Cask test"' \
 'rationale = "Cask rationale"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "cask"' \
 'install.locator = "homebrew/cask/visual-studio-code"' \
 '[tool.store]' 'name = "Store"' 'category = "core"' 'purpose = "Store test"' \
 'rationale = "Store rationale"' 'platforms = ["any"]' \
 'install.provider = "store"' 'install.kind = "mas"' 'install.locator = "12345"' \
 '[tool.python]' 'name = "Python"' 'category = "core"' 'purpose = "Python test"' \
 'rationale = "Python rationale"' 'platforms = ["any"]' \
 'install.provider = "python"' 'install.kind = "tool"' 'install.locator = "ruff"' \
 '[tool.dotfile]' 'name = "Dotfile"' 'category = "core"' 'purpose = "Dotfile test"' \
 'rationale = "Dotfile rationale"' 'platforms = ["any"]' \
 'install.provider = "dotfiles"' 'install.kind = "target"' \
 'install.locator = "/tmp/example target"' \
    '[profile.default]' 'tools = ["formula", "cask", "store", "python", "dotfile"]' \
    '[provider.brew]' 'adapter = "homebrew"' "executable = \"$native_bin/brew\"" \
    'arguments = ["--global value"]' 'capabilities = ["observe", "apply"]' \
    '[provider.store]' 'adapter = "homebrew"' \
    'capabilities = ["observe", "apply"]' \
    '[provider.python]' 'adapter = "uv"' \
    'capabilities = ["observe", "apply"]' \
    '[provider.dotfiles]' 'adapter = "chezmoi"' \
    'capabilities = ["observe", "apply"]' \
    '[provider.unselected]' 'adapter = "uv"' \
    "executable = \"$BATS_TEST_TMPDIR/missing-unselected\"" 'capabilities = ["observe"]' \
 >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'formula\tbrew\tpresent\t-'* ]] || false
  [[ "$output" == *$'cask\tbrew\tpresent\t-'* ]] || false
  [[ "$output" == *$'store\tstore\tpresent\t-'* ]] || false
  [[ "$output" == *$'python\tpython\tpresent\t-'* ]] || false
  [[ "$output" == *$'dotfile\tdotfiles\tpresent\t-'* ]] || false
  [ "$(wc -l <"$native_log" | tr -d ' ')" -eq 5 ]
  [[ "$(cat "$native_log")" == *$'brew|--global value|list|--formula|--versions|--formula value|jq\n'* ]] || false
  [[ "$(cat "$native_log")" == *$'brew|--global value|list|--cask|--versions|visual-studio-code\n'* ]] || false

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$native_log" | tr -d ' ')" -eq 5 ]

  : >"$native_log"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    PATH="$native_bin:$PATH" RIG_NATIVE_LOG="$native_log" "$RIG" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$native_log")" = "$(printf '%s\n' \
    'brew|--global value|install|--cask|homebrew/cask/visual-studio-code' \
    'chezmoi|apply|--|/tmp/example target' \
    'brew|--global value|install|--formula|--formula value|homebrew/core/jq' \
    'uv|tool|install|ruff' \
    'mas|install|12345')" ]
}

@test "Homebrew observation preserves unqualified formula and cask identities" {
  local native native_log
  native=$BATS_TEST_TMPDIR/unqualified-brew-$BATS_TEST_NUMBER
  native_log=$BATS_TEST_TMPDIR/unqualified-brew-log-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >>"$RIG_NATIVE_LOG"' \
    'exit 0' >"$native"
  chmod +x "$native"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
 '[tool.formula]' 'name = "Formula"' 'category = "core"' 'purpose = "Formula test"' \
 'rationale = "Formula rationale"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "formula"' 'install.locator = "jq"' \
 '[tool.cask]' 'name = "Cask"' 'category = "core"' 'purpose = "Cask test"' \
 'rationale = "Cask rationale"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "cask"' \
 'install.locator = "visual-studio-code"' \
    '[profile.default]' 'tools = ["formula", "cask"]' \
    '[provider.brew]' 'adapter = "homebrew"' "executable = \"$native\"" \
    'capabilities = ["observe"]' \
 >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" "$RIG" status

  [ "$status" -eq 0 ]
  [[ "$(cat "$native_log")" == *'list --formula --versions jq'* ]] || false
  [[ "$(cat "$native_log")" == *'list --cask --versions visual-studio-code'* ]] || false
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
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
 '[tool.base]' 'name = "Base"' 'category = "core"' 'purpose = "Base"' \
 'rationale = "Base"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "formula"' 'install.locator = "broken"' \
 '[tool.app]' 'name = "App"' 'category = "core"' 'purpose = "App"' \
 'rationale = "App"' 'platforms = ["any"]' 'requires = ["base"]' \
 'install.provider = "brew"' 'install.kind = "formula"' 'install.locator = "app"' \
 '[tool.other]' 'name = "Other"' 'category = "core"' 'purpose = "Other"' \
 'rationale = "Other"' 'platforms = ["any"]' \
 'install.provider = "brew"' 'install.kind = "formula"' 'install.locator = "other"' \
    '[profile.default]' 'tools = ["app", "other"]' \
    '[provider.brew]' 'adapter = "homebrew"' "executable = \"$native\"" 'capabilities = ["apply"]' \
 >"$CONFIG_HOME/rig.toml"

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
  sed "/adapter = \"homebrew\"/a\\
executable = \"$missing\"\\
capabilities = [\"observe\", \"apply\"]" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/native.toml"
  mv "$CONFIG_HOME/native.toml" "$CONFIG_HOME/rig.toml"

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
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
 '[tool.download]' 'name = "Download"' 'category = "core"' 'purpose = "Download test"' \
 'rationale = "Download rationale"' 'platforms = ["any"]' \
 'install.provider = "download"' 'install.kind = "executable"' \
 'install.locator = "https://example.invalid/downloaded-tool"' \
 'install.destination = "~/bin/downloaded-tool"' \
 "install.checksum = \"sha256:$digest\"" \
    '[profile.default]' 'tools = ["download"]' \
    '[provider.download]' 'adapter = "direct-download"' "executable = \"$downloader\"" \
    'capabilities = ["observe", "apply"]' \
 >"$CONFIG_HOME/rig.toml"

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
  sed "s/sha256:$digest/sha256:$bad_digest/" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/bad.toml"
  mv "$CONFIG_HOME/bad.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" "$RIG" apply
  [ "$status" -eq 1 ]
  [ "$(cat "$destination")" = 'existing destination' ]
  run bash -c 'compgen -G "$1.rig-tmp.*"' _ "$destination"
  [ "$status" -ne 0 ]

  sed "s/sha256:$bad_digest/sha256:$digest/" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/race.toml"
  mv "$CONFIG_HOME/race.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' 'existing destination' >"$destination"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_NATIVE_LOG="$native_log" RIG_DOWNLOAD_SOURCE="$source_file" \
    RIG_UNSAFE_DESTINATION="$destination" "$RIG" apply
  [ "$status" -eq 1 ]
  [ -d "$destination" ]
  [ -z "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

@test "Homebrew mas installations require numeric application identities" {
  write_minimal_config
  sed -e 's/kind = "formula"/kind = "mas"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/mas.toml"
  mv "$CONFIG_HOME/mas.toml" "$CONFIG_HOME/rig.toml"

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
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
 '[tool.download]' 'name = "Download"' 'category = "core"' 'purpose = "Download test"' \
 'rationale = "Download rationale"' 'platforms = ["any"]' \
 'install.provider = "download"' 'install.kind = "executable"' \
 'install.locator = "https://example.invalid/downloaded-tool"' \
 "install.destination = \"$destination\"" \
 'install.checksum = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
    '[profile.default]' 'tools = ["download"]' \
    '[provider.download]' 'adapter = "direct-download"' "executable = \"$downloader\"" \
    'capabilities = ["apply"]' \
 >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'refuses unsafe destination'* ]] || false

  sed 's#https://#http://#' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/http.toml"
  mv "$CONFIG_HOME/http.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'direct-download locator must use HTTPS'* ]] || false

 sed -e 's#http://#https://#' -e '/^install.checksum = /d' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/incomplete.toml"
  mv "$CONFIG_HOME/incomplete.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'checksum'"* ]] || false

 sed '/^\[profile.default\]/i\
install.checksum = "sha256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"' \
 "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid-checksum.toml"
 mv "$CONFIG_HOME/invalid-checksum.toml" "$CONFIG_HOME/rig.toml"
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
    'default-profile = "private"' \
    '[category.navigation]' \
    'name = "Navigation & Search"' \
    'purpose = "Find <things> safely"' \
    '[category.private]' \
    'name = "Private category"' \
    'purpose = "Never disclose this category"' \
    '[tool.alpha]' \
    'name = "Alpha <One>"' \
    'category = "navigation"' \
    'purpose = "Find & select"' \
    'rationale = "Safer \"choice\" for public work"' \
 'platforms = ["any"]' \
 'related = ["beta"]' \
 'alternatives = ["secret"]' \
 'install.provider = "publisher"' \
 'install.kind = "executable"' \
 'install.locator = "private-locator-token"' \
 'install.arguments = ["install-argument-token"]' \
    '[tool.beta]' \
    'name = "Beta"' \
    'category = "navigation"' \
    'purpose = "Browse public material"' \
    'rationale = "Complements Alpha"' \
    'platforms = ["linux"]' \
    '[tool.secret]' \
    'name = "Secret Tool"' \
    'category = "private"' \
    'purpose = "private-purpose-token"' \
    'rationale = "private-rationale-token"' \
    'platforms = ["any"]' \
    '[profile.public]' \
    'tools = ["alpha", "beta"]' \
    '[profile.private]' \
    'profiles = ["public"]' \
    'tools = ["secret"]' \
    '[provider.publisher]' \
    'adapter = "custom"' \
    "executable = \"$PUBLICATION_PROVIDER\"" \
    'capabilities = ["publish"]' \
    'manifest = "/private/provider-manifest-token"' \
    'arguments = ["provider-argument-token"]' \
 '[publication.site]' \
    'profile = "public"' \
    'title = "Kris & Rig"' \
    'base-url = "https://example.test/rig/"' \
    'publisher = "publisher"' >"$CONFIG_HOME/rig.toml"
}

@test "export writes valid allow-listed versioned public data as complete tree" {
  local destination file_count
  destination=$BATS_TEST_TMPDIR/public-site-$BATS_TEST_NUMBER
  write_publication_config
  mkdir -p "$destination/obsolete"
  printf '%s\n' stale >"$destination/obsolete/stale.txt"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PUBLICATION_MARKER="$PUBLICATION_MARKER" "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  [ "$output" = "Exported site to $destination" ]
  [ -f "$destination/rig.json" ]
  [ ! -L "$destination/rig.json" ]
  [ ! -e "$destination/obsolete/stale.txt" ]
  file_count=$(find "$destination" -type f | wc -l | tr -d ' ')
  [ "$file_count" -eq 1 ]
  run python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    data = json.load(source)
assert data["format"] == "rig-publication"
assert data["version"] == 1
assert data["publication"] == {
    "id": "site",
    "title": "Kris & Rig",
    "canonical_url": "https://example.test/rig/",
}
assert data["profile"]["id"] == "public"
assert data["profile"]["categories"] == [{
    "id": "navigation",
    "name": "Navigation & Search",
    "purpose": "Find <things> safely",
}]
assert [tool["id"] for tool in data["profile"]["tools"]] == ["alpha", "beta"]
assert data["profile"]["tools"][0]["name"] == "Alpha <One>"
assert data["profile"]["tools"][0]["rationale"] == "Safer \"choice\" for public work"
assert data["profile"]["tools"][1]["platforms"] == ["linux"]
' "$destination/rig.json"
  [ "$status" -eq 0 ]
  ! grep -R -E 'Secret Tool|private-purpose-token|private-rationale-token|provider-manifest-token|provider-argument-token|private-locator-token|install-argument-token' "$destination"
  [ ! -e "$PUBLICATION_MARKER" ]
}

@test "export closes relationships over selected public tools" {
  local destination
  destination=$BATS_TEST_TMPDIR/relationship-site-$BATS_TEST_NUMBER
  write_publication_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  run python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    tools = {tool["id"]: tool for tool in json.load(source)["profile"]["tools"]}
assert tools["alpha"]["relationships"]["related"] == ["beta"]
assert tools["alpha"]["relationships"]["alternatives"] == []
assert tools["beta"]["relationships"] == {
    "requires": [], "related": [], "alternatives": []
}
' "$destination/rig.json"
  [ "$status" -eq 0 ]
  ! grep -F 'secret' "$destination/rig.json"
}

@test "export is deterministic across declaration order and active host platform" {
  local second_config first_output second_output
  second_config=$BATS_TEST_TMPDIR/config-reordered-$BATS_TEST_NUMBER
  first_output=$BATS_TEST_TMPDIR/site-first-$BATS_TEST_NUMBER
  second_output=$BATS_TEST_TMPDIR/site-second-$BATS_TEST_NUMBER
  write_publication_config
  mkdir -p "$second_config/conf.d"
  sed -e 's/tool = alpha/tool = temporary/' \
    -e 's/tool = beta/tool = alpha/' \
    -e 's/tool = temporary/tool = beta/' \
    "$CONFIG_HOME/rig.toml" >"$second_config/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$first_output"
  [ "$status" -eq 0 ]
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$second_config" RIG_PLATFORM=linux \
    "$RIG" export site --output "$second_output"
  [ "$status" -eq 0 ]
  diff -r "$first_output" "$second_output"
}

@test "export normalizes base URL as canonical publication metadata" {
  local destination
  destination=$BATS_TEST_TMPDIR/url-site-$BATS_TEST_NUMBER
  write_publication_config
  sed 's#https://example.test/rig/#https://rig.example.test#' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/root.toml"
  mv "$CONFIG_HOME/root.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" export site --output "$destination"

  [ "$status" -eq 0 ]
  grep -F '"canonical_url": "https://rig.example.test/"' "$destination/rig.json"
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
      "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid.toml"
    mv "$CONFIG_HOME/invalid.toml" "$CONFIG_HOME/rig.toml"

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
    '  mkdir -p -- "$RIG_PUBLISH_SWAP_TARGET/$stage_name"' \
    '  printf victim >"$RIG_PUBLISH_SWAP_TARGET/$stage_name/rig.json"' \
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
    'adapter = "custom"' \
    "executable = \"$OTHER_PUBLISHER\"" \
    'capabilities = ["publish"]' >>"$CONFIG_HOME/rig.toml"
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
  cache_real=$(cd "$cache/publish/staging" && pwd -P)
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
  [ -z "$(find "$cache/publish/staging" -mindepth 1 -maxdepth 1 -print -quit)" ]
  [ -z "$(find "$cache/publish/retained" -mindepth 1 -maxdepth 1 -print -quit)" ]
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
    case "$stage" in
      */publish/retained/site.rig-publish.*) ;;
      *) false ;;
    esac
    [ -d "$stage" ]
    [ -f "$stage/rig.json" ]
    file_count=$(find "$stage" -type f | wc -l | tr -d ' ')
    [ "$file_count" -eq 1 ]
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
  case "$stage" in
    */publish/retained/site.rig-publish.*) ;;
    *) false ;;
  esac
  [ -f "$stage/rig.json" ]
  [ ! -e "$OTHER_PUBLISH_LOG" ]
  rm -rf -- "$stage"
}

@test "publish interruption before handoff removes incomplete staging" {
  local cache root stage

  cache=$BATS_TEST_TMPDIR/publish-pre-dispatch-interrupt-$BATS_TEST_NUMBER
  mkdir -p "$cache/publish/staging" "$cache/publish/retained"
  root=$(cd "$cache/publish" && pwd -P)
  stage=$root/staging/site.rig-publish.partial
  mkdir -p "$stage"
  printf partial >"$stage/rig.json"

  run env RIG_TEST_ROOT="$root" RIG_TEST_STAGE="$stage" /bin/bash -c '
    . "$1"
    RIG_PUBLISH_ROOT=$RIG_TEST_ROOT
    RIG_PUBLISH_STAGING_ROOT=$RIG_TEST_ROOT/staging
    RIG_PUBLISH_RETAINED_ROOT=$RIG_TEST_ROOT/retained
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
  [[ "$output" == *'publication cache path must be a directory'* ]] || false
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
  [ -L "$cache_real/publish/staging" ]
  [ "$(cat "$victim/$stage_name/rig.json")" = victim ]
  [ -f "$moved/$stage_name/rig.json" ]

  rm -- "$cache_real/publish/staging"
  rm -rf -- "$moved" "$victim"
}

@test "publish rejects invalid selection and capability boundaries before export or invocation" {
  local cache original
  cache=$BATS_TEST_TMPDIR/publish-reject-cache-$BATS_TEST_NUMBER
  write_publish_config
  original=$BATS_TEST_TMPDIR/publish-original-$BATS_TEST_NUMBER
  cp "$CONFIG_HOME/rig.toml" "$original"

  sed 's/capabilities = \["publish"\]/capabilities = []/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not declare capability 'publish'"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]
  [ ! -e "$cache/publish" ]

  sed -e 's/adapter = "custom"/adapter = "homebrew"/' \
    -e 's/kind = "executable"/kind = "formula"/' \
    "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires a custom publisher"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  sed "s#executable = \"$PUBLICATION_PROVIDER\"#executable = \"$BATS_TEST_TMPDIR/missing-publisher\"#" \
    "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *"publisher 'publisher' executable unavailable"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  sed 's#base-url = "https://example.test/rig/"#base-url = "https://user@example.test/"#' \
    "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish site
  [ "$status" -eq 2 ]
  [[ "$output" == *'must not contain user information'* ]] || false
  [ ! -e "$PUBLISH_LOG" ]

  cp "$original" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    RIG_PLATFORM=macos RIG_PUBLISH_LOG="$PUBLISH_LOG" "$RIG" publish absent
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown publication 'absent'"* ]] || false
  [ ! -e "$PUBLISH_LOG" ]
}

@test "clean no-op help and syntax do not require configuration" {
  local cache
  cache=$BATS_TEST_TMPDIR/clean-empty-$BATS_TEST_NUMBER

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_CACHE_HOME="$cache" \
    "$RIG" clean --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'CLASS\tSTATE\tACTION\tPATH'* ]] || false
  [[ "$output" == *'Summary: eligible=0 removed=0 skipped=0'* ]] || false
  [ ! -e "$cache" ]

  run "$RIG" clean --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig clean [--dry-run]' ]

  run "$RIG" clean --unknown
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig clean [--dry-run]'* ]] || false
}

@test "clean previews then removes retained exports and resumes cleanup claims" {
  local cache retained claim
  cache=$BATS_TEST_TMPDIR/clean-cache-$BATS_TEST_NUMBER
  retained=$cache/publish/retained
  claim=$cache/publish/cleanup
  mkdir -p "$retained/site.rig-publish.101" \
    "$retained/docs.rig-publish.102" "$claim/site.rig-publish.99"
  printf '{}\n' >"$retained/site.rig-publish.101/rig.json"
  printf '{}\n' >"$retained/docs.rig-publish.102/rig.json"
  printf '{}\n' >"$claim/site.rig-publish.99/rig.json"

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" "$RIG" clean --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'publication\tcleanup-claim\twould-remove'* ]] || false
  [[ "$output" == *$'publication\tretained\twould-remove'* ]] || false
  [[ "$output" == *'Summary: eligible=3 removed=0 skipped=0'* ]] || false
  [ -f "$retained/site.rig-publish.101/rig.json" ]
  [ -f "$claim/site.rig-publish.99/rig.json" ]

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" RIG_PROGRESS=always "$RIG" clean
  [ "$status" -eq 0 ]
  [[ "$output" == *'rig: cleaning 0/3'* ]] || false
  [[ "$output" == *'Summary: eligible=3 removed=3 skipped=0'* ]] || false
  [ -z "$(find "$retained" "$claim" -mindepth 1 -print -quit)" ]
}

@test "clean skips legacy and unsafe cache entries while removing independent candidates" {
  local cache retained legacy target
  cache=$BATS_TEST_TMPDIR/clean-unsafe-$BATS_TEST_NUMBER
  retained=$cache/publish/retained
  legacy=$cache/publish/site.rig-publish.7
  target=$cache/target
  mkdir -p "$retained/good.rig-publish.1" "$retained/extra.rig-publish.2" \
    "$legacy" "$target"
  printf '{}\n' >"$retained/good.rig-publish.1/rig.json"
  printf '{}\n' >"$retained/extra.rig-publish.2/rig.json"
  printf keep >"$retained/extra.rig-publish.2/unexpected"
  printf '{}\n' >"$legacy/rig.json"
  ln -s "$target" "$retained/link.rig-publish.3"

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" "$RIG" clean
  [ "$status" -eq 1 ]
  [[ "$output" == *$'publication\tlegacy-unclassified\tskipped'* ]] || false
  [[ "$output" == *$'publication\tunsafe\tskipped'* ]] || false
  [[ "$output" == *'Summary: eligible=1 removed=1 skipped=3'* ]] || false
  [ ! -e "$retained/good.rig-publish.1" ]
  [ -f "$retained/extra.rig-publish.2/unexpected" ]
  [ -L "$retained/link.rig-publish.3" ]
  [ -f "$legacy/rig.json" ]
  [ -d "$target" ]
}

@test "clean rejects a symlinked publication cache boundary" {
  local cache outside
  cache=$BATS_TEST_TMPDIR/clean-boundary-$BATS_TEST_NUMBER
  outside=$BATS_TEST_TMPDIR/clean-outside-$BATS_TEST_NUMBER
  mkdir -p "$cache" "$outside"
  printf keep >"$outside/keep"
  ln -s "$outside" "$cache/publish"

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" "$RIG" clean
  [ "$status" -eq 2 ]
  [[ "$output" == *'publication cache path must be a directory, not a symlink'* ]] || false
  [ "$(cat "$outside/keep")" = keep ]
}

@test "clean claim refuses a substituted retained parent" {
  local cache root retained moved victim candidate
  cache=$BATS_TEST_TMPDIR/clean-parent-swap-$BATS_TEST_NUMBER
  mkdir -p "$cache/publish/retained/site.rig-publish.8" "$cache/victim/site.rig-publish.8"
  printf original >"$cache/publish/retained/site.rig-publish.8/rig.json"
  printf victim >"$cache/victim/site.rig-publish.8/rig.json"
  root=$(cd "$cache/publish" && pwd -P)
  retained=$root/retained
  candidate=$retained/site.rig-publish.8
  moved=$root/retained-moved
  victim=$(cd "$cache/victim" && pwd -P)

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" "$RIG" clean --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$root/cleanup" ]

  mv -- "$retained" "$moved"
  ln -s -- "$victim" "$retained"
  run env RIG_TEST_ROOT="$root" RIG_TEST_CANDIDATE="$candidate" /bin/bash -c '
    . "$1"
    RIG_CLEAN_ROOT=$RIG_TEST_ROOT
    rig_clean_claim "$RIG_TEST_CANDIDATE"
  ' bash "$RIG"

  [ "$status" -eq 1 ]
  [ "$(cat "$victim/site.rig-publish.8/rig.json")" = victim ]
  [ "$(cat "$moved/site.rig-publish.8/rig.json")" = original ]
}

@test "clean interruption reports a resumable exact-shape claim" {
  local cache claim
  cache=$BATS_TEST_TMPDIR/clean-interrupt-$BATS_TEST_NUMBER
  claim=$cache/publish/cleanup/site.rig-publish.55
  mkdir -p "$claim"
  printf '{}\n' >"$claim/rig.json"

  run env RIG_TEST_CLAIM="$claim" /bin/bash -c '
    . "$1"
    RIG_CLEAN_CLAIM=$RIG_TEST_CLAIM
    rig_clean_interrupted 143
  ' bash "$RIG"

  [ "$status" -eq 143 ]
  [[ "$output" == *"resumable claim: $claim"* ]] || false
  [ -f "$claim/rig.json" ]

  run env HOME="$TEST_HOME" RIG_CACHE_HOME="$cache" "$RIG" clean
  [ "$status" -eq 0 ]
  [ ! -e "$claim" ]
}

@test "concurrent cleaners never traverse active staging and leave no eligible exports" {
  local cache index statuses
  cache=$BATS_TEST_TMPDIR/clean-concurrent-$BATS_TEST_NUMBER
  mkdir -p "$cache/publish/staging/active.rig-publish.1" "$cache/publish/retained"
  printf active >"$cache/publish/staging/active.rig-publish.1/rig.json"
  index=1
  while [ "$index" -le 20 ]; do
    mkdir "$cache/publish/retained/site.rig-publish.$index"
    printf '{}\n' >"$cache/publish/retained/site.rig-publish.$index/rig.json"
    index=$((index + 1))
  done

  run env RIG_TEST_HOME="$TEST_HOME" RIG_TEST_CACHE="$cache" RIG_TEST_RIG="$RIG" \
    /bin/bash -c '
      HOME=$RIG_TEST_HOME RIG_CACHE_HOME=$RIG_TEST_CACHE "$RIG_TEST_RIG" clean >"$RIG_TEST_CACHE/one.log" 2>&1 &
      first=$!
      HOME=$RIG_TEST_HOME RIG_CACHE_HOME=$RIG_TEST_CACHE "$RIG_TEST_RIG" clean >"$RIG_TEST_CACHE/two.log" 2>&1 &
      second=$!
      first_status=0
      second_status=0
      wait "$first" || first_status=$?
      wait "$second" || second_status=$?
      printf "%s %s\n" "$first_status" "$second_status"
    '

  [ "$status" -eq 0 ]
  statuses=${lines[0]}
  case "$statuses" in
    '0 0'|'0 1'|'1 0'|'1 1') ;;
    *) false ;;
  esac
  [ -f "$cache/publish/staging/active.rig-publish.1/rig.json" ]
  [ -z "$(find "$cache/publish/retained" "$cache/publish/cleanup" -mindepth 1 -print -quit)" ]
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
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Core tools"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
    'purpose = "Exercise declared operations"' \
    'rationale = "Keeps host actions configuration-led"' \
    'platforms = ["macos", "linux"]' \
    '[profile.default]' \
    'tools = ["alpha"]' \
    '[provider.runner]' \
    'adapter = "custom"' \
    "executable = \"$OPERATION_PROVIDER\"" \
    'arguments = ["provider value;$(touch provider-marker)"]' \
    'capabilities = ["audit", "restart"]' \
    '[action.runner.audit]' \
    'mode = "observe"' \
    'description = "Inspect Alpha"' \
    'platforms = ["macos"]' \
    'arguments = ["configured value", "configured * literal"]' \
    'allowed-arguments = ["--verbose", "value with spaces", "semi;$(touch caller-marker)"]' \
    '[action.runner.restart]' \
    'mode = "mutate"' \
    'description = "Restart Alpha"' \
    'arguments = ["restart now"]' >"$CONFIG_HOME/rig.toml"
}

@test "run dispatches declared observe and mutate operations with literal arguments" {
  local expected
  write_operation_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" RIG_OPERATION_STDOUT='operation stdout' \
    RIG_OPERATION_STDERR='operation stderr' RIG_OPERATION_EXIT=7 \
    "$RIG" run runner audit -- --verbose 'value with spaces' --verbose 'semi;$(touch caller-marker)'

  [ "$status" -eq 7 ]
  [[ "$output" == *'operation stdout'* ]] || false
  [[ "$output" == *'operation stderr'* ]] || false
  expected=$(printf '%s\n' \
    'BEGIN' \
    'ARG=<provider value;$(touch provider-marker)>' \
    'ARG=<rig-provider-v1>' \
    'ARG=<observe>' \
    'ARG=<runner>' \
    'ARG=<runner>' \
    'ARG=<action>' \
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
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner restart

  [ "$status" -eq 0 ]
  expected=$(printf '%s\n' \
    'BEGIN' \
    'ARG=<provider value;$(touch provider-marker)>' \
    'ARG=<rig-provider-v1>' \
    'ARG=<apply>' \
    'ARG=<runner>' \
    'ARG=<runner>' \
    'ARG=<action>' \
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
      RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit -- "$argument"
    [ "$status" -eq 2 ]
    [[ "$output" == *'argument is not allowed'* ]] || false
    [ ! -e "$OPERATION_LOG" ]
  done

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"action 'runner audit' not supported on platform 'linux'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner restart -- --verbose
  [ "$status" -eq 2 ]
  [ ! -e "$OPERATION_LOG" ]
}

@test "action schema rejects invalid trust declarations before invocation" {
  local original
  write_operation_config
  original=$BATS_TEST_TMPDIR/operation-original-$BATS_TEST_NUMBER
  cp "$CONFIG_HOME/rig.toml" "$original"

  sed 's/mode = "observe"/mode = "execute"/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"mode must be 'observe' or 'mutate'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/allowed-arguments = \[/argument-policy = "shell" # /' \
    "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"argument-policy must be 'rig' or 'provider'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/\[action.runner.audit\]/[action.absent.audit]/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'absent'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/adapter = "custom"/adapter = "homebrew"/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *'actions require custom provider'* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed '/description = "Inspect Alpha"/d' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'description'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/\[action.runner.audit\]/[action.ghost.audit]/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"references unknown provider 'ghost'"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  sed 's/\[action.runner.audit\]/[action.runner.audit.extra]/' "$original" >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *'invalid section identity [action.runner.audit.extra]'* ]] || false
  [ ! -e "$OPERATION_LOG" ]
}

@test "run rejects unavailable provider and exposes local help" {
  write_operation_config
  sed "s#executable = \"$OPERATION_PROVIDER\"#executable = \"$BATS_TEST_TMPDIR/missing-operation-provider\"#" \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable.toml"
  mv "$CONFIG_HOME/unavailable.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'runner' executable unavailable"* ]] || false
  [ ! -e "$OPERATION_LOG" ]

  run "$RIG" run --help
  [ "$status" -eq 0 ]
  [ "$output" = 'Usage: rig run PROVIDER ACTION [-- ARGUMENT...]' ]

  run "$RIG" run runner
  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig run PROVIDER ACTION [-- ARGUMENT...]'* ]] || false
}

write_inventory_config() {
  INVENTORY_PROVIDER=$BATS_TEST_TMPDIR/inventory-provider-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    '[ "$1" = rig-provider-v1 ] || exit 64' \
    'case "$2" in' \
    '  observe) printf "present\n" ;;' \
    '  inventory)' \
    '    case "${RIG_TEST_INVENTORY:-normal}" in' \
    '      exit-7) exit 7 ;;' \
    '      empty) : ;;' \
    '      mutating) printf "declared\nundeclared-one\tnative\n" ;;' \
    '      *) printf "declared\nundeclared-one\tnative\nundeclared two\n" ;;' \
    '    esac' \
    '    ;;' \
    '  *) exit 65 ;;' \
    'esac' >"$INVENTORY_PROVIDER"
  chmod +x "$INVENTORY_PROVIDER"
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Essential tools"' \
    '[tool.alpha]' \
    'name = "Alpha"' \
    'category = "core"' \
 'purpose = "Test inventory"' \
 'rationale = "A dependable test tool"' \
 'platforms = ["any"]' \
 'install.provider = "surveyor"' \
 'install.kind = "app"' \
 'install.locator = "declared"' \
    '[profile.default]' \
    'tools = ["alpha"]' \
    "[provider.surveyor]" \
    'adapter = "custom"' \
    "executable = \"$INVENTORY_PROVIDER\"" \
 'capabilities = ["observe", "inventory"]' >"$CONFIG_HOME/rig.toml"
}

@test "custom provider default executable covers every trust-boundary invocation" {
  local data_home
  data_home=$BATS_TEST_TMPDIR/rig-data-$BATS_TEST_NUMBER
  mkdir -p "$data_home/providers"

  write_orchestration_config
  cp "$ORCHESTRATION_PROVIDER" "$data_home/providers/runner"
  chmod +x "$data_home/providers/runner"
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status
  [ "$status" -eq 0 ]
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" apply
  [ "$status" -eq 0 ]

  write_operation_config
  cp "$OPERATION_PROVIDER" "$data_home/providers/runner"
  chmod +x "$data_home/providers/runner"
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_PLATFORM=macos RIG_OPERATION_LOG="$OPERATION_LOG" "$RIG" run runner audit
  [ "$status" -eq 0 ]

  write_inventory_config
  cp "$INVENTORY_PROVIDER" "$data_home/providers/surveyor"
  chmod +x "$data_home/providers/surveyor"
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_PLATFORM=macos "$RIG" status --unmanaged
  [ "$status" -eq 0 ]
  [[ "$output" == *'Unmanaged: 2'* ]] || false

  write_publication_config
  cp "$PUBLICATION_PROVIDER" "$data_home/providers/publisher"
  chmod +x "$data_home/providers/publisher"
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_CACHE_HOME="$BATS_TEST_TMPDIR/publish-cache-$BATS_TEST_NUMBER" \
    RIG_STATE_HOME="$BATS_TEST_TMPDIR/publish-state-$BATS_TEST_NUMBER" \
    RIG_PLATFORM=macos RIG_PUBLICATION_MARKER="$PUBLICATION_MARKER" "$RIG" publish site
  [ "$status" -eq 0 ]
  [ -e "$PUBLICATION_MARKER" ]
}

@test "custom provider default follows XDG data home and explicit executable wins" {
  local xdg_data missing_data
  xdg_data=$BATS_TEST_TMPDIR/xdg-data-$BATS_TEST_NUMBER
  missing_data=$BATS_TEST_TMPDIR/missing-data-$BATS_TEST_NUMBER
  mkdir -p "$xdg_data/rig/providers"

  write_orchestration_config
  cp "$ORCHESTRATION_PROVIDER" "$xdg_data/rig/providers/runner"
  chmod +x "$xdg_data/rig/providers/runner"
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME= \
    XDG_DATA_HOME="$xdg_data" RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" \
    "$RIG" status
  [ "$status" -eq 0 ]

  write_orchestration_config
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$missing_data" \
    XDG_DATA_HOME="$missing_data" RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" \
    "$RIG" status
  [ "$status" -eq 0 ]
}

@test "missing custom provider default reports its exact conventional path" {
  local data_home expected
  data_home=$BATS_TEST_TMPDIR/empty-rig-data-$BATS_TEST_NUMBER
  expected=$data_home/providers/runner
  write_orchestration_config
  sed '/^executable = /d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/default-provider.toml"
  mv "$CONFIG_HOME/default-provider.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_DATA_HOME="$data_home" \
    RIG_PLATFORM=macos RIG_TEST_LOG="$ORCHESTRATION_LOG" "$RIG" status

  [ "$status" -eq 1 ]
  [[ "$output" == *$'base\trunner\tunavailable\texecutable-unavailable'* ]] || false
  [ ! -e "$expected" ]
}

@test "status reports observed identities that no tool installation declares" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" == *$'alpha\tsurveyor\tpresent\t-'* ]] || false
  [[ "$output" == *$'undeclared-one\tsurveyor\tunmanaged\tnative'* ]] || false
  [[ "$output" == *$'undeclared two\tsurveyor\tunmanaged\t-'* ]] || false
  [[ "$output" == *'Unmanaged: 2'* ]] || false
}

write_resource_fixture() {
  RESOURCE_LOG=$BATS_TEST_TMPDIR/resource-provider-$BATS_TEST_NUMBER.log
  RESOURCE_PROVIDER=$BATS_TEST_TMPDIR/resource-provider-$BATS_TEST_NUMBER
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -u' \
    'log=${RESOURCE_LOG:?}' \
    'printf "%s\n" "$*" >>"$log"' \
    'if [ "${RESOURCE_FAIL_ID:-}" = "${4:-}" ] && [ "$2" = apply-resource ]; then exit 9; fi' \
    'case "$2" in' \
    '  observe-resource) printf "%s\n" present ;;' \
    '  *) exit 0 ;;' \
    'esac' >"$RESOURCE_PROVIDER"
  chmod +x "$RESOURCE_PROVIDER"
  : >"$RESOURCE_LOG"
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    'bootstrap-profile = "default"' \
    '' \
    '[category.system]' \
    'name = "System"' \
    'purpose = "System support."' \
    '' \
    '[tool.base]' \
    'name = "Base"' \
    'category = "system"' \
    'purpose = "Support a service."' \
    'rationale = "Required by the declared service."' \
    'platforms = ["macos"]' \
    '' \
    '[provider.runner]' \
    'adapter = "custom"' \
    "executable = \"$RESOURCE_PROVIDER\"" \
    'capabilities = ["resource-observe", "resource-apply", "resource-retire"]' \
    '' \
    '[service.daemon]' \
    'name = "Test daemon"' \
    'purpose = "Exercise service reconciliation."' \
    'rationale = "Proves deferred execution stays declarative."' \
    'provider = "runner"' \
    'locator = "example.test.daemon"' \
    'platforms = ["macos"]' \
    'requires = ["base"]' \
    'desired-state = "running"' \
    'program = ["/usr/bin/example", "--literal value", "$(not-executed)"]' \
    'environment = ["SAFE=value;still-literal"]' \
    'restart-policy = "always"' \
    'start-policy = "load"' \
    'standard-output = "/tmp/example.out"' \
    'standard-error = "/tmp/example.err"' \
    '' \
    '[scheduled-job.morning]' \
    'name = "Morning"' \
    'purpose = "Exercise calendar projection."' \
    'rationale = "Proves scheduled argv is inspectable."' \
    'provider = "runner"' \
    'locator = "example.test.morning"' \
    'platforms = ["macos"]' \
    'desired-state = "enabled"' \
    'program = ["/usr/bin/true"]' \
    'schedule.calendar = ["hour=8,minute=0", "weekday=1,hour=9"]' \
    'run-policy = "scheduled-only"' \
    'priority = "background"' \
    '' \
    '[profile.default]' \
    'services = ["daemon"]' \
    'scheduled-jobs = ["morning"]' \
    '' \
    '[action.runner.restart]' \
    'mode = "mutate"' \
    'description = "Restart one selected resource."' \
    'platforms = ["macos"]' \
    'argument-policy = "provider"' \
    'resource-kinds = ["service", "scheduled-job"]' >"$CONFIG_HOME/rig.toml"
}

@test "operational resources resolve through profiles and remain inert in queries" {
  write_resource_fixture

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" show
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Services: 1\nID\tNAME\tPROVIDER\tDESIRED'* ]]
  [[ "$output" == *$'daemon\tTest daemon\trunner\trunning'* ]]
  [[ "$output" == *'Scheduled jobs: 1'* ]]
  [[ "$output" == *$'morning\tMorning\trunner\tenabled\tcalendar:hour=8,minute=0;weekday=1,hour=9'* ]]
  [ ! -s "$RESOURCE_LOG" ]

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RESOURCE_LOG="$RESOURCE_LOG" \
    RIG_PLATFORM=macos "$RIG" explain service:daemon
  [ "$status" -eq 0 ]
  [[ "$output" == *'Resource: service:daemon'* ]]
  [[ "$output" == *'program=$(not-executed)'* ]]
  [[ "$output" == *'Profiles: default'* ]]
  [ ! -s "$RESOURCE_LOG" ]
}

@test "resource status and dry-run use literal provider records without mutation" {
  write_resource_fixture

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'daemon\tservice\trunner\tpresent\t-'* ]]
  [[ "$output" == *$'morning\tscheduled-job\trunner\tpresent\t-'* ]]
  grep -F 'rig-provider-v1 observe-resource runner daemon service example.test.daemon' "$RESOURCE_LOG"
  : >"$RESOURCE_LOG"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'daemon\tservice\trunner\tplanned\treconcile:example.test.daemon'* ]]
  [[ "$output" == *'program=--literal value'* ]]
  [[ "$output" == *'program=$(not-executed)'* ]]
  [[ "$output" == *'schedule-calendar=hour=8,minute=0'* ]]
  [ ! -s "$RESOURCE_LOG" ]
  [ ! -e "$BATS_TEST_TMPDIR/state/resources/macos.tsv" ]
}

@test "resource-aware actions receive selected declaration before caller arguments" {
  write_resource_fixture

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RESOURCE_LOG="$RESOURCE_LOG" \
    RIG_PLATFORM=macos "$RIG" run runner restart -- service:daemon --follow
  [ "$status" -eq 0 ]
  run grep -F 'rig-provider-v1 apply runner runner action restart resource-v1 service daemon example.test.daemon' "$RESOURCE_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *'program=/usr/bin/example'* ]]
  [[ "$output" == *' -- --follow'* ]]
}

@test "resource apply records managed identities and retires deselected entries" {
  write_resource_fixture
  sed '/requires = \["base"\]/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/without-requirement.toml"
  mv "$CONFIG_HOME/without-requirement.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/state/resources/macos.tsv" ]
  grep -F $'runner\tservice\tdaemon\texample.test.daemon' "$BATS_TEST_TMPDIR/state/resources/macos.tsv"
  grep -F $'runner\tscheduled-job\tmorning\texample.test.morning' "$BATS_TEST_TMPDIR/state/resources/macos.tsv"

  sed 's/services = \["daemon"\]/services = []/; s/scheduled-jobs = \["morning"\]/scheduled-jobs = []/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/deselected.toml"
  mv "$CONFIG_HOME/deselected.toml" "$CONFIG_HOME/rig.toml"
  : >"$RESOURCE_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ]
  grep -F 'rig-provider-v1 retire-resource runner daemon service example.test.daemon previous-managed=true' "$RESOURCE_LOG"
  grep -F 'rig-provider-v1 retire-resource runner morning scheduled-job example.test.morning previous-managed=true' "$RESOURCE_LOG"
  [ ! -s "$BATS_TEST_TMPDIR/state/resources/macos.tsv" ]
}

@test "resource schema rejects unsafe calendar declarations before provider execution" {
  write_resource_fixture
  sed 's/hour=8,minute=0/hour=24,minute=0/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid.toml"
  mv "$CONFIG_HOME/invalid.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RESOURCE_LOG="$RESOURCE_LOG" \
    RIG_PLATFORM=macos "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *"out-of-range schedule.calendar pair 'hour=24'"* ]]
  [ ! -s "$RESOURCE_LOG" ]
}

@test "resource apply preflights every provider before any mutation" {
  write_resource_fixture
  sed '/^\[scheduled-job.morning\]/,/^\[profile.default\]/ s/provider = "runner"/provider = "bad"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/preflight.toml"
  printf '%s\n' \
    '' \
    '[provider.bad]' \
    'adapter = "custom"' \
    "executable = \"$RESOURCE_PROVIDER\"" \
    'capabilities = ["resource-observe"]' >>"$CONFIG_HOME/preflight.toml"
  mv "$CONFIG_HOME/preflight.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'bad' does not declare capability 'resource-apply'"* ]]
  [ ! -s "$RESOURCE_LOG" ]
  [ ! -e "$BATS_TEST_TMPDIR/state/resources/macos.tsv" ]
}

@test "resource locator transfer renames receipt ownership without retirement" {
  write_resource_fixture
  sed '/requires = \["base"\]/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/without-requirement.toml"
  mv "$CONFIG_HOME/without-requirement.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ]

  sed 's/\[service.daemon\]/[service.renamed]/; s/services = \["daemon"\]/services = ["renamed"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/renamed.toml"
  mv "$CONFIG_HOME/renamed.toml" "$CONFIG_HOME/rig.toml"
  : >"$RESOURCE_LOG"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ]
  grep -F 'rig-provider-v1 apply-resource runner renamed service example.test.daemon' "$RESOURCE_LOG"
  ! grep -F 'retire-resource runner daemon' "$RESOURCE_LOG"
  grep -F $'runner\tservice\trenamed\texample.test.daemon' "$BATS_TEST_TMPDIR/state/resources/macos.tsv"
  ! grep -F $'runner\tservice\tdaemon\t' "$BATS_TEST_TMPDIR/state/resources/macos.tsv"
}

@test "resource apply failure preserves the previous atomic receipt" {
  write_resource_fixture
  sed '/requires = \["base"\]/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/without-requirement.toml"
  mv "$CONFIG_HOME/without-requirement.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ]
  cp "$BATS_TEST_TMPDIR/state/resources/macos.tsv" "$BATS_TEST_TMPDIR/expected-receipt.tsv"

  sed 's/locator = "example.test.daemon"/locator = "example.test.daemon.changed"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/changed.toml"
  mv "$CONFIG_HOME/changed.toml" "$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RESOURCE_LOG="$RESOURCE_LOG" RESOURCE_FAIL_ID=daemon RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 1 ]
  cmp "$BATS_TEST_TMPDIR/expected-receipt.tsv" "$BATS_TEST_TMPDIR/state/resources/macos.tsv"
}

@test "status omits declared locators from the unmanaged table" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" != *$'declared\tsurveyor\tunmanaged'* ]] || false
}

@test "unmanaged locator matching remains inside provider namespace" {
  write_inventory_config
  printf '%s\n' \
    '[provider.other]' \
    'adapter = "custom"' \
    "executable = \"$INVENTORY_PROVIDER\"" \
    'capabilities = ["inventory"]' >>"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" != *$'declared\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" == *$'declared\tother\tunmanaged'* ]] || false
}

@test "unmanaged findings are informational and do not make status unhealthy" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
}

@test "status without the unmanaged flag invokes no inventory" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status

  [ "$status" -eq 0 ]
  [[ "$output" != *'Unmanaged:'* ]] || false
  [[ "$output" != *'IDENTITY'* ]] || false
}

@test "status reports an inventory native failure without exposing the provider exit" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_INVENTORY=exit-7 "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" == *$'surveyor\tunknown\texit:7'* ]] || false
  [[ "$output" == *'Unmanaged: 0'* ]] || false
}

@test "status reports an empty inventory as no unmanaged identities" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_INVENTORY=empty "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" == *'Unmanaged: 0'* ]] || false
}

@test "status reports an unavailable inventory executable without invocation" {
  write_inventory_config
  rm -f "$INVENTORY_PROVIDER"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 1 ]
  [[ "$output" == *$'surveyor\tunavailable\texecutable-unavailable'* ]] || false
}

@test "providers that declare no inventory capability are never asked to enumerate" {
  write_inventory_config
  sed 's/capabilities = \["observe", "inventory"\]/capabilities = ["observe"]/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/no-inventory.toml"
  mv "$CONFIG_HOME/no-inventory.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" == *'Unmanaged: 0'* ]] || false
}

@test "status rejects an unknown flag alongside unmanaged" {
  write_inventory_config

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged --bogus

  [ "$status" -eq 2 ]
}

@test "an artifact declared on a tool is not unmanaged whichever provider observed it" {
  write_inventory_config
  sed 's|^platforms = \["any"\]$|platforms = ["any"]\nartifacts = ["undeclared-one"]|' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/artifact.toml"
  mv "$CONFIG_HOME/artifact.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" != *$'undeclared-one\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" == *$'undeclared two\tsurveyor\tunmanaged\t-'* ]] || false
  [[ "$output" == *'Unmanaged: 1'* ]] || false
}

@test "a tool may declare several artifacts" {
  write_inventory_config
  sed 's|^platforms = \["any"\]$|platforms = ["any"]\nartifacts = ["undeclared-one", "undeclared two"]|' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/artifacts.toml"
  mv "$CONFIG_HOME/artifacts.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" == *'Unmanaged: 0'* ]] || false
}

@test "artifact comparison expands only supported leading home prefixes" {
  write_inventory_config
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '[ "$1" = rig-provider-v1 ] || exit 64' \
    'case "$2" in' \
    '  observe) printf "present\n" ;;' \
    '  inventory)' \
    '    printf "%s\n" "$HOME/bin/home-tool" "$HOME/bin/tilde-tool"' \
    '    printf "%s\n" "/opt/rig/absolute-tool"' \
    '    printf "%s\n" "prefix-$HOME/bin/embedded" "$HOME/bin/other"' \
    '    ;;' \
    '  *) exit 65 ;;' \
    'esac' >"$INVENTORY_PROVIDER"
  chmod +x "$INVENTORY_PROVIDER"
  sed 's|^platforms = \["any"\]$|platforms = ["any"]\
artifacts = ["$HOME/bin/home-tool", "~/bin/tilde-tool", "/opt/rig/absolute-tool", "prefix-$HOME/bin/embedded", "$TOOLS_HOME/bin/other"]|' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/artifacts.toml"
  mv "$CONFIG_HOME/artifacts.toml" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    "$RIG" status --unmanaged

  [ "$status" -eq 0 ]
  [[ "$output" != *$'home-tool\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" != *$'tilde-tool\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" != *$'absolute-tool\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" == *$'prefix-'"$TEST_HOME"$'/bin/embedded\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" == *$TEST_HOME$'/bin/other\tsurveyor\tunmanaged'* ]] || false
  [[ "$output" == *'Unmanaged: 2'* ]] || false
}
