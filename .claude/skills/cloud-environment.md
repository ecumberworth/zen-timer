---
name: cloud-environment
description: Working in Claude Code cloud (remote/web) environments. Use when dealing with git, installing packages, network access, filesystem, or any environment-specific behavior in a cloud container session.
---

# Claude Code Cloud Environment Guide

This skill documents the quirks and constraints of Claude Code cloud (remote/web) container environments.

## Environment Detection

```bash
[ "$CLAUDE_CODE_REMOTE" = "true" ]  # Cloud environment
[ "$CCR_TEST_GITPROXY" = "1" ]      # Git proxy active
echo "$CLAUDE_CODE_BASE_REF"        # Base branch (typically "main")
```

## Filesystem

- Working directory: `/home/user/<repo-name>`
- Home directory: `/root`
- The container is Linux (Debian/Ubuntu-based), not macOS
- `/tmp` is writable and useful for downloading tools
- `~/.claude/` exists but does NOT persist across sessions — put skills and config in the repo's `.claude/` directory instead

## Network & Egress

All outbound HTTP/HTTPS goes through an egress proxy:

- **Proxy env vars:** `HTTP_PROXY`, `HTTPS_PROXY`, `GLOBAL_AGENT_HTTP_PROXY` — all set automatically
- The proxy uses a JWT for authentication and restricts traffic to an allowlist of hosts (package registries, GitHub, common dev sites)
- Direct internet access is blocked — all traffic must go through the proxy
- `localhost` and `127.0.0.1` bypass the proxy (`no_proxy` is set)

## Package Installation

- **apt:** `sudo apt update && sudo apt install <pkg>` — may fail if the package source isn't on the egress allowlist. GPG key fetches from third-party repos (e.g., GitHub CLI's apt repo) typically fail.
- **Direct binary downloads:** Preferred approach for CLI tools. Download tarballs from GitHub releases to `/tmp` and extract there.
- **pip/npm/cargo:** Generally work since pypi.org, registry.npmjs.org, crates.io are on the allowlist.

```bash
# Example: installing a CLI tool via direct download
curl -fsSL "https://github.com/<org>/<repo>/releases/download/<version>/<archive>.tar.gz" -o /tmp/tool.tar.gz
tar xzf /tmp/tool.tar.gz -C /tmp
export PATH="/tmp/<extracted-dir>/bin:$PATH"
```

## Git

### Git Proxy

Git uses a local proxy that handles GitHub authentication transparently:

- **Remote URL format:** `http://local_proxy@127.0.0.1:<port>/git/<owner>/<repo>`
- The proxy injects GitHub credentials for git protocol operations (push, pull, fetch, clone)
- No GitHub token needed for git commands
- The proxy ONLY supports git smart HTTP protocol — it does NOT serve GitHub REST/GraphQL API requests

```bash
git push -u origin <branch-name>     # Always use -u for tracking
git fetch origin <branch-name>       # Fetch specific branches
git pull origin <branch-name>
```

**Retry on network errors:** Up to 4 retries with exponential backoff (2s, 4s, 8s, 16s).

### Creating Pull Requests

The git proxy does NOT expose the GitHub API, and the environment does NOT have a GitHub API token. **Do not attempt to:**

- Use `gh pr create` (will fail with 401)
- Extract tokens from `GLOBAL_AGENT_HTTP_PROXY`, `CODESIGN_MCP_TOKEN`, or git credential helpers
- Call `api.github.com` directly (no auth available)

**Instead:** Push the branch and give the user a comparison URL:

```
https://github.com/<owner>/<repo>/compare/main...<branch-name>
```

The user can create the PR from the GitHub web UI.

### Branch Naming

Follow the pattern from task instructions, typically `claude/<description>-<session-id-suffix>`.

## MCP Services

- **Codesign MCP** runs on `127.0.0.1:$CODESIGN_MCP_PORT` — provides `sign_file` for git commit signing. Authenticated via `$CODESIGN_MCP_TOKEN`.
- This is the only MCP service available by default. It does NOT provide GitHub API access.

## Key Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_REMOTE` | `"true"` if in cloud environment |
| `CLAUDE_CODE_BASE_REF` | Base branch name (e.g., `"main"`) |
| `CCR_TEST_GITPROXY` | `"1"` if git proxy is active |
| `CODESIGN_MCP_PORT` | Port for code signing MCP service |
| `CODESIGN_MCP_TOKEN` | Auth token for codesign MCP |
| `IS_SANDBOX` | `"yes"` — commands run in a sandbox |
| `GIT_EDITOR` | Set to `"true"` to prevent interactive editors |
