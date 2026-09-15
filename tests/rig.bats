#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
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
