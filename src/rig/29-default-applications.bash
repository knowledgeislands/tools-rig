# rig-module: 29-default-applications
# shellcheck shell=bash
# Cross-module native observations and application paths are shared deliberately.
# shellcheck disable=SC2004,SC2034

# The embedded bridge is static JavaScript; declarations travel only as argv.
# shellcheck disable=SC2016
RIG_DEFAULT_HANDLER_SCRIPT='
ObjC.import("Foundation");
ObjC.import("CoreServices");
function run(argv) {
    var action = argv[0], kind = argv[1], value = argv[2];
    var bundle = argv[3], path = argv[4], type, result, code;
    function contentType() {
        if (kind === "uti") return $(value);
        type = $.UTTypeCreatePreferredIdentifierForTag($.kUTTagClassFilenameExtension, $(value), null);
        if (!ObjC.unwrap(type)) throw new Error("extension content type unavailable");
        return type;
    }
    if (action === "observe") {
        result = kind === "scheme" ? $.LSCopyDefaultHandlerForURLScheme($(value)) :
            $.LSCopyDefaultRoleHandlerForContentType(contentType(), $.kLSRolesAll);
        result = ObjC.unwrap(ObjC.castRefToObject(result));
        return result ? String(result) : "-";
    }
    if (action !== "apply") throw new Error("unsupported handler operation");
    code = $.LSRegisterURL($.NSURL.fileURLWithPath($(path)), true);
    if (code !== 0) throw new Error("application registration failed: " + code);
    code = kind === "scheme" ? $.LSSetDefaultHandlerForURLScheme($(value), $(bundle)) :
        $.LSSetDefaultRoleHandlerForContentType(contentType(), $.kLSRolesAll, $(bundle));
    if (code !== 0) throw new Error("handler assignment failed: " + code);
    return "assigned";
}
'

rig_default_application_identity() {
  local section kind value
  section=$1
  rig_get_value "$section" kind || return 2; kind=$RIG_VALUE
  rig_get_value "$section" value || return 2; value=$RIG_VALUE
  [ "$kind" != extension ] || value=${value#.}
  RIG_VALUE=$kind:$value
}

rig_validate_default_application() {
  local section index tool bundle field end found value kind
  section=$1; index=$2
  rig_require_field "$section" name || return
  rig_require_field "$section" purpose || return
  rig_require_field "$section" rationale || return
  rig_require_field "$section" provider || return
  [ "$RIG_VALUE" = macos-handlers ] || rig_fail "[$section] provider must be 'macos-handlers'" || return
  rig_require_field "$section" requires || return; tool=$RIG_VALUE
  rig_reference_exists tool "$tool" || rig_fail "[$section] unknown application tool '$tool'" || return
  rig_require_field "$section" bundle-id || return; bundle=$RIG_VALUE
  rig_retired_valid_bundle_id "$bundle" || rig_fail "[$section] invalid application bundle-id" || return
  rig_require_field "$section" kind || return; kind=$RIG_VALUE
  rig_require_field "$section" value || return; value=$RIG_VALUE
  case "$kind" in
    uti) rig_retired_valid_bundle_id "$value" || rig_fail "[$section] invalid UTI" || return ;;
    extension)
      value=${value#.}
      case "$value" in ''|*[!a-z0-9_-]*) rig_fail "[$section] extension must be a lowercase extension with an optional leading dot"; return ;; esac
      ;;
    scheme)
      case "$value" in ''|[!a-z]*|*[!a-z0-9+.-]*) rig_fail "[$section] scheme must be a lowercase URL scheme without a colon"; return ;; esac
      ;;
    *) rig_fail "[$section] kind must be 'uti', 'extension' or 'scheme'"; return ;;
  esac
  rig_validate_macos_platforms "$section" || return
  rig_validate_references_for_field "$index" member-profile profile || return
  # Installation is optional, but the catalogue must own an application artifact.
  rig_section_index "tool.$tool" || return 2
  field=${RIG_SECTION_FIELD_STARTS[$RIG_INDEX]}; end=${RIG_SECTION_FIELD_ENDS[$RIG_INDEX]}; found=0
  while [ "$field" -lt "$end" ]; do
    case "${RIG_FIELD_KEYS[$field]}" in artifact|variant:*:artifact)
      case "${RIG_FIELD_VALUES[$field]}" in *.app|*.app/) found=1 ;; esac ;;
    esac
    field=$((field + 1))
  done
  [ "$found" -eq 1 ] || rig_fail "[$section] application tool requires a declared .app artifact" || return
}

rig_default_application_preflight() {
  RIG_RESOURCE_PREFLIGHT_DETAIL=
  if [ "${RIG_RESOLVED_PLATFORM:-}" != macos ]; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=unsupported-platform
    return 1
  fi
  if ! rig_executable_available "${RIG_OSASCRIPT:-/usr/bin/osascript}" ||
    ! rig_executable_available "${RIG_PLUTIL:-/usr/bin/plutil}"; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=handler-executable-unavailable
    return 1
  fi
  RIG_VALUE=${RIG_OSASCRIPT:-/usr/bin/osascript}
}

