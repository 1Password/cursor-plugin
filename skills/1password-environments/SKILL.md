---
name: 1password-environments
description: >-
  Canonical workflow for 1Password Developer Environments in Cursor via MCP.
  Use when creating, importing, migrating, or mounting .env files; managing repo
  secrets; listing Environment variable names; or calling any 1password MCP tool.
  Read this entire file once before the first MCP call in the turn.
---

# 1Password Environments

## Not done until

**Import / create from `.env`** (including "using values from the project `.env`"):

- [ ] Environment created or resolved
- [ ] Variables appended via `append_variables`
- [ ] `create_local_env_file` at the **source** `.env` absolute path
- [ ] Mount verified with `list_local_env_files`

Stopping after `create_environment` + `append_variables` is wrong. `list_variables` is not mount verification.

**Mount only:** mount exists at the requested path (`list_local_env_files`).

## Do not

- Read files under `mcps/**/tools/*.json` — call MCP tools directly
- Fetch `1password://docs/getting-started` or `environments-guide` — they omit import-and-mount; this skill is the workflow
- Read secret `.env` paths — parse with `grep`; templates (`.env.example`, etc.) may be Read
- Report success or offer "want me to mount?" before the import checklist is complete

## MCP tools

Parameters use camelCase (`accountId`, `environmentId`). Responses may use snake_case.

| Tool | Use |
|------|-----|
| `authenticate` | First call each turn; returns `accountId` |
| `list_environments` | Resolve Environment by name |
| `create_environment` | New empty Environment (import continues below) |
| `rename_environment` | Rename |
| `list_variables` | Names only — never values |
| `append_variables` | `{ name, value, concealed }` — secrets `concealed: true` |
| `list_local_env_files` | Check existing mounts |
| `create_local_env_file` | Mount at `mountPath` (macOS/Linux) |

## Import from a plain `.env` file

Default path: `{workspace_root}/.env` unless the user names another path.

1. **Plain file check:** `test -f "$path" && ! test -p "$path"`. If FIFO, use `list_local_env_files` instead of importing from disk.
2. **Parse** (do not Read the secret path):

   ```bash
   grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$path" | grep -v '^#'
   ```

   Strip optional quotes; pass values to MCP only — do not paste into chat.
3. **`authenticate`** → `accountId`
4. **`create_environment`** (new name) or **`list_environments`** (existing)
5. **`append_variables`** with all parsed variables
6. **Mount** (required unless user declined):
   - `list_local_env_files` — skip if mount already at path
   - `create_local_env_file` with `accountId`, `environmentId`, `environmentName`, `mountPath` (absolute source path)
   - `list_local_env_files` again to verify

If shell `grep` is blocked, see [reference.md](reference.md) (mount conflict).

## Other flows

**Mount existing Environment:** authenticate → resolve Environment → step 6 above.

**Inspect names:** authenticate → resolve → `list_variables` → summarize names only.

**Rename:** authenticate → resolve → confirm name → `rename_environment`.

**Add/update variables:** authenticate → resolve → `list_variables` → `append_variables`.

## Safety

- Never reveal secret values in chat
- Never Read mounted FIFO `.env` files — use MCP for mounts
- Ask before changing variables unless the request is explicit

## Troubleshooting

Mount conflict, validation modes, setup: [reference.md](reference.md)
