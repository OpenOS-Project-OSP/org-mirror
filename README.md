# org-mirror

Mirrors all repos from **OpenOS-Project-OSP** → **OpenOS-Project-Ecosystem-OOC**.

Runs daily at 01:30 UTC via GitHub Actions. Can also be triggered manually.

## Setup

1. Create a PAT with `repo` and `admin:org` scopes (access to both orgs)
2. Store it as `MIRROR_TOKEN` in this repo's Actions secrets
3. The workflow handles the rest: creates missing repos in OOC, then `git push --mirror`

## How it works

- Lists all repos in OSP via the GitHub API
- For each repo, checks if it exists in OOC — creates it if not
- Does a bare clone + `git push --mirror` to sync all branches, tags, and refs
- Skips the `org-mirror` repo itself to avoid recursion
