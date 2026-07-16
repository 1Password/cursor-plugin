# 1Password Plugin for Cursor

The official [1Password](https://1password.com) plugin for [Cursor](https://cursor.com). It ships three pieces that work together: **hooks** that validate locally mounted `.env` files, an **agent skill** with the complete Developer Environment workflow, and **MCP configuration** for the 1Password desktop app server. Secret values stay in 1Password — the agent sees variable names and mount paths, not secret contents.

Install the **plugin** (not a hand-configured MCP entry alone). The bundled `1password-environments` skill is the authoritative agent workflow; the MCP server's built-in documentation resources cover tool basics only and omit import-and-mount steps.

For more on 1Password's developer tools, see the [1Password Developer Documentation](https://developer.1password.com).

## Requirements

- [1Password](https://1password.com) subscription
- [1Password desktop app](https://1password.com/downloads) on **macOS or Linux**
- [Cursor](https://cursor.com)

Additional requirements by feature:

- **Hooks** — [sqlite3](https://www.sqlite.org/) installed and available in your `PATH` (pre-installed on macOS; install via your package manager on Linux)
- **MCP** — 1Password Labs **MCP Server** experiment enabled in the desktop app (`onepassword://settings/labs`). If the setting is missing, your account may not have the `ai-local-mcp-server` feature flag. The plugin's `mcp.json` launches the `1password-mcp` command from your `PATH`, as described in the [1Password MCP server documentation](https://www.1password.dev/environments/mcp-server).

> **Platform support:** MCP, local `.env` mounts, and mount validation are supported on **macOS and Linux**. On **Windows**, the validation hook returns `allow` and skips checks so agent shells are not blocked; MCP and local mounts are not available. **`hooks.json`** invokes **`./scripts/validate-mounted-env-files`** with no extension. On macOS and Linux, that runs the Bash script. On Windows, the shell resolves **`validate-mounted-env-files.cmd`** via `PATHEXT`.

## Installation and Setup

### Step 1: Set up your Environments

Before using this plugin, you'll need to configure your secrets in 1Password:

1. [Create one or more Environments](https://developer.1password.com/docs/environments) in 1Password to store your project secrets.
2. [Configure locally mounted `.env` files](https://developer.1password.com/docs/environments/local-env-file) for them.

### Step 2: Install the plugin

Install from the [Cursor Marketplace](https://cursor.com/marketplace). This registers hooks, the `1password-environments` agent skill, and `mcp.json` together:

1. Open **Cursor Settings** > **Plugins**.
2. Search for **1password**.
3. Click **Install**.

Or use the command palette: `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) > **Plugins: Install Plugin** > search for `1password`.

Or install directly:

```
/add-plugin 1password
```

### Step 3: Enable MCP in 1Password (required for Environment management)

Enable the **MCP Server** experiment in the 1Password desktop app: open **Settings → Labs** (or use `onepassword://settings/labs`) and turn on **MCP Server**. The plugin's `mcp.json` connects Cursor to that server after this step.

The plugin registers the same MCP command 1Password documents for other clients:

```json
{
  "mcpServers": {
    "1password": {
      "command": "1password-mcp"
    }
  }
}
```

Install the 1Password desktop app on macOS or Linux so `1password-mcp` is available on your `PATH`. For platform-specific install paths and troubleshooting, see the [1Password MCP server documentation](https://www.1password.dev/environments/mcp-server).

## Features

### Hooks

#### Local `.env` File Validation (`beforeShellExecution`)

Validates locally mounted `.env` files from [1Password Environments](https://developer.1password.com/docs/environments) before any shell command executes. When required environment files are missing, disabled, or misconfigured, the hook blocks execution and surfaces actionable error messages so the Cursor Agent can guide you to a fix.

This hook was originally developed in the [1Password Agent Hooks](https://github.com/1Password/agent-hooks) repository. For the full setup guide, see [Validate local `.env` files with Cursor Agent](https://developer.1password.com/docs/environments/cursor-hook-validate/).

**How it works:**

Every time Cursor attempts to execute a shell command, the hook:

1. **Discovers** your configured [local `.env` files](https://developer.1password.com/docs/environments/local-env-file) by querying the 1Password database.
2. **Validates** that each file exists as a valid FIFO (named pipe) and is enabled in 1Password.
3. **Allows** command execution if all environment files are properly configured.
4. **Blocks** command execution and provides clear error messages when files are missing or disabled.

The hook uses a **"fail open"** approach: if 1Password is not installed, the database is unavailable, or `sqlite3` is missing, the hook allows execution to proceed. This prevents blocking development in environments where 1Password isn't set up.

##### Validation Modes

The hook supports two validation modes depending on whether a TOML configuration file is present.

**Default Mode**

When no `.1password/environments.toml` file exists in your project (or when the file exists but doesn't contain a `mount_paths` field), the hook automatically:

1. Detects your operating system (macOS or Linux).
2. Queries the 1Password database for all configured mount entries.
3. Filters to only the local `.env` files relevant to the current workspace.
4. Validates that each discovered file is enabled and exists as a valid FIFO.

**Configured Mode**

When a `.1password/environments.toml` file exists at your project root **and** contains a `mount_paths` field, only the specified files are validated:

```toml
# Validate only these specific files
mount_paths = [".env", "billing.env", "database.env"]
```

This gives you precise control over which files the hook checks. Configuration examples:


| Configuration                           | Behavior                                                                |
| --------------------------------------- | ----------------------------------------------------------------------- |
| `mount_paths = [".env"]`                | Only `.env` is validated                                                |
| `mount_paths = [".env", "billing.env"]` | Both files are validated                                                |
| `mount_paths = []`                      | Validation is disabled — all commands allowed                           |
| *(no TOML file)*                        | Default mode — all 1Password-mounted files in the project are validated |


Mount paths can be relative to the project root or absolute. Multi-line arrays are supported:

```toml
mount_paths = [
    ".env",
    "billing.env",
    "database.env",
]
```

For each file, the hook checks:

- **Exists** — the file is present on disk.
- **Is FIFO** — the file is a named pipe (how 1Password mounts secrets).
- **Is enabled** — the mount is turned on in the 1Password app.

##### Debugging

**Cursor Execution Log**

1. Open **Cursor Settings** > **Hooks** > **Execution Log**.
2. Look for `beforeShellExecution` entries tied to `validate-mounted-env-files`.
3. Each entry shows the hook's permission decision and any error messages.

**Manual Testing with Debug Mode**

Run the hook directly with `DEBUG=1` to see detailed output on stderr:

```bash
DEBUG=1 echo '{"command": "echo test", "workspace_roots": ["/path/to/your/project"]}' | ./scripts/validate-mounted-env-files
```

**Log File**

When not running in debug mode, the hook writes logs to `/tmp/1password-cursor-hooks.log`. Log entries include timestamps and details about 1Password queries, validation results, and permission decisions.

### MCP and agent skill

The plugin connects Cursor to the local 1Password MCP server and bundles the **`1password-environments`** skill (`skills/1password-environments/SKILL.md`). Agents should read that skill before calling MCP tools — it defines the complete workflow for importing a plain `.env` file, appending variables, and mounting at the source path. The MCP server's built-in docs cover tool basics but omit those import-and-mount steps.

See `skills/1password-environments/reference.md` for setup, mount conflicts, and shell validation details.

#### Example prompts

- "List my 1Password Environments"
- "Mount my staging Environment as `.env` in this repo"
- "What variables are in my production Environment?"
- "Create a new Environment called `my-app-dev`"
- "Create an Environment from my project `.env` file"
- "Import `.env` into 1Password and mount it here"
- "Add a placeholder for my OpenAI API key"

#### MCP tools

| Tool | Description |
|------|-------------|
| `authenticate` | Authenticate with the 1Password desktop app; returns `accountId` |
| `list_environments` | List Developer Environments for an account |
| `create_environment` | Create a new Developer Environment |
| `rename_environment` | Rename an existing Developer Environment |
| `list_variables` | List variable names in an Environment (no values) |
| `append_variables` | Add or update Environment variables |
| `create_local_env_file` | Mount an Environment as a local `.env` file |
| `list_local_env_files` | List existing local `.env` mounts for an Environment |

Confirm the MCP server is connected in **Cursor Settings → MCP** after installing the plugin and enabling the Labs experiment in 1Password.

## Plugin Structure

```
cursor-plugin/
├── .cursor-plugin/
│   └── plugin.json                    # Plugin manifest
├── hooks/
│   └── hooks.json                     # beforeShellExecution mount validation
├── skills/
│   └── 1password-environments/
│       ├── SKILL.md                   # Agent skill for MCP workflows
│       └── reference.md               # Setup, mount conflict, and troubleshooting
├── mcp.json                           # MCP server configuration
├── assets/
│   └── logo.svg                       # Plugin logo
├── scripts/
│   ├── lib/
│   │   └── telemetry.sh               # Opt-in telemetry helpers for the validation hook
│   ├── validate-mounted-env-files      # Bash hook (macOS / Linux)
│   └── validate-mounted-env-files.cmd  # Windows cmd wrapper returns allow (validation skipped)
├── LICENSE
└── README.md
```


## Telemetry

The validation hook emits **opt-in** telemetry so 1Password can understand plugin adoption and the prevalence of common failure modes (missing files, disabled mounts). Two event types are emitted:

- `agent_hook_execution` — fired once per hook invocation; carries the hook name, plugin version, client (`cursor`), bucketed duration, decision (`allow`/`deny`), reason for deny, validation mode (`default`/`configured`), and a count of mounts checked.
- `agent_hook_install` — fired once per `(hook_name, plugin_version)` on the first hook run after installation or upgrade; `install_method` is `plugin_marketplace`.

**Opt-in only.** Events are written only when the file `~/.config/1Password/telemetry-enabled` exists. The 1Password desktop app creates and removes this file based on your in-app telemetry preference (Settings → Manage Account → Data Usage). If the app has never run, or all accounts have opted out, no events are written.

**No PII.** Events contain hook name and version, client, decision, bucketed duration, mode, mount count, and a deny reason. No paths, file contents, environment names, or workspace paths are recorded.

**Fail-open.** Telemetry runs in a detached background subshell after the hook has returned its decision to Cursor. Any failure (missing helpers, disk full, permission denied) is silently swallowed — telemetry can never affect a hook decision.

**Where events are written.** Events are appended as JSON lines to `~/.config/1Password/data/hook-events/events.jsonl`. The 1Password desktop app periodically ingests this file and forwards events to 1Password's telemetry pipeline. Telemetry only fires on macOS and Linux; the Windows stub does not emit events.

**To disable.** Open the 1Password desktop app → Settings → Manage Account → Data Usage and turn off product telemetry.

## Resources

- [Validate local `.env` files with Cursor Agent](https://developer.1password.com/docs/environments/cursor-hook-validate/) — full setup guide on the 1Password Developer site
- [1Password MCP server documentation](https://www.1password.dev/environments/mcp-server)
- [1Password Agent Hooks](https://github.com/1Password/agent-hooks) — the original hooks repository this plugin is based on
- [1Password Environments](https://developer.1password.com/docs/environments) — documentation for 1Password's environment and secrets management
- [1Password Local `.env` Files](https://developer.1password.com/docs/environments/local-env-file) — how local `.env` file mounting works
- [Cursor Hooks Documentation](https://cursor.com/docs/agent/hooks) — how Cursor hooks work
- [Cursor Plugin Documentation](https://cursor.com/docs/plugins/building) — how to build and publish Cursor plugins

## License

[MIT](./LICENSE) — Copyright (c) 2026 1Password
