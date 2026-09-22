# rig-module: 10-configuration
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_model_reset() {
  RIG_SECTION_NAMES=()
  RIG_SECTION_TYPES=()
  RIG_SECTION_IDS=()
  RIG_SECTION_SECONDARY_IDS=()
  RIG_SECTION_FIELD_STARTS=()
  RIG_SECTION_FIELD_ENDS=()
  RIG_SECTION_DECLARED_STARTS=()
  RIG_SECTION_DECLARED_ENDS=()
  RIG_SECTION_LOOKUP_NAMES=()
  RIG_SECTION_LOOKUP_INDICES=()
  RIG_FIELD_SECTIONS=()
  RIG_FIELD_KEYS=()
  RIG_FIELD_VALUES=()
  RIG_SELECTED_TOOLS=()
  RIG_SELECTED_SKILLS=()
  RIG_SELECTED_BINDINGS=()
  RIG_SELECTED_VARIANTS=()
  RIG_SELECTED_RESOURCE_SECTIONS=()
  RIG_SELECTED_PORTS=()
  RIG_ACTIVE_PROFILES=()
  RIG_PLAN_TOOLS=()
  RIG_PLAN_BINDINGS=()
  RIG_PLAN_PROVIDERS=()
  RIG_PLAN_RESULTS=()
  RIG_PLAN_DETAILS=()
  RIG_PLAN_STATES=()
  RIG_RESOURCE_PLAN_SECTIONS=()
  RIG_RESOURCE_PLAN_RESULTS=()
  RIG_RESOURCE_PLAN_DETAILS=()
  RIG_RESOURCE_PLAN_STATES=()
  RIG_RESOURCE_PREFLIGHT_DETAILS=()
  RIG_STALE_RESOURCE_PROVIDERS=()
  RIG_STALE_RESOURCE_KINDS=()
  RIG_STALE_RESOURCE_IDS=()
  RIG_STALE_RESOURCE_LOCATORS=()
  RIG_INVOKE_ARGUMENTS=()
  RIG_VISIT_NAMES=()
  RIG_VISIT_STATES=()
  RIG_QUERY_ITEMS=()
  RIG_DECLARED_FIELD_KEYS=()
  RIG_PORT_STATES=()
  RIG_PORT_DETAILS=()
  RIG_SKILL_STATES=()
  RIG_SKILL_DETAILS=()
  RIG_SKILL_RESULTS=()
  RIG_SKILL_PREFLIGHT_DETAILS=()
  RIG_SKILL_PLANNED=0
  RIG_SKILL_COMPLETED=0
  RIG_SKILL_FAILED=0
  RIG_SKILL_SKIPPED=0
  RIG_SKILLS_INVENTORY_NAMES=()
  RIG_SKILLS_INVENTORY_SOURCES=()
  RIG_SKILLS_INVENTORY_AGENTS=()
  RIG_SKILLS_INVENTORY_LOADED=0
  RIG_SKILLS_INVENTORY_STATUS=
  RIG_SKILLS_INVENTORY_DETAIL=
  RIG_LISTENER_PORTS=()
  RIG_LISTENER_SCOPES=()
  RIG_LISTENER_COMMANDS=()
  RIG_LISTENER_PIDS=()
  RIG_OBSERVATION_CACHE_KEYS=()
  RIG_OBSERVATION_CACHE_OUTPUTS=()
  RIG_OBSERVATION_CACHE_STATUSES=()
  RIG_VALUE=
  RIG_INDEX=
  RIG_COUNT=0
  RIG_RESOURCE_PREFLIGHT_DETAIL=
  RIG_RESOLVED_PROFILE=
  RIG_RESOLVED_PLATFORM=
  RIG_RESOLVED_PROFILE_KIND=
  RIG_PROFILE_SELECTION_MODE=
  RIG_PUBLICATION_PLATFORM_NEUTRAL=0
  RIG_LISTENER_OBSERVATION_AVAILABLE=0
}

rig_trim() {
  local value

  value=$1
  value=${value#"${value%%[![:blank:]]*}"}
  value=${value%"${value##*[![:blank:]]}"}
  RIG_VALUE=$value
}

rig_valid_id() {
  case "$1" in
    ''|[!a-z]*|*[!a-z0-9-]*) return 1 ;;
  esac
  return 0
}

