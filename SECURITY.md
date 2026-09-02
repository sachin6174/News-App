# Credential remediation

The previously committed NewsAPI key must still be treated as compromised even
though it has now been removed from reachable public branch history.

During this upgrade, the local `origin` URL was also found to contain a GitHub
personal access token. The repository configuration has been changed back to the
credential-free `https://github.com/sachin6174/News-App.git` URL. Revoke that GitHub
token in **GitHub Settings → Developer settings → Personal access tokens**, then
use Git Credential Manager or SSH instead of embedding a token in a remote URL.

## Required now

1. Revoke the old key in the NewsAPI dashboard.
2. Revoke the exposed GitHub personal access token.
3. A replacement NewsAPI key has been generated; keep it only in ignored local or
   encrypted CI storage.
4. Add the replacement to the ignored `.env` for local development, run
   `scripts/configure-local-env.sh`, or use a secret CI setting. Never commit the
   generated `Config/Secrets.xcconfig`.
5. Check `git status` before every commit. `Config/Secrets.xcconfig` must remain
   untracked.

Rotation is the security fix. History cleanup reduces accidental rediscovery, but
cannot make a credential safe after somebody may have copied it.

## Completed public-history cleanup

On 2 September 2026, `master` and `codex/news-app-2-production` were rewritten to
remove the historical `News App/App/AppConstants.swift` path without copying its
secret value into a command or replacement file. Both branches were force-pushed
with leases tied to their inspected remote heads. A scan of every commit reachable
from the rewritten branches found zero credential-shaped source values.

Existing collaborators must make a fresh clone, and cached forks may retain the
old objects. The old key must remain revoked regardless of cleanup success.

## Reporting

Do not open a public issue containing a credential. Revoke it first and contact the
repository owner privately with only the file path and commit, not the key value.
