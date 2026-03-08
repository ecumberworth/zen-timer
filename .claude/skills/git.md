---
name: git
description: Git operations in Claude Code remote environments. Use when pushing, pulling, creating branches, or creating PRs. Covers the git proxy, authentication, and GitHub API access patterns.
---

# Git in Claude Code Remote Environments

## Remote Git Proxy

In Claude Code remote (web) environments, git uses a local proxy:

- **Remote URL format:** `http://local_proxy@127.0.0.1:<port>/git/<owner>/<repo>`
- The proxy handles GitHub authentication transparently for git operations (push, pull, fetch, clone)
- You do NOT need a GitHub token for git commands — the proxy injects credentials automatically
- The proxy ONLY supports git smart HTTP protocol — it cannot serve GitHub REST API requests

## Git Operations

```bash
# Push (always use -u to set upstream tracking)
git push -u origin <branch-name>

# Fetch a specific branch
git fetch origin <branch-name>

# Pull
git pull origin <branch-name>
```

**Retry on network errors:** Up to 4 retries with exponential backoff (2s, 4s, 8s, 16s).

## Creating Pull Requests

The git proxy does NOT expose the GitHub API. To create PRs, use `gh` CLI:

### Installing gh (if not available)

```bash
# Download binary directly (apt/brew may not work in sandboxed environments)
curl -fsSL "https://github.com/cli/cli/releases/download/v2.62.0/gh_2.62.0_linux_amd64.tar.gz" -o /tmp/gh.tar.gz
tar xzf /tmp/gh.tar.gz -C /tmp
export PATH="/tmp/gh_2.62.0_linux_amd64/bin:$PATH"
```

### Authentication

The remote environment does NOT have a GitHub API token by default. The git proxy only handles git protocol auth. To create PRs:

1. **Check if `gh` is already authenticated:** `gh auth status`
2. **If not**, you cannot create PRs programmatically from this environment. Instead:
   - Push the branch to the remote
   - Inform the user the branch is pushed and provide the comparison URL:
     `https://github.com/<owner>/<repo>/compare/main...<branch-name>`
   - The user can create the PR from the GitHub web UI

### Key gotchas

- `gh` requires a GitHub token (`GH_TOKEN` or `gh auth login`) — the git proxy credentials do NOT work for API calls
- The egress proxy JWT (`GLOBAL_AGENT_HTTP_PROXY`) authenticates outbound HTTP but is NOT a GitHub token
- The `CODESIGN_MCP_TOKEN` is for the code signing MCP service, not GitHub
- Do NOT waste time trying to extract GitHub API tokens from git credential helpers or proxy URLs — they don't contain one

## Branch Naming

Branches created for Claude Code sessions should follow the pattern specified in the task instructions (typically `claude/<description>-<session-id-suffix>`).

## Environment Detection

```bash
# Check if in Claude Code remote environment
[ "$CLAUDE_CODE_REMOTE" = "true" ]

# Check if git proxy is active
[ "$CCR_TEST_GITPROXY" = "1" ]

# Get the base branch
echo "$CLAUDE_CODE_BASE_REF"  # typically "main"
```
