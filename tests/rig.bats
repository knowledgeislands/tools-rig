#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
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

run_loader() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" \
    bash -c '. "$1"; rig_load_config' _ "$RIG"
}

@test "help describes the current command surface" {
  run "$RIG" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rig"* ]]
  [[ "$output" == *"paths"* ]]
  [[ "$output" == *"completion bash|zsh"* ]]
}

@test "version comes from the executable marker" {
  run "$RIG" --version

  [ "$status" -eq 0 ]
  [ "$output" = "rig 0.1.0" ]
}

@test "paths follow XDG base directories" {
  run env \
    HOME=/tmp/rig-home \
    XDG_CONFIG_HOME=/tmp/rig-config \
    XDG_DATA_HOME=/tmp/rig-data \
    XDG_STATE_HOME=/tmp/rig-state \
    XDG_CACHE_HOME=/tmp/rig-cache \
    "$RIG" paths

  [ "$status" -eq 0 ]
  [ "$output" = $'config=/tmp/rig-config/rig\ndata=/tmp/rig-data/rig\nstate=/tmp/rig-state/rig\ncache=/tmp/rig-cache/rig' ]
}

@test "Rig path overrides take precedence" {
  run env \
    HOME=/tmp/rig-home \
    RIG_CONFIG_HOME=/tmp/custom-config \
    RIG_DATA_HOME=/tmp/custom-data \
    RIG_STATE_HOME=/tmp/custom-state \
    RIG_CACHE_HOME=/tmp/custom-cache \
    "$RIG" paths

  [ "$status" -eq 0 ]
  [ "$output" = $'config=/tmp/custom-config\ndata=/tmp/custom-data\nstate=/tmp/custom-state\ncache=/tmp/custom-cache' ]
}

@test "completion emits shell registration" {
  run "$RIG" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"complete -F _rig rig"* ]]

  run "$RIG" completion zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#compdef rig"* ]]
  [[ "$output" == *"compdef _rig rig"* ]]
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
