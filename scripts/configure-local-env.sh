#!/bin/bash

# Turn the repository's ignored `.env` value into the ignored xcconfig file
# that Xcode understands. Xcode does not read `.env` by itself, so this tiny
# bridge keeps the developer setup explicit and easy to audit.

set -euo pipefail

SCRIPT_DIRECTORY=$(cd "$(dirname "$0")" && pwd)
REPOSITORY_DIRECTORY=$(cd "$SCRIPT_DIRECTORY/.." && pwd)
ENV_FILE="$REPOSITORY_DIRECTORY/.env"
OUTPUT_FILE="$REPOSITORY_DIRECTORY/Config/Secrets.xcconfig"

if [ ! -f "$ENV_FILE" ]; then
    echo "Missing .env. Copy .env.example to .env and add a newly rotated key."
    exit 1
fi

# Read only NEWS_API_KEY instead of `source`-ing the whole file. `source` would
# execute arbitrary shell text, while a settings reader should only read data.
KEY_LINE=$(grep -E '^[[:space:]]*NEWS_API_KEY[[:space:]]*=' "$ENV_FILE" | tail -n 1 || true)
API_KEY=${KEY_LINE#*=}

# Remove a Windows carriage return, surrounding whitespace, and one matching
# pair of quotes. This lets `NEWS_API_KEY=value` and `NEWS_API_KEY="value"` both
# behave as a beginner would reasonably expect.
API_KEY=$(printf '%s' "$API_KEY" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
case "$API_KEY" in
    \"*\") API_KEY=${API_KEY#\"}; API_KEY=${API_KEY%\"} ;;
    \'*\') API_KEY=${API_KEY#\'}; API_KEY=${API_KEY%\'} ;;
esac

if [ -z "$API_KEY" ] || [ "$API_KEY" = "replace_with_newly_rotated_key" ]; then
    echo "NEWS_API_KEY is empty or still an example. Add a newly rotated key to .env."
    exit 1
fi

# NewsAPI keys use simple token characters. Rejecting spaces, slashes, and
# punctuation prevents an accidental xcconfig directive from being smuggled in
# through the value. The key itself is deliberately never printed to the log.
case "$API_KEY" in
    *[!A-Za-z0-9_-]*)
        echo "NEWS_API_KEY contains unsupported characters. Expected letters, numbers, _ or -."
        exit 1
        ;;
esac

# `umask 077` makes the generated file readable and writable only by its owner.
# Writing a temporary file and renaming it avoids leaving a half-written secret
# if the command is interrupted at exactly the wrong moment.
umask 077
TEMPORARY_FILE=$(mktemp "$OUTPUT_FILE.tmp.XXXXXX")
trap 'rm -f "$TEMPORARY_FILE"' EXIT

printf '%s\n' \
    '// Generated from the ignored .env file. Never commit this file.' \
    "NEWS_API_KEY = $API_KEY" \
    > "$TEMPORARY_FILE"

mv "$TEMPORARY_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "Created Config/Secrets.xcconfig without printing the secret."
echo "The value is for local Debug builds only; do not mistake a bundled key for a production secret."
