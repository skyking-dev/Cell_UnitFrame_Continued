# Midnight Migration Notes

`Cell_UnitFrame_Continued` keeps the original addon identity used by existing installs:

- addon folder: `Cell_UnitFrames`
- `.toc` file: `Cell_UnitFrames.toc`
- SavedVariables: `CUF_DB`

That means existing users can replace the addon files without renaming their folder or losing their current settings.

## Fork Compatibility Work

This continuation fork updates the addon for modern Retail 12.x builds and current Cell Midnight/Beta API behavior, including:

- compatibility fixes for recent Cell API changes
- Secret Value-safe handling for health, power, casts, and auras
- updates to tag formatting behavior
- support for external anchor targets
- dummy-anchor refresh improvements for migration from other unit frame setups

## Migration Expectation

For most users, migration should be a direct file replacement:

1. Remove the old `Cell_UnitFrames` addon folder.
2. Install the packaged release so the folder remains `Cell_UnitFrames`.
3. Launch WoW and verify the addon appears in the AddOns list.

If you used custom snippets, external frame anchors, or helper WeakAuras that reference frame names, review those integrations after updating.
