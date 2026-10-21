# rig-module: 21-signed-release
# shellcheck shell=bash
# Cross-module state intentionally consumed by the assembled runtime.
# shellcheck disable=SC2034

rig_release_version_valid() {
  local pattern
  pattern='^v(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$'
  [[ $1 =~ $pattern ]]
}

rig_release_version_compare() {
  local left right index
  local -a left_parts right_parts
  left=${1#v}
  right=${2#v}
  IFS=. read -r -a left_parts <<< "$left"
  IFS=. read -r -a right_parts <<< "$right"
  RIG_VERSION_ORDER=0
  for index in 0 1 2; do
    if [ "${left_parts[$index]}" -gt "${right_parts[$index]}" ]; then
      RIG_VERSION_ORDER=1; return
    elif [ "${left_parts[$index]}" -lt "${right_parts[$index]}" ]; then
      RIG_VERSION_ORDER=-1; return
    fi
  done
}

rig_validate_version_policy() {
  local binding adapter kind exact minimum field
  binding=$1; adapter=$2; kind=$3
  exact=; minimum=
  if rig_get_value "$binding" version; then exact=$RIG_VALUE; fi
  if rig_get_value "$binding" minimum-version; then minimum=$RIG_VALUE; fi
  for field in "$exact" "$minimum"; do
    [ -z "$field" ] || rig_release_version_valid "$field" ||
      rig_fail "[$binding] version policy requires canonical vMAJOR.MINOR.PATCH (nine digits per component)" || return
  done
  if [ -n "$exact" ]; then
    [ "$adapter:$kind" = direct-download:signed-release ] ||
      rig_fail "[$binding] install.version is only valid for signed-release" || return
  fi
  if [ -n "$minimum" ]; then
    case "$adapter:$kind" in
      direct-download:signed-release|homebrew:formula) ;;
      *) rig_fail "[$binding] install.minimum-version requires signed-release or Homebrew formula" || return ;;
    esac
  fi
  if [ -n "$exact" ] && [ -n "$minimum" ]; then
    rig_release_version_compare "$exact" "$minimum"
    [ "$RIG_VERSION_ORDER" -ge 0 ] || rig_fail "[$binding] exact version is below minimum-version" || return
  fi
  if [ "$adapter:$kind" != direct-download:signed-release ]; then
    if rig_get_value "$binding" release-name || rig_get_value "$binding" public-key; then
      rig_fail "[$binding] release-name and public-key require signed-release" || return
    fi
  fi
}

rig_validate_signed_release() {
  local binding locator name destination key
  binding=$1
  rig_get_value "$binding" locator || return 2
  locator=$RIG_VALUE
  case "$locator" in https://?*) ;; *) rig_fail "[$binding] signed-release locator must use HTTPS" || return ;; esac
  case "$locator" in *'?'*|*'#'*|*$'\n'*|*$'\r'*|*$'\t'*) rig_fail "[$binding] unsafe release base" || return ;; esac
  rig_require_field "$binding" release-name || return
  name=$RIG_VALUE
  rig_valid_id "$name" || rig_fail "[$binding] invalid release-name" || return
  rig_require_field "$binding" public-key || return
  key=$RIG_VALUE
  case "$key" in /*) ;; *) rig_fail "[$binding] public-key must be an absolute local PEM path or start with '~/': $key" || return ;; esac
  rig_require_field "$binding" destination || return
  destination=$RIG_VALUE
  rig_signed_home_path "$destination" || rig_fail "[$binding] signed-release destination must be a safe path inside HOME" || return
  if ! rig_get_value "$binding" version && ! rig_get_value "$binding" minimum-version; then
    rig_fail "[$binding] signed-release requires version or minimum-version" || return
  fi
  if rig_get_value "$binding" checksum || rig_get_value "$binding" argument; then
    rig_fail "[$binding] signed-release forbids checksum-only metadata and install.arguments" || return
  fi
}

rig_signed_home_path() {
  [ -n "${HOME:-}" ] || return 1
  case "$1" in "$HOME"/?*) ;; *) return 1 ;; esac
  case "$1/" in *'/../'*|*'/./'*|*'//'*|*$'\n'*|*$'\r'*|*$'\t'*) return 1 ;; esac
  case "$1" in */) return 1 ;; esac
}

