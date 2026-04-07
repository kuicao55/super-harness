#!/usr/bin/env bash
# Version bump script for claude-codex-harness
# Usage: bump-version.sh <major|minor|patch>
#
# Reads current version from .claude-plugin/plugin.json,
# increments the specified component, and updates all files
# listed in .version-bump.json.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_JSON="${SCRIPT_DIR}/.claude-plugin/plugin.json"
BUMP_CONFIG="${SCRIPT_DIR}/.version-bump.json"

# Require argument
if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 1
fi

BUMP_TYPE="$1"

# Read current version
CURRENT_VERSION=$(python3 -c "
import json
with open('${PLUGIN_JSON}') as f:
    d = json.load(f)
print(d['version'])
")

echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -ra PARTS <<< "$CURRENT_VERSION"
MAJOR="${PARTS[0]}"
MINOR="${PARTS[1]}"
PATCH="${PARTS[2]}"

# Bump
case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Invalid bump type: $BUMP_TYPE. Must be major, minor, or patch."
    exit 1
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "New version: $NEW_VERSION"

# Update plugin.json
python3 -c "
import json
with open('${PLUGIN_JSON}') as f:
    d = json.load(f)
d['version'] = '${NEW_VERSION}'
with open('${PLUGIN_JSON}', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
echo "Updated: .claude-plugin/plugin.json"

# Update session-start hook
SESSION_START="${SCRIPT_DIR}/hooks/session-start"
if [[ -f "$SESSION_START" ]]; then
  sed -i.bak "s/v${CURRENT_VERSION}/v${NEW_VERSION}/g" "$SESSION_START"
  rm -f "${SESSION_START}.bak"
  echo "Updated: hooks/session-start"
fi

# Update README.md if it contains the version
README="${SCRIPT_DIR}/README.md"
if [[ -f "$README" ]] && grep -q "v${CURRENT_VERSION}" "$README"; then
  sed -i.bak "s/v${CURRENT_VERSION}/v${NEW_VERSION}/g" "$README"
  rm -f "${README}.bak"
  echo "Updated: README.md"
fi

echo ""
echo "Version bumped: $CURRENT_VERSION → $NEW_VERSION"
echo "Next step: git add -A && git commit -m \"chore: bump version to v$NEW_VERSION\""