rig_section_index() {
  local wanted low high middle candidate
  local LC_ALL=C

  wanted=$1
  low=0
  high=$((${#RIG_SECTION_LOOKUP_NAMES[@]} - 1))
  while [ "$low" -le "$high" ]; do
    middle=$(((low + high) / 2))
    candidate=${RIG_SECTION_LOOKUP_NAMES[$middle]}
    if [ "$candidate" = "$wanted" ]; then
      RIG_INDEX=${RIG_SECTION_LOOKUP_INDICES[$middle]}
      return 0
    fi
    if [[ "$candidate" < "$wanted" ]]; then
      low=$((middle + 1))
    else
      high=$((middle - 1))
    fi
  done
  RIG_INDEX=
  return 1
}

rig_index_section_name() {
  local name section_index position previous
  local LC_ALL=C

  name=$1
  section_index=$2
  position=${#RIG_SECTION_LOOKUP_NAMES[@]}
  while [ "$position" -gt 0 ]; do
    previous=${RIG_SECTION_LOOKUP_NAMES[$((position - 1))]}
    [[ "$name" < "$previous" ]] || break
    RIG_SECTION_LOOKUP_NAMES[$position]=$previous
    RIG_SECTION_LOOKUP_INDICES[$position]=${RIG_SECTION_LOOKUP_INDICES[$((position - 1))]}
    position=$((position - 1))
  done
  RIG_SECTION_LOOKUP_NAMES[$position]=$name
  RIG_SECTION_LOOKUP_INDICES[$position]=$section_index
}

rig_parse_section_identity() {
  local name rest first second

  name=$1
  RIG_SECTION_TYPE=
  RIG_SECTION_ID=
  RIG_SECTION_SECONDARY_ID=

  if [ "$name" = rig ]; then
    RIG_SECTION_TYPE=rig
    return 0
  fi

  case "$name" in
    category.*|tool.*|skill.*|profile.*|provider.*|publication.*|service.*|scheduled-job.*|setting.*|dock.*|dock-item.*|port.*)
      RIG_SECTION_TYPE=${name%%.*}
      rest=${name#*.}
      rig_valid_id "$rest" || return 1
      RIG_SECTION_ID=$rest
      ;;
    action.*)
      RIG_SECTION_TYPE=${name%%.*}
      rest=${name#*.}
      [ "$rest" != "${rest#*.}" ] || return 1
      first=${rest%%.*}
      second=${rest#*.}
      rig_valid_id "$first" || return 1
      rig_valid_id "$second" || return 1
      RIG_SECTION_ID=$first
      RIG_SECTION_SECONDARY_ID=$second
      ;;
    *) return 1 ;;
  esac
  return 0
}

rig_add_section() {
  local name file line index

  name=$1
  file=$2
  line=$3
  rig_parse_section_identity "$name" ||
    rig_fail "$file:$line: invalid section identity [$name]" || return
  if rig_section_index "$name"; then
    rig_fail "$file:$line: duplicate section [$name]" || return
  fi

  index=${#RIG_SECTION_NAMES[@]}
  RIG_SECTION_NAMES[$index]=$name
  RIG_SECTION_TYPES[$index]=$RIG_SECTION_TYPE
  RIG_SECTION_IDS[$index]=$RIG_SECTION_ID
  RIG_SECTION_SECONDARY_IDS[$index]=$RIG_SECTION_SECONDARY_ID
  RIG_SECTION_FIELD_STARTS[$index]=${#RIG_FIELD_KEYS[@]}
  RIG_SECTION_FIELD_ENDS[$index]=${#RIG_FIELD_KEYS[@]}
  RIG_SECTION_DECLARED_STARTS[$index]=${#RIG_DECLARED_FIELD_KEYS[@]}
  RIG_SECTION_DECLARED_ENDS[$index]=${#RIG_DECLARED_FIELD_KEYS[@]}
  rig_index_section_name "$name" "$index"
  RIG_INDEX=$index
}

rig_add_derived_binding_section() {
  local tool_id provider variant name index

  tool_id=$1
  provider=$2
  variant=${3:-}
  name=binding.$tool_id.$provider
  [ -z "$variant" ] || name=$name.$variant
  if rig_section_index "$name"; then
    rig_fail "duplicate internal installation [$name]" || return
  fi

  index=${#RIG_SECTION_NAMES[@]}
  RIG_SECTION_NAMES[$index]=$name
  RIG_SECTION_TYPES[$index]=binding
  RIG_SECTION_IDS[$index]=$tool_id
  RIG_SECTION_SECONDARY_IDS[$index]=$provider
  RIG_SECTION_FIELD_STARTS[$index]=${#RIG_FIELD_KEYS[@]}
  RIG_SECTION_FIELD_ENDS[$index]=${#RIG_FIELD_KEYS[@]}
  RIG_SECTION_DECLARED_STARTS[$index]=${#RIG_DECLARED_FIELD_KEYS[@]}
  RIG_SECTION_DECLARED_ENDS[$index]=${#RIG_DECLARED_FIELD_KEYS[@]}
  rig_index_section_name "$name" "$index"
  RIG_INDEX=$index
  [ -z "$variant" ] || rig_add_field "$index" variant "$variant" '<derived install>' 0 || return
}

rig_field_kind() {
  local section_type key

  section_type=$1
  key=$2
  RIG_FIELD_KIND=
  case "$section_type:$key" in
    rig:schema|rig:default-profile|rig:bootstrap-profile|\
    category:name|category:purpose|\
    tool:name|tool:category|tool:purpose|tool:rationale|\
    skill:name|skill:purpose|skill:rationale|skill:authority|skill:source|\
    skill:source-skill|skill:trust|skill:public-source|\
    profile:name|profile:purpose|profile:kind|\
    tool:install-provider|tool:install-kind|tool:install-locator|\
    tool:install-destination|tool:install-checksum|\
    provider:adapter|provider:command|provider:executable|provider:manifest|\
    provider:autoupdate-interval|\
    binding:kind|binding:locator|binding:destination|binding:checksum|binding:variant|\
    tool:variant:*:install-provider|tool:variant:*:install-kind|\
    tool:variant:*:install-locator|tool:variant:*:install-destination|\
    tool:variant:*:install-checksum|\
    publication:profile|publication:title|publication:base-url|publication:publisher|\
    service:name|service:purpose|service:rationale|service:provider|service:locator|\
    service:desired-state|service:working-directory|service:standard-output|\
    service:standard-error|service:restart-policy|service:start-policy|\
    scheduled-job:name|scheduled-job:purpose|scheduled-job:rationale|\
    scheduled-job:provider|scheduled-job:locator|scheduled-job:desired-state|\
    scheduled-job:working-directory|scheduled-job:standard-output|\
    scheduled-job:standard-error|scheduled-job:schedule-interval|\
    scheduled-job:run-policy|scheduled-job:priority|\
    setting:name|setting:purpose|setting:rationale|setting:provider|setting:domain|\
    setting:key|setting:value-type|setting:value|\
    dock:name|dock:purpose|dock:rationale|dock:provider|\
    dock-item:kind|dock-item:path|dock-item:view|dock-item:display|\
    port:name|port:purpose|port:rationale|port:protocol|port:port|port:scope|port:mode|port:owner|\
    action:mode|action:description|action:argument-policy)
      RIG_FIELD_KIND=scalar
      ;;
    tool:platform|tool:requires|tool:related|tool:alternative|tool:artifact|tool:member-profile|\
    tool:variant:*:platform|tool:variant:*:artifact|tool:variant:*:install-argument|\
    tool:install-platform|tool:install-argument|\
    skill:platform|skill:runtime|skill:requires|skill:member-profile|\
    profile:profile|profile:inherit|profile:tool|profile:skill|profile:service|profile:scheduled-job|\
    profile:setting|profile:dock|profile:port|\
    provider:argument|provider:capability|provider:autoupdate-option|\
    binding:platform|binding:argument|\
    service:platform|service:requires|service:program|service:environment|service:member-profile|\
    service:resource-dependency|\
    scheduled-job:platform|scheduled-job:requires|scheduled-job:program|\
    scheduled-job:environment|scheduled-job:schedule-calendar|scheduled-job:member-profile|\
    scheduled-job:resource-dependency|\
    setting:platform|setting:requires|setting:member-profile|setting:resource-dependency|\
    dock:platform|dock:requires|dock:item|dock:member-profile|dock:resource-dependency|\
    port:member-profile|\
    action:platform|action:argument|action:allow-argument|action:resource-kind)
      RIG_FIELD_KIND=repeatable
      ;;
    *) return 1 ;;
  esac
  return 0
}

rig_toml_variant_field() {
  local key rest variant field canonical

  key=$1
  case "$key" in variant.*.*) ;; *) return 1 ;; esac
  rest=${key#variant.}
  variant=${rest%%.*}
  field=${rest#*.}
  rig_valid_id "$variant" || return 1
  case "$field" in
    platforms) canonical=platform; RIG_TOML_FIELD_TYPE=array ;;
    artifacts) canonical=artifact; RIG_TOML_FIELD_TYPE=array ;;
    install.provider) canonical=install-provider; RIG_TOML_FIELD_TYPE=string ;;
    install.kind) canonical=install-kind; RIG_TOML_FIELD_TYPE=string ;;
    install.locator) canonical=install-locator; RIG_TOML_FIELD_TYPE=string ;;
    install.destination) canonical=install-destination; RIG_TOML_FIELD_TYPE=string ;;
    install.checksum) canonical=install-checksum; RIG_TOML_FIELD_TYPE=string ;;
    install.arguments) canonical=install-argument; RIG_TOML_FIELD_TYPE=array ;;
    *) return 1 ;;
  esac
  RIG_TOML_FIELD_KEY=variant:$variant:$canonical
}

rig_toml_field() {
  local section_type key

  section_type=$1
  key=$2
  RIG_TOML_FIELD_KEY=
  RIG_TOML_FIELD_TYPE=
  if [ "$section_type" = tool ] && rig_toml_variant_field "$key"; then
    return 0
  fi
  case "$section_type:$key" in
    rig:schema)
      RIG_TOML_FIELD_KEY=schema
      RIG_TOML_FIELD_TYPE=integer
      ;;
    rig:default-profile|rig:bootstrap-profile|\
    category:name|category:purpose|profile:name|profile:purpose|profile:kind|\
    tool:name|tool:category|tool:purpose|tool:rationale|\
    skill:name|skill:purpose|skill:rationale|skill:authority|skill:source|\
    skill:source-skill|skill:trust|skill:public-source|\
    provider:adapter|provider:command|provider:executable|provider:manifest|\
    binding:kind|binding:locator|binding:destination|binding:checksum|\
    publication:profile|publication:title|publication:base-url|publication:publisher|\
    service:name|service:purpose|service:rationale|service:provider|service:locator|\
    service:desired-state|service:working-directory|service:standard-output|\
    service:standard-error|service:restart-policy|service:start-policy|\
    scheduled-job:name|scheduled-job:purpose|scheduled-job:rationale|\
    scheduled-job:provider|scheduled-job:locator|scheduled-job:desired-state|\
    scheduled-job:working-directory|scheduled-job:standard-output|\
    scheduled-job:standard-error|scheduled-job:run-policy|scheduled-job:priority|\
    setting:name|setting:purpose|setting:rationale|setting:provider|setting:domain|\
    setting:key|setting:value-type|setting:value|\
    dock:name|dock:purpose|dock:rationale|dock:provider|\
    dock-item:kind|dock-item:path|dock-item:view|dock-item:display|\
    port:name|port:purpose|port:rationale|port:protocol|port:scope|port:mode|port:owner|\
    action:mode|action:description|action:argument-policy)
      RIG_TOML_FIELD_KEY=$key
      RIG_TOML_FIELD_TYPE=string
      ;;
    provider:autoupdate-interval)
      RIG_TOML_FIELD_KEY=autoupdate-interval
      RIG_TOML_FIELD_TYPE=integer
      ;;
    port:port)
      RIG_TOML_FIELD_KEY=port
      RIG_TOML_FIELD_TYPE=integer
      ;;
    tool:install.provider) RIG_TOML_FIELD_KEY=install-provider; RIG_TOML_FIELD_TYPE=string ;;
    tool:install.kind) RIG_TOML_FIELD_KEY=install-kind; RIG_TOML_FIELD_TYPE=string ;;
    tool:install.locator) RIG_TOML_FIELD_KEY=install-locator; RIG_TOML_FIELD_TYPE=string ;;
    tool:install.destination) RIG_TOML_FIELD_KEY=install-destination; RIG_TOML_FIELD_TYPE=string ;;
    tool:install.checksum) RIG_TOML_FIELD_KEY=install-checksum; RIG_TOML_FIELD_TYPE=string ;;
    tool:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    tool:requires) RIG_TOML_FIELD_KEY=requires ; RIG_TOML_FIELD_TYPE=array ;;
    tool:related) RIG_TOML_FIELD_KEY=related ; RIG_TOML_FIELD_TYPE=array ;;
    tool:alternatives) RIG_TOML_FIELD_KEY=alternative ; RIG_TOML_FIELD_TYPE=array ;;
    tool:artifacts) RIG_TOML_FIELD_KEY=artifact ; RIG_TOML_FIELD_TYPE=array ;;
    tool:profiles) RIG_TOML_FIELD_KEY=member-profile ; RIG_TOML_FIELD_TYPE=array ;;
    skill:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    skill:runtimes) RIG_TOML_FIELD_KEY=runtime ; RIG_TOML_FIELD_TYPE=array ;;
    skill:requires) RIG_TOML_FIELD_KEY=requires ; RIG_TOML_FIELD_TYPE=array ;;
    skill:profiles) RIG_TOML_FIELD_KEY=member-profile ; RIG_TOML_FIELD_TYPE=array ;;
    tool:install.platforms) RIG_TOML_FIELD_KEY=install-platform ; RIG_TOML_FIELD_TYPE=array ;;
    tool:install.arguments) RIG_TOML_FIELD_KEY=install-argument ; RIG_TOML_FIELD_TYPE=array ;;
    profile:profiles) RIG_TOML_FIELD_KEY=profile ; RIG_TOML_FIELD_TYPE=array ;;
    profile:inherits) RIG_TOML_FIELD_KEY=inherit ; RIG_TOML_FIELD_TYPE=array ;;
    profile:tools) RIG_TOML_FIELD_KEY=tool ; RIG_TOML_FIELD_TYPE=array ;;
    profile:skills) RIG_TOML_FIELD_KEY=skill ; RIG_TOML_FIELD_TYPE=array ;;
    profile:services) RIG_TOML_FIELD_KEY=service ; RIG_TOML_FIELD_TYPE=array ;;
    profile:scheduled-jobs) RIG_TOML_FIELD_KEY=scheduled-job ; RIG_TOML_FIELD_TYPE=array ;;
    profile:settings) RIG_TOML_FIELD_KEY=setting ; RIG_TOML_FIELD_TYPE=array ;;
    profile:docks) RIG_TOML_FIELD_KEY=dock ; RIG_TOML_FIELD_TYPE=array ;;
    profile:ports) RIG_TOML_FIELD_KEY=port ; RIG_TOML_FIELD_TYPE=array ;;
    service:platforms|scheduled-job:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    service:profiles|scheduled-job:profiles|setting:profiles|dock:profiles)
      RIG_TOML_FIELD_KEY=member-profile
      RIG_TOML_FIELD_TYPE=array
      ;;
    port:profiles) RIG_TOML_FIELD_KEY=member-profile ; RIG_TOML_FIELD_TYPE=array ;;
    service:requires|scheduled-job:requires) RIG_TOML_FIELD_KEY=requires ; RIG_TOML_FIELD_TYPE=array ;;
    service:depends-on|scheduled-job:depends-on|setting:depends-on|dock:depends-on)
      RIG_TOML_FIELD_KEY='resource-dependency'
      RIG_TOML_FIELD_TYPE=array
      ;;
    service:program|scheduled-job:program) RIG_TOML_FIELD_KEY=program ; RIG_TOML_FIELD_TYPE=array ;;
    service:environment|scheduled-job:environment) RIG_TOML_FIELD_KEY=environment ; RIG_TOML_FIELD_TYPE=array ;;
    scheduled-job:schedule.calendar) RIG_TOML_FIELD_KEY='schedule-calendar' ; RIG_TOML_FIELD_TYPE=array ;;
    scheduled-job:schedule.interval) RIG_TOML_FIELD_KEY='schedule-interval' ; RIG_TOML_FIELD_TYPE=string ;;
    setting:platforms|dock:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    setting:requires|dock:requires) RIG_TOML_FIELD_KEY=requires ; RIG_TOML_FIELD_TYPE=array ;;
    dock:items) RIG_TOML_FIELD_KEY=item ; RIG_TOML_FIELD_TYPE=array ;;
    provider:arguments) RIG_TOML_FIELD_KEY=argument ; RIG_TOML_FIELD_TYPE=array ;;
    provider:capabilities) RIG_TOML_FIELD_KEY=capability ; RIG_TOML_FIELD_TYPE=array ;;
    provider:autoupdate-options) RIG_TOML_FIELD_KEY=autoupdate-option ; RIG_TOML_FIELD_TYPE=array ;;
    binding:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    binding:arguments) RIG_TOML_FIELD_KEY=argument ; RIG_TOML_FIELD_TYPE=array ;;
    action:platforms) RIG_TOML_FIELD_KEY=platform ; RIG_TOML_FIELD_TYPE=array ;;
    action:arguments) RIG_TOML_FIELD_KEY=argument ; RIG_TOML_FIELD_TYPE=array ;;
    action:allowed-arguments) RIG_TOML_FIELD_KEY=allow-argument ; RIG_TOML_FIELD_TYPE=array ;;
    action:resource-kinds) RIG_TOML_FIELD_KEY='resource-kind' ; RIG_TOML_FIELD_TYPE=array ;;
    *) return 1 ;;
  esac
}

rig_toml_mark_field() {
  local section_index key file line index end

  section_index=$1
  key=$2
  file=$3
  line=$4
  index=${RIG_SECTION_DECLARED_STARTS[$section_index]}
  end=${RIG_SECTION_DECLARED_ENDS[$section_index]}
  while [ "$index" -lt "$end" ]; do
    [ "${RIG_DECLARED_FIELD_KEYS[$index]}" != "$key" ] ||
      rig_fail "$file:$line: duplicate field '$key' in [${RIG_SECTION_NAMES[$section_index]}]" || return
    index=$((index + 1))
  done
  index=${#RIG_DECLARED_FIELD_KEYS[@]}
  RIG_DECLARED_FIELD_KEYS[$index]=$key
  RIG_SECTION_DECLARED_ENDS[$section_index]=$((index + 1))
}

rig_toml_strip_comment() {
  local input output character index length in_string escaped

  input=$1
  case "$input" in
    *'#'*) ;;
    *) RIG_VALUE=$input; return 0 ;;
  esac
  output=
  index=0
  length=${#input}
  in_string=0
  escaped=0
  while [ "$index" -lt "$length" ]; do
    character=${input:$index:1}
    if [ "$in_string" -eq 1 ]; then
      output=$output$character
      if [ "$escaped" -eq 1 ]; then
        escaped=0
      else
        case "$character" in
          \\) escaped=1 ;;
          '"') in_string=0 ;;
        esac
      fi
    else
      case "$character" in
        '#') break ;;
        '"') in_string=1 ; output=$output$character ;;
        *) output=$output$character ;;
      esac
    fi
    index=$((index + 1))
  done
  RIG_VALUE=$output
}

rig_toml_parse_string() {
  local input file line body output character escaped index length

  input=$1
  file=$2
  line=$3
  case "$input" in
    '"'*'"') ;;
    *) rig_fail "$file:$line: expected TOML basic string" || return ;;
  esac
  body=${input#\"}
  body=${body%\"}
  case "$body" in
    *\\*|*\"*) ;;
    *) RIG_VALUE=$body; return 0 ;;
  esac
  output=
  escaped=0
  index=0
  length=${#body}
  while [ "$index" -lt "$length" ]; do
    character=${body:$index:1}
    if [ "$escaped" -eq 1 ]; then
      case "$character" in
        '"'|\\) output=$output$character ;;
        b) output=$output$'\b' ;;
        t) output=$output$'\t' ;;
        n) output=$output$'\n' ;;
        f) output=$output$'\f' ;;
        r) output=$output$'\r' ;;
        *) rig_fail "$file:$line: unsupported TOML string escape '\\$character'" || return ;;
      esac
      escaped=0
    else
      case "$character" in
        \\) escaped=1 ;;
        '"') rig_fail "$file:$line: unescaped quote in TOML basic string" || return ;;
        *) output=$output$character ;;
      esac
    fi
    index=$((index + 1))
  done
  [ "$escaped" -eq 0 ] || rig_fail "$file:$line: incomplete TOML string escape" || return
  RIG_VALUE=$output
}

