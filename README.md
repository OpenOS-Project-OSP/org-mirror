# org-mirror

[![AI agent ready](https://img.shields.io/badge/AI_agent-ready-2ea44f?style=flat-square)](https://github.com/Interested-Deving-1896/fork-sync-all/blob/main/DOCS/ai-agent-badges.md)
[![Open in Codex](https://img.shields.io/badge/Open_in-Codex-000000?style=flat-square&logo=openai&logoColor=white)](https://chatgpt.com/codex)
[![Open in Claude Code](https://img.shields.io/badge/Open_in-Claude_Code-d97757?style=flat-square&logo=anthropic&logoColor=white)](https://claude.ai/code)
[![Open in GitHub Copilot](https://img.shields.io/badge/Open_in-GitHub_Copilot-181717?style=flat-square&logo=githubcopilot&logoColor=white)](https://github.com/copilot)
[![Open in Cursor](https://img.shields.io/badge/Open_in-Cursor-111111?style=flat-square)](https://cursor.com/agents)
[![Use with Gemini CLI](https://img.shields.io/badge/Use_with-Gemini_CLI-4285f4?style=flat-square&logo=googlegemini&logoColor=white)](https://github.com/google-gemini/gemini-cli)
[![KDE Eco](https://img.shields.io/badge/KDE%20Eco-certified-brightgreen?logo=kde&logoColor=white&style=flat-square)](https://eco.kde.org/) [![Blue Angel](https://img.shields.io/badge/Blue%20Angel-DE--UZ%20215-0055a4?style=flat-square)](https://www.blauer-engel.de/en/certification/criteria)




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
