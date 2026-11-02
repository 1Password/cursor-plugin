# 1Password Environments — reference

Supplement to [SKILL.md](SKILL.md). Use for setup, mount conflicts, and shell
validation behavior.

## Plugin components

This plugin ships:

| Component | Path | Purpose |
|-----------|------|---------|
| MCP config | `mcp.json` | Connects Cursor to the 1Password desktop MCP server via `1password-mcp` (macOS/Linux) |
| Agent skill | `skills/1password-environments/SKILL.md` | Import, mount, and Environment management workflow |
| Mount validation hook | `hooks/hooks.json` → `scripts/validate-mounted-env-files` | Blocks shell when mounts are missing or misconfigured |

Install the plugin from the Cursor marketplace — do not add the MCP server
manually in user settings without the bundled skill and hooks.

## Official documentation

Fetch hosted docs when you need product context, security boundaries, or
edge cases beyond this plugin's workflow. Index:
[llms.txt](https://www.1password.dev/llms.txt)

| Topic | Doc |
|-------|-----|
| Local `.env` mounts (FIFO, git conflicts, dotenv compatibility) | [local-env-file.md](https://www.1password.dev/environments/local-env-file.md) |
| MCP server (setup, auth prompts, security model) | [mcp-server.md](https://www.1password.dev/environments/mcp-server.md) |
| Mount validation hook (canonical guide) | [agent-hook-validate.md](https://www.1password.dev/environments/agent-hook-validate.md) |

## Setup

**Requirements**

- **macOS or Linux** with the [1Password desktop app](https://1password.com/downloads) installed
- **1Password Cursor plugin installed** (marketplace or local symlink) so this skill, hooks, and MCP config load together
- **Integrate with MCP clients** turned on under **Settings > Developer** in the desktop app
- Access to a 1Password account with Developer Environments enabled
- `1password-mcp` on your `PATH` (registered by the desktop app when MCP is enabled)
- `sqlite3` in `PATH` for mount validation (pre-installed on macOS; install via your package manager on Linux)

On **Windows**, the validation hook is a no-op and MCP/local mounts are unavailable.

MCP server setup and platform details: [mcp-server.md](https://www.1password.dev/environments/mcp-server.md)

**When things fail**

- Authentication or environment access fails — the 1Password desktop app may need approval, unlocking, or account access
- MCP server unavailable — turn on **Integrate with MCP clients** under **Settings > Developer**. If the checkbox is missing, update 1Password; your account may not have the `ai-local-mcp-server` feature flag. If it is disabled by an administrator, ask your administrator to check **Policies > Sharing and permissions > Agentic permissions > Local MCP server** — see [mcp-server.md](https://www.1password.dev/environments/mcp-server.md)
- MCP server fails to start on macOS 27 Golden Gate (`MCP error -32000: Connection closed`, or `Failed to start logger: Log cannot be written` in the MCP logs) — macOS is blocking Cursor from 1Password app data. Ask the user to open **System Settings > Privacy & Security > Files & Folders**, select **Cursor**, turn on the setting that starts with **"Data shared by 1Password"**, then quit and reopen Cursor. Full Disk Access is not needed. Cursor appears in that list only after one failed connection attempt
- `create_local_env_file` fails — confirm the user is on macOS or Linux
- Shell commands denied while 1Password expects a mount that is missing or disabled — see **Mount conflict** below

## Mount validation hook

Canonical hook guide: [agent-hook-validate.md](https://www.1password.dev/environments/agent-hook-validate.md).
This plugin's hook adds repo-scoped validation via `.1password/environments.toml` (below).

`scripts/validate-mounted-env-files` runs on `beforeShellExecution`. It blocks
**all** shell commands when 1Password expects a mount at a path that is missing,
disabled, or not a FIFO (for example a plain `.env` still on disk at the mount
path). Reading the `.env` with the Read tool is unaffected — only shell commands
are gated.

The hook **fails open**: if 1Password is not installed, the database is
unavailable, or `sqlite3` is missing, shell commands proceed normally.

### Validation modes

Scope depends on `.1password/environments.toml` at the project root:

| Configuration | Behavior |
|---------------|----------|
| No TOML file (or no `mount_paths` field) | **Default mode** — all 1Password mount destinations for this workspace are validated |
| `mount_paths = [".env", ...]` | **Configured mode** — only listed paths are validated |
| `mount_paths = []` | Validation disabled for this repo; all shell commands allowed |

Example configured mode:

```toml
mount_paths = [".env", "billing.env"]
```

For each path, the hook checks that the file exists, is a FIFO (named pipe), and
is enabled in 1Password.

### Mount conflict

If shell commands are blocked with a message about missing, invalid, or disabled
environment files:

1. Check whether 1Password already has a destination for the same path (`list_local_env_files`, or the 1Password app Destinations tab)
2. Resolve by one of:
   - Temporarily set `mount_paths = []` in `.1password/environments.toml` to disable mount validation for this repo
   - Fix the mount in 1Password (enable the destination, or remove it until migration finishes)

The import itself does not need shell — Read the `.env` directly to get its keys
and values, then use MCP tools per [SKILL.md](SKILL.md).

### Debugging the hook

- **Cursor Settings → Hooks → Execution Log** — look for `beforeShellExecution` entries tied to `validate-mounted-env-files`
- **Debug run:** `DEBUG=1 echo '{"command": "echo test", "workspace_roots": ["/path/to/project"]}' | ./scripts/validate-mounted-env-files`
- **Log file:** `/tmp/1password-cursor-hooks.log` (when not in debug mode)