rig_toml_take_string() {
  local input file line character escaped index length token rest item

  input=$1
  file=$2
  line=$3
  case "$input" in
    '"'*) ;;
    *) rig_fail "$file:$line: TOML arrays must contain basic strings" || return ;;
  esac
  case "$input" in
    *\\*) ;;
    *)
      rest=${input#\"}
      case "$rest" in
        *\"*)
          item=${rest%%\"*}
          RIG_VALUE=$item
          RIG_TOML_REST=${rest#*\"}
          return 0
          ;;
      esac
      ;;
  esac
  escaped=0
  index=1
  length=${#input}
  while [ "$index" -lt "$length" ]; do
    character=${input:$index:1}
    if [ "$escaped" -eq 1 ]; then
      escaped=0
    else
      case "$character" in
        \\) escaped=1 ;;
        '"')
          token=${input:0:$((index + 1))}
          RIG_TOML_REST=${input:$((index + 1))}
          rig_toml_parse_string "$token" "$file" "$line" || return
          return 0
          ;;
      esac
    fi
    index=$((index + 1))
  done
  rig_fail "$file:$line: unterminated TOML basic string" || return
}

rig_toml_array_complete() {
  local input file line character escaped index length in_string

  input=$1
  file=$2
  line=$3
  RIG_COUNT=0
  case "$input" in \[*) ;; *) return 1 ;; esac
  case "$input" in *\]) RIG_COUNT=1; return 0 ;; esac
  escaped=0
  in_string=0
  index=1
  length=${#input}
  while [ "$index" -lt "$length" ]; do
    character=${input:$index:1}
    if [ "$in_string" -eq 1 ]; then
      if [ "$escaped" -eq 1 ]; then
        escaped=0
      else
        case "$character" in
          \\) escaped=1 ;;
          '"') in_string=0 ;;
        esac
      fi
    else
      case "$character" in
        '"') in_string=1 ;;
        ']') RIG_COUNT=1; return 0 ;;
      esac
    fi
    index=$((index + 1))
  done
  [ "$in_string" -eq 0 ] ||
    rig_fail "$file:$line: TOML basic strings must not span lines" || return
  return 0
}

rig_toml_parse_array() {
  local section_index key input file line body item

  section_index=$1
  key=$2
  input=$3
  file=$4
  line=$5
  case "$input" in
    \[*\]) ;;
    *) rig_fail "$file:$line: expected single-line TOML string array" || return ;;
  esac
  body=${input#\[}
  body=${body%\]}
  rig_trim "$body"
  body=$RIG_VALUE
  while [ -n "$body" ]; do
    rig_toml_take_string "$body" "$file" "$line" || return
    item=$RIG_VALUE
    [ -n "$item" ] || rig_fail "$file:$line: array values must not be empty" || return
    rig_add_field "$section_index" "$key" "$item" "$file" "$line" || return
    rig_trim "$RIG_TOML_REST"
    body=$RIG_VALUE
    [ -n "$body" ] || break
    case "$body" in
      ,*)
        body=${body#,}
        rig_trim "$body"
        body=$RIG_VALUE
        ;;
      *) rig_fail "$file:$line: expected comma between TOML array values" || return ;;
    esac
  done
}

rig_field_count() {
  local section_index key index end count

  section_index=$1
  key=$2
  index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  count=0
  while [ "$index" -lt "$end" ]; do
    if [ "${RIG_FIELD_KEYS[$index]}" = "$key" ]; then
      count=$((count + 1))
    fi
    index=$((index + 1))
  done
  RIG_COUNT=$count
}

rig_field_declared() {
  local section_name key section_index index end

  section_name=$1
  key=$2
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  index=${RIG_SECTION_DECLARED_STARTS[$section_index]}
  end=${RIG_SECTION_DECLARED_ENDS[$section_index]}
  while [ "$index" -lt "$end" ]; do
    [ "${RIG_DECLARED_FIELD_KEYS[$index]}" != "$key" ] || return 0
    index=$((index + 1))
  done
  return 1
}