# Require an existing writable parent, reject links all the way to HOME and
# resolve the parent physically before any staging or replacement.
rig_signed_destination_safe() {
  local destination ancestor parent physical_home physical_parent
  destination=$1
  rig_signed_home_path "$destination" || return 1
  ancestor=$destination
  while [ "$ancestor" != "$HOME" ]; do
    [ ! -L "$ancestor" ] || return 1
    ancestor=${ancestor%/*}
  done
  [ ! -L "$HOME" ] || return 1
  [ ! -e "$destination" ] || [ -f "$destination" ] || return 1
  parent=${destination%/*}
  [ -d "$parent" ] && [ -w "$parent" ] || return 1
  physical_home=$(cd "$HOME" && pwd -P) || return 1
  physical_parent=$(cd "$parent" && pwd -P) || return 1
  case "$physical_parent/" in "$physical_home/"*) return 0 ;; esac
  return 1
}

rig_signed_target() {
  local platform architecture
  rig_current_platform || return
  platform=$RIG_VALUE
  architecture=${RIG_ARCH:-$(uname -m)}
  case "$architecture" in arm64|aarch64) architecture=arm64 ;; x64|x86_64|amd64) architecture=x64 ;; *) return 1 ;; esac
  case "$platform" in macos) platform=darwin ;; linux) ;; *) return 1 ;; esac
  RIG_VALUE=$platform-$architecture
}

rig_preflight_signed_release() {
  local binding destination key verifier command text
  binding=$1
  rig_signed_target || rig_fail 'signed-release platform or architecture is unsupported' || return
  rig_get_value "$binding" destination || return 2
  destination=$RIG_VALUE
  rig_signed_destination_safe "$destination" || rig_fail "signed-release refuses unsafe or unavailable destination: $destination" || return
  rig_get_value "$binding" public-key || return 2
  key=$RIG_VALUE
  [ -f "$key" ] && [ ! -L "$key" ] && [ -r "$key" ] || rig_fail 'signed-release public key must be a readable regular local PEM file' || return
  verifier=${RIG_OPENSSL:-openssl}
  for command in "$verifier" tar mktemp mv rm chmod tail od tr; do
    rig_executable_available "$command" || rig_fail "signed-release required executable unavailable: $command" || return
  done
  rig_sha256_available || rig_fail 'signed-release SHA-256 verifier unavailable' || return
  text=$("$verifier" pkey -pubin -inform PEM -in "$key" -text -noout 2>/dev/null) || rig_fail 'signed-release public key is invalid' || return
  case "$text" in 'ED25519 Public-Key:'*) ;; *) rig_fail 'signed-release requires an Ed25519 public key' || return ;; esac
}

rig_observe_release_version() {
  local binding actual exact minimum
  binding=$1; actual=$2
  case "$actual" in v*) ;; *) actual=v$actual ;; esac
  RIG_OBSERVATION=unknown
  RIG_OBSERVATION_DETAIL='version-unavailable'
  rig_release_version_valid "$actual" || return 0
  exact=; minimum=
  if rig_get_value "$binding" version; then exact=$RIG_VALUE; fi
  if rig_get_value "$binding" minimum-version; then minimum=$RIG_VALUE; fi
  RIG_OBSERVATION=present
  RIG_OBSERVATION_DETAIL=version:$actual
  if [ -n "$exact" ]; then
    RIG_OBSERVATION_DETAIL="$RIG_OBSERVATION_DETAIL;exact:$exact"
    [ "$actual" = "$exact" ] || RIG_OBSERVATION=drifted
  fi
  if [ -n "$minimum" ]; then
    RIG_OBSERVATION_DETAIL="$RIG_OBSERVATION_DETAIL;minimum:$minimum"
    rig_release_version_compare "$actual" "$minimum"
    [ "$RIG_VERSION_ORDER" -ge 0 ] || RIG_OBSERVATION=drifted
  fi
}

rig_observe_signed_release() {
  local binding destination actual
  binding=$1
  rig_get_value "$binding" destination || return 2
  destination=$RIG_VALUE
  RIG_OBSERVATION=unavailable; RIG_OBSERVATION_DETAIL=unsafe-destination
  rig_signed_destination_safe "$destination" || return 0
  if [ ! -e "$destination" ]; then RIG_OBSERVATION=missing; RIG_OBSERVATION_DETAIL=not-installed; return 0; fi
  RIG_OBSERVATION=unknown; RIG_OBSERVATION_DETAIL='version-unavailable'
  [ -x "$destination" ] || return 0
  actual=$("$destination" --version 2>/dev/null) || return 0
  rig_observe_release_version "$binding" "$actual"
}

rig_observe_homebrew_minimum() {
  local binding locator output identity candidate suffix best
  local -a words
  binding=$1; locator=$2; output=$3
  RIG_OBSERVATION=unknown; RIG_OBSERVATION_DETAIL='version-unavailable'
  case "$output" in *$'\n'*) return 0 ;; esac
  read -r -a words <<< "$output"
  [ "${#words[@]}" -gt 1 ] || return 0
  identity=${words[0]}
  [ "$identity" = "${locator##*/}" ] || return 0
  best=
  for candidate in "${words[@]:1}"; do
    case "$candidate" in
      *_*) suffix=${candidate#*_}; case "$suffix" in ''|*[!0-9]*) continue ;; esac; candidate=${candidate%%_*} ;;
    esac
    candidate=v$candidate
    rig_release_version_valid "$candidate" || continue
    if [ -n "$best" ]; then
      rig_release_version_compare "$candidate" "$best"
      [ "$RIG_VERSION_ORDER" -gt 0 ] || continue
    fi
    best=$candidate
  done
  [ -n "$best" ] || return 0
  rig_observe_release_version "$binding" "$best"
}

