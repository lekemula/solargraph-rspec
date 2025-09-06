#!/usr/bin/env bash
# Credits: This file was originally copied and adapted from the log_bench gem.
# https://raw.githubusercontent.com/silva96/log_bench/refs/heads/main/release_gem.sh
set -euo pipefail

############################################
# Config — tweak if your gem/repo differs
############################################
GEM_NAME="solargraph-rspec"
LIB_DIR="lib/solargraph/rspec"
DEFAULT_BRANCH="main"
VERSION_FILE="${LIB_DIR}/version.rb"
GEMSPEC_FILE="${GEM_NAME}.gemspec"
TAG_PREFIX="v"

# Bump mode: patch | minor | major (default patch)
BUMP="${BUMP:-patch}"

############################################
# Arg parsing (optional)
############################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) BUMP="${2:-patch}"; shift 2 ;;
    --bump=*) BUMP="${1#*=}"; shift 1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--bump patch|minor|major]
Defaults to --bump patch (e.g., 0.2.6 -> 0.2.7).
EOF
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

case "$BUMP" in
  patch|minor|major) : ;;
  *) echo "Invalid --bump: $BUMP (use patch|minor|major)"; exit 1 ;;
esac

############################################
# Pretty logging
############################################
if command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ]; then
  BOLD=$(tput bold) || BOLD=""
  RESET=$(tput sgr0) || RESET=""
  GREEN=$(tput setaf 2) || GREEN=""
  YELLOW=$(tput setaf 3) || YELLOW=""
  RED=$(tput setaf 1) || RED=""
  BLUE=$(tput setaf 4) || BLUE=""
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; RED=""; BLUE=""
fi

log()     { printf "%b\n" "${BLUE}▸${RESET} $*"; }
success() { printf "%b\n" "${GREEN}✔${RESET} $*"; }
warn()    { printf "%b\n" "${YELLOW}⚠${RESET} $*"; }
error()   { printf "%b\n" "${RED}✖${RESET} $*"; }
die()     { error "$*"; exit 1; }

############################################
# Helpers
############################################
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

current_version() {
  # Extract the first X.Y.Z from the VERSION file
  grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' "$VERSION_FILE" | head -n1
}

validate_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

bump_version() {
  local mode="$1" ver="$2"
  IFS='.' read -r MA MI PA <<<"$ver"
  case "$mode" in
    patch) echo "${MA}.${MI}.$((PA+1))" ;;
    minor) echo "${MA}.$((MI+1)).0" ;;
    major) echo "$((MA+1)).0.0" ;;
  esac
}

update_version_file() {
  local new="$1"
  # Robust sed (preserves indentation, quote style, optional .freeze)
  sed -E "s/^([[:space:]]*)VERSION[[:space:]]*=[[:space:]]*(['\"])[0-9]+\.[0-9]+\.[0-9]+(['\"])(\.freeze)?/\1VERSION = \2${new}\3\4/" \
    "$VERSION_FILE" > "${VERSION_FILE}.tmp"
  mv "${VERSION_FILE}.tmp" "$VERSION_FILE"
}

ensure_clean_worktree() {
  if [ -n "$(git status --porcelain)" ]; then
    warn "Your working tree has uncommitted changes:"
    git status --short
    read -rp "$(printf '%b' "${YELLOW}Proceed anyway? [y/N] ${RESET}")" ans
    [[ "${ans:-}" =~ ^[Yy]$ ]] || die "Aborted due to dirty working tree."
  fi
}

############################################
# Checks
############################################
require_cmd git
require_cmd bundle
require_cmd gem
require_cmd sed

if ! command -v gh >/dev/null 2>&1; then
  warn "GitHub CLI (gh) not found. GitHub release creation will be skipped."
  GH_AVAILABLE="false"
else
  GH_AVAILABLE="true"
fi

[ -f "$VERSION_FILE" ] || die "Version file not found: $VERSION_FILE"
[ -f "$GEMSPEC_FILE" ] || die "Gemspec not found: $GEMSPEC_FILE"

