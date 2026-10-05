#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$CONFIG_HOME"
}

@test "diag proves linked checkout provenance and hides all private paths and values" {
  ln -s "$RIG" "$BATS_TEST_TMPDIR/linked-rig"
  printf '%s\n' 'private-secret = "never-report-this-value"' > "$CONFIG_HOME/rig.toml"
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$BATS_TEST_TMPDIR/linked-rig" diag
  [ "$status" -eq 0 ] || false
  for label in Tool Version Installation Platform Architecture Runtime Configuration; do
    [[ "$output" == *"$label: "* ]] || false
  done
  [[ "$output" == *'Installation: local'* ]] || false
  [[ "$output" == *'Configuration: present'* ]] || false
  [[ "$output" != *"$BATS_TEST_TMPDIR"* ]] || false
  [[ "$output" != *'never-report-this-value'* ]] || false

  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$BATS_TEST_TMPDIR/linked-rig" diag --full
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"Executable: "* ]] || false
  [[ "$output" == *"Config home: $CONFIG_HOME"* ]] || false
  [[ "$output" != *'never-report-this-value'* ]] || false
}

@test "diag does not guess release provenance for a copied executable" {
  cp "$RIG" "$BATS_TEST_TMPDIR/rig"
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$BATS_TEST_TMPDIR/rig" diag
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Installation: unknown'* ]] || false

  mkdir -p "$BATS_TEST_TMPDIR/Cellar/rig/0.4.0/bin"
  cp "$RIG" "$BATS_TEST_TMPDIR/Cellar/rig/0.4.0/bin/rig"
  printf '{}' > "$BATS_TEST_TMPDIR/Cellar/rig/0.4.0/INSTALL_RECEIPT.json"
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$BATS_TEST_TMPDIR/Cellar/rig/0.4.0/bin/rig" diag
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Installation: release'* ]] || false
}

@test "diag recognizes fragment-only configuration without parsing it" {
  mkdir -p "$CONFIG_HOME/conf.d"
  printf '%s\n' 'not valid toml' > "$CONFIG_HOME/conf.d/local.toml"
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" diag
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Configuration: present'* ]] || false
}

@test "runtime platform is distinct from selected provider platform" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos bash -c '
    source "$1"
    OSTYPE=linux-gnu
    rig_diagnostic_context
    rig_diagnostic_context_text
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Platform: linux'* ]] || false
}

@test "doctor JSON reports common context honest coverage and item counts" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" init
  [ "$status" -eq 0 ] || false
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PROGRESS=never "$RIG" doctor --format json
  [ "$status" -eq 0 ] || false
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["healthy"] and d["verdict"] == "healthy"
c=d["context"]
assert set(("tool", "version", "installation", "platform", "architecture", "runtime", "runtime_version", "configuration")) <= set(c)
assert c["tool"] == "rig" and c["installation"] == "local"
assert "executable" not in c
s=d["checks"]
assert s == {"pass":6,"warn":0,"fail":0,"skipped":0,"unit":"item","coverage":"configuration,xdg,tools,resources,ports,skills,apply-history","read_only":True,"freshness":"not-checked"}
' || false

  run env RIG_CONFIG_HOME="$BATS_TEST_TMPDIR/absent" RIG_PROGRESS=never "$RIG" doctor --format json
  [ "$status" -eq 1 ] || false
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["verdict"] == "unhealthy" and not d["healthy"]
assert d["checks"]["fail"] == 1 and d["checks"]["skipped"] == 1
assert d["checks"]["coverage"] == "configuration,xdg,apply-history"
assert "correct-configuration" in str(d["findings"])
' || false
}

@test "diag retains known host platforms beyond native provider targets" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    source "$1"
    OSTYPE=freebsd
    rig_diagnostic_context
    rig_diagnostic_context_text
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Platform: freebsd'* ]] || false
  run env RIG_CONFIG_HOME="$CONFIG_HOME" bash -c '
    source "$1"
    uname() { printf aarch64; }
    OSTYPE=win32
    rig_diagnostic_context
    rig_diagnostic_context_text
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Platform: windows'* ]] || false
  [[ "$output" == *'Architecture: arm64'* ]] || false
}

