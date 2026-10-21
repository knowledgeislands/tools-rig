#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
SIGNED_OPENSSL=${SIGNED_OPENSSL:-${RIG_TEST_OPENSSL:-${RIG_OPENSSL:-$(command -v openssl)}}}

setup() {
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export RIG_OPENSSL=$SIGNED_OPENSSL RIG_ARCH=x64
  export RIG_SIGNED_FIXTURES=$BATS_TEST_TMPDIR/releases
  export RIG_SIGNED_LOG=$BATS_TEST_TMPDIR/downloads
  mkdir -p "$RIG_CONFIG_HOME/conf.d" "$HOME/bin" "$RIG_SIGNED_FIXTURES/payload/man" "$HOME/keys"
  export SIGNED_OPENSSL
  "$SIGNED_OPENSSL" genpkey -algorithm ED25519 -out "$BATS_TEST_TMPDIR/signing.pem" >/dev/null 2>&1
  "$SIGNED_OPENSSL" pkey -in "$BATS_TEST_TMPDIR/signing.pem" -pubout -out "$BATS_TEST_TMPDIR/public.pem" >/dev/null 2>&1
  "$SIGNED_OPENSSL" genpkey -algorithm ED25519 -out "$BATS_TEST_TMPDIR/wrong.pem" >/dev/null 2>&1
  "$SIGNED_OPENSSL" pkey -in "$BATS_TEST_TMPDIR/wrong.pem" -pubout -out "$BATS_TEST_TMPDIR/wrong-public.pem" >/dev/null 2>&1
  cp "$BATS_TEST_TMPDIR/public.pem" "$HOME/keys/public.pem"
  : > "$RIG_SIGNED_LOG"
  cat > "$RIG_TEST_PROVIDER_BIN/curl" <<'SH'
#!/bin/bash
set -u
[ "$#" -eq 11 ] || exit 99
[ "$1|$2|$3|$4|$5|$6|$7|$8|$9" = '--fail|--location|--proto|=https|--proto-redir|=https|--silent|--show-error|--output' ] || exit 99
url=${11}; output=${10}; leaf=${url##*/}
[ "$url" = "https://releases.invalid/sample/releases/download/$RIG_SIGNED_FIXTURE_VERSION/$leaf" ] || exit 99
case "$output" in "$HOME/bin/.rig-signed."*/*) ;; *) exit 99 ;; esac
case "$leaf" in sample-checksums.txt|sample-checksums.txt.sig|sample-v*-darwin-arm64.tar.gz|sample-v*-darwin-x64.tar.gz|sample-v*-linux-arm64.tar.gz|sample-v*-linux-x64.tar.gz) ;; *) exit 99 ;; esac
printf '%s\n' "$url" >> "$RIG_SIGNED_LOG"
cp "$RIG_SIGNED_FIXTURES/$leaf" "$output"
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/curl"
  make_release v1.2.3
  write_signed_config 'install.version = "v1.2.3"'
}

sign_manifest() {
  "$SIGNED_OPENSSL" pkeyutl -sign -rawin -inkey "$BATS_TEST_TMPDIR/signing.pem" \
    -in "$RIG_SIGNED_FIXTURES/sample-checksums.txt" -out "$RIG_SIGNED_FIXTURES/sample-checksums.txt.sig"
}

manifest_for_archives() {
  local target digest
  printf 'format=sample-release-checksums-v1\nversion=%s\n' "$RIG_SIGNED_FIXTURE_VERSION" > "$RIG_SIGNED_FIXTURES/sample-checksums.txt"
  for target in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
    digest=$(shasum -a 256 "$RIG_SIGNED_FIXTURES/sample-$RIG_SIGNED_FIXTURE_VERSION-$target.tar.gz") || return 1
    printf '%s  sample-%s-%s.tar.gz\n' "${digest%% *}" "$RIG_SIGNED_FIXTURE_VERSION" "$target" >> "$RIG_SIGNED_FIXTURES/sample-checksums.txt"
  done
  sign_manifest
}

make_release() {
  local target
  export RIG_SIGNED_FIXTURE_VERSION=$1
  printf '#!/bin/bash\n[ "$1" = --version ] || exit 99\nprintf "%%s\\n" "%s"\n' "${1#v}" > "$RIG_SIGNED_FIXTURES/payload/sample"
  printf '.TH SAMPLE 1\n' > "$RIG_SIGNED_FIXTURES/payload/man/sample.1"
  chmod 0755 "$RIG_SIGNED_FIXTURES/payload/sample"
  for target in darwin-arm64 darwin-x64 linux-arm64 linux-x64; do
    tar -czf "$RIG_SIGNED_FIXTURES/sample-$1-$target.tar.gz" -C "$RIG_SIGNED_FIXTURES/payload" sample man/sample.1 || return 1
  done
  manifest_for_archives
}

write_signed_config() {
  cat > "$RIG_CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "host"
[category.core]
name = "Core"
purpose = "Signed fixture tools"
[tool.sample]
name = "Sample"
category = "core"
purpose = "Exercise authenticated releases"
rationale = "Verify before installing"
platforms = ["macos", "linux"]
install.provider = "direct-download"
install.kind = "signed-release"
install.locator = "https://releases.invalid/sample"
install.release-name = "sample"
install.public-key = "~/keys/public.pem"
install.destination = "~/bin/sample"
$1
[profile.host]
name = "Host"
tools = ["sample"]
EOF
}

assert_failure_preserves() {
  printf 'preserve existing destination\n' > "$HOME/bin/sample"
  run "$RIG" apply
  [ "$status" -ne 0 ] || return 1
  [ "$(cat "$HOME/bin/sample")" = 'preserve existing destination' ] || return 1
  ! compgen -G "$HOME/bin/.rig-signed.*" >/dev/null || return 1
}

@test "signed-release installs exact home-only commands on all four platform targets and reports versions" {
  local platform arch target
  for platform in macos linux; do
    for arch in x64 arm64; do
      rm -f "$HOME/bin/sample"
      : > "$RIG_SIGNED_LOG"
      run env RIG_PLATFORM="$platform" RIG_ARCH="$arch" "$RIG" apply
      [ "$status" -eq 0 ] || false
      [ "$("$HOME/bin/sample" --version)" = 1.2.3 ] || false
      [ ! -e "$HOME/bin/man" ] || false
      [ "$(wc -l < "$RIG_SIGNED_LOG" | tr -d ' ')" -eq 3 ] || false
      target=$platform; [ "$platform" != macos ] || target=darwin
      grep -Fq "sample-v1.2.3-$target-$arch.tar.gz" "$RIG_SIGNED_LOG" || false
      run env RIG_PLATFORM="$platform" "$RIG" status --json
      [ "$status" -eq 0 ] || false
      [[ "$output" == *'version:v1.2.3;exact:v1.2.3'* ]] || false
      ! compgen -G "$HOME/bin/.rig-signed.*" >/dev/null || false
    done
  done
}

@test "signed-release minimum installs the floor and preserves compatible newer versions numerically" {
  write_signed_config 'install.minimum-version = "v1.2.3"'
  run "$RIG" apply
  [ "$status" -eq 0 ] || false
  printf '#!/bin/bash\nprintf "1.10.0\\n"\n' > "$HOME/bin/sample"
  : > "$RIG_SIGNED_LOG"
  run "$RIG" status --json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'version:v1.10.0;minimum:v1.2.3'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
  [ "$("$HOME/bin/sample" --version)" = 1.10.0 ] || false
  printf '#!/bin/bash\nprintf "1.1.99\\n"\n' > "$HOME/bin/sample"
  run "$RIG" apply
  [ "$status" -eq 0 ] || false
  [ "$("$HOME/bin/sample" --version)" = 1.2.3 ] || false
}

@test "signed-release exact pin replaces a newer version while respecting a shared minimum" {
  write_signed_config $'install.version = "v1.2.3"\ninstall.minimum-version = "v1.0.0"'
  printf '#!/bin/bash\nprintf "1.10.0\\n"\n' > "$HOME/bin/sample"
  chmod +x "$HOME/bin/sample"
  run "$RIG" status --json
  [[ "$output" == *'drifted'* && "$output" == *'version:v1.10.0;exact:v1.2.3;minimum:v1.0.0'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ] || false
  [ "$("$HOME/bin/sample" --version)" = 1.2.3 ] || false
}

@test "signature failures wrong keys and altered manifests fail before requesting an archive" {
  local scenario
  for scenario in missing invalid wrong-key altered; do
    make_release v1.2.3
    cp "$BATS_TEST_TMPDIR/public.pem" "$HOME/keys/public.pem"
    : > "$RIG_SIGNED_LOG"
    case "$scenario" in
      missing) rm "$RIG_SIGNED_FIXTURES/sample-checksums.txt.sig" ;;
      invalid) printf invalid > "$RIG_SIGNED_FIXTURES/sample-checksums.txt.sig" ;;
      wrong-key) cp "$BATS_TEST_TMPDIR/wrong-public.pem" "$HOME/keys/public.pem" ;;
      altered) printf altered >> "$RIG_SIGNED_FIXTURES/sample-checksums.txt" ;;
    esac
    assert_failure_preserves || false
    ! grep -q 'tar.gz' "$RIG_SIGNED_LOG" || false
    [ "$(wc -l < "$RIG_SIGNED_LOG" | tr -d ' ')" -eq 2 ] || false
    if [ "$scenario" != missing ]; then
      [[ "$output" == *'manifest signature verification failed'* ]] || false
    fi
  done
}

@test "authenticated manifest framing duplicate targets wrong versions and missing targets fail closed" {
  local scenario manifest
  manifest=$RIG_SIGNED_FIXTURES/sample-checksums.txt
  for scenario in format version duplicate target crlf no-final-lf; do
    make_release v1.2.3
    case "$scenario" in
      format) sed 's/format=sample/format=foreign/' "$manifest" > "$manifest.new" ;;
      version) sed 's/version=v1.2.3/version=v9.9.9/' "$manifest" > "$manifest.new" ;;
      duplicate) cat "$manifest" > "$manifest.new"; tail -n 1 "$manifest" >> "$manifest.new" ;;
      target) sed '/darwin-x64/d' "$manifest" > "$manifest.new" ;;
      crlf) awk '{printf "%s\r\n", $0}' "$manifest" > "$manifest.new" ;;
      no-final-lf) printf '%s' "$(cat "$manifest")" > "$manifest.new" ;;
    esac
    mv "$manifest.new" "$manifest"
    sign_manifest
    : > "$RIG_SIGNED_LOG"
    assert_failure_preserves || false
    [[ "$output" == *'malformed manifest'* ]] || false
    ! grep -q 'tar.gz' "$RIG_SIGNED_LOG" || false
    [ "$(wc -l < "$RIG_SIGNED_LOG" | tr -d ' ')" -eq 2 ] || false
  done
}

@test "altered archives and signed payload version mismatches preserve the installed destination" {
  printf corrupted >> "$RIG_SIGNED_FIXTURES/sample-v1.2.3-darwin-x64.tar.gz"
  assert_failure_preserves
  [[ "$output" == *'archive checksum mismatch'* ]] || false
  make_release v1.2.3
  printf '#!/bin/bash\nprintf "9.9.9\\n"\n' > "$RIG_SIGNED_FIXTURES/payload/sample"
  tar -czf "$RIG_SIGNED_FIXTURES/sample-v1.2.3-darwin-x64.tar.gz" -C "$RIG_SIGNED_FIXTURES/payload" sample man/sample.1
  manifest_for_archives
  assert_failure_preserves
  [[ "$output" == *'payload version mismatch'* ]] || false
}

@test "signed archives reject traversal absolute duplicate extra and non-regular members" {
  local scenario
  for scenario in traversal absolute duplicate extra symlink hardlink directory manual-link; do
    make_release v1.2.3
    python3 - "$RIG_SIGNED_FIXTURES/sample-v1.2.3-darwin-x64.tar.gz" "$scenario" <<'PY'
import io, sys, tarfile
path, scenario = sys.argv[1:]
with tarfile.open(path, 'w:gz', format=tarfile.USTAR_FORMAT) as archive:
    for name in ['sample', 'man/sample.1'] + (['sample'] if scenario == 'duplicate' else ['extra'] if scenario == 'extra' else []):
        info = tarfile.TarInfo(name)
        if name == 'sample':
            if scenario == 'traversal': info.name = '../escape'
            if scenario == 'absolute': info.name = '/escape'
            if scenario == 'symlink': info.type, info.linkname = tarfile.SYMTYPE, '../escape'
            if scenario == 'hardlink': info.type, info.linkname = tarfile.LNKTYPE, '/escape'
            if scenario == 'directory': info.type = tarfile.DIRTYPE
        elif scenario == 'manual-link': info.type, info.linkname = tarfile.SYMTYPE, '/escape'
        data = b'#!/bin/bash\nprintf "1.2.3\\n"\n'
        if info.isreg(): info.size = len(data)
        archive.addfile(info, io.BytesIO(data) if info.isreg() else None)
PY
    manifest_for_archives
    assert_failure_preserves || false
    [[ "$output" == *'unsafe archive members'* || "$output" == *'non-regular archive member'* ]] || false
    [ ! -e "$HOME/escape" ] || false
  done
}

@test "signed-release rejects unsupported targets missing verifiers and non-Ed25519 keys before downloading" {
  run env RIG_ARCH=sparc "$RIG" apply
  [ "$status" -ne 0 ] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
  sed 's/\["macos", "linux"\]/["freebsd"]/' "$RIG_CONFIG_HOME/rig.toml" > "$RIG_CONFIG_HOME/new"
  mv "$RIG_CONFIG_HOME/new" "$RIG_CONFIG_HOME/rig.toml"
  run env RIG_PLATFORM=freebsd "$RIG" apply
  [ "$status" -ne 0 ] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
  write_signed_config 'install.version = "v1.2.3"'
  mv "$HOME/keys/public.pem" "$HOME/keys/saved.pem"
  run "$RIG" apply
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'readable regular local PEM file'* ]] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
  mv "$HOME/keys/saved.pem" "$HOME/keys/public.pem"
  run env RIG_OPENSSL="$HOME/absent-openssl" "$RIG" apply
  [ "$status" -ne 0 ] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
  "$SIGNED_OPENSSL" genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 -out "$BATS_TEST_TMPDIR/rsa.pem" >/dev/null 2>&1
  "$SIGNED_OPENSSL" pkey -in "$BATS_TEST_TMPDIR/rsa.pem" -pubout -out "$HOME/keys/public.pem" >/dev/null 2>&1
  run "$RIG" apply
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'Ed25519 public key'* ]] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
}

@test "signed-release Linux minimum installs a numerical floor and failed authentication creates no destination" {
  export RIG_PLATFORM=linux
  make_release v1.10.0
  write_signed_config 'install.minimum-version = "v1.10.0"'
  printf invalid > "$RIG_SIGNED_FIXTURES/sample-checksums.txt.sig"
  run "$RIG" apply
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'manifest signature verification failed'* ]] || false
  [ ! -e "$HOME/bin/sample" ] || false
  ! compgen -G "$HOME/bin/.rig-signed.*" >/dev/null || false
  sign_manifest
  printf '#!/bin/bash\nprintf "1.9.99\\n"\n' > "$HOME/bin/sample"
  chmod +x "$HOME/bin/sample"
  run "$RIG" status --json
  [[ "$output" == *'drifted'* && "$output" == *'minimum:v1.10.0'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ] || false
  [ "$("$HOME/bin/sample" --version)" = 1.10.0 ] || false
}

@test "signed-release final rename failure preserves the destination and cleans staging" {
  printf '#!/bin/bash\nexit 17\n' > "$RIG_TEST_PROVIDER_BIN/mv"
  chmod +x "$RIG_TEST_PROVIDER_BIN/mv"
  assert_failure_preserves
  [ "$(wc -l < "$RIG_SIGNED_LOG" | tr -d ' ')" -eq 3 ] || false
}

@test "signed-release refuses outside-home traversal linked ancestors and linked destinations" {
  local destination
  for destination in "$BATS_TEST_TMPDIR/outside" "$HOME/bin/../escape"; do
    write_signed_config "install.version = \"v1.2.3\""
    sed "s|~/bin/sample|$destination|" "$RIG_CONFIG_HOME/rig.toml" > "$RIG_CONFIG_HOME/new"
    mv "$RIG_CONFIG_HOME/new" "$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" apply
    [ "$status" -ne 0 ] || false
    [ ! -s "$RIG_SIGNED_LOG" ] || false
  done
  write_signed_config 'install.version = "v1.2.3"'
  ln -s "$BATS_TEST_TMPDIR/outside" "$HOME/bin/sample"
  run "$RIG" apply
  [ "$status" -ne 0 ] || false
  rm "$HOME/bin/sample"
  rmdir "$HOME/bin"
  mkdir "$HOME/elsewhere"
  ln -s "$HOME/elsewhere" "$HOME/bin"
  run "$RIG" apply
  [ "$status" -ne 0 ] || false
  [ ! -s "$RIG_SIGNED_LOG" ] || false
}

@test "signed-release validates version policies metadata kinds and absent provider fields before native work" {
  local policy
  for policy in 'install.version = "1.2.3"' 'install.version = "v01.2.3"' 'install.version = "v1.2.3-rc.1"' 'install.version = "v1000000000.2.3"' $'install.version = "v1.2.3"\ninstall.minimum-version = "v2.0.0"' $'install.version = "v1.2.3"\ninstall.checksum = "sha256:bad"' $'install.version = "v1.2.3"\ninstall.arguments = ["--unsafe"]' ''; do
    write_signed_config "$policy"
    run "$RIG" show
    [ "$status" -ne 0 ] || false
    [ ! -s "$RIG_SIGNED_LOG" ] || false
  done
  write_signed_config 'install.version = "v1.2.3"'
  sed '/install.provider/d' "$RIG_CONFIG_HOME/rig.toml" > "$RIG_CONFIG_HOME/new"
  mv "$RIG_CONFIG_HOME/new" "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'requires install.provider'* ]] || false
}

write_shared_role() {
  cat > "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml" <<'EOF'
[category.core]
name = "Core"
purpose = "Shared role"
[tool.sample]
name = "Sample"
category = "core"
purpose = "One shared tool declaration"
rationale = "Platform policies without host copies"
platforms = ["macos", "linux"]
variant.linux.platforms = ["linux"]
variant.linux.install.provider = "direct-download"
variant.linux.install.kind = "signed-release"
variant.linux.install.locator = "https://releases.invalid/sample"
variant.linux.install.release-name = "sample"
variant.linux.install.public-key = "~/keys/public.pem"
variant.linux.install.destination = "~/bin/sample"
variant.linux.install.version = "v1.2.3"
variant.linux.install.minimum-version = "v1.0.0"
variant.macos.platforms = ["macos"]
variant.macos.install.provider = "homebrew"
variant.macos.install.kind = "formula"
variant.macos.install.locator = "sample"
variant.macos.install.minimum-version = "v1.0.0"
[profile.agentic-rig]
name = "Shared agentic rig"
tools = ["sample"]
EOF
  cat > "$RIG_CONFIG_HOME/rig.toml" <<'EOF'
[rig]
schema = 1
default-profile = "host"
EOF
  cat > "$RIG_CONFIG_HOME/conf.d/90-host.toml" <<'EOF'
[profile.host]
name = "Local host"
inherits = ["agentic-rig"]
EOF
}

@test "shared role composes inherits and conf.d with Linux exact pins and macOS native formula floors" {
  write_shared_role
  run env RIG_PLATFORM=linux "$RIG" apply
  [ "$status" -eq 0 ] || false
  run env RIG_PLATFORM=linux "$RIG" status --json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'version:v1.2.3;exact:v1.2.3;minimum:v1.0.0'* ]] || false
  rig_test_provider brew
  rig_test_provider_response brew 'list --formula --versions sample' 0 'sample 1.10.0_2'
  run env RIG_PLATFORM=macos "$RIG" status --json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'version:v1.10.0;minimum:v1.0.0'* ]] || false
  run env RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ] || false
  ! grep -q 'install\|upgrade' "$RIG_TEST_PROVIDER_LOG" || false
  : > "$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --versions sample' 0 'sample 0.9.0'
  rig_test_provider_response brew 'upgrade --formula sample' 0 -
  run env RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ] || false
  grep -q 'upgrade --formula sample' "$RIG_TEST_PROVIDER_LOG" || false
  : > "$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --versions sample' 1 -
  rig_test_provider_response brew 'install --formula sample' 0 -
  run env RIG_PLATFORM=macos "$RIG" apply
  [ "$status" -eq 0 ] || false
  grep -q 'install --formula sample' "$RIG_TEST_PROVIDER_LOG" || false
  : > "$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --versions sample' 0 'sample HEAD'
  run env RIG_PLATFORM=macos "$RIG" status --json
  [[ "$output" == *'version-unavailable'* && "$output" == *'unknown'* ]] || false
}

@test "version policies remain bounded to signed releases and native formula floors" {
  local change
  for change in 's/formula/cask/' 's/homebrew/uv/;s/formula/tool/'; do
    write_shared_role
    sed "$change" "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml" > "$RIG_CONFIG_HOME/new"
    mv "$RIG_CONFIG_HOME/new" "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml"
    run "$RIG" show
    [ "$status" -ne 0 ] || false
    [[ "$output" == *'minimum-version requires signed-release or Homebrew formula'* ]] || false
  done
  write_shared_role
  printf '\n' >> "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml"
  sed '/variant.macos.install.minimum-version/a\
variant.macos.install.version = "v1.2.3"\
' "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml" > "$RIG_CONFIG_HOME/new"
  mv "$RIG_CONFIG_HOME/new" "$RIG_CONFIG_HOME/conf.d/10-agentic-role.toml"
  run "$RIG" show
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'install.version is only valid for signed-release'* ]] || false
}
