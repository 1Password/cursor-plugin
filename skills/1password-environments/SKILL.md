---
name: 1password-environments
description: Use the local 1Password MCP server to work with secure project environment configuration, 1Password Developer Environments, environment variables, API keys, secrets, and local .env mounts. Use when the user asks to set up env vars for a repo, configure secrets, mount or create a local .env from 1Password, store API keys in 1Password, inspect 1Password Environment variable names, or work with the 1Password MCP server.
---

# 1Password Environments

Use the 1Password MCP server for all 1Password Developer Environment work.

This skill ships with the **1Password Cursor plugin**, which also runs two hooks: `deny-env-file-read` blocks Read on secret `.env` paths, and `validate-mounted-env-files` blocks shell commands when required local mounts are missing, disabled, or not FIFOs.

## Use When

- The user mentions 1Password Environments, 1Password Developer Environments, the 1Password MCP server, or local `.env` files from 1Password.
- The user asks to set up, mount, create, or sync a project `.env` file from a secret manager and 1Password is available.
- The user asks to configure repo environment variables, API keys, tokens, credentials, or secrets securely with 1Password.
- The user wants to list or compare Environment variable names without exposing secret values.

Do not use this skill for unrelated password-manager tasks or non-1Password secret stores. Use the **Import from a plain-text `.env` file** flow below when the user asks to migrate an existing on-disk `.env` into 1Password.

## Setup and troubleshooting

**Requirements**

- macOS or Linux with the 1Password desktop app installed (local `.env` mounts are macOS/Linux only; on Windows the validation hook is a no-op).
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
- Shell commands denied during a plain `.env` import — see **Mount conflict** under "Import from a plain-text `.env` file".

## MCP tools and resources

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

Documentation resources: `1password://docs/getting-started`, `1password://docs/environments-guide`. No resource templates are currently exposed.

## Workflow

1. Call `authenticate` first when you do not already have an account ID for this turn. The 1Password desktop app will ask the user to approve the connection.
2. Use `accountId` for subsequent calls. Server docs may spell the returned value as `account_id`; MCP tool calls use camelCase parameters such as `accountId` and `environmentId`.
3. Call `list_environments` with the returned `accountId` before operating on an Environment, unless the user already provided a current `environmentId`.
4. If the target Environment is ambiguous, ask the user which Environment to use instead of guessing.
5. Use the `environmentId` returned by the server for environment-level calls.
6. Prefer `list_variables` when the user wants to inspect an Environment. It returns names only, not secret values.
7. Use `append_variables` only when the user explicitly asks to add or update variables, or as part of the **Import from a plain-text `.env` file** flow.
8. Use `create_local_env_file` for local `.env` mounts. When importing from an on-disk `.env`, default `mountPath` to that file's absolute path unless the user explicitly asked not to mount. Full mount steps are in the import flow below.

## Common Flows

### Authenticate and resolve an Environment

Most operations start here. Run this sequence at the beginning of any turn unless you already hold both IDs.

1. Call `authenticate`. The 1Password desktop app will prompt the user for approval on first connection.
2. Store the returned `accountId`.
3. Call `list_environments` with `accountId`.
4. If the target Environment is unambiguous from the user's request, use it. Otherwise, ask the user to choose — do not guess.
5. Store the returned `environmentId`.

### Mount 1Password as this repo's `.env`

1. Authenticate and resolve the Environment (see above).
2. If the user says "here", "this repo", or "this project", derive the absolute path by appending `/.env` to the current workspace root. Otherwise use the path they gave.
3. Follow the **Create a local file mount** steps in "Import from a plain-text `.env` file" (step 6), using that path as `mountPath`.

### Inspect variables

1. Authenticate and resolve the Environment (see above).
2. Call `list_variables`. Summarize the returned variable names only — do not request or display values.

### Create a new Environment

1. Call `authenticate` and store `accountId`.
2. Confirm the intended name with the user if it was not explicitly stated.
3. Call `create_environment` with `accountId` and the chosen name.
4. Store the `environmentId` from the response for any follow-on operations.
5. If the user wants to add variables immediately, proceed to the "Add or update variables" flow.

