# 1Password Environments — reference

## Mount conflict (Read hook vs shell validation hook)

The Read hook denies `.env` reads; the `beforeShellExecution` hook blocks **all** shell commands when 1Password expects a mount at a path that is missing, disabled, or not a FIFO (for example a plain `.env` still on disk at the mount path). That is a policy deadlock: Read is denied, then shell is denied too.

Validation scope depends on `.1password/environments.toml`:

- No TOML file (or no `mount_paths` field) — default mode: all 1Password mount destinations for this workspace are validated.
- `mount_paths = [".env", ...]` — only listed paths are validated.
- `mount_paths = []` — validation disabled for this repo; all shell commands allowed.

If shell parsing fails with a message about missing, invalid, or disabled environment files:

1. Check whether 1Password already has a destination for the same path (`list_local_env_files`, or the 1Password app Destinations tab).
2. Run `test -p "$path"` — if false while 1Password lists that path, the file is plain text colliding with an expected mount.
3. Help the user pick a workaround:
   - Copy the source to a non-mount path and parse that copy (e.g. `cp .env .env.import` then `grep` `.env.import`).
   - Temporarily set `mount_paths = []` in `.1password/environments.toml` to disable mount validation for this repo.
   - Fix the mount in 1Password (enable the destination, or remove it until migration finishes).
   - Paste `KEY=value` lines into chat instead of parsing from disk.

If parsing via shell is blocked for other reasons, ask the user to paste `KEY=value` lines (without values in follow-up messages if they prefer).

## Setup and troubleshooting

**Requirements**

- macOS or Linux with the 1Password desktop app installed (local `.env` mounts are macOS/Linux only; on Windows the validation hook is a no-op).
- **1Password Cursor plugin installed** (marketplace or local symlink) so this skill, hooks, and MCP config load together.
- 1Password Labs **MCP Server** experiment enabled in the desktop app (`onepassword://settings/labs`).
- Access to a 1Password account with Developer Environments enabled.

The MCP server binary on macOS:

```text
/Applications/1Password.app/Contents/MacOS/1password-mcp
```

On Linux, see the [1Password MCP server documentation](https://www.1password.dev/environments/mcp-server) for the binary path on your platform.

**When things fail**

- Authentication or environment access fails — the 1Password desktop app may need approval, unlocking, or account access.
- MCP server unavailable — enable the **1Password Labs MCP Server** experiment via `onepassword://settings/labs`. If the Labs setting is missing, the account may not have the required `ai-local-mcp-server` feature flag.
- `create_local_env_file` fails — confirm the user is on macOS or Linux.
- Shell commands denied during a plain `.env` import — see **Mount conflict** above.
