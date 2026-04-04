# Changelog

## v1.0.2 - 2026-04-04

- Added a dedicated Private Auras widget with layout defaults, menu controls, countdown options, and boss-frame support.
- Improved Midnight aura processing so secret spell data falls back safely for filtering, dispels, player-source checks, and totem displays.
- Fixed Midnight health and power bar updates so they no longer call `ResetSmoothedValue()` on secret min/max data and trigger `MathUtil.Clamp` errors.
- Hardened the cast bar against secret `startTime`, `endTime`, and empower hold values by falling back to duration objects whenever Lua time arithmetic is unsafe.
- Added `/cuf midnight` diagnostics to help verify Midnight restriction and private-aura API state in-game.
- Tested this release against `https://github.com/skyking-dev/Cell` and confirmed normal operation.

## v1.0.1 - 2026-04-01

- Fixed Midnight-safe target and target-of-target name rendering so secret names no longer disappear.
- Updated shared name and custom tag formatting to use the same secret-safe display path and cached non-secret fallback names when available.
- Reworked target aura caching and classification to keep Midnight secret auras, classify them with server-side filters when needed, and avoid Lua crashes on secret aura fields.
- Hardened target buff and debuff icon filtering and rendering against secret values; additional in-game validation is still pending for exact Midnight aura behavior.

## v1.0.0 - 2026-03-31

- Rebranded the project as `Cell_UnitFrame_Continued` for public fork distribution.
- Preserved original credit for Kristian Vollmer and documented fork attribution.
- Added publication notes for GitHub and addon-platform release setup.
- Updated Retail 12.x / Cell Midnight compatibility.
- Fixed tag handling, external anchors, dummy-anchor refresh behavior, and shield/power display issues introduced by modern API changes.