rig_add_field() {
  local section_index key value file line field_index section_type

  section_index=$1
  key=$2
  value=$3
  file=$4
  line=$5
  section_type=${RIG_SECTION_TYPES[$section_index]}

  rig_field_kind "$section_type" "$key" ||
    rig_fail "$file:$line: unknown field '$key' in [${RIG_SECTION_NAMES[$section_index]}]" || return
  [ -n "$value" ] || rig_fail "$file:$line: field '$key' must not be empty" || return

  if [ "$RIG_FIELD_KIND" = scalar ]; then
    rig_field_count "$section_index" "$key"
    [ "$RIG_COUNT" -eq 0 ] ||
      rig_fail "$file:$line: duplicate scalar field '$key' in [${RIG_SECTION_NAMES[$section_index]}]" || return
  fi

  if [ "$section_type:$key" = provider:executable ] ||
    [ "$section_type:$key" = provider:manifest ] ||
    [ "$section_type:$key" = binding:destination ]; then
    case "$value" in
      \~/*)
        [ -n "${HOME:-}" ] || rig_fail "$file:$line: HOME is required to expand '$key'" || return
        value=$HOME/${value#\~/}
        ;;
    esac
  fi

  field_index=${#RIG_FIELD_KEYS[@]}
  RIG_FIELD_SECTIONS[$field_index]=$section_index
  RIG_FIELD_KEYS[$field_index]=$key
  RIG_FIELD_VALUES[$field_index]=$value
  RIG_SECTION_FIELD_ENDS[$section_index]=$((field_index + 1))
}

rig_parse_file() {
  local file line line_number current_section key value section_type internal_key value_type
  local array_line array_lines

  file=$1
  current_section=
  line_number=0
  [ -f "$file" ] && [ -r "$file" ] || rig_fail "cannot read configuration file: $file" || return

  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    rig_toml_strip_comment "$line"
    line=$RIG_VALUE
    rig_trim "$line"
    line=$RIG_VALUE
    case "$line" in
      '') continue ;;
    esac

    case "$line" in
      \[*\])
        value=${line#\[}
        value=${value%\]}
        rig_add_section "$value" "$file" "$line_number" || return
        current_section=$RIG_INDEX
        ;;
      *)
        [ -n "$current_section" ] || rig_fail "$file:$line_number: field appears before a section" || return
        [ "$line" != "${line#*=}" ] || rig_fail "$file:$line_number: malformed record" || return
        key=${line%%=*}
        value=${line#*=}
        rig_trim "$key"
        key=$RIG_VALUE
        rig_trim "$value"
        value=$RIG_VALUE
        case "$key" in
          ''|*[!a-z0-9.-]*) rig_fail "$file:$line_number: invalid field name '$key'" || return ;;
        esac
        section_type=${RIG_SECTION_TYPES[$current_section]}
        rig_toml_field "$section_type" "$key" ||
          rig_fail "$file:$line_number: unknown field '$key' in [${RIG_SECTION_NAMES[$current_section]}]" || return
        internal_key=$RIG_TOML_FIELD_KEY
        value_type=$RIG_TOML_FIELD_TYPE
        rig_toml_mark_field "$current_section" "$internal_key" "$file" "$line_number" || return
        case "$value_type" in
          integer)
            case "$value" in
              ''|*[!0-9]*) rig_fail "$file:$line_number: field '$key' must be a decimal integer" || return ;;
            esac
            rig_add_field "$current_section" "$internal_key" "$value" "$file" "$line_number" || return
            ;;
          string)
            rig_toml_parse_string "$value" "$file" "$line_number" || return
            rig_add_field "$current_section" "$internal_key" "$RIG_VALUE" "$file" "$line_number" || return
            ;;
          array)
            case "$value" in
              \[*) ;;
              *) rig_fail "$file:$line_number: expected TOML string array" || return ;;
            esac
            array_line=$line_number
            array_lines=1
            rig_toml_array_complete "$value" "$file" "$line_number" || return
            while [ "$RIG_COUNT" -eq 0 ]; do
              [ "$array_lines" -lt 1024 ] ||
                rig_fail "$file:$array_line: TOML string array exceeds 1024 lines" || return
              if ! IFS= read -r line; then
                rig_fail "$file:$array_line: unterminated TOML string array" || return
              fi
              line_number=$((line_number + 1))
              array_lines=$((array_lines + 1))
              rig_toml_strip_comment "$line"
              rig_trim "$RIG_VALUE"
              line=$RIG_VALUE
              [ -z "$line" ] || value="$value $line"
              rig_toml_array_complete "$value" "$file" "$line_number" || return
            done
            rig_toml_parse_array "$current_section" "$internal_key" "$value" "$file" "$line_number" || return
            ;;
        esac
        ;;
    esac
  done <"$file"
}

rig_get_value() {
  local section_name key occurrence section_index index end seen

  section_name=$1
  key=$2
  occurrence=${3:-1}
  RIG_VALUE=
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  seen=0
  while [ "$index" -lt "$end" ]; do
    if [ "${RIG_FIELD_KEYS[$index]}" = "$key" ]; then
      seen=$((seen + 1))
      if [ "$seen" -eq "$occurrence" ]; then
        RIG_VALUE=${RIG_FIELD_VALUES[$index]}
        return 0
      fi
    fi
    index=$((index + 1))
  done
  return 1
}

rig_collect_tool_variants() {
  local section_index field_index field_end key rest variant

  section_index=$1
  RIG_QUERY_ITEMS=()
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    case "$key" in variant:*:*)
      rest=${key#variant:}
      variant=${rest%%:*}
      if [ "${#RIG_QUERY_ITEMS[@]}" -eq 0 ] ||
        ! rig_array_contains "$variant" "${RIG_QUERY_ITEMS[@]}"; then
        RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=$variant
      fi
      ;;
    esac
    field_index=$((field_index + 1))
  done
  rig_sort_query_items
}

rig_synthesise_binding_fields() {
  local tool_index binding_index prefix field_index field_end key value target

  tool_index=$1
  binding_index=$2
  prefix=$3
  field_index=${RIG_SECTION_FIELD_STARTS[$tool_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$tool_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    value=${RIG_FIELD_VALUES[$field_index]}
    target=
    case "$key" in
      "$prefix"install-kind) target=kind ;;
      "$prefix"install-locator) target=locator ;;
      "$prefix"install-destination) target=destination ;;
      "$prefix"install-checksum) target=checksum ;;
      "$prefix"install-platform) target=platform ;;
      "$prefix"platform) [ -z "$prefix" ] || target=platform ;;
      "$prefix"install-argument) target=argument ;;
    esac
    [ -z "$target" ] ||
      rig_add_field "$binding_index" "$target" "$value" '<derived install>' 0 || return
    field_index=$((field_index + 1))
  done
}

rig_synthesise_bindings() {
  local original_count index tool_id tool_section provider binding_index variant variant_key
  local variant_index
  local -a variants

  original_count=${#RIG_SECTION_NAMES[@]}
  index=0
  while [ "$index" -lt "$original_count" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = tool ]; then
      tool_id=${RIG_SECTION_IDS[$index]}
      tool_section=tool.$tool_id
      if rig_get_value "$tool_section" install-provider; then
        provider=$RIG_VALUE
        rig_valid_id "$provider" || rig_fail "[$tool_section] has invalid install.provider '$provider'" || return
        rig_add_derived_binding_section "$tool_id" "$provider" || return
        binding_index=$RIG_INDEX
        rig_synthesise_binding_fields "$index" "$binding_index" '' || return
      fi

      rig_collect_tool_variants "$index"
      variants=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")
      variant_index=0
      while [ "$variant_index" -lt "${#variants[@]}" ]; do
        variant=${variants[$variant_index]}
        variant_key=variant:$variant:
        if rig_get_value "$tool_section" "${variant_key}install-provider"; then
          provider=$RIG_VALUE
          rig_valid_id "$provider" ||
            rig_fail "[$tool_section] variant '$variant' has invalid install.provider '$provider'" || return
          rig_add_derived_binding_section "$tool_id" "$provider" "$variant" || return
          binding_index=$RIG_INDEX
          rig_synthesise_binding_fields "$index" "$binding_index" "$variant_key" || return
        fi
        variant_index=$((variant_index + 1))
      done
    fi
    index=$((index + 1))
  done
}

rig_require_field() {
  local section_name key

  section_name=$1
  key=$2
  if ! rig_get_value "$section_name" "$key"; then
    rig_fail "[$section_name] requires field '$key'" || return
  fi
}

rig_reference_exists() {
  rig_section_index "$1.$2"
}

rig_validate_references_for_field() {
  local section_index key target_type index end target

  section_index=$1
  key=$2
  target_type=$3
  index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$index" -lt "$end" ]; do
    if [ "${RIG_FIELD_KEYS[$index]}" = "$key" ]; then
      target=${RIG_FIELD_VALUES[$index]}
      if ! rig_valid_id "$target" || ! rig_reference_exists "$target_type" "$target"; then
        rig_fail "[${RIG_SECTION_NAMES[$section_index]}] references unknown $target_type '$target'" || return
      fi
    fi
    index=$((index + 1))
  done
}

rig_visit_get() {
  local name index

  name=$1
  index=0
  RIG_VALUE=
  while [ "$index" -lt "${#RIG_VISIT_NAMES[@]}" ]; do
    if [ "${RIG_VISIT_NAMES[$index]}" = "$name" ]; then
      RIG_VALUE=${RIG_VISIT_STATES[$index]}
      RIG_INDEX=$index
      return 0
    fi
    index=$((index + 1))
  done
  RIG_INDEX=
  return 1
}

rig_visit_set() {
  local name state index

  name=$1
  state=$2
  if rig_visit_get "$name"; then
    RIG_VISIT_STATES[$RIG_INDEX]=$state
  else
    index=${#RIG_VISIT_NAMES[@]}
    RIG_VISIT_NAMES[$index]=$name
    RIG_VISIT_STATES[$index]=$state
  fi
}

rig_profile_kind() {
  local profile

  profile=$1
  if rig_get_value "profile.$profile" kind; then
    return 0
  fi
  RIG_VALUE=complete
}

rig_detect_profile_selection_mode() {
  local index section_type section_name central item

  central=0
  item=0
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    section_type=${RIG_SECTION_TYPES[$index]}
    section_name=${RIG_SECTION_NAMES[$index]}
    case "$section_type" in
      profile)
      if rig_field_declared "$section_name" tool ||
        rig_field_declared "$section_name" skill ||
          rig_field_declared "$section_name" service ||
          rig_field_declared "$section_name" scheduled-job ||
          rig_field_declared "$section_name" setting ||
          rig_field_declared "$section_name" dock ||
          rig_field_declared "$section_name" port; then
          central=1
        fi
        ;;
    tool|skill|service|scheduled-job|setting|dock|port)
        if rig_field_declared "$section_name" member-profile; then
          item=1
        fi
        ;;
    esac
    index=$((index + 1))
  done
  if [ "$central" -eq 1 ] && [ "$item" -eq 1 ]; then
    rig_fail 'configuration cannot mix central profile members with item profiles' || return
  fi
  if [ "$central" -eq 1 ]; then
    RIG_PROFILE_SELECTION_MODE=central
  else
    RIG_PROFILE_SELECTION_MODE=item
  fi
}

rig_profile_cycle_visit() {
  local profile section_index field_index field_end child state

  profile=$1
  if rig_visit_get "$profile"; then
    state=$RIG_VALUE
    [ "$state" != visiting ] || rig_fail "profile cycle includes '$profile'" || return
    [ "$state" != visited ] || return 0
  fi

  rig_visit_set "$profile" visiting
  rig_section_index "profile.$profile" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] && {
      [ "${RIG_FIELD_KEYS[$field_index]}" = profile ] ||
        [ "${RIG_FIELD_KEYS[$field_index]}" = inherit ];
    }; then
      child=${RIG_FIELD_VALUES[$field_index]}
      rig_profile_cycle_visit "$child" || return
    fi
    field_index=$((field_index + 1))
  done
  rig_visit_set "$profile" visited
}

rig_tool_cycle_visit() {
  local tool section_index field_index field_end child state

  tool=$1
  if rig_visit_get "$tool"; then
    state=$RIG_VALUE
    [ "$state" != visiting ] || rig_fail "required-tool cycle includes '$tool'" || return
    [ "$state" != visited ] || return 0
  fi

  rig_visit_set "$tool" visiting
  rig_section_index "tool.$tool" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      child=${RIG_FIELD_VALUES[$field_index]}
      rig_tool_cycle_visit "$child" || return
    fi
    field_index=$((field_index + 1))
  done
  rig_visit_set "$tool" visited
}

rig_resource_reference() {
  local reference kind id

  reference=$1
  case "$reference" in *:*) ;; *) return 1 ;; esac
  kind=${reference%%:*}
  id=${reference#*:}
  case "$kind" in service|scheduled-job|setting|dock) ;; *) return 1 ;; esac
  rig_valid_id "$id" || return 1
  rig_reference_exists "$kind" "$id" || return 1
  RIG_VALUE=$kind.$id
}

rig_validate_resource_dependencies() {
  local section_name section_index field_index field_end reference

  section_name=$1
  section_index=$2
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = resource-dependency ]; then
      reference=${RIG_FIELD_VALUES[$field_index]}
      rig_resource_reference "$reference" ||
        rig_fail "[$section_name] depends-on references unknown resource '$reference'" || return
    fi
    field_index=$((field_index + 1))
  done
}

rig_resource_cycle_visit() {
  local section_name section_index field_index field_end reference child state

  section_name=$1
  if rig_visit_get "$section_name"; then
    state=$RIG_VALUE
    [ "$state" != visiting ] ||
      rig_fail "resource dependency cycle includes '$section_name'" || return
    [ "$state" != visited ] || return 0
  fi
  rig_visit_set "$section_name" visiting
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = resource-dependency ]; then
      reference=${RIG_FIELD_VALUES[$field_index]}
      rig_resource_reference "$reference" || return 2
      child=$RIG_VALUE
      rig_resource_cycle_visit "$child" || return
    fi
    field_index=$((field_index + 1))
  done
  rig_visit_set "$section_name" visited
}

rig_validate_cycles() {
  local index

  RIG_VISIT_NAMES=()
  RIG_VISIT_STATES=()
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = profile ]; then
      rig_profile_cycle_visit "${RIG_SECTION_IDS[$index]}" || return
    fi
    index=$((index + 1))
  done

  RIG_VISIT_NAMES=()
  RIG_VISIT_STATES=()
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = tool ]; then
      rig_tool_cycle_visit "${RIG_SECTION_IDS[$index]}" || return
    fi
    index=$((index + 1))
  done

  RIG_VISIT_NAMES=()
  RIG_VISIT_STATES=()
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    case "${RIG_SECTION_TYPES[$index]}" in service|scheduled-job|setting|dock)
      rig_resource_cycle_visit "${RIG_SECTION_NAMES[$index]}" || return
      ;;
    esac
    index=$((index + 1))
  done
}

rig_validate_provider_adapter() {
  local section_name adapter

  section_name=$1
  adapter=$2
  case "$adapter" in
    custom) ;;
    homebrew|uv|mise|npm|chezmoi|direct-download|launchd|macos-applications|macos-defaults|macos-dock|skills-cli|ki) ;;
    *) rig_fail "[$section_name] has unsupported adapter '$adapter'" || return ;;
  esac
}

rig_builtin_provider_adapter() {
  case "$1" in
    homebrew|uv|mise|npm|chezmoi|direct-download|launchd|macos-applications|macos-defaults|macos-dock|skills-cli|ki)
      RIG_VALUE=$1
      return 0
      ;;
  esac
  return 1
}

rig_provider_adapter() {
  local provider

  provider=$1
  if rig_get_value "provider.$provider" adapter; then
    return 0
  fi
  rig_builtin_provider_adapter "$provider"
}

rig_provider_exists() {
  local provider

  provider=$1
  rig_reference_exists provider "$provider" || rig_builtin_provider_adapter "$provider"
}

rig_validate_binding_adapter() {
  local section_name provider adapter kind locator destination checksum digest

  section_name=$1
  provider=$2
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_get_value "$section_name" kind || return 2
  kind=$RIG_VALUE
  rig_get_value "$section_name" locator || return 2
  locator=$RIG_VALUE

  case "$adapter:$kind" in
    custom:*) ;;
    homebrew:formula|homebrew:cask|homebrew:mas|uv:tool|mise:tool|npm:global|chezmoi:target) ;;
    direct-download:executable) ;;
    launchd:*|macos-applications:*|macos-defaults:*|macos-dock:*|skills-cli:*|ki:*)
      rig_fail "[$section_name] adapter '$adapter' cannot install tools" || return
      ;;
    homebrew:*|uv:*|mise:*|npm:*|chezmoi:*|direct-download:*)
      rig_fail "[$section_name] kind '$kind' is not supported by adapter '$adapter'" || return
      ;;
  esac

  if [ "$adapter:$kind" = homebrew:mas ]; then
    case "$locator" in
      ''|*[!0-9]*)
        rig_fail "[$section_name] Homebrew mas locator must be a numeric application identity" || return
        ;;
    esac
  fi

  if [ "$adapter" = direct-download ]; then
    case "$locator" in
      https://*) ;;
      *) rig_fail "[$section_name] direct-download locator must use HTTPS" || return ;;
    esac
    rig_require_field "$section_name" destination || return
    destination=$RIG_VALUE
    case "$destination" in
      /*) ;;
      *) rig_fail "[$section_name] direct-download destination must be absolute or start with '~/'" || return ;;
    esac
    rig_require_field "$section_name" checksum || return
    checksum=$RIG_VALUE
    case "$checksum" in
      sha256:*) digest=${checksum#sha256:} ;;
      *) rig_fail "[$section_name] direct-download checksum must use 'sha256:'" || return ;;
    esac
    [ "${#digest}" -eq 64 ] ||
      rig_fail "[$section_name] direct-download checksum must contain 64 lowercase hexadecimal characters" || return
    case "$digest" in
      *[!0-9a-f]*)
        rig_fail "[$section_name] direct-download checksum must contain 64 lowercase hexadecimal characters" || return
        ;;
    esac
  else
    if rig_get_value "$section_name" destination || rig_get_value "$section_name" checksum; then
      rig_fail "[$section_name] destination and checksum are only valid for direct-download installations" || return
    fi
  fi
}

rig_validate_calendar_entry() {
  local section_name entry remaining pair key value seen number

  section_name=$1
  entry=$2
  [ -n "$entry" ] || rig_fail "[$section_name] schedule.calendar entries must not be empty" || return
  remaining=$entry
  seen=,
  while :; do
    case "$remaining" in
      *,*) pair=${remaining%%,*}; remaining=${remaining#*,} ;;
      *) pair=$remaining; remaining= ;;
    esac
    [ -n "$pair" ] && [ "$pair" != "${pair#*=}" ] ||
      rig_fail "[$section_name] has invalid schedule.calendar entry '$entry'" || return
    key=${pair%%=*}
    value=${pair#*=}
    case "$value" in ''|*[!0-9]*)
      rig_fail "[$section_name] has invalid schedule.calendar value '$value'" || return ;;
    esac
    case "$seen" in *,$key,*)
      rig_fail "[$section_name] repeats schedule.calendar key '$key'" || return ;;
    esac
    number=$((10#$value))
    case "$key" in
      minute) [ "$number" -le 59 ] ;;
      hour) [ "$number" -le 23 ] ;;
      day) [ "$number" -ge 1 ] && [ "$number" -le 31 ] ;;
      weekday) [ "$number" -le 7 ] ;;
      month) [ "$number" -ge 1 ] && [ "$number" -le 12 ] ;;
      *) false ;;
    esac || rig_fail "[$section_name] has out-of-range schedule.calendar pair '$pair'" || return
    seen=$seen$key,
    [ -z "$remaining" ] && break
  done
}

rig_validate_environment_entry() {
  local section_name entry key

  section_name=$1
  entry=$2
  [ "$entry" != "${entry#*=}" ] ||
    rig_fail "[$section_name] environment entry requires KEY=value: '$entry'" || return
  key=${entry%%=*}
  case "$key" in
    ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
      rig_fail "[$section_name] has invalid environment name '$key'" || return ;;
  esac
}

rig_validate_resource() {
  local section_name section_type section_index provider adapter value
  local field_index field_end calendar_count interval_count

  section_name=$1
  section_type=$2
  rig_require_field "$section_name" name || return
  rig_require_field "$section_name" purpose || return
  rig_require_field "$section_name" rationale || return
  rig_require_field "$section_name" provider || return
  provider=$RIG_VALUE
  rig_valid_id "$provider" && rig_provider_exists "$provider" ||
    rig_fail "[$section_name] references unknown provider '$provider'" || return
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  case "$adapter" in
    custom|launchd) ;;
    *) rig_fail "[$section_name] resources require a resource-capable provider" || return ;;
  esac
  rig_require_field "$section_name" locator || return
  case "$RIG_VALUE" in *$'\t'*|*$'\n'*)
    rig_fail "[$section_name] locator must not contain tabs or newlines" || return ;;
  esac
  [ -n "$RIG_VALUE" ] || rig_fail "[$section_name] locator must not be empty" || return
  rig_require_field "$section_name" desired-state || return
  value=$RIG_VALUE
  case "$section_type:$value" in
    service:running|service:stopped|scheduled-job:enabled|scheduled-job:disabled) ;;
    service:*) rig_fail "[$section_name] desired-state must be 'running' or 'stopped'" || return ;;
    scheduled-job:*) rig_fail "[$section_name] desired-state must be 'enabled' or 'disabled'" || return ;;
  esac

  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  rig_field_count "$section_index" platform
  [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section_name] requires field 'platforms'" || return
  rig_field_count "$section_index" program
  [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section_name] requires field 'program'" || return
  rig_validate_references_for_field "$section_index" requires tool || return
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    case "${RIG_FIELD_KEYS[$field_index]}" in
      program)
        [ -n "${RIG_FIELD_VALUES[$field_index]}" ] ||
          rig_fail "[$section_name] program entries must not be empty" || return ;;
      environment)
        rig_validate_environment_entry "$section_name" "${RIG_FIELD_VALUES[$field_index]}" || return ;;
      schedule-calendar)
        rig_validate_calendar_entry "$section_name" "${RIG_FIELD_VALUES[$field_index]}" || return ;;
    esac
    field_index=$((field_index + 1))
  done

  if [ "$section_type" = service ]; then
    if rig_get_value "$section_name" restart-policy; then
      case "$RIG_VALUE" in always|never) ;; *)
        rig_fail "[$section_name] restart-policy must be 'always' or 'never'" || return ;;
      esac
    fi
    if rig_get_value "$section_name" start-policy; then
      case "$RIG_VALUE" in load|manual) ;; *)
        rig_fail "[$section_name] start-policy must be 'load' or 'manual'" || return ;;
      esac
    fi
    return 0
  fi

  rig_field_count "$section_index" schedule-calendar
  calendar_count=$RIG_COUNT
  rig_field_count "$section_index" schedule-interval
  interval_count=$RIG_COUNT
  [ "$calendar_count" -gt 0 ] && [ "$interval_count" -eq 0 ] ||
    { [ "$calendar_count" -eq 0 ] && [ "$interval_count" -eq 1 ]; } ||
    rig_fail "[$section_name] requires exactly one of schedule.calendar or schedule.interval" || return
  if [ "$interval_count" -eq 1 ]; then
    rig_get_value "$section_name" schedule-interval || return 2
    case "$RIG_VALUE" in ''|*[!0-9]*|0)
      rig_fail "[$section_name] schedule.interval must be a positive decimal string" || return ;;
    esac
  fi
  if rig_get_value "$section_name" run-policy; then
    case "$RIG_VALUE" in scheduled-only|also-at-load) ;; *)
      rig_fail "[$section_name] run-policy must be 'scheduled-only' or 'also-at-load'" || return ;;
    esac
  fi
  if rig_get_value "$section_name" priority; then
    case "$RIG_VALUE" in background|normal) ;; *)
      rig_fail "[$section_name] priority must be 'background' or 'normal'" || return ;;
    esac
  fi
}

rig_validate_resource_locators() {
  local index scan provider locator other_provider other_locator

  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    case "${RIG_SECTION_TYPES[$index]}" in service|scheduled-job) ;; *)
      index=$((index + 1)); continue ;;
    esac
    rig_get_value "${RIG_SECTION_NAMES[$index]}" provider || return 2
    provider=$RIG_VALUE
    rig_get_value "${RIG_SECTION_NAMES[$index]}" locator || return 2
    locator=$RIG_VALUE
    scan=$((index + 1))
    while [ "$scan" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
      case "${RIG_SECTION_TYPES[$scan]}" in service|scheduled-job) ;;
        *) scan=$((scan + 1)); continue ;;
      esac
      rig_get_value "${RIG_SECTION_NAMES[$scan]}" provider || return 2
      other_provider=$RIG_VALUE
      rig_get_value "${RIG_SECTION_NAMES[$scan]}" locator || return 2
      other_locator=$RIG_VALUE
      if [ "$provider" = "$other_provider" ] && [ "$locator" = "$other_locator" ]; then
        rig_fail "[${RIG_SECTION_NAMES[$scan]}] duplicates provider locator from [${RIG_SECTION_NAMES[$index]}]" || return
      fi
      scan=$((scan + 1))
    done
    index=$((index + 1))
  done
}

rig_validate_action() {
  local section_name provider adapter mode argument_policy section_index field_index field_end kind

  section_name=$1
  provider=$2

  rig_provider_exists "$provider" ||
    rig_fail "[$section_name] references unknown provider '$provider'" || return
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  [ "$adapter" = custom ] ||
    rig_fail "[$section_name] actions require a custom provider" || return

  rig_require_field "$section_name" mode || return
  mode=$RIG_VALUE
  case "$mode" in
    observe|mutate) ;;
    *) rig_fail "[$section_name] mode must be 'observe' or 'mutate'" || return ;;
  esac
  rig_require_field "$section_name" description || return

  argument_policy=rig
  if rig_get_value "$section_name" argument-policy; then
    argument_policy=$RIG_VALUE
  fi
  case "$argument_policy" in
    rig|provider) ;;
    *) rig_fail "[$section_name] argument-policy must be 'rig' or 'provider'" || return ;;
  esac
  if [ "$argument_policy" = provider ]; then
    rig_section_index "$section_name" || return 2
    section_index=$RIG_INDEX
    rig_field_count "$section_index" allow-argument
    [ "$RIG_COUNT" -eq 0 ] ||
      rig_fail "[$section_name] cannot combine argument-policy 'provider' with allowed-arguments" || return
  fi
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  rig_field_count "$section_index" resource-kind
  if [ "$RIG_COUNT" -gt 0 ]; then
    [ "$argument_policy" = provider ] ||
      rig_fail "[$section_name] resource-kinds require argument-policy 'provider'" || return
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = resource-kind ]; then
        kind=${RIG_FIELD_VALUES[$field_index]}
        case "$kind" in service|scheduled-job) ;; *)
          rig_fail "[$section_name] resource-kinds accepts only 'service' or 'scheduled-job'" || return ;;
        esac
      fi
      field_index=$((field_index + 1))
    done
  fi
}

rig_validate_macos_platforms() {
  local section_name section_index field_index field_end count

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  count=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = platform ]; then
      count=$((count + 1))
      [ "${RIG_FIELD_VALUES[$field_index]}" = macos ] ||
        rig_fail "[$section_name] supports only platform 'macos'" || return
    fi
    field_index=$((field_index + 1))
  done
  [ "$count" -gt 0 ] || rig_fail "[$section_name] requires field 'platform'" || return
}

rig_validate_setting() {
  local section_name value_type value

  section_name=$1
  rig_require_field "$section_name" name || return
  rig_require_field "$section_name" purpose || return
  rig_require_field "$section_name" rationale || return
  rig_require_field "$section_name" provider || return
  [ "$RIG_VALUE" = macos-defaults ] ||
    rig_fail "[$section_name] provider must be 'macos-defaults'" || return
  rig_require_field "$section_name" domain || return
  rig_require_field "$section_name" key || return
  rig_require_field "$section_name" value-type || return
  value_type=$RIG_VALUE
  rig_require_field "$section_name" value || return
  value=$RIG_VALUE
  case "$value_type" in
    bool)
      case "$value" in true|false) ;; *) rig_fail "[$section_name] invalid bool value '$value'" || return ;; esac
      ;;
    int)
      [[ "$value" =~ ^-?[0-9]+$ ]] || rig_fail "[$section_name] invalid int value '$value'" || return
      ;;
    float)
      [[ "$value" =~ ^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] ||
        rig_fail "[$section_name] invalid float value '$value'" || return
      ;;
    string) ;;
    *) rig_fail "[$section_name] unsupported value-type '$value_type'" || return ;;
  esac
  rig_validate_macos_platforms "$section_name" || return
  rig_section_index "$section_name" || return 2
  rig_validate_references_for_field "$RIG_INDEX" requires tool
}

rig_validate_dock() {
  local section_name section_index field_index field_end item seen count

  section_name=$1
  rig_require_field "$section_name" name || return
  rig_require_field "$section_name" purpose || return
  rig_require_field "$section_name" rationale || return
  rig_require_field "$section_name" provider || return
  [ "$RIG_VALUE" = macos-dock ] ||
    rig_fail "[$section_name] provider must be 'macos-dock'" || return
  rig_validate_macos_platforms "$section_name" || return
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  rig_validate_references_for_field "$section_index" requires tool || return
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  seen=,
  count=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = item ]; then
      item=${RIG_FIELD_VALUES[$field_index]}
      rig_valid_id "$item" && rig_reference_exists dock-item "$item" ||
        rig_fail "[$section_name] references unknown dock item '$item'" || return
      case "$seen" in
        *,$item,*) rig_fail "[$section_name] repeats dock item '$item'" || return ;;
      esac
      seen=$seen$item,
      count=$((count + 1))
    fi
    field_index=$((field_index + 1))
  done
  [ "$count" -gt 0 ] || rig_fail "[$section_name] requires field 'item'" || return
}

rig_validate_dock_item() {
  local section_name kind

  section_name=$1
  rig_require_field "$section_name" kind || return
  kind=$RIG_VALUE
  rig_require_field "$section_name" path || return
  case "$kind" in
    application)
      if rig_get_value "$section_name" view || rig_get_value "$section_name" display; then
        rig_fail "[$section_name] application cannot declare folder fields" || return
      fi
      ;;
    folder) ;;
    *) rig_fail "[$section_name] unsupported kind '$kind'" || return ;;
  esac
}

rig_validate_port() {
  local section_name section_index number owner kind id

  section_name=$1
  section_index=$2
  rig_require_field "$section_name" name || return
  rig_require_field "$section_name" purpose || return
  rig_require_field "$section_name" rationale || return
  rig_require_field "$section_name" protocol || return
  [ "$RIG_VALUE" = tcp ] || rig_fail "[$section_name] protocol must be 'tcp'" || return
  rig_require_field "$section_name" port || return
  number=$RIG_VALUE
  case "$number" in ''|*[!0-9]*) rig_fail "[$section_name] port must be a decimal integer" || return ;; esac
  [ "$number" -ge 1 ] && [ "$number" -le 65535 ] ||
    rig_fail "[$section_name] port must be between 1 and 65535" || return
  rig_require_field "$section_name" scope || return
  case "$RIG_VALUE" in loopback|all-interfaces) ;; *)
    rig_fail "[$section_name] scope must be 'loopback' or 'all-interfaces'" || return ;;
  esac
  rig_require_field "$section_name" mode || return
  case "$RIG_VALUE" in required|on-demand|allocated) ;; *)
    rig_fail "[$section_name] mode must be 'required', 'on-demand', or 'allocated'" || return ;;
  esac
  rig_require_field "$section_name" owner || return
  owner=$RIG_VALUE
  case "$owner" in *:*) kind=${owner%%:*}; id=${owner#*:} ;; *)
    rig_fail "[$section_name] owner must be a qualified declaration reference" || return ;;
  esac
  case "$kind" in tool|service|scheduled-job) ;; *)
    rig_fail "[$section_name] owner has unsupported kind '$kind'" || return ;;
  esac
  rig_valid_id "$id" && rig_reference_exists "$kind" "$id" ||
    rig_fail "[$section_name] owner references unknown declaration '$owner'" || return
  rig_validate_references_for_field "$section_index" member-profile profile
}

rig_variant_supports_platform() {
  local section_name variant platform section_index field_index field_end key

  section_name=$1
  variant=$2
  platform=$3
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  key=variant:$variant:platform
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = "$key" ] && {
      [ "${RIG_FIELD_VALUES[$field_index]}" = any ] ||
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$platform" ];
    }; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_select_compatible_variant() {
  local section_name platform section_index variant index matches selected
  local -a variants

  section_name=$1
  platform=$2
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  rig_collect_tool_variants "$section_index"
  variants=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")
  [ "${#variants[@]}" -gt 0 ] || { RIG_VALUE=; return 0; }
  matches=0
  selected=
  index=0
  while [ "$index" -lt "${#variants[@]}" ]; do
    variant=${variants[$index]}
    if rig_variant_supports_platform "$section_name" "$variant" "$platform"; then
      matches=$((matches + 1))
      selected=$variant
    fi
    index=$((index + 1))
  done
  [ "$matches" -ne 0 ] ||
    rig_fail "[$section_name] has no variant for platform '$platform'" || return
  [ "$matches" -eq 1 ] ||
    rig_fail "[$section_name] has ambiguous variants for platform '$platform'" || return
  RIG_VALUE=$selected
}

rig_validate_tool_variants() {
  local section_name section_index variant index field_index field_end key field
  local install_fields artifact_count platform_count variant_installs tool_platform matches
  local -a variants

  section_name=$1
  section_index=$2
  rig_collect_tool_variants "$section_index"
  variants=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")
  [ "${#variants[@]}" -gt 0 ] || return 0
  variant_installs=0
  index=0
  while [ "$index" -lt "${#variants[@]}" ]; do
    variant=${variants[$index]}
    platform_count=0
    artifact_count=0
    install_fields=0
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      key=${RIG_FIELD_KEYS[$field_index]}
      case "$key" in variant:"$variant":*)
        field=${key#variant:"$variant":}
        case "$field" in
          platform) platform_count=$((platform_count + 1)) ;;
          artifact) artifact_count=$((artifact_count + 1)) ;;
          install-*) install_fields=$((install_fields + 1)) ;;
        esac
        ;;
      esac
      field_index=$((field_index + 1))
    done
    [ "$platform_count" -gt 0 ] ||
      rig_fail "[$section_name] variant '$variant' requires field 'platforms'" || return
    if rig_get_value "$section_name" "variant:$variant:install-provider"; then
      variant_installs=$((variant_installs + 1))
      rig_get_value "$section_name" "variant:$variant:install-kind" ||
        rig_fail "[$section_name] variant '$variant' requires install.kind" || return
      rig_get_value "$section_name" "variant:$variant:install-locator" ||
        rig_fail "[$section_name] variant '$variant' requires install.locator" || return
    elif [ "$install_fields" -gt 0 ]; then
      rig_fail "[$section_name] variant '$variant' install metadata requires install.provider" || return
    fi
    [ "$artifact_count" -gt 0 ] || [ "$install_fields" -gt 0 ] ||
      rig_fail "[$section_name] variant '$variant' has no installation or artifacts" || return
    index=$((index + 1))
  done
  if [ "$variant_installs" -gt 0 ] && rig_get_value "$section_name" install-provider; then
    rig_fail "[$section_name] cannot combine install.* with variant installations" || return
  fi

  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = platform ]; then
      tool_platform=${RIG_FIELD_VALUES[$field_index]}
      matches=0
      index=0
      while [ "$index" -lt "${#variants[@]}" ]; do
        rig_variant_supports_platform "$section_name" "${variants[$index]}" "$tool_platform" &&
          matches=$((matches + 1))
        index=$((index + 1))
      done
      [ "$matches" -ne 0 ] ||
        rig_fail "[$section_name] has no variant for declared platform '$tool_platform'" || return
      [ "$matches" -eq 1 ] ||
        rig_fail "[$section_name] has ambiguous variants for declared platform '$tool_platform'" || return
    fi
    field_index=$((field_index + 1))
  done
}

rig_validate_skill() {
  local section_name section_index authority trust source source_skill field_index field_end runtime

  section_name=$1
  section_index=$2
  rig_require_field "$section_name" name || return
  rig_require_field "$section_name" purpose || return
  rig_require_field "$section_name" rationale || return
  rig_require_field "$section_name" authority || return
  authority=$RIG_VALUE
  rig_require_field "$section_name" source || return
  source=$RIG_VALUE
  rig_require_field "$section_name" trust || return
  trust=$RIG_VALUE
  case "$authority:$trust" in
    skills-cli:reviewed|ki:reviewed|local:reviewed|runtime:authority-owned|plugin:authority-owned) ;;
    skills-cli:*|ki:*|local:*)
      rig_fail "[$section_name] materialising authority '$authority' requires trust 'reviewed'" || return
      ;;
    runtime:*|plugin:*)
      rig_fail "[$section_name] observation-only authority '$authority' requires trust 'authority-owned'" || return
      ;;
    *) rig_fail "[$section_name] has unsupported authority '$authority'" || return ;;
  esac
  if rig_get_value "$section_name" source-skill; then
    source_skill=$RIG_VALUE
    rig_valid_id "$source_skill" || rig_fail "[$section_name] has invalid source-skill '$source_skill'" || return
  fi
  if [ "$authority" = local ]; then
    case "$source" in /*|\~/*|\$HOME/*) ;; *)
          rig_fail "[$section_name] local source must be absolute or start with '~/' or '\$HOME/'" || return ;;
    esac
  fi
  if rig_get_value "$section_name" public-source; then
    case "$RIG_VALUE" in https://*|http://*) ;; *)
      rig_fail "[$section_name] public-source must be an absolute HTTP or HTTPS URL" || return ;;
    esac
  fi
  rig_field_count "$section_index" platform
  [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section_name] requires field 'platform'" || return
  rig_field_count "$section_index" runtime
  [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section_name] requires field 'runtime'" || return
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = runtime ]; then
      runtime=${RIG_FIELD_VALUES[$field_index]}
      case "$runtime" in agents|claude-code|codex|github-copilot|warp|zed) ;;
        *) rig_fail "[$section_name] has unsupported runtime '$runtime'" || return ;;
      esac
    fi
    field_index=$((field_index + 1))
  done
  rig_validate_references_for_field "$section_index" requires tool || return
  rig_validate_references_for_field "$section_index" member-profile profile
}

rig_validate_model() {
  local index section_name section_type section_id secondary_id adapter provider profile
  local field_index field_end

  rig_section_index rig || rig_fail 'missing [rig] section' || return
  rig_require_field rig schema || return
  [ "$RIG_VALUE" = 1 ] || rig_fail "unsupported schema version '$RIG_VALUE'" || return
  rig_require_field rig default-profile || return
  rig_valid_id "$RIG_VALUE" || rig_fail "invalid default profile '$RIG_VALUE'" || return
  rig_reference_exists profile "$RIG_VALUE" || rig_fail "[rig] references unknown profile '$RIG_VALUE'" || return
  if rig_get_value rig bootstrap-profile; then
    rig_valid_id "$RIG_VALUE" || rig_fail "invalid bootstrap profile '$RIG_VALUE'" || return
    rig_reference_exists profile "$RIG_VALUE" ||
      rig_fail "[rig] references unknown bootstrap profile '$RIG_VALUE'" || return
  fi

  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    section_name=${RIG_SECTION_NAMES[$index]}
    section_type=${RIG_SECTION_TYPES[$index]}
    section_id=${RIG_SECTION_IDS[$index]}
    secondary_id=${RIG_SECTION_SECONDARY_IDS[$index]}

    case "$section_type" in
      rig) ;;
      category)
        rig_require_field "$section_name" name || return
        rig_require_field "$section_name" purpose || return
        ;;
      tool)
        rig_require_field "$section_name" name || return
        rig_require_field "$section_name" category || return
        rig_valid_id "$RIG_VALUE" || rig_fail "[$section_name] has invalid category '$RIG_VALUE'" || return
        rig_reference_exists category "$RIG_VALUE" || rig_fail "[$section_name] references unknown category '$RIG_VALUE'" || return
        rig_require_field "$section_name" purpose || return
        rig_require_field "$section_name" rationale || return
      rig_field_count "$index" platform
      [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section_name] requires field 'platform'" || return
      if ! rig_get_value "$section_name" install-provider; then
        if rig_get_value "$section_name" install-kind ||
          rig_get_value "$section_name" install-locator ||
          rig_get_value "$section_name" install-destination ||
          rig_get_value "$section_name" install-checksum ||
          rig_get_value "$section_name" install-platform ||
          rig_get_value "$section_name" install-argument; then
          rig_fail "[$section_name] install metadata requires install.provider" || return
        fi
      fi
      rig_validate_tool_variants "$section_name" "$index" || return
      rig_validate_references_for_field "$index" requires tool || return
        rig_validate_references_for_field "$index" related tool || return
        rig_validate_references_for_field "$index" alternative tool || return
        rig_validate_references_for_field "$index" member-profile profile || return
        ;;
      skill)
        rig_validate_skill "$section_name" "$index" || return
        ;;
      profile)
        rig_validate_references_for_field "$index" profile profile || return
        rig_validate_references_for_field "$index" inherit profile || return
        rig_validate_references_for_field "$index" tool tool || return
        rig_validate_references_for_field "$index" skill skill || return
        rig_validate_references_for_field "$index" service service || return
        rig_validate_references_for_field "$index" scheduled-job scheduled-job || return
        rig_validate_references_for_field "$index" setting setting || return
        rig_validate_references_for_field "$index" dock dock || return
        rig_validate_references_for_field "$index" port port || return
        if rig_field_declared "$section_name" profile &&
          rig_field_declared "$section_name" inherit; then
          rig_fail "[$section_name] cannot combine 'profiles' with 'inherits'" || return
        fi
        rig_profile_kind "$section_id" || return
        case "$RIG_VALUE" in complete|view) ;; *)
          rig_fail "[$section_name] kind must be 'complete' or 'view'" || return ;;
        esac
        ;;
      service|scheduled-job)
        rig_validate_resource "$section_name" "$section_type" || return
        rig_validate_references_for_field "$index" member-profile profile || return
        rig_validate_resource_dependencies "$section_name" "$index" || return
        ;;
      setting)
        rig_validate_setting "$section_name" || return
        rig_validate_references_for_field "$index" member-profile profile || return
        rig_validate_resource_dependencies "$section_name" "$index" || return
        ;;
      dock)
        rig_validate_dock "$section_name" || return
        rig_validate_references_for_field "$index" member-profile profile || return
        rig_validate_resource_dependencies "$section_name" "$index" || return
        ;;
      dock-item) rig_validate_dock_item "$section_name" || return ;;
      port) rig_validate_port "$section_name" "$index" || return ;;
    provider)
      if rig_get_value "$section_name" command; then
        rig_fail "[$section_name] field 'command' is not supported" || return
      fi
      if rig_builtin_provider_adapter "$section_id"; then
          if rig_get_value "$section_name" adapter; then
            rig_fail "[$section_name] reserved built-in provider cannot declare adapter" || return
          fi
        rig_field_count "$index" capability
        [ "$RIG_COUNT" -eq 0 ] ||
          rig_fail "[$section_name] reserved built-in provider cannot declare capabilities" || return
        if rig_get_value "$section_name" autoupdate-interval; then
          [ "$section_id" = homebrew ] ||
            rig_fail "[$section_name] autoupdate policy is only supported by Homebrew" || return
          case "$RIG_VALUE" in
            ''|*[!0-9]*|0) rig_fail "[$section_name] has invalid autoupdate interval '$RIG_VALUE'" || return ;;
          esac
        fi
        rig_field_count "$index" autoupdate-option
        if [ "$RIG_COUNT" -gt 0 ]; then
          [ "$section_id" = homebrew ] ||
            rig_fail "[$section_name] autoupdate policy is only supported by Homebrew" || return
          rig_get_value "$section_name" autoupdate-interval ||
            rig_fail "[$section_name] autoupdate options require autoupdate-interval" || return
          field_index=${RIG_SECTION_FIELD_STARTS[$index]}
          field_end=${RIG_SECTION_FIELD_ENDS[$index]}
          while [ "$field_index" -lt "$field_end" ]; do
            if [ "${RIG_FIELD_KEYS[$field_index]}" = autoupdate-option ]; then
              case "${RIG_FIELD_VALUES[$field_index]}" in
                upgrade|cleanup|immediate|sudo) ;;
                *)
                  rig_fail "[$section_name] has invalid autoupdate option '${RIG_FIELD_VALUES[$field_index]}'" || return
                  ;;
              esac
            fi
            field_index=$((field_index + 1))
          done
        fi
      else
          rig_require_field "$section_name" adapter || return
          adapter=$RIG_VALUE
          [ "$adapter" = custom ] ||
            rig_fail "[$section_name] external provider adapter must be 'custom'" || return
          rig_validate_provider_adapter "$section_name" "$adapter" || return
          rig_field_count "$index" capability
          [ "$RIG_COUNT" -gt 0 ] ||
            rig_fail "[$section_name] requires field 'capabilities'" || return
          if rig_get_value "$section_name" manifest; then
            rig_fail "[$section_name] external provider cannot declare manifest" || return
          fi
        fi
        ;;
      binding)
        rig_reference_exists tool "$section_id" || rig_fail "[$section_name] references unknown tool '$section_id'" || return
        rig_provider_exists "$secondary_id" || rig_fail "[$section_name] references unknown provider '$secondary_id'" || return
        rig_require_field "$section_name" kind || return
        rig_require_field "$section_name" locator || return
        rig_validate_binding_adapter "$section_name" "$secondary_id" || return
        ;;
      publication)
        rig_require_field "$section_name" profile || return
        profile=$RIG_VALUE
        rig_valid_id "$RIG_VALUE" && rig_reference_exists profile "$RIG_VALUE" ||
          rig_fail "[$section_name] references unknown profile '$RIG_VALUE'" || return
        rig_require_field "$section_name" title || return
        rig_require_field "$section_name" base-url || return
        rig_require_field "$section_name" publisher || return
        provider=$RIG_VALUE
        rig_valid_id "$provider" && rig_reference_exists provider "$provider" ||
          rig_fail "[$section_name] publisher must reference an explicit provider" || return
        rig_provider_adapter "$provider" || return 2
        [ "$RIG_VALUE" = custom ] ||
          rig_fail "[$section_name] publisher must reference a custom provider" || return
        rig_provider_has_capability "$provider" publish ||
          rig_fail "[$section_name] publisher '$provider' requires capability 'publish'" || return
        rig_profile_kind "$profile" || return
        [ "$RIG_VALUE" = view ] ||
          rig_fail "[$section_name] profile '$profile' must be a non-appliable view" || return
        ;;
    action)
      rig_validate_action "$section_name" "$section_id" || return
      ;;
    esac
    index=$((index + 1))
  done

  rig_detect_profile_selection_mode || return

  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = profile ]; then
      section_name=${RIG_SECTION_NAMES[$index]}
      section_id=${RIG_SECTION_IDS[$index]}
      rig_profile_kind "$section_id" || return
      if [ "$RIG_VALUE" = view ]; then
        field_index=${RIG_SECTION_FIELD_STARTS[$index]}
        field_end=${RIG_SECTION_FIELD_ENDS[$index]}
        while [ "$field_index" -lt "$field_end" ]; do
          case "${RIG_FIELD_KEYS[$field_index]}" in profile|inherit)
            rig_profile_kind "${RIG_FIELD_VALUES[$field_index]}" || return
            [ "$RIG_VALUE" = view ] ||
              rig_fail "[$section_name] view cannot inherit appliable profile '${RIG_FIELD_VALUES[$field_index]}'" || return
            ;;
          esac
          field_index=$((field_index + 1))
        done
      fi
    fi
    index=$((index + 1))
  done

  if rig_get_value rig bootstrap-profile; then
    rig_profile_kind "$RIG_VALUE" || return
    [ "$RIG_VALUE" = complete ] || rig_fail '[rig] bootstrap-profile must be appliable' || return
  fi

  rig_validate_cycles
}

rig_load_config() {
  local config_home root_file fragment source_count source_index
  local -a sources
  local LC_ALL=C

  rig_model_reset
  if [ -n "${RIG_CONFIG_HOME:-}" ]; then
    config_home=$RIG_CONFIG_HOME
  else
    [ -n "${HOME:-}" ] || rig_fail 'HOME is required when RIG_CONFIG_HOME is not set' || return
    config_home=${XDG_CONFIG_HOME:-$HOME/.config}/rig
  fi

  root_file=$config_home/rig.toml
  sources=()
  rig_progress_start 'configuration discovery' 1
  rig_progress_begin sources
  source_count=0
  if [ -e "$root_file" ]; then
    sources[${#sources[@]}]=$root_file
    source_count=$((source_count + 1))
  fi
  for fragment in "$config_home"/conf.d/*.toml; do
    [ -f "$fragment" ] || continue
    sources[${#sources[@]}]=$fragment
    source_count=$((source_count + 1))
  done
  [ "$source_count" -gt 0 ] ||
    rig_fail "no configuration sources under: $config_home" || return
  rig_progress_result succeeded sources
  rig_progress_finish

  rig_progress_start 'configuration parsing' "$source_count"
  source_index=0
  while [ "$source_index" -lt "$source_count" ]; do
    rig_progress_begin "source $((source_index + 1))"
    rig_parse_file "${sources[$source_index]}" || return
    rig_progress_result succeeded "source $((source_index + 1))"
    source_index=$((source_index + 1))
  done
  rig_progress_finish

  rig_progress_start 'configuration synthesis' 1
  rig_progress_begin model
  rig_synthesise_bindings || return
  rig_progress_result succeeded model
  rig_progress_finish

  rig_progress_start 'configuration validation' 1
  rig_progress_begin model
  rig_validate_model || return
  rig_progress_result succeeded model
  rig_progress_finish
}

rig_tool_supports_platform() {
  local tool platform section_index field_index field_end

  [ "$RIG_PUBLICATION_PLATFORM_NEUTRAL" -ne 1 ] || return 0
  tool=$1
  platform=$2
  rig_section_index "tool.$tool" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = platform ] &&
      { [ "${RIG_FIELD_VALUES[$field_index]}" = any ] ||
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$platform" ]; }; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_array_contains() {
  local wanted item

  wanted=$1
  shift
  for item in "$@"; do
    [ "$item" != "$wanted" ] || return 0
  done
  return 1
}

rig_select_tool() {
  local tool platform required_by section_index field_index field_end child

  tool=$1
  platform=$2
  required_by=${3:-}
  if ! rig_tool_supports_platform "$tool" "$platform"; then
    [ -z "$required_by" ] && return 0
    rig_fail "tool '$required_by' requires '$tool', which does not support platform '$platform'" || return
  fi
  if [ "${#RIG_SELECTED_TOOLS[@]}" -gt 0 ]; then
    rig_array_contains "$tool" "${RIG_SELECTED_TOOLS[@]}" && return 0
  fi
  RIG_SELECTED_TOOLS[${#RIG_SELECTED_TOOLS[@]}]=$tool

  rig_section_index "tool.$tool" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      child=${RIG_FIELD_VALUES[$field_index]}
      rig_select_tool "$child" "$platform" "$tool" || return
    fi
    field_index=$((field_index + 1))
  done
}

rig_skill_supports_platform() {
  local skill platform section_index field_index field_end

  [ "$RIG_PUBLICATION_PLATFORM_NEUTRAL" -ne 1 ] || return 0
  skill=$1
  platform=$2
  rig_section_index "skill.$skill" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = platform ] && {
      [ "${RIG_FIELD_VALUES[$field_index]}" = any ] ||
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$platform" ];
    }; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_select_skill() {
  local skill platform section_index field_index field_end tool

  skill=$1
  platform=$2
  rig_skill_supports_platform "$skill" "$platform" || return 0
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ] &&
    rig_array_contains "$skill" "${RIG_SELECTED_SKILLS[@]}"; then
    return 0
  fi
  rig_section_index "skill.$skill" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      tool=${RIG_FIELD_VALUES[$field_index]}
      rig_select_tool "$tool" "$platform" "skill.$skill" || return
    fi
    field_index=$((field_index + 1))
  done
  RIG_SELECTED_SKILLS[${#RIG_SELECTED_SKILLS[@]}]=$skill
}

rig_sort_selected_skills() {
  local index scan value previous
  local LC_ALL=C

  index=1
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    value=${RIG_SELECTED_SKILLS[$index]}
    scan=$index
    while [ "$scan" -gt 0 ]; do
      previous=${RIG_SELECTED_SKILLS[$((scan - 1))]}
      [[ "$value" < "$previous" ]] || break
      RIG_SELECTED_SKILLS[$scan]=$previous
      scan=$((scan - 1))
    done
    RIG_SELECTED_SKILLS[$scan]=$value
    index=$((index + 1))
  done
}

rig_resource_supports_platform() {
  local section_name platform section_index field_index field_end

  section_name=$1
  platform=$2
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = platform ] &&
      [ "${RIG_FIELD_VALUES[$field_index]}" = "$platform" ]; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_select_resource() {
  local kind resource platform section_name section_index field_index field_end tool reference dependency

  kind=$1
  resource=$2
  platform=$3
  section_name=$kind.$resource
  rig_resource_supports_platform "$section_name" "$platform" ||
    rig_fail "$kind '$resource' does not support platform '$platform'" || return
  if [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -gt 0 ] &&
    rig_array_contains "$section_name" "${RIG_SELECTED_RESOURCE_SECTIONS[@]}"; then
    return 0
  fi
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    case "${RIG_FIELD_KEYS[$field_index]}" in
      requires)
        tool=${RIG_FIELD_VALUES[$field_index]}
        rig_select_tool "$tool" "$platform" "$section_name" || return
        ;;
      resource-dependency)
        reference=${RIG_FIELD_VALUES[$field_index]}
        rig_resource_reference "$reference" || return 2
        dependency=$RIG_VALUE
        rig_select_resource "${dependency%%.*}" "${dependency#*.}" "$platform" || return
        ;;
    esac
    field_index=$((field_index + 1))
  done
  RIG_SELECTED_RESOURCE_SECTIONS[${#RIG_SELECTED_RESOURCE_SECTIONS[@]}]=$section_name
}

rig_select_port() {
  local port

  port=$1
  rig_section_index "port.$port" || rig_fail "unknown port '$port'" || return
  if [ "${#RIG_SELECTED_PORTS[@]}" -eq 0 ] ||
    ! rig_array_contains "$port" "${RIG_SELECTED_PORTS[@]}"; then
    RIG_SELECTED_PORTS[${#RIG_SELECTED_PORTS[@]}]=$port
  fi
}

rig_validate_selected_ports() {
  local index scan port other number other_number protocol other_protocol

  index=0
  while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
    port=${RIG_SELECTED_PORTS[$index]}
    rig_get_value "port.$port" protocol || return 2
    protocol=$RIG_VALUE
    rig_get_value "port.$port" port || return 2
    number=$RIG_VALUE
    scan=$((index + 1))
    while [ "$scan" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
      other=${RIG_SELECTED_PORTS[$scan]}
      rig_get_value "port.$other" protocol || return 2
      other_protocol=$RIG_VALUE
      rig_get_value "port.$other" port || return 2
      other_number=$RIG_VALUE
      [ "$protocol:$number" != "$other_protocol:$other_number" ] ||
        rig_fail "[port.$other] conflicts with [port.$port] at '$protocol:$number'" || return
      scan=$((scan + 1))
    done
    index=$((index + 1))
  done
}

rig_sort_selected_ports() {
  local index scan value previous
  local LC_ALL=C

  index=1
  while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
    value=${RIG_SELECTED_PORTS[$index]}
    scan=$index
    while [ "$scan" -gt 0 ]; do
      previous=${RIG_SELECTED_PORTS[$((scan - 1))]}
      [[ "$value" < "$previous" ]] || break
      RIG_SELECTED_PORTS[$scan]=$previous
      scan=$((scan - 1))
    done
    RIG_SELECTED_PORTS[$scan]=$value
    index=$((index + 1))
  done
}

rig_resource_dependencies_selected() {
  local section_name section_index field_index field_end reference dependency

  section_name=$1
  shift
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = resource-dependency ]; then
      reference=${RIG_FIELD_VALUES[$field_index]}
      rig_resource_reference "$reference" || return 2
      dependency=$RIG_VALUE
      [ "$#" -gt 0 ] && rig_array_contains "$dependency" "$@" || return 1
    fi
    field_index=$((field_index + 1))
  done
}

rig_sort_selected_resources() {
  local candidate best index remaining_index
  local LC_ALL=C
  local -a remaining ordered next

  remaining=("${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}")
  ordered=()
  while [ "${#remaining[@]}" -gt 0 ]; do
    best=
    index=0
    while [ "$index" -lt "${#remaining[@]}" ]; do
      candidate=${remaining[$index]}
      if rig_resource_dependencies_selected "$candidate" "${ordered[@]+"${ordered[@]}"}"; then
        if [ -z "$best" ] || [[ "$candidate" < "$best" ]]; then
          best=$candidate
        fi
      fi
      index=$((index + 1))
    done
    [ -n "$best" ] || rig_fail 'resource dependency graph cannot be ordered' || return
    ordered[${#ordered[@]}]=$best
    next=()
    remaining_index=0
    while [ "$remaining_index" -lt "${#remaining[@]}" ]; do
      candidate=${remaining[$remaining_index]}
      [ "$candidate" = "$best" ] || next[${#next[@]}]=$candidate
      remaining_index=$((remaining_index + 1))
    done
    remaining=("${next[@]+"${next[@]}"}")
  done
  RIG_SELECTED_RESOURCE_SECTIONS=("${ordered[@]+"${ordered[@]}"}")
}

rig_activate_profile() {
  local profile section_index field_index field_end child

  profile=$1
  if [ "${#RIG_ACTIVE_PROFILES[@]}" -gt 0 ] &&
    rig_array_contains "$profile" "${RIG_ACTIVE_PROFILES[@]}"; then
    return 0
  fi
  RIG_ACTIVE_PROFILES[${#RIG_ACTIVE_PROFILES[@]}]=$profile
  rig_section_index "profile.$profile" || rig_fail "unknown profile '$profile'" || return
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    case "${RIG_FIELD_KEYS[$field_index]}" in profile|inherit)
      child=${RIG_FIELD_VALUES[$field_index]}
      rig_activate_profile "$child" || return
      ;;
    esac
    field_index=$((field_index + 1))
  done
}

rig_item_selected_by_active_profiles() {
  local section_name section_index field_index field_end profile default_profile

  section_name=$1
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  if rig_field_declared "$section_name" member-profile; then
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = member-profile ]; then
        profile=${RIG_FIELD_VALUES[$field_index]}
        if [ "${#RIG_ACTIVE_PROFILES[@]}" -gt 0 ] &&
          rig_array_contains "$profile" "${RIG_ACTIVE_PROFILES[@]}"; then
          return 0
        fi
      fi
      field_index=$((field_index + 1))
    done
    return 1
  fi
  rig_get_value rig default-profile || return 2
  default_profile=$RIG_VALUE
  [ "${#RIG_ACTIVE_PROFILES[@]}" -gt 0 ] &&
    rig_array_contains "$default_profile" "${RIG_ACTIVE_PROFILES[@]}"
}

rig_item_declares_profile() {
  local section_name profile section_index field_index field_end default_profile

  section_name=$1
  profile=$2
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  if rig_field_declared "$section_name" member-profile; then
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = member-profile ] &&
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$profile" ]; then
        return 0
      fi
      field_index=$((field_index + 1))
    done
    return 1
  fi
  rig_get_value rig default-profile || return 2
  default_profile=$RIG_VALUE
  [ "$profile" = "$default_profile" ]
}

rig_select_item_memberships() {
  local platform index section_type section_name section_id

  platform=$1
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    section_type=${RIG_SECTION_TYPES[$index]}
    section_name=${RIG_SECTION_NAMES[$index]}
    section_id=${RIG_SECTION_IDS[$index]}
    case "$section_type" in tool|skill|service|scheduled-job|setting|dock|port) ;; *)
      index=$((index + 1)); continue ;;
    esac
    if rig_item_selected_by_active_profiles "$section_name"; then
      case "$section_type" in
        tool) rig_select_tool "$section_id" "$platform" || return ;;
        skill) rig_select_skill "$section_id" "$platform" || return ;;
        port) rig_select_port "$section_id" || return ;;
        *) rig_select_resource "$section_type" "$section_id" "$platform" || return ;;
      esac
    fi
    index=$((index + 1))
  done
}

rig_select_central_profile() {
  local profile platform section_index field_index field_end key target

  profile=$1
  platform=$2
  rig_section_index "profile.$profile" || rig_fail "unknown profile '$profile'" || return
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ]; then
      key=${RIG_FIELD_KEYS[$field_index]}
      target=${RIG_FIELD_VALUES[$field_index]}
      case "$key" in
        profile|inherit) rig_select_central_profile "$target" "$platform" || return ;;
        tool) rig_select_tool "$target" "$platform" || return ;;
        skill) rig_select_skill "$target" "$platform" || return ;;
        service) rig_select_resource service "$target" "$platform" || return ;;
        scheduled-job) rig_select_resource scheduled-job "$target" "$platform" || return ;;
        setting) rig_select_resource setting "$target" "$platform" || return ;;
        dock) rig_select_resource dock "$target" "$platform" || return ;;
        port) rig_select_port "$target" || return ;;
      esac
    fi
    field_index=$((field_index + 1))
  done
}

rig_view_tool_is_explicit() {
  local tool profile section_index field_index field_end

  tool=$1
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    rig_item_selected_by_active_profiles "tool.$tool"
    return
  fi
  for profile in "${RIG_ACTIVE_PROFILES[@]}"; do
    rig_section_index "profile.$profile" || return 2
    section_index=$RIG_INDEX
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = tool ] &&
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$tool" ]; then
        return 0
      fi
      field_index=$((field_index + 1))
    done
  done
  return 1
}

rig_view_skill_is_explicit() {
  local skill profile section_index field_index field_end

  skill=$1
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    rig_item_selected_by_active_profiles "skill.$skill"
    return
  fi
  for profile in "${RIG_ACTIVE_PROFILES[@]}"; do
    rig_section_index "profile.$profile" || return 2
    section_index=$RIG_INDEX
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = skill ] &&
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$skill" ]; then
        return 0
      fi
      field_index=$((field_index + 1))
    done
  done
  return 1
}

rig_validate_view_closure() {
  local profile tool skill

  profile=$1
  for tool in "${RIG_SELECTED_TOOLS[@]+"${RIG_SELECTED_TOOLS[@]}"}"; do
    rig_view_tool_is_explicit "$tool" ||
      rig_fail "view profile '$profile' dependency '$tool' is not explicitly opted in" || return
  done
  for skill in "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}"; do
    rig_view_skill_is_explicit "$skill" ||
      rig_fail "view profile '$profile' skill '$skill' is not explicitly opted in" || return
  done
}

rig_resource_native_target() {
  local section_name section_index kind provider domain key locator

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  kind=${RIG_SECTION_TYPES[$section_index]}
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  case "$kind" in
    service|scheduled-job)
      rig_get_value "$section_name" locator || return 2
      locator=$RIG_VALUE
      RIG_VALUE=$provider:locator:$locator
      ;;
    setting)
      rig_get_value "$section_name" domain || return 2
      domain=$RIG_VALUE
      rig_get_value "$section_name" key || return 2
      key=$RIG_VALUE
      RIG_VALUE=$provider:setting:$domain:$key
      ;;
    dock) RIG_VALUE=$provider:dock ;;
    *) return 1 ;;
  esac
}

rig_validate_selected_native_targets() {
  local index scan section_name other target other_target

  index=0
  while [ "$index" -lt "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" ]; do
    section_name=${RIG_SELECTED_RESOURCE_SECTIONS[$index]}
    rig_resource_native_target "$section_name" || return
    target=$RIG_VALUE
    scan=$((index + 1))
    while [ "$scan" -lt "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" ]; do
      other=${RIG_SELECTED_RESOURCE_SECTIONS[$scan]}
      rig_resource_native_target "$other" || return
      other_target=$RIG_VALUE
      [ "$target" != "$other_target" ] ||
        rig_fail "[$other] conflicts with [$section_name] at native target '$target'" || return
      scan=$((scan + 1))
    done
    index=$((index + 1))
  done
}

rig_sort_selected_tools() {
  local index scan value previous
  local LC_ALL=C

  index=1
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    value=${RIG_SELECTED_TOOLS[$index]}
    scan=$index
    while [ "$scan" -gt 0 ]; do
      previous=${RIG_SELECTED_TOOLS[$((scan - 1))]}
      [[ "$value" < "$previous" ]] || break
      RIG_SELECTED_TOOLS[$scan]=$previous
      scan=$((scan - 1))
    done
    RIG_SELECTED_TOOLS[$scan]=$value
    index=$((index + 1))
  done
}

rig_select_tool_variants() {
  local platform index tool

  platform=$1
  RIG_SELECTED_VARIANTS=()
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$index]}
    if [ "$RIG_PUBLICATION_PLATFORM_NEUTRAL" -eq 1 ]; then
      RIG_SELECTED_VARIANTS[$index]=
    else
      rig_select_compatible_variant "tool.$tool" "$platform" || return
      RIG_SELECTED_VARIANTS[$index]=$RIG_VALUE
    fi
    index=$((index + 1))
  done
}

rig_binding_supports_platform() {
  local section_index platform field_index field_end declared

  section_index=$1
  platform=$2
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  declared=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = platform ]; then
      declared=1
      if [ "${RIG_FIELD_VALUES[$field_index]}" = any ] ||
        [ "${RIG_FIELD_VALUES[$field_index]}" = "$platform" ]; then
        return 0
      fi
    fi
    field_index=$((field_index + 1))
  done
  [ "$declared" -eq 0 ]
}

rig_select_bindings() {
  local platform tool_index tool section_index total matches binding_name
  local selected_variant binding_variant variant_install compatible_variant

  platform=$1
  RIG_SELECTED_BINDINGS=()
  tool_index=0
  while [ "$tool_index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$tool_index]}
    selected_variant=${RIG_SELECTED_VARIANTS[$tool_index]:-}
    section_index=0
    total=0
    matches=0
    binding_name=
    while [ "$section_index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
      if [ "${RIG_SECTION_TYPES[$section_index]}" = binding ] &&
        [ "${RIG_SECTION_IDS[$section_index]}" = "$tool" ]; then
        compatible_variant=1
        if rig_get_value "${RIG_SECTION_NAMES[$section_index]}" variant; then
          binding_variant=$RIG_VALUE
          [ "$binding_variant" = "$selected_variant" ] || compatible_variant=0
        elif [ -n "$selected_variant" ]; then
          variant_install=variant:$selected_variant:install-provider
          if rig_get_value "tool.$tool" "$variant_install"; then
            compatible_variant=0
          fi
        fi
        [ "$compatible_variant" -eq 1 ] || { section_index=$((section_index + 1)); continue; }
        total=$((total + 1))
        if rig_binding_supports_platform "$section_index" "$platform"; then
          matches=$((matches + 1))
          binding_name=${RIG_SECTION_NAMES[$section_index]}
        fi
      fi
      section_index=$((section_index + 1))
    done

    if [ "$total" -eq 0 ]; then
      RIG_SELECTED_BINDINGS[$tool_index]=
      tool_index=$((tool_index + 1))
      continue
    fi
    [ "$matches" -ne 0 ] || rig_fail "tool '$tool' has no compatible installation for platform '$platform'" || return
    [ "$matches" -eq 1 ] || rig_fail "tool '$tool' has ambiguous installations for platform '$platform'" || return
    RIG_SELECTED_BINDINGS[$tool_index]=$binding_name
    tool_index=$((tool_index + 1))
  done
}

rig_resolve_profile() {
  local profile platform

  profile=${1:-}
  platform=${2:-}
  RIG_SELECTED_TOOLS=()
  RIG_SELECTED_SKILLS=()
  RIG_SELECTED_BINDINGS=()
  RIG_SELECTED_VARIANTS=()
  RIG_SELECTED_RESOURCE_SECTIONS=()
  RIG_SELECTED_PORTS=()
  RIG_ACTIVE_PROFILES=()
  RIG_RESOLVED_PROFILE=
  RIG_RESOLVED_PLATFORM=
  RIG_RESOLVED_PROFILE_KIND=
  [ -n "$platform" ] || rig_fail 'a platform is required for profile resolution' || return
  if [ -z "$profile" ]; then
    rig_get_value rig default-profile || rig_fail 'configuration is not loaded' || return
    profile=$RIG_VALUE
  fi
  rig_valid_id "$profile" || rig_fail "invalid profile '$profile'" || return

  rig_activate_profile "$profile" || return
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    rig_select_item_memberships "$platform" || return
  else
    rig_select_central_profile "$profile" "$platform" || return
  fi
  rig_sort_selected_tools
  rig_sort_selected_skills
  rig_select_tool_variants "$platform" || return
  rig_sort_selected_resources
  rig_sort_selected_ports
  rig_validate_selected_native_targets || return
  rig_validate_selected_ports || return
  rig_profile_kind "$profile" || return
  RIG_RESOLVED_PROFILE_KIND=$RIG_VALUE
  if [ "$RIG_RESOLVED_PROFILE_KIND" = view ]; then
    rig_validate_view_closure "$profile" || return
  fi
  RIG_RESOLVED_PROFILE=$profile
  RIG_RESOLVED_PLATFORM=$platform
}

rig_resolve_publication_profile() {
  local profile platform exit_code

  profile=$1
  platform=$2
  RIG_PUBLICATION_PLATFORM_NEUTRAL=1
  if rig_resolve_profile "$profile" "$platform"; then
    exit_code=0
  else
    exit_code=$?
  fi
  RIG_PUBLICATION_PLATFORM_NEUTRAL=0
  return "$exit_code"
}

rig_resolve_bindings() {
  [ -n "$RIG_RESOLVED_PLATFORM" ] || rig_fail 'a profile must be resolved before installations' || return
  rig_select_bindings "$RIG_RESOLVED_PLATFORM"
}

rig_dump_resolution() {
  local index binding provider section_index

  printf 'profile=%s\nplatform=%s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    printf 'tool=%s\n' "${RIG_SELECTED_TOOLS[$index]}"
    binding=${RIG_SELECTED_BINDINGS[$index]:-}
    if [ -n "$binding" ]; then
      rig_section_index "$binding" || return 2
      section_index=$RIG_INDEX
      provider=${RIG_SECTION_SECONDARY_IDS[$section_index]}
      printf 'binding=%s:%s\n' "${RIG_SELECTED_TOOLS[$index]}" "$provider"
    fi
    index=$((index + 1))
  done
}
