# Credential remediation

The previously committed NewsAPI key must be treated as compromised.

During this upgrade, the local `origin` URL was also found to contain a GitHub
personal access token. The repository configuration has been changed back to the
credential-free `https://github.com/sachin6174/News-App.git` URL. Revoke that GitHub
token in **GitHub Settings → Developer settings → Personal access tokens**, then
use Git Credential Manager or SSH instead of embedding a token in a remote URL.

## Required now

1. Revoke the old key in the NewsAPI dashboard.
2. Revoke the exposed GitHub personal access token.
3. Generate a replacement NewsAPI key.
4. Add the replacement only as `NEWS_API_KEY` in an Xcode environment variable or
   secret CI setting.
5. Check `git status` before every commit. `Config/Secrets.xcconfig` must remain
   untracked.

Rotation is the security fix. History cleanup reduces accidental rediscovery, but
cannot make a credential safe after somebody may have copied it.

## Optional public-history cleanup

History rewriting changes commit IDs for every collaborator. Make a backup and
coordinate before running it. Use `git-filter-repo` to replace the exact old token
with a marker, verify with a secret scanner, then force-push using
`--force-with-lease`. Do not paste the old value into a shell-history command;
place the replacement rule in a temporary protected file instead.

After pushing, ask collaborators to make a fresh clone, clear cached forks where
possible, and confirm GitHub secret scanning shows no active credential. The old
key must remain revoked regardless of cleanup success.

## Reporting

Do not open a public issue containing a credential. Revoke it first and contact the
repository owner privately with only the file path and commit, not the key value.
