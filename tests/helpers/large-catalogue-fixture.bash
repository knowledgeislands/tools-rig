#!/usr/bin/env bash

# Write a deterministic catalogue large enough to expose repeated full-model scans.
write_large_catalogue_fixture() {
  local output index tool previous next category provider

  output=$1
  index=1

  {
    printf '%s\n' \
      '[rig]' \
      'schema = 1' \
      'default-profile = default'

    while [ "$index" -le 5 ]; do
      printf '\n[category.category-%s]\n' "$index"
      printf 'name = Category %s\n' "$index"
      printf 'purpose = Deterministic fixture category %s\n' "$index"
      index=$((index + 1))
    done

    printf '%s\n' \
      '' \
      '[provider.homebrew]' \
      'adapter = homebrew' \
      '' \
      '[provider.fixture]' \
      'adapter = custom' \
      'executable = /usr/bin/false' \
      'capability = install'

    index=1
    while [ "$index" -le 100 ]; do
      printf -v tool 'tool-%03d' "$index"
      category=$((index % 5 + 1))

      printf '\n[tool.%s]\n' "$tool"
      printf 'name = Tool %03d\n' "$index"
      printf 'category = category-%s\n' "$category"
      printf 'purpose = Exercise deterministic catalogue query %03d\n' "$index"
      printf 'rationale = Keep fixture tool %03d for correctness and timing coverage\n' "$index"
      printf '%s\n' 'platform = any' 'platform = macos'

      if [ "$index" -gt 1 ]; then
        printf -v previous 'tool-%03d' "$((index - 1))"
        printf 'requires = %s\n' "$previous"
      fi
      if [ "$index" -lt 100 ]; then
        printf -v next 'tool-%03d' "$((index + 1))"
        printf 'related = %s\n' "$next"
      fi
      if [ "$index" -gt 2 ]; then
        printf '%s\n' 'alternative = tool-001'
      fi

      if [ $((index % 2)) -eq 0 ]; then
        provider=fixture
      else
        provider=homebrew
      fi
      printf '\n[binding.%s.%s]\n' "$tool" "$provider"
      printf '%s\n' 'kind = formula'
      printf 'locator = fixture/%s\n' "$tool"
      printf '%s\n' 'platform = macos'

      index=$((index + 1))
    done

    printf '%s\n' \
      '' \
      '[profile.base]' \
      'tool = tool-001' \
      '' \
      '[profile.developer]' \
      'profile = base' \
      'tool = tool-100' \
      '' \
      '[profile.default]' \
      'profile = developer'
  } >"$output"
}
