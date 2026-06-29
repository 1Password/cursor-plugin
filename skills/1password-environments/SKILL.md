---
name: 1password-environments
description: >-
  Provides the canonical Cursor agent workflow for 1Password Developer Environments
  via MCP — supersedes the MCP server's getting-started and environments-guide
  resources, which omit import and mount steps. Use when the user asks to create,
  import, migrate, or mount plain .env files with 1Password, configure repo secrets,
  list Environment variable names, manage Developer Environments, or call any
  1Password MCP tool. Requires reading this skill in full before the first MCP call
  in a turn.
---

# 1Password Environments

**MUST:** Read this entire skill before calling any 1Password MCP tool.

This skill ships with the **1Password Cursor plugin** (hooks + MCP config + this skill). It is the **authoritative agent workflow** for Developer Environments in Cursor.

## Quick start

1. Read this skill (required before MCP calls).
2. **Route by intent:**
   - On-disk `.env` to import, migrate, or populate from → [Import from a plain-text `.env` file](#import-from-a-plain-text-env-file) (through mount).
   - Mount an existing Environment → [Mount 1Password as this repo's `.env`](#mount-1password-as-this-repos-env).
   - New empty Environment (name only) → [Create a new Environment](#create-a-new-environment).
   - Add or update specific variables → [Add or update variables](#add-or-update-variables).
   - Inspect names only → [Inspect variables](#inspect-variables).
3. Call `authenticate`, then proceed with the chosen flow.

## Gotchas

- **MCP built-in docs are incomplete.** The server may point to `1password://docs/getting-started` and `1password://docs/environments-guide`. Those cover tool basics only — not import or default mount. Follow **this skill**, not those resources alone.
- **Install the plugin, not MCP alone.** Manual MCP setup without the plugin leaves agents without this workflow.
- **"Create from `.env`" is an import.** Do not stop after `create_environment` and `append_variables`; finish with `create_local_env_file` unless the user declines.
- **Do not Read secret `.env` paths.** Parse with shell `grep`. Templates (`.env.example`, `.env.sample`, `.env.template`, `.env.dist`) may be read normally.

## MCP tools

| Tool | Description |
|------|-------------|
| `authenticate` | Authenticate with the 1Password desktop app; returns `accountId` |
| `list_environments` | List Developer Environments for an account |
| `create_environment` | Create a new Developer Environment |
| `rename_environment` | Rename an existing Developer Environment |
| `list_variables` | List variable names in an Environment (no values) |
| `append_variables` | Add or update Environment variables |
| `create_local_env_file` | Mount an Environment as a local `.env` file (macOS/Linux) |
| `list_local_env_files` | List existing local `.env` mounts for an Environment |

MCP tool parameters use camelCase (`accountId`, `environmentId`). Server responses may use snake_case (`account_id`).

## Common flows

### Authenticate and resolve an Environment

Run at the start of any turn unless you already hold both IDs.

1. Call `authenticate` (desktop app prompts for approval on first connection).
2. Store `accountId`. Call `list_environments` unless the user provided a current `environmentId`.
3. Pick the target Environment from the user's request; ask if ambiguous — do not guess.
4. Store `environmentId`.

### Mount 1Password as this repo's `.env`

1. Authenticate and resolve the Environment.
2. Path: workspace root + `/.env` when the user says "here", "this repo", or "this project"; otherwise use their path.
3. Follow step 6 of [Import from a plain-text `.env` file](#import-from-a-plain-text-env-file).

### Inspect variables

1. Authenticate and resolve the Environment.
2. Call `list_variables`. Summarize names only — never request or display values.

### Create a new Environment

For a **new empty Environment** only (name, no `.env` import).

1. Call `authenticate` and store `accountId`.
2. Confirm the name if not explicitly stated.
3. Call `create_environment` with `accountId` and the chosen name.
4. Store `environmentId`. If variables come from a file, switch to the import flow.

### Import from a plain-text `.env` file

For creating or populating an Environment from a **regular file** on disk (`.env`, `.env.local`, or "values from the project `.env`"). No MCP import tool — parse locally, then `append_variables`. **Mount at the source path by default** (step 6).

1. Confirm source path; migration includes create, append, and mount unless the user opts out.
2. Verify plain file: `test -f "$path" && ! test -p "$path"`. If FIFO, stop — use `list_local_env_files` instead.
3. Parse (do not Read secret paths):

   ```bash
   grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$path" | grep -v '^#'
   ```

   Strip optional quotes before MCP; do not paste raw output into chat.
4. `authenticate`, then `create_environment` or resolve an existing Environment.
5. `append_variables` with `{ "name", "value", "concealed" }` — `true` for secrets, `false` for non-sensitive config. Pass values to MCP only.
6. **Mount** at the source absolute path (required unless declined):
   - `list_local_env_files` — skip if mount already exists at path.
   - `create_local_env_file` with `accountId`, `environmentId`, `environmentName`, `mountPath`.
   - Verify with `list_local_env_files`, not by reading the mounted file.

**Import completion checklist:**

- [ ] Environment created or resolved
- [ ] Variables appended
- [ ] Mount created at source path (unless user declined)
- [ ] Mount verified with `list_local_env_files`

If shell parsing is blocked, see [reference.md](reference.md) (mount conflict and troubleshooting).

### Rename an Environment

1. Authenticate and resolve the Environment.
2. Confirm the new name if not stated.
3. Call `rename_environment` with `accountId`, `environmentId`, and the new name.

### Add or update variables

1. Confirm the user wants to create or update variables; collect missing names/values.
2. Authenticate and resolve the Environment.
3. `list_variables` to check existing names.
4. `append_variables` with `{ "name", "value", "concealed" }`.

## Safety

- Do not reveal, log, or echo secret values in chat.
- Do not Read secret `.env` paths or mounted FIFO `.env` files; use MCP tools for mounted files.
- Ask before creating or modifying variables unless the request is explicit ("import my `.env`", "add API_KEY to staging").
- If the user pasted a secret, refer to it by variable name only.

## Additional resources

- Mount conflict, validation modes, and setup troubleshooting: [reference.md](reference.md)
