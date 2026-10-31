#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <JIRA-KEY>\n' "${0##*/}" >&2
  printf 'Required settings: JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN\n' >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

issue_key=$1
if [[ ! $issue_key =~ ^[A-Za-z][A-Za-z0-9_]*-[0-9]+$ ]]; then
  printf 'Invalid Jira issue key: %s\n' "$issue_key" >&2
  usage
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
skill_dir=$(cd -- "$script_dir/.." && pwd)
env_file=${JIRA_ENV_FILE:-"$skill_dir/.env"}

if [[ -f $env_file ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    [[ $line =~ ^[[:space:]]*# ]] && continue

    if [[ $line =~ ^[[:space:]]*(export[[:space:]]+)?(JIRA_BASE_URL|JIRA_EMAIL|JIRA_TOKEN)[[:space:]]*=(.*)$ ]]; then
      name=${BASH_REMATCH[2]}
      value=${BASH_REMATCH[3]}
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      if [[ ${#value} -ge 2 ]]; then
        first_char=${value:0:1}
        last_char=${value: -1}
        if [[ ($first_char == '"' && $last_char == '"') || ($first_char == "'" && $last_char == "'") ]]; then
          value=${value:1:${#value}-2}
        fi
      fi

      if [[ ! -v $name ]]; then
        printf -v "$name" '%s' "$value"
        export "$name"
      fi
    fi
  done < "$env_file"
fi

if [[ -z ${JIRA_BASE_URL:-} || -z ${JIRA_EMAIL:-} || -z ${JIRA_TOKEN:-} ]]; then
  printf 'JIRA_BASE_URL, JIRA_EMAIL, and JIRA_TOKEN must be set in the environment or %s.\n' "$env_file" >&2
  exit 2
fi

if [[ ! $JIRA_BASE_URL =~ ^https://[^/]+/?$ ]]; then
  printf 'JIRA_BASE_URL must be an HTTPS Jira site URL, for example https://your-company.atlassian.net.\n' >&2
  exit 2
fi

base_url=${JIRA_BASE_URL%/}
curl --fail --show-error --silent \
  --request GET \
  --user "$JIRA_EMAIL:$JIRA_TOKEN" \
  --header 'Accept: application/json' \
  "$base_url/rest/api/3/issue/$issue_key"