### Import from a plain-text `.env` file

Use when the user asks to create or populate a 1Password Environment from an existing **regular file** on disk (for example `.env` or `.env.local`). There is no MCP "import from file" tool — variables must be parsed locally, then sent with `append_variables`. Unless the user explicitly declines, finish by mounting at the source path (step 6).

1. Confirm the source path and that the user wants to migrate variables into 1Password. That confirmation covers creating the Environment, appending variables, and mounting unless they opt out of mounting.
2. Verify the source is a regular file, not a 1Password mount:
   - Run `test -f "$path" && ! test -p "$path"` in the shell.
   - If the path is a named pipe (FIFO), stop. That path is a 1Password mount — use `list_local_env_files` and MCP tools instead.
3. **Do not use the Read tool on secret `.env` paths.** This plugin's `deny-env-file-read` hook denies Read on `.env` and `.env.*` files (templates such as `.env.example`, `.env.sample`, `.env.template`, and `.env.dist` are allowed). Parse plaintext sources with a shell command instead:

   ```bash
   grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$path" | grep -v '^#'
   ```

   Strip optional surrounding quotes from values in your head before calling MCP; do not paste raw output into chat.
4. Call `authenticate`, then `create_environment` (or resolve an existing Environment if the user named one).
5. Call `append_variables` with the parsed name/value pairs. Pass values to MCP only — do not echo secret values in chat. Use `{ "name": "...", "value": "...", "concealed": true }` for secrets and `concealed: false` for non-sensitive values such as URLs or feature flags.
6. **Create a local file mount** at the source file's absolute path (required unless the user explicitly declined):
   - Resolve the absolute path to the original `.env` file (for example workspace root + `/.env`).
   - Call `list_local_env_files` with `accountId` and `environmentId` to check for an existing mount at that path.
   - If no duplicate exists, call `create_local_env_file` with `accountId`, `environmentId`, `environmentName`, and `mountPath` set to that absolute path.
   - Report the mount path and Environment name. Verify with `list_local_env_files`, not by reading the mounted file.
   - If a temporary copy was used for parsing (see **Mount conflict** below), the mount still targets the original `.env` path; suggest removing or gitignoring the temporary copy after the mount succeeds.

**Mount conflict (Read hook vs shell validation hook).** The Read hook denies `.env` reads; the `beforeShellExecution` hook blocks **all** shell commands when 1Password expects a mount at a path that is missing, disabled, or not a FIFO (for example a plain `.env` still on disk at the mount path). That is a policy deadlock: Read is denied, then shell is denied too.

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

### Rename an Environment

1. Authenticate and resolve the Environment (see above).
2. Confirm the new name with the user if it was not explicitly stated.
3. Call `rename_environment` with `accountId`, `environmentId`, and the new name.

### Add or update variables

1. Confirm the user explicitly wants to create or update variables, and collect any missing names or values before proceeding.
2. Authenticate and resolve the Environment (see above).
3. Call `list_variables` first to identify whether the requested variable names already exist.
4. Call `append_variables` with structured objects: `{ "name": "API_KEY", "value": "...", "concealed": true }` for secrets and `concealed: false` for non-sensitive values such as URLs or feature flags.

## Safety

- Do not reveal, log, or echo secret values in chat.
- Do not use the Read tool on secret `.env` paths — parse plaintext sources via shell when migrating into 1Password. Template files (`.env.example`, `.env.sample`, `.env.template`, `.env.dist`) may be read normally.
- Do not read a **mounted** `.env` file (1Password FIFO) for any reason; use MCP tools instead.
- Ask before creating or modifying Environment variables unless the user's request is already explicit (including "import my `.env`" or "add API_KEY to staging").
- Treat local `.env` mounts as sensitive even though 1Password does not persist plaintext secret contents to disk.
- If a user pasted a secret into the chat, avoid repeating it back; refer to it by variable name.