rig_default_application_app() {
  local section tool expected actual
  section=$1
  RIG_DEFAULT_APPLICATION_STATE=unavailable
  RIG_DEFAULT_APPLICATION_DETAIL=application-artifact-unavailable
  RIG_DEFAULT_APPLICATION_PATH=
  rig_get_value "$section" requires || return 2; tool=$RIG_VALUE
  rig_get_value "$section" bundle-id || return 2; expected=$RIG_VALUE
  rig_application_artifact "$tool" || return 0
  RIG_DEFAULT_APPLICATION_PATH=$RIG_APPLICATION_PATH
  rig_observe_tool_artifacts "$tool" 1 || return
  if [ "$RIG_ARTIFACT_STATE" != present ]; then
    RIG_DEFAULT_APPLICATION_STATE=$RIG_ARTIFACT_STATE
    RIG_DEFAULT_APPLICATION_DETAIL=application:$RIG_ARTIFACT_DETAIL
    return 0
  fi
  if ! actual=$("${RIG_PLUTIL:-/usr/bin/plutil}" -extract CFBundleIdentifier raw -o - \
    "$RIG_DEFAULT_APPLICATION_PATH/Contents/Info.plist" 2>/dev/null); then
    RIG_DEFAULT_APPLICATION_STATE=unknown
    RIG_DEFAULT_APPLICATION_DETAIL=application-bundle-id-unavailable
  elif [ "$actual" != "$expected" ]; then
    RIG_DEFAULT_APPLICATION_STATE=drifted
    RIG_DEFAULT_APPLICATION_DETAIL=application-bundle-id-mismatch
  else
    RIG_DEFAULT_APPLICATION_STATE=present
    RIG_DEFAULT_APPLICATION_DETAIL=-
  fi
}

rig_default_application_native() {
  local action section kind value bundle
  action=$1; section=$2
  rig_get_value "$section" kind || return 2; kind=$RIG_VALUE
  rig_get_value "$section" value || return 2; value=$RIG_VALUE
  rig_get_value "$section" bundle-id || return 2; bundle=$RIG_VALUE
  [ "$kind" != extension ] || value=${value#.}
  RIG_INVOKE_ARGUMENTS=(-l JavaScript -e "$RIG_DEFAULT_HANDLER_SCRIPT" -- \
    "$action" "$kind" "$value" "$bundle" "$RIG_DEFAULT_APPLICATION_PATH")
  rig_capture_invocation "${RIG_OSASCRIPT:-/usr/bin/osascript}"
}

rig_default_application_observe() {
  local section bundle
  section=$1
  RIG_OBSERVATION=unavailable
  RIG_OBSERVATION_DETAIL=-
  if ! rig_default_application_preflight; then
    RIG_OBSERVATION_DETAIL=$RIG_RESOURCE_PREFLIGHT_DETAIL
    return 0
  fi
  rig_default_application_app "$section" || return
  RIG_OBSERVATION=$RIG_DEFAULT_APPLICATION_STATE
  RIG_OBSERVATION_DETAIL=$RIG_DEFAULT_APPLICATION_DETAIL
  [ "$RIG_OBSERVATION" = present ] || return 0
  rig_default_application_native observe "$section" || return
  if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=handler-observation-failed:exit:$RIG_NATIVE_STATUS
    return 0
  fi
  rig_get_value "$section" bundle-id || return 2; bundle=$RIG_VALUE
  if [ "$RIG_CAPTURED_OUTPUT" = "$bundle" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=-
  elif [ "$RIG_CAPTURED_OUTPUT" = - ] || rig_retired_valid_bundle_id "$RIG_CAPTURED_OUTPUT"; then
    RIG_OBSERVATION=drifted
    RIG_OBSERVATION_DETAIL=handler-mismatch:current:$RIG_CAPTURED_OUTPUT:expected:$bundle
  else
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=invalid-handler-response
  fi
}

rig_default_application_apply() {
  local section
  section=$1
  rig_default_application_observe "$section" || return
  [ "$RIG_OBSERVATION" != present ] || return 0
  case "$RIG_OBSERVATION_DETAIL" in handler-mismatch:*) ;; *)
    printf 'rig: %s: %s\n' "$section" "$RIG_OBSERVATION_DETAIL" >&2; return 1 ;;
  esac
  rig_default_application_native apply "$section" || return
  if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
    printf 'rig: %s: native handler assignment failed (exit %s).\n' "$section" "$RIG_NATIVE_STATUS" >&2
    return 1
  fi
  rig_default_application_observe "$section" || return
  if [ "$RIG_OBSERVATION" != present ]; then
    printf 'rig: %s: handler assignment not effective (%s); native confirmation may be required.\n' \
      "$section" "$RIG_OBSERVATION_DETAIL" >&2
    return 1
  fi
}
