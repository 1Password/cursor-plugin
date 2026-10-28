# Changelog

All notable changes to this plugin are documented here. A new entry is added when you push a release branch; see [Releasing](README.md#releasing).

## [1.3.0] - 2026-10-28

### Features
- Renamed the plugin's display name to "1Password Developer Tools". The install ID is still `1password`. (#21)
- MCP connections made through the plugin are now tagged as coming from the plugin. (#20)

### Fixes
- The validation hook now reads single-quoted and mixed-quote `mount_paths` values in `environments.toml`. Previously it ignored single-quoted paths. (#22)
- The validation hook no longer exits early on expected failures under `set -e`. (#18)
- On Linux, the hook now also finds the 1Password database when the file is named `1password.sqlite` in lowercase. (#16)

