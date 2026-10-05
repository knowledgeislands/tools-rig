# rig-module: 05-declarations
# shellcheck shell=bash
# Cross-module metadata is consumed by the parser and documentation checks.
# shellcheck disable=SC2034

# Supported authored declarations, in kind|role|identity-segments|label form.
# Setup items describe active intent; their providers determine what can be
# applied. Ports are setup intent but never materialise sockets. Observation
# records have no application lifecycle. Components belong to a setup item;
# supporting tables organise intent, and extension actions remain inert metadata.
# Internal binding sections are derived from tools, not authored declarations.
RIG_DECLARATION_REGISTRY=(
  'tool|setup|1|Tools and apps'
  'skill|setup|1|Agent skills'
  'service|setup|1|Services'
  'scheduled-job|setup|1|Scheduled jobs'
  'setting|setup|1|Settings'
  'dock|setup|1|Dock layouts'
  'port|setup|1|Private ports'
  'retired-application|observation|1|Retired applications'
  'dock-item|component|1|Dock items'
  'rig|supporting|0|Rig configuration'
  'category|supporting|1|Categories'
  'profile|supporting|1|Profiles'
  'provider|supporting|1|Providers'
  'action|extension|2|Extension actions'
)

# Return declaration metadata separately from RIG_VALUE: parser recognition
# must not clobber an unread configuration value.
rig_declaration_lookup() {
  local record rest

  RIG_DECLARATION_ROLE=
  RIG_DECLARATION_SEGMENTS=
  RIG_DECLARATION_LABEL=
  for record in "${RIG_DECLARATION_REGISTRY[@]}"; do
    case "$record" in
      "$1|"*)
        rest=${record#*|}
        RIG_DECLARATION_ROLE=${rest%%|*}
        rest=${rest#*|}
        RIG_DECLARATION_SEGMENTS=${rest%%|*}
        RIG_DECLARATION_LABEL=${rest#*|}
        return 0
        ;;
    esac
  done
  return 1
}