############################################
# Start
############################################
log "${BOLD}Publishing ${GEM_NAME}${RESET}"
ensure_clean_worktree

log "Pulling latest from origin/${DEFAULT_BRANCH}…"
git checkout "$DEFAULT_BRANCH" >/dev/null 2>&1 || true
git pull origin "$DEFAULT_BRANCH"
success "Up to date."

CURR_VER="$(current_version)"
[ -n "$CURR_VER" ] || die "Could not determine current version from $VERSION_FILE"

log "Current version detected in ${VERSION_FILE}: ${BOLD}${CURR_VER}${RESET}"
PROPOSED="$(bump_version "$BUMP" "$CURR_VER")"
read -rp "$(printf '%b' "${BLUE}Proposed next ${BOLD}${BUMP}${RESET}${BLUE} version is ${BOLD}${PROPOSED}${RESET}${BLUE}. Press Enter to accept or type a different semver (X.Y.Z): ${RESET}")" NEW_VER
NEW_VER="${NEW_VER:-$PROPOSED}"
validate_semver "$NEW_VER" || die "Invalid semver: $NEW_VER"

TAG="${TAG_PREFIX}${NEW_VER}"

# Guard against existing tag
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  die "Tag ${TAG} already exists."
fi

log "Updating version file to ${BOLD}${NEW_VER}${RESET}…"
before_contents="$(cat "$VERSION_FILE")"
update_version_file "$NEW_VER"
after_contents="$(cat "$VERSION_FILE")"
if [ "$before_contents" = "$after_contents" ]; then
  AFTER_VER="$(current_version || true)"
  if [ "$AFTER_VER" = "$NEW_VER" ]; then
    warn "Version file already at ${NEW_VER}; nothing to change."
  else
    die "Failed to update ${VERSION_FILE}. Ensure it has a line like:
  VERSION = \"${CURR_VER}\"
(or with single quotes / optional .freeze)."
  fi
else
  success "Updated ${VERSION_FILE}."
fi

log "Installing gems (bundle install)…"
bundle install
success "Dependencies installed."

log "Committing version bump (including Gemfile.lock if changed)…"
FILES_TO_COMMIT=()
if ! git diff --quiet -- "$VERSION_FILE"; then
  FILES_TO_COMMIT+=("$VERSION_FILE")
fi
if [ -f "Gemfile.lock" ] && ! git diff --quiet -- "Gemfile.lock"; then
  FILES_TO_COMMIT+=("Gemfile.lock")
fi

if [ "${#FILES_TO_COMMIT[@]}" -gt 0 ]; then
  git add "${FILES_TO_COMMIT[@]}"
  git commit -m "Bump version to ${NEW_VER}"
  success "Committed: ${FILES_TO_COMMIT[*]}"
else
  warn "No changes to commit (version file and Gemfile.lock unchanged)."
fi

log "Creating tag ${BOLD}${TAG}${RESET}…"
git tag "${TAG}" -m "Release version ${NEW_VER}"
success "Tag created."

log "Pushing branch & tag to origin…"
git push origin "$DEFAULT_BRANCH"
git push origin "${TAG}"
success "Pushed."

if [ "$GH_AVAILABLE" = "true" ]; then
  log "Creating GitHub release ${BOLD}${TAG}${RESET} with auto-generated notes…"
  gh release create "${TAG}" --title "Release version ${NEW_VER}" --generate-notes || warn "Failed to create GitHub release via gh."
  success "GitHub release created."
else
  warn "Skipping GitHub release creation (gh not installed)."
fi

log "Building gem…"
gem build "$GEMSPEC_FILE"
GEM_FILE="${GEM_NAME}-${NEW_VER}.gem"
[ -f "$GEM_FILE" ] || die "Gem file not found after build: $GEM_FILE"
success "Built ${GEM_FILE}."

log "Pushing gem to RubyGems…"
gem push "$GEM_FILE"
success "Gem pushed to RubyGems."

success "${BOLD}${GEM_NAME} ${NEW_VER}${RESET} has been published! 🎉"
