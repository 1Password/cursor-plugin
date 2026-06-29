---
name: 1password-environments
description: Use the local 1Password MCP server to work with secure project environment configuration, 1Password Developer Environments, environment variables, API keys, secrets, and local .env mounts. Use when the user asks to set up env vars for a repo, configure secrets, mount or create a local .env from 1Password, store API keys in 1Password, inspect 1Password Environment variable names, or work with the 1Password MCP server.
---

# 1Password Environments

Use the 1Password MCP server for all 1Password Developer Environment work.

## Use When

- The user mentions 1Password Environments, 1Password Developer Environments, the 1Password MCP server, or local `.env` files from 1Password.
- The user asks to set up, mount, create, or sync a project `.env` file from a secret manager and 1Password is available.
- The user asks to configure repo environment variables, API keys, tokens, credentials, or secrets securely with 1Password.
- The user wants to list or compare Environment variable names without exposing secret values.

Do not use this skill for unrelated password-manager tasks or non-1Password secret stores. Use the **Import from a plain-text `.env` file** flow below when the user asks to migrate an existing on-disk `.env` into 1Password.

## Prerequisites

- macOS or Linux with the 1Password desktop app installed.
- 1Password Labs MCP server experiment enabled in the desktop app (`onepassword://settings/labs`).
- Access to a 1Password account with Developer Environments enabled.

The MCP server binary is at:

```text
/Applications/1Password.app/Contents/MacOS/1password-mcp
```

