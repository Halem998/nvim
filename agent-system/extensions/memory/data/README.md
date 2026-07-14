# Data Directory

Extension data directories for user-created content.

## Contents

- [.memory/](.memory/README.md) - Obsidian-compatible memory vault

## Data Handling

Data directories use merge-copy semantics:
- On extension load: Skeleton files are copied only if they don't exist
- On extension unload: Only skeleton files are removed, user content is preserved

## Navigation

- [Parent Directory](../README.md)