rig_apply_homebrew_minimum() {
  local tool binding provider verb executable
  tool=$1; binding=$2; provider=$3
  rig_observe_provider "$tool" "$binding" "$provider" || return
  case "$RIG_OBSERVATION" in
    present) return 0 ;;
    missing) verb=apply ;;
    drifted) verb=upgrade-minimum ;;
    *) rig_fail 'Homebrew minimum version cannot be established' || return ;;
  esac
  rig_prepare_builtin_invocation "$verb" "$binding" "$provider" || return
  executable=$RIG_EXECUTABLE
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
}

# The signature has already been verified when this parser is called. Every
# line, including the last, must end in LF; every target occurs at most once.
rig_signed_manifest_digest() {
  local manifest name version asset line number digest filename target seen pattern
  manifest=$1; name=$2; version=$3; asset=$4
  number=0; seen=' '; RIG_VALUE=
  pattern='^[0-9a-f]{64}  '
  while IFS= read -r line || [ -n "$line" ]; do
    # read returns non-zero for a partial final line: detect it independently
    # using the manifest's last byte before reaching this parser.
    number=$((number + 1))
    case "$number" in
      1) [ "$line" = "format=$name-release-checksums-v1" ] || return 1 ;;
      2) [ "$line" = "version=$version" ] || return 1 ;;
      *)
        [ "$number" -le 6 ] && [[ $line =~ $pattern ]] || return 1
        digest=${line:0:64}; filename=${line:66}
        case "$filename" in "$name-$version-"*.tar.gz) ;; *) return 1 ;; esac
        target=${filename#"$name-$version-"}; target=${target%.tar.gz}
        case "$target" in darwin-arm64|darwin-x64|linux-arm64|linux-x64) ;; *) return 1 ;; esac
        case "$seen" in *" $target "*) return 1 ;; esac
        seen="$seen$target "
        [ "$filename" != "$asset" ] || RIG_VALUE=$digest
        ;;
    esac
  done < "$manifest"
  [ "$number" -ge 3 ] && [ -n "$RIG_VALUE" ]
}