On Linux, see the [1Password MCP server documentation](https://www.1password.dev/environments/mcp-server) for the binary path on your platform.

If the MCP server is unavailable, direct the user to enable the **1Password Labs MCP Server** experiment in the desktop app. If the Labs setting is missing, the account may not have the required `ai-local-mcp-server` feature flag.

## MCP Contents

The local server exposes these tools:

- `authenticate`
- `list_environments`
- `create_environment`
- `rename_environment`
- `list_variables`
- `append_variables`
- `create_local_env_file`
- `list_local_env_files`

The local server also exposes documentation resources:

- `1password://docs/getting-started`
- `1password://docs/environments-guide`

No resource templates are currently exposed.

## Workflow

1. Call `authenticate` first when you do not already have an account ID for this turn. The 1Password desktop app will ask the user to approve the connection.
2. Use `accountId` for subsequent calls. Server docs may spell the returned value as `account_id`; MCP tool calls use camelCase parameters such as `accountId` and `environmentId`.
3. Call `list_environments` with the returned `accountId` before operating on an Environment, unless the user already provided a current `environmentId`.
4. If the target Environment is ambiguous, ask the user which Environment to use instead of guessing.
5. Use the `environmentId` returned by the server for environment-level calls.
6. Prefer `list_variables` when the user wants to inspect an Environment. It returns names only, not secret values.
7. Use `append_variables` only when the user explicitly asks to add or update variables.
8. Use `create_local_env_file` for local `.env` mounts on macOS or Linux, and pass the absolute `mountPath` the user wants.
9. Use `list_local_env_files` to check existing local mounts before creating a duplicate.

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
2. Call `list_local_env_files` with `accountId` and `environmentId` to check for an existing mount at the target path.
3. If the user says "here", "this repo", or "this project", derive the absolute path by appending `/.env` to the current workspace root.
4. If no duplicate exists, call `create_local_env_file` with `accountId`, `environmentId`, `environmentName`, and the absolute `mountPath`.
5. Report the mount path and Environment name. Do not read the mounted `.env` file to verify it — use `list_local_env_files` instead.

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

Use when the user asks to create a new 1Password Environment from an existing **regular file** on disk (for example `.env` or `.env.local`). There is no MCP "import from file" tool — variables must be parsed locally, then sent with `append_variables`.

1. Confirm the source path and that the user wants to migrate variables into 1Password.
2. Verify the source is a regular file, not a 1Password mount:
   - Run `test -f "$path" && ! test -p "$path"` in the shell.
   - If the path is a named pipe (FIFO), stop. That path is a 1Password mount — use `list_local_env_files` and MCP tools instead. Never read a mounted `.env`.
3. **Do not use the Read tool on `.env` paths.** Cursor treats env files as sensitive and the Read tool often blocks or appears to hang (waiting for approval that may not render). Parse the file with a shell command instead:

   ```bash
   grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$path" | grep -v '^#'
   ```

   Strip optional surrounding quotes from values in your head before calling MCP; do not paste raw output into chat.
4. Call `authenticate`, then `create_environment` (or resolve an existing Environment if the user named one).
5. Call `append_variables` with the parsed name/value pairs. Pass values to MCP only — do not echo secret values in chat. Mark secrets with `concealed: true`.
6. Optionally offer `create_local_env_file` to replace the plaintext file with a 1Password mount, and suggest removing or gitignoring the old plaintext source.

If parsing via shell is blocked, ask the user to paste `KEY=value` lines (without values in follow-up messages if they prefer), or to confirm approval if Cursor shows "Waiting for approval" on a file read.

### Rename an Environment

1. Authenticate and resolve the Environment (see above).
2. Confirm the new name with the user if it was not explicitly stated.
3. Call `rename_environment` with `accountId`, `environmentId`, and the new name.

### Add or update variables

1. Confirm the user explicitly wants to create or update variables, and collect any missing names or values before proceeding.
2. Authenticate and resolve the Environment (see above).
3. Call `list_variables` first to identify whether the requested variable names already exist.
4. Call `append_variables` using the active MCP tool schema exactly as exposed in the current session.
5. When the active schema accepts structured variable objects, use `{ "name": "API_KEY", "value": "...", "concealed": true }` for secrets and `concealed: false` only for non-sensitive values such as URLs or feature flags.
6. When the active schema exposes `variables` as `string[]`, do not send unsupported object fields. Use the string format required by that schema, and ask for clarification if the user's requested variable format is ambiguous.

## Tools

- `authenticate`: Authenticate with the 1Password desktop app and return the account ID.
- `list_environments`: List Developer Environments for an account.
- `create_environment`: Create a new Developer Environment.
- `rename_environment`: Rename an existing Developer Environment.
- `list_variables`: List variable names in an Environment without returning values.
- `append_variables`: Add or update Environment variables.
- `create_local_env_file`: Mount an Environment as a local `.env` file on macOS or Linux.
- `list_local_env_files`: List local `.env` mounts for an Environment.

## Error Handling

- If authentication or environment access fails, tell the user the 1Password desktop app may need approval, unlocking, or account access.
- If the MCP server is unavailable, tell the user to enable the 1Password Labs MCP Server experiment in the desktop app via `onepassword://settings/labs`.
- If the Labs setting is missing, the account may not have the required `ai-local-mcp-server` feature flag.
- If `create_local_env_file` fails, confirm the user is on macOS or Linux. Local `.env` mounts are documented for macOS and Linux only.
- If the agent appears stuck while "reading" a `.env` file, Cursor is likely waiting on sensitive-file approval that never renders. The plugin's Read hooks deny `.env` reads (plain files and FIFO mounts) and redirect to shell parsing — if you still see a hang, scroll up for a hidden approval card or send a follow-up message to unblock.

## Safety

- Do not reveal, log, or echo secret values in chat.
- Do not use the Read tool on `.env` paths — parse plain-text sources via shell when migrating into 1Password.
- Do not read a **mounted** `.env` file (1Password FIFO) for any reason; use MCP tools instead.
- Ask before creating or modifying Environment variables unless the user's request is already explicit.
- Treat local `.env` mounts as sensitive even though 1Password does not persist plaintext secret contents to disk.
- If a user pasted a secret into the chat, avoid repeating it back; refer to it by variable name.

## Notes

The local MCP server is enabled from 1Password Labs in the desktop app and connects through the bundled `1password-mcp` binary. Local `.env` mounts are supported on macOS and Linux.
