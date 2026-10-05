#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG_ROOT=$BATS_TEST_DIRNAME/..
  source "$RIG_ROOT/src/rig/05-declarations.bash"
  source "$RIG_ROOT/src/rig/10-configuration.bash"
}

@test "declaration registry separates active intent observation and supporting records" {
  RIG_VALUE=unread-value
  rig_declaration_lookup port || false
  [ "$RIG_DECLARATION_ROLE" = setup ] || false
  rig_declaration_lookup retired-application || false
  [ "$RIG_DECLARATION_ROLE" = observation ] || false
  rig_declaration_lookup dock-item || false
  [ "$RIG_DECLARATION_ROLE" = component ] || false
  rig_declaration_lookup profile || false
  [ "$RIG_DECLARATION_ROLE" = supporting ] || false
  rig_declaration_lookup action || false
  [ "$RIG_DECLARATION_ROLE" = extension ] || false
  [ "$RIG_VALUE" = unread-value ] || false

  ! rig_declaration_lookup binding || false
  [ -z "$RIG_DECLARATION_ROLE" ] || false
  [ -z "$RIG_DECLARATION_SEGMENTS" ] || false
  [ -z "$RIG_DECLARATION_LABEL" ] || false
}

@test "registry identity shapes accept every declaration and reject malformed identities" {
  local record kind identity seen
  seen='|'
  for record in "${RIG_DECLARATION_REGISTRY[@]}"; do
    kind=${record%%|*}
    [[ "$seen" != *"|$kind|"* ]] || false
    seen="$seen$kind|"
    rig_declaration_lookup "$kind" || false
    [ -n "$RIG_DECLARATION_LABEL" ] || false
    case "$RIG_DECLARATION_SEGMENTS" in
      0) identity=$kind ;;
      1) identity=$kind.example ;;
      2) identity=$kind.example.operation ;;
      *) false ;;
    esac
    rig_parse_section_identity "$identity" || false
    [ "$RIG_SECTION_TYPE" = "$kind" ] || false
    case "$RIG_DECLARATION_SEGMENTS" in
      0) [ -z "$RIG_SECTION_ID" ] || false ;;
      1) [ "$RIG_SECTION_ID" = example ] || false ;;
      2)
        [ "$RIG_SECTION_ID" = example ] || false
        [ "$RIG_SECTION_SECONDARY_ID" = operation ] || false
        ;;
    esac
    ! rig_parse_section_identity "$identity.extra" || false
  done

  for identity in tool tool. tool.Example tool.1example tool.example.extra \
    action action.example action.example. action.example.operation.extra \
    rig.example binding.example unknown.example; do
    ! rig_parse_section_identity "$identity" || false
  done
}

@test "Getting Started lists every setup and observation type exactly once" {
  local record kind expected actual
  expected=$BATS_TEST_TMPDIR/expected-items
  actual=$BATS_TEST_TMPDIR/documented-items
  : >"$expected"
  for record in "${RIG_DECLARATION_REGISTRY[@]}"; do
    kind=${record%%|*}
    rig_declaration_lookup "$kind" || false
    case "$RIG_DECLARATION_ROLE" in
      setup|observation) printf '%s\n' "$RIG_DECLARATION_LABEL" >>"$expected" ;;
    esac
  done
  awk '
    /^## What Rig can manage$/ { inventory = 1; next }
    inventory && /^Supported installation methods / { exit }
    inventory && /^- \*\*/ {
      sub(/^- \*\*/, "")
      sub(/:\*\*.*/, "")
      print
    }
  ' "$RIG_ROOT/docs/guides/user/getting-started.md" >"$actual"
  [ "$(LC_ALL=C sort "$expected")" = "$(LC_ALL=C sort "$actual")" ] || false
}

@test "canonical table specification includes every registry identity exactly once" {
  local record kind identity expected actual
  expected=$BATS_TEST_TMPDIR/expected-tables
  actual=$BATS_TEST_TMPDIR/documented-tables
  : >"$expected"
  for record in "${RIG_DECLARATION_REGISTRY[@]}"; do
    kind=${record%%|*}
    rig_declaration_lookup "$kind" || false
    case "$RIG_DECLARATION_SEGMENTS" in
      0) identity=$kind ;;
      1) identity=$kind.ID ;;
      2) identity=$kind.PROVIDER.NAME ;;
      *) false ;;
    esac
    printf '`[%s]`\n' "$identity" >>"$expected"
  done
  sed -n '/^### RIG-CONF-008 — /,/^_Conformance:_/p' \
    "$RIG_ROOT/docs/specs/configuration.md" | grep -oE '`\[[^`]+\]`' >"$actual"
  [ "$(LC_ALL=C sort "$expected")" = "$(LC_ALL=C sort "$actual")" ] || false
}
