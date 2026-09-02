#!/bin/bash

# Fail CI if a credential-shaped value or a local-only secret file reaches Git.
# This script intentionally lives in one place so the Linux audit job and the
# macOS build job enforce exactly the same rule.

set -euo pipefail

# The search expressions are broad on purpose. They look for common GitHub
# tokens, the old Swift `apiKey = "..."` shape, and a populated xcconfig/.env
# assignment. `git grep` examines tracked files only, so the ignored developer
# `.env` is never opened and its value can never leak into CI output.
PATTERN='(github_pat_|ghp_[A-Za-z0-9]+|x-access-token:|api(Key|_key)[[:space:]]*=[[:space:]]*"[A-Za-z0-9_-]{20,}"|NEWS_API_KEY[[:space:]]*=[[:space:]]*[A-Za-z0-9_-]{20,})'

# The script contains the pattern as documentation, so it excludes itself from
# the search. Example/placeholder lines are filtered by their unmistakable words
# instead of weakening the real credential pattern.
MATCHES=$(git grep -n -I -E "$PATTERN" -- . ':!scripts/audit-tracked-secrets.sh' || true)
REAL_MATCHES=$(printf '%s\n' "$MATCHES" | grep -Eiv '(placeholder|paste_your|replace_with)' || true)

if [ -n "$REAL_MATCHES" ]; then
    echo "A credential-shaped value was found in tracked source:"
    printf '%s\n' "$REAL_MATCHES"
    exit 1
fi

# These files were the exact historical failure modes. The checks make a future
# accidental re-addition fail with a small, understandable error.
test ! -e Config/Secrets.xcconfig
test ! -e "News App/App/AppConstants.swift"
test ! -e "News App/Views/Main.storyboard"

echo "Tracked-source credential audit passed."