# A subshell owns its cleanup traps; the single final rename is the only
# installed-file mutation. Archive members are streamed, never extracted.
rig_apply_signed_release() (
  local binding provider destination name key version base target asset stage verifier expected actual members listing line count executable
  binding=$1; provider=$2
  rig_preflight_signed_release "$binding" || exit 1
  rig_observe_signed_release "$binding" || exit 1
  [ "$RIG_OBSERVATION" != present ] || exit 0
  rig_get_value "$binding" destination || exit 2; destination=$RIG_VALUE
  rig_get_value "$binding" release-name || exit 2; name=$RIG_VALUE
  rig_get_value "$binding" public-key || exit 2; key=$RIG_VALUE
  if ! rig_get_value "$binding" version; then rig_get_value "$binding" minimum-version || exit 2; fi
  version=$RIG_VALUE
  rig_get_value "$binding" locator || exit 2; base=${RIG_VALUE%/}
  rig_signed_target || exit 1; target=$RIG_VALUE
  asset=$name-$version-$target.tar.gz
  verifier=${RIG_OPENSSL:-openssl}
  stage=$(mktemp -d "${destination%/*}/.rig-signed.XXXXXX") || exit 1
  RIG_SIGNED_STAGE=$stage
  trap 'rm -rf "$RIG_SIGNED_STAGE"' EXIT
  trap 'exit 1' HUP INT TERM
  rig_provider_executable "$provider" direct-download signed-release || exit 2
  executable=$RIG_VALUE
  for target in "$name-checksums.txt" "$name-checksums.txt.sig"; do
    rig_prepare_builtin_invocation apply "$binding" "$provider" || exit 2
    "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" --output "$stage/$target" "$base/releases/download/$version/$target" 1>&2 || exit 1
  done
  "$verifier" pkeyutl -verify -rawin -pubin -inkey "$key" -in "$stage/$name-checksums.txt" -sigfile "$stage/$name-checksums.txt.sig" >/dev/null 2>&1 || { rig_fail 'signed-release manifest signature verification failed'; exit 1; }
  # Check framing only after authentication, before parsing any manifest data.
  actual=$(tail -c 1 "$stage/$name-checksums.txt" | od -An -t x1 | tr -d '[:space:]')
  [ "$actual" = 0a ] || { rig_fail 'signed-release malformed manifest'; exit 1; }
  rig_signed_manifest_digest "$stage/$name-checksums.txt" "$name" "$version" "$asset" || { rig_fail 'signed-release malformed manifest or missing target'; exit 1; }
  expected=$RIG_VALUE
  rig_prepare_builtin_invocation apply "$binding" "$provider" || exit 2
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" --output "$stage/archive" "$base/releases/download/$version/$asset" 1>&2 || exit 1
  rig_sha256_file "$stage/archive" || exit 1; actual=$RIG_VALUE
  [ "$actual" = "$expected" ] || { rig_fail 'signed-release archive checksum mismatch'; exit 1; }
  members=$(tar -tzf "$stage/archive") || exit 1
  [ "$members" = "$(printf '%s\nman/%s.1' "$name" "$name")" ] || { rig_fail 'signed-release unsafe archive members'; exit 1; }
  listing=$(tar -tvzf "$stage/archive") || exit 1
  count=0
  while IFS= read -r line; do
    case "$line" in -*) ;; *) rig_fail 'signed-release non-regular archive member'; exit 1 ;; esac
    count=$((count + 1))
  done <<< "$listing"
  [ "$count" -eq 2 ] || exit 1
  tar -xOzf "$stage/archive" "$name" > "$stage/payload" || exit 1
  chmod 0755 "$stage/payload" || exit 1
  actual=$("$stage/payload" --version) || exit 1
  case "$actual" in v*) ;; *) actual=v$actual ;; esac
  [ "$actual" = "$version" ] || { rig_fail 'signed-release payload version mismatch'; exit 1; }
  rig_signed_destination_safe "$destination" || { rig_fail 'signed-release destination became unsafe'; exit 1; }
  mv -f "$stage/payload" "$destination" || exit 1
)