table_at_width() {
  /usr/bin/python3 -c '
import os,pty,fcntl,termios,struct,subprocess,sys
master,slave=pty.openpty()
fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack("HHHH",24,int(sys.argv[2]),0,0))
code="""source "$1"
rig_table_reset
rig_table_add_column ID 24 end keep
rig_table_add_column PURPOSE 72
rig_table_add_row "$3" "$2"
rig_table_print"""
p=subprocess.Popen(["/bin/bash","-c",code,"_",sys.argv[1],sys.argv[3],sys.argv[4]],stdout=slave,stderr=subprocess.PIPE)
os.close(slave)
result=b""
while True:
    try:
        part=os.read(master,4096)
        if not part: break
        result+=part
    except OSError: break
os.close(master)
sys.stdout.write(result.decode().replace("\r\n","\n"))
sys.exit(p.wait())
' "$RIG" "$1" "${2:-This is descriptive prose which must remain complete and wrap at the real terminal width rather than being shortened.}" "${3:-copyable-identifier}"
}

@test "tables use actual terminal width wrap prose and preserve identifiers" {
  run table_at_width 48
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'copyable-identifier'* ]] || false
  [[ "$output" == *'being shortened.'* ]] || false
  [[ "$output" != *...* ]] || false
  [[ "$output" != *$'\033'* ]] || false
  printf '%s\n' "$output" | awk 'length > 48 { exit 1 }' || false

  run table_at_width 24
  [ "$status" -eq 0 ] || false
  [[ "$output" == *$'ID:\n  copyable-identifier\nPURPOSE:'* ]] || false
  printf '%s\n' "$output" | awk 'length > 24 { exit 1 }' || false
}

@test "redirected tables ignore ambient width and keep lossless text" {
  run env COLUMNS=10 bash -c '
    source "$1"
    rig_table_reset
    rig_table_add_column ID 24 end keep
    rig_table_add_column PURPOSE 40
    rig_table_add_row intact-id "A complete description that is longer than a single column but is never abbreviated."
    rig_table_print
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  first=$output
  [[ "$first" == *'intact-id'* ]] || false
  [[ "$first" == *'abbreviated.'* ]] || false
  [[ "$first" != *$'\033'* ]] || false
  run env COLUMNS=200 bash -c '
    source "$1"
    rig_table_reset
    rig_table_add_column ID 24 end keep
    rig_table_add_column PURPOSE 40
    rig_table_add_row intact-id "A complete description that is longer than a single column but is never abbreviated."
    rig_table_print
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  [ "$output" = "$first" ] || false
}

@test "tables conservatively budget wide UTF-8 glyphs without splitting their bytes" {
  run table_at_width 18 '漢字漢字漢字漢字漢字漢字漢字漢字漢字漢字' item
  [ "$status" -eq 0 ] || false
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import sys,unicodedata
text=sys.stdin.read()
assert "漢字" in text
assert "\ufffd" not in text
for line in text.splitlines():
    width=sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in ("W","F") else 1 for c in line)
    assert width <= 18, (width,line)
assert text.count("漢") == 10 and text.count("字") == 10
' || false
}

@test "human table cells visibly escape terminal controls without altering source values" {
  run bash -c '
    source "$1"
    original=$(printf "erase\033[2J\rreturn\177\001end")
    rig_table_reset
    rig_table_add_column ID 24 end keep
    rig_table_add_column DETAIL 60
    rig_table_add_row safe "$original"
    rig_table_print
    printf "JSON="
    rig_json_field "{" original "$original"
    printf "}\n"
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  human=${output%%$'\nJSON='*}
  [[ "$human" != *$'\033'* ]] || false
  [[ "$human" != *$'\r'* ]] || false
  [[ "$human" != *$'\177'* ]] || false
  [[ "$human" == *'erase\x1b[2J\rreturn\x7f\x01end'* ]] || false
  # The existing JSON writer escapes control bytes while retaining their values.
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import json,sys
line=next(l for l in sys.stdin.read().splitlines() if l.startswith("JSON="))
assert json.loads(line[5:])["original"] == "erase\x1b[2J\rreturn\x7f\x01end"
' || false
}

@test "malformed UTF-8 is escaped visibly and wrapping always makes progress" {
  run bash -c '
    source "$1"
    invalid=$(printf "\300\257bad\342\202")
    rig_table_reset
    rig_table_add_column ID 24 end keep
    rig_table_add_column DETAIL 20
    rig_table_add_row item "$invalid"
    rig_table_print
  ' _ "$RIG"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'\xc0\xafbad\xe2\x82'* ]] || false
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import sys
t=sys.stdin.buffer.read().decode("utf-8",errors="strict")
assert "\\xc0\\xafbad\\xe2\\x82" in t
' || false
}
