# MCP-NixOS Integration

The MCP-NixOS server provides enhanced package and option validation. When configured, it lets
agents verify that a package name, option path, or version actually exists before writing it into
a configuration, instead of guessing from memory.

## Available Tools

```bash
# Search nixpkgs for a package
mcp__nixos__nix(action="search", query="pkgname", source="nixpkgs")

# Look up NixOS module options
mcp__nixos__nix(action="options", query="services.X", source="nixos-options")

# List available versions of a package
mcp__nixos__nix_versions(package="nodejs")
```

## Sources

| `source` value | Contents |
|----------------|----------|
| `nixpkgs` | Package attribute names, descriptions, metadata |
| `nixos-options` | NixOS module options with types, defaults, descriptions |
| `home-manager-options` | Home Manager module options |

## When to Use

- Before adding a package to `environment.systemPackages` or `home.packages` -- confirm the
  attribute name is spelled correctly and exists in the target channel.
- Before setting `services.*` or `programs.*` options -- confirm the option path exists and
  check its declared type and default.
- When pinning or mixing channels -- confirm which versions a package has available.

## Graceful Degradation

Agents gracefully degrade to WebSearch and CLI commands when MCP is unavailable. Equivalent
local fallbacks:

```bash
# Package search fallback
nix search nixpkgs pkgname

# Option lookup fallback (requires a built configuration)
nix eval .#nixosConfigurations.hostname.options.services.X.enable.type

# Option and package search on the web
# https://search.nixos.org/packages
# https://search.nixos.org/options
```

Never block on MCP unavailability -- fall back, and note in the research report which source was
used so a reviewer can judge how strongly the package or option name was verified.
