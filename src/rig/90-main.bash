# rig-module: 90-main
# shellcheck shell=bash
# Cross-module state is intentionally consumed by the assembled executable.
# shellcheck disable=SC2004,SC2034,SC2094

main() {
  local command_name

  set -u
  RIG_INVOKED_PATH=$0
  command_name=${1:-help}
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
            -h|--help) ;;
            *) syntax_error "unexpected $2" || return ;;
          esac
          ;;
        *) syntax_error 'usage: rig help [-h|--help]' || return ;;
      esac
      print_help
      ;;
    -V|--version)
      [ "$#" -eq 1 ] || syntax_error "unexpected arguments for $command_name" || return
      printf 'rig %s\n' "$RIG_VERSION"
      ;;
    show)
      shift
      rig_command_show "$@"
      ;;
    list)
      shift
      rig_command_list "$@"
      ;;
    explain)
      shift
      rig_command_explain "$@"
      ;;
    status)
      shift
      rig_command_status "$@"
      ;;
    doctor)
      shift
      rig_command_doctor "$@"
      ;;
    apply)
      shift
      rig_command_apply "$@"
      ;;
    bootstrap)
      shift
      rig_command_bootstrap "$@"
      ;;
    update)
      shift
      rig_command_lifecycle update "$@"
      ;;
    maintain)
      shift
      rig_command_lifecycle maintain "$@"
      ;;
    capture)
      shift
      rig_command_capture "$@"
      ;;
    run)
      shift
      rig_command_run_action "$@"
      ;;
    export)
      shift
      rig_command_export "$@"
      ;;
    publish)
      shift
      rig_command_publish "$@"
      ;;
    clean)
      shift
      rig_command_clean "$@"
      ;;
    diag)
      shift
      rig_command_diag "$@"
      ;;
    completion)
      [ "$#" -eq 2 ] || syntax_error 'usage: rig completion bash|zsh' || return
      case "$2" in
        -h|--help) printf '%s\n' 'Usage: rig completion bash|zsh' ;;
        bash) print_bash_completion ;;
        zsh) print_zsh_completion ;;
        *) syntax_error "unsupported shell: $2" || return ;;
      esac
      ;;
    *) syntax_error "unknown command: $command_name" || return ;;
  esac
}

if [[ ${BASH_SOURCE[0]} = "$0" ]]; then
  main "$@"
fi
