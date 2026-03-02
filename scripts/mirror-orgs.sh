#!/usr/bin/env bash
#
# Mirrors all repos from SOURCE_ORG to TARGET_ORG.
# Creates repos in TARGET_ORG if they don't exist, then git push --mirror.
#
# Requires: MIRROR_TOKEN, SOURCE_ORG, TARGET_ORG
#
set -o pipefail

if [[ -z "${MIRROR_TOKEN:-}" ]]; then
  echo "ERROR: MIRROR_TOKEN secret is not set."
  echo "Add it at: Settings → Secrets and variables → Actions → New repository secret"
  exit 1
fi
: "${SOURCE_ORG:?SOURCE_ORG is required}"
: "${TARGET_ORG:?TARGET_ORG is required}"

API="https://api.github.com"
PER_PAGE=100

synced=0
failed=0
created=0

gh_api() {
  local method="$1" url="$2"
  shift 2

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    -X "$method" \
    -H "Authorization: token ${MIRROR_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@" \
    "$url" 2>/dev/null) || true

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "$body"
    return 0
  else
    echo "$body" >&2
    return 1
  fi
}

get_source_repos() {
  local page=1
  while true; do
    local result
    result=$(gh_api GET "${API}/orgs/${SOURCE_ORG}/repos?type=all&per_page=${PER_PAGE}&page=${page}") || break

    local count
    count=$(echo "$result" | jq 'length' 2>/dev/null) || break
    [[ -z "$count" || "$count" == "0" || "$count" == "null" ]] && break

    # Output: name description private default_branch
    echo "$result" | jq -r '.[] | "\(.name)\t\(.description // "")\t\(.private)\t\(.default_branch)"' 2>/dev/null
    (( page++ ))
  done
}

repo_exists_in_target() {
  local name="$1"
  gh_api GET "${API}/repos/${TARGET_ORG}/${name}" >/dev/null 2>&1
}

create_target_repo() {
  local name="$1" description="$2" private="$3"

  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg desc "Mirrored from ${SOURCE_ORG}/${name}" \
    --argjson private "$private" \
    '{name: $name, description: $desc, private: $private, has_issues: false, has_projects: false, has_wiki: false}')

  gh_api POST "${API}/orgs/${TARGET_ORG}/repos" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1
}

mirror_repo() {
  local name="$1" default_branch="$2"
  local tmpdir
  tmpdir=$(mktemp -d)
  local clonedir="${tmpdir}/${name}.git"

  # Bare clone from source
  local clone_output
  if ! clone_output=$(git clone --bare \
    "https://x-access-token:${MIRROR_TOKEN}@github.com/${SOURCE_ORG}/${name}.git" \
    "$clonedir" 2>&1); then
    echo "    failed: could not clone ${SOURCE_ORG}/${name}"
    echo "    ${clone_output}" | sed "s/${MIRROR_TOKEN}/***TOKEN***/g"
    rm -rf "$tmpdir"
    return 1
  fi

  # Push mirror to target (retry up to 3 times for newly created repos)
  cd "$clonedir" || return 1
  local push_output
  local attempt=0
  while (( attempt < 3 )); do
    if push_output=$(git push --mirror \
      "https://x-access-token:${MIRROR_TOKEN}@github.com/${TARGET_ORG}/${name}.git" 2>&1); then
      cd /
      rm -rf "$tmpdir"
      return 0
    fi
    attempt=$(( attempt + 1 ))
    if (( attempt < 3 )); then
      echo "    push attempt ${attempt} failed, retrying in 5s..."
      sleep 5
    fi
  done

  echo "    failed: could not push to ${TARGET_ORG}/${name}"
  echo "    ${push_output}" | sed "s/${MIRROR_TOKEN}/***TOKEN***/g"
  cd /
  rm -rf "$tmpdir"
  return 1
}

# ── main ─────────────────────────────────────────────────────────────────────

# Validate token has access
echo "Validating token..."
if ! gh_api GET "${API}/user" >/dev/null 2>&1; then
  echo "ERROR: MIRROR_TOKEN is invalid or lacks required permissions."
  exit 1
fi
echo "Token OK."
echo ""

echo "Fetching repos from ${SOURCE_ORG}..."
mapfile -t repo_lines < <(get_source_repos)
echo "Found ${#repo_lines[@]} repos."
echo ""

for line in "${repo_lines[@]}"; do
  [[ -z "$line" ]] && continue

  name=$(echo "$line" | cut -f1)
  description=$(echo "$line" | cut -f2)
  private=$(echo "$line" | cut -f3)
  default_branch=$(echo "$line" | cut -f4)

  [[ -z "$name" ]] && continue

  # Skip the mirror repo itself to avoid recursion
  [[ "$name" == "org-mirror" ]] && continue

  echo "Mirroring ${name}..."

  # Create in target org if it doesn't exist
  if ! repo_exists_in_target "$name"; then
    echo "  Creating ${TARGET_ORG}/${name}..."
    if create_target_repo "$name" "$description" "$private"; then
      created=$(( created + 1 ))
      # Wait for GitHub to initialize the repo before pushing
      sleep 5
    else
      echo "    failed: could not create repo"
      failed=$(( failed + 1 ))
      continue
    fi
  fi

  if mirror_repo "$name" "$default_branch"; then
    synced=$(( synced + 1 ))
    echo "  done."
  else
    failed=$(( failed + 1 ))
  fi
done

echo ""
echo "========================================"
echo "  Mirror complete: ${SOURCE_ORG} → ${TARGET_ORG}"
echo "  Repos synced:    ${synced}"
echo "  Repos created:   ${created}"
echo "  Repos failed:    ${failed}"
echo "========================================"

[[ "$failed" -gt 0 ]] && exit 1
exit 0
