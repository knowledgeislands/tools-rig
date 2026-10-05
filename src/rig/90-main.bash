# rig-module: 90-main
# shellcheck shell=bash
# Cross-module state is intentionally consumed by the assembled executable.
# shellcheck disable=SC2004,SC2034,SC2094

rig_command_diag() {
  local full
  full=0
  case "${1:-}" in
    '') ;;
    --full) full=1; shift ;;
    -h|--help) [ "$#" -eq 1 ] || rig_command_syntax_error diag || return
      rig_command_help diag; return ;;
    *) rig_command_syntax_error diag; return ;;
  esac
  [ "$#" -eq 0 ] || rig_command_syntax_error diag || return
  rig_diagnostic_context || return
  rig_diagnostic_context_text
  [ "$full" -eq 0 ] || printf 'Executable: %s\nConfig home: %s\nData home: %s\nState home: %s\nCache home: %s\n' \
    "$RIG_DIAG_EXECUTABLE" "$RIG_DIAG_CONFIG_HOME" "$RIG_DIAG_DATA_HOME" "$RIG_DIAG_STATE_HOME" "$RIG_DIAG_CACHE_HOME"
}

main() {
  local command_name exit_code

  set -u
  RIG_INVOKED_PATH=$0
  command_name=${1:-help}
  rig_progress_reset
  case "$command_name" in
    init|repair|show|status|doctor|diag|apply|upgrade|capture|export|help|completion)
      RIG_PROGRESS_COMMAND=$command_name ;;
  esac
  rig_dock_reset_snapshot
  case "$command_name" in
    init|status|doctor|apply|upgrade|capture|export)
      RIG_PROGRESS_CONTEXT=operational
      ;;
    *) RIG_PROGRESS_CONTEXT=query ;;
  esac
  trap 'rig_progress_signal 129' HUP
  trap 'rig_progress_signal 130' INT
  trap 'rig_progress_signal 143' TERM
  trap rig_progress_cleanup EXIT
  trap rig_progress_resize WINCH
  case "$command_name" in
    -h|--help)
      [ "$#" -eq 1 ] || syntax_error "unexpected arguments for $command_name" || return
      print_help
      ;;
    help)
      case "$#" in
        1) ;;
        2)
          case "$2" in
            -h|--help|help) ;;
            init|repair|show|status|doctor|diag|apply|upgrade|capture|export|completion)
              rig_command_help "$2"; return ;;
            *) syntax_error "unknown command: $2" || return ;;
          esac ;;
        *) syntax_error 'usage: rig help [COMMAND]' || return ;;
      esac
      print_help
      ;;
    -V|--version)
      [ "$#" -eq 1 ] || syntax_error "unexpected arguments for $command_name" || return
      printf 'rig %s\n' "$RIG_VERSION"
      ;;
    init)
      shift
      rig_command_init "$@"
      ;;
    repair)
      shift
      rig_command_repair "$@"
      ;;
    show)
      shift
      rig_command_show "$@"
      ;;
    status)
      shift
      rig_command_status "$@"
      ;;
    doctor)
      shift
      rig_command_doctor "$@"
      ;;
    diag)
      shift
      rig_command_diag "$@"
      ;;
    apply)
      shift
      rig_command_apply "$@"
      ;;
    upgrade)
      shift
      rig_command_lifecycle upgrade "$@"
      ;;
    capture)
      shift
      rig_command_capture "$@"
      ;;
    export)
      shift
      rig_command_export "$@"
      ;;
    completion)
      [ "$#" -eq 2 ] || rig_command_syntax_error completion || return
      case "$2" in
        -h|--help) rig_command_help completion ;;
        bash) print_bash_completion ;;
        zsh) print_zsh_completion ;;
        *) syntax_error "unsupported shell: $2" || return ;;
      esac
      ;;
    list|explain) syntax_error "command '$command_name' was removed; use rig show [ITEM] or rig show --all" || return ;;
    bootstrap) syntax_error "command 'bootstrap' was removed; use rig apply [--profile NAME]" || return ;;
    update) syntax_error "command 'update' was removed; use rig upgrade" || return ;;
    run|maintain) syntax_error "command '$command_name' was removed; use the provider's native tools" || return ;;
    *) syntax_error "unknown command: $command_name" || return ;;
  esac
  exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    rig_progress_fail
  elif [ "$RIG_PROGRESS_ACTIVE" -eq 1 ]; then
    rig_progress_finish
  fi
  rig_progress_cleanup
  case "$command_name" in
    # Help, version, and completion answer about Rig itself rather than
    # reaching a state of the machine, and completion output is evaluated by
    # every new shell.
    -h|--help|help|-V|--version|completion) ;;
    *) rig_outcome_report "$command_name" "$exit_code" ;;
  esac
  trap - EXIT HUP INT TERM WINCH
  return "$exit_code"
}

if [[ ${BASH_SOURCE[0]} = "$0" ]]; then
  main "$@"
fi
