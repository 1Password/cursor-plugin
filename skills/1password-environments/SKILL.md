---
name: 1password-environments
description: >-
  Manage 1Password Developer Environments via the bundled MCP server. Use when
  creating, importing, or mounting .env files; listing Environment variable names;
  adding or updating Environment variables; renaming environments; or calling any
  1Password MCP tool. On macOS/Linux, import-from-.env includes
  create_local_env_file at the source .env path unless the user opts out.
  On Windows, never mount — recommend op run --environment to the user.
  Mounted .env paths are FIFOs, not regular files — verify with list_local_env_files or test -p.
---

# 1Password Environments

Workflow for the 1Password MCP tools bundled with this plugin. Read this skill
before calling MCP tools — the MCP server's built-in docs cover tool basics but
omit import-and-mount steps. Conceptual background and edge cases:
[reference.md](reference.md).

## Prerequisites

- **macOS or Linux** with the 1Password desktop app installed (MCP, local `.env` mounts, and mount validation are not supported on Windows)
- **MCP Server** Labs experiment enabled in the desktop app (`onepassword://settings/labs`)
- Plugin installed (registers `1password-mcp` MCP config, this skill, and mount validation hooks together)

Setup details: [reference.md](reference.md)

## Windows

**Detect the platform before any workflow** (`user_info` OS, `C:\` paths, `OS=Windows_NT`,
etc.). On Windows, local `.env` mounts and the desktop MCP server are **not supported**.

**Hard stop:** do **not** call `create_local_env_file`, attempt mounting, or run mount-only
flows. Import is complete after `create_environment` (or resolve) + `append_variables`.

Recommend **1Password CLI environment injection** ([Load secrets into the environment](https://www.1password.dev/cli/secrets-environment-variables)).

Example to share:

```shell
op run --environment=<environmentId> -- <their-start-command>
```

Use the `environmentId` from the import response. Apps that read a `.env` file from disk need
this wrapper.

This section **overrides** mount steps below on Windows.

## Not done until

**Import / create from `.env`** (including "using values from the project `.env`"):

- [ ] Environment created or resolved
- [ ] Variables appended via `append_variables`
- [ ] `create_local_env_file` at the **source** `.env` absolute path — **always**
- [ ] Mount verified with `list_local_env_files`

Mounting at the source `.env` path is mandatory, not optional follow-up. The
**only** exception is the user explicitly opting out ("without mounting", "do not
mount", "skip the mount"). Never ask "want me to mount?" — just mount.

Stopping after `create_environment` + `append_variables` is **incomplete**.
`list_variables` is not mount verification. Do not report success until the mount
checklist is done.

**Mount only:** mount exists at the requested path (`list_local_env_files`).

On **Windows**, skip mount steps — see **Windows** above.

## Do not

- Attempt mounting or call `create_local_env_file` on **Windows**
- Skip `create_local_env_file` on import unless the user explicitly opted out
- Report success before the import checklist (including mount) is complete
- Offer mounting as optional follow-up — it is mandatory on import
- Call `create_environment` when `list_environments` already shows that name — ask the user first (see **Duplicate environment name**)
- Reveal secret values in chat
- Read a mounted `.env` path — once mounted, the path is a live FIFO (named pipe); use `list_variables` instead
- Verify a mount with regular-file checks (`test -f`, `[ -f ]`, `find -type f`, etc.) — mounts are FIFOs; use `list_local_env_files` or `test -p` instead. A failed `-f` check does not mean the mount is missing

## MCP tools

Discover tool schemas for `plugin-1password-1password` before invoking tools
(`GetMcpTools`, MCP tool descriptors, or equivalent).

Request params use **camelCase** (`accountId`, `environmentId`); responses may use
snake_case (`account_id`, `environment_id`). Pass every required param.

Non-obvious schema details:

- `create_local_env_file`: `mountPath` must be the **absolute** path of the source `.env` file (macOS/Linux)
- Environment-level tools may prompt the user for per-environment approval on first use

If MCP calls fail with authentication errors, call `authenticate`, then retry with
the returned account ID (use as `accountId` in subsequent calls).

## Resolve environment

After `authenticate` → `list_environments`:

1. Match `environmentName` exactly (case-sensitive) to get `environmentId`
2. If no match, ask the user for the correct name — do not guess
3. If multiple accounts/environments confuse the match, list names only and ask

## Duplicate environment name

Before **`create_environment`**, call **`list_environments`** and check whether the
target `environmentName` already exists.

If it does, **stop and ask the user** how they want to proceed. Offer options such as:

- **Use the existing environment** — skip `create_environment`; use its `environmentId` for later steps (`append_variables`, mount, etc.)
- **Use a different name** — wait for a new name from the user, then `create_environment`
- **Cancel** — do not create or modify anything

Do not silently choose one of these paths. Do not call `create_environment` with a
name that already exists unless the user has explicitly chosen a different name.

## Import from a `.env` file

Default path: `{workspace_root}/.env` unless the user names another path.

1. **Read** the `.env` file with the Read tool to get its keys and values. Strip optional surrounding quotes from values. Pass values to MCP only — never paste secret values into chat.
2. **`authenticate`** → `accountId`
3. **`list_environments`** — if the target name already exists, follow **Duplicate environment name** and wait for the user's choice. Otherwise **`create_environment`** (new name) or resolve the existing environment per the user's choice.
4. **`append_variables`** with all variables (see **Concealed variables**)
5. **Git-tracked `.env`** — **all platforms**, including Windows:
   - If the `.env` is **git-tracked**, stop and tell the user to delete it and commit that removal ([local `.env` file docs](https://www.1password.dev/environments/local-env-file.md)). On macOS/Linux, do not proceed to mount until this is done.
6. **Mount (macOS/Linux only)** — **always** (skip only if the user explicitly said not to mount; on **Windows**, skip entirely — see **Windows**):
   - `list_local_env_files` — skip `create_local_env_file` only if a mount already exists at the source path
   - `create_local_env_file` with `accountId`, `environmentId`, `environmentName`, `mountPath` (absolute path of the original `.env`)
   - `list_local_env_files` again to verify

If shell commands are blocked because 1Password expects a mount at the path, see
[reference.md](reference.md) (mount conflict).

## Other flows

**Create new Environment:** authenticate → `list_environments` → if the name exists, follow **Duplicate environment name** → `create_environment` only when the name is available or the user chose a different name.

**Mount existing Environment:** authenticate → resolve environment → steps 5–6 above (step 6 macOS/Linux only).

**Inspect names:** authenticate → resolve environment → `list_variables` → summarize names only.

**Rename:** authenticate → resolve environment → confirm name → `rename_environment`.

**Add/update variables:** authenticate → resolve environment → `list_variables` → `append_variables`.

## Concealed variables

When calling `append_variables`, set `concealed` per variable:

- Set `concealed: true` for API keys, tokens, passwords, private keys, and connection strings with credentials.
- Set `concealed: false` for ports, public URLs, feature flags, and non-sensitive config unless the user says otherwise.
- When unsure, default to `concealed: true`.

## Safety

- Never reveal secret values in chat
- Ask before changing variables unless the request is explicit

## Plugin hook

The plugin runs `validate-mounted-env-files` on `beforeShellExecution`. It blocks
shell commands when 1Password expects a mount that is missing, disabled, or not a
FIFO (for example a plain `.env` still on disk at the mount path). Reading the
`.env` with the Read tool is unaffected.

Validation modes and recovery steps: [reference.md](reference.md)

## Troubleshooting

Mount conflict, validation modes, setup: [reference.md](reference.md)
