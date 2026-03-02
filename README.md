# 1Password Plugin for Cursor

The official [1Password](https://1password.com) plugin for [Cursor](https://cursor.com). It brings 1Password's secret management capabilities directly into your editor, helping you develop securely without leaving your workflow.

For more on 1Password's developer tools, see the [1Password Developer Documentation](https://developer.1password.com).

## Requirements

- [1Password](https://1password.com) subscription
- [1Password for Mac or Linux](https://1password.com/downloads)
- [Cursor](https://cursor.com)
- [sqlite3](https://www.sqlite.org/) installed and available in your `PATH` (pre-installed on macOS; install via your package manager on Linux)

> **Note:** [Local `.env` files](https://developer.1password.com/docs/environments/local-env-file) from 1Password Environments are only available on macOS and Linux. Windows is not yet supported — Cursor will automatically skip validations on Windows.

## Installation and Setup

### Step 1: Set up your Environments

Before using this plugin, you'll need to configure your secrets in 1Password:

1. [Create one or more Environments](https://developer.1password.com/docs/environments) in 1Password to store your project secrets.
2. [Configure locally mounted `.env` files](https://developer.1password.com/docs/environments/local-env-file) for them.

### Step 2: Install the plugin

Install from the [Cursor Marketplace](https://cursor.com/marketplace):

1. Open **Cursor Settings** > **Plugins**.
2. Search for **1password**.
3. Click **Install**.

Or use the command palette: `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) > **Plugins: Install Plugin** > search for `1password`.

## Features

### Hooks

#### Local `.env` File Validation (`beforeShellExecution`)

Validates locally mounted `.env` files from [1Password Environments](https://developer.1password.com/docs/environments) before any shell command executes. When required environment files are missing, disabled, or misconfigured, the hook blocks execution and surfaces actionable error messages so the Cursor Agent can guide you to a fix.

This hook was originally developed in the [1Password Cursor Hooks](https://github.com/1Password/cursor-hooks) repository. For the full setup guide, see [Validate local `.env` files with Cursor Agent](https://developer.1password.com/docs/environments/cursor-hook-validate/).

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
2. Look for `beforeShellExecution` entries tied to `validate-mounted-env-files.sh`.
3. Each entry shows the hook's permission decision and any error messages.

**Manual Testing with Debug Mode**

Run the hook directly with `DEBUG=1` to see detailed output on stderr:

```bash
DEBUG=1 echo '{"command": "echo test", "workspace_roots": ["/path/to/your/project"]}' | ./scripts/validate-mounted-env-files.sh
```

**Log File**

When not running in debug mode, the hook writes logs to `/tmp/1password-cursor-hooks.log`. Log entries include timestamps and details about 1Password queries, validation results, and permission decisions.

## Plugin Structure

```
1password/
├── .cursor-plugin/
│   └── plugin.json                    # Plugin manifest
├── hooks/
│   └── hooks.json                     # Hook event configuration
├── assets/
│   └── logo.svg                       # Plugin logo
├── scripts/
│   └── validate-mounted-env-files.sh  # Validation hook script
├── LICENSE
└── README.md
```

## Resources

- [Validate local `.env` files with Cursor Agent](https://developer.1password.com/docs/environments/cursor-hook-validate/) — full setup guide on the 1Password Developer site
- [1Password Cursor Hooks](https://github.com/1Password/cursor-hooks) — the original hooks repository this plugin is based on
- [1Password Environments](https://developer.1password.com/docs/environments) — documentation for 1Password's environment and secrets management
- [1Password Local `.env` Files](https://developer.1password.com/docs/environments/local-env-file) — how local `.env` file mounting works
- [Cursor Hooks Documentation](https://cursor.com/docs/agent/hooks) — how Cursor hooks work
- [Cursor Plugin Documentation](https://cursor.com/docs/plugins/building) — how to build and publish Cursor plugins

## License

[MIT](./LICENSE) — Copyright (c) 2026 1Password