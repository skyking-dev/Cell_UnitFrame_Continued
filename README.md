# Cell_UnitFrame_Continued

Community-maintained continuation fork of the original **Cell Unit Frames** addon for **[Cell](https://www.curseforge.com/wow/addons/cell)**.

This fork exists because the original project is no longer being updated. The goal is to keep the addon working on modern Retail builds, including the current Cell Midnight/Beta API changes, while preserving the existing addon identity used by current users.

## Project Status

- Active continuation fork for Retail 12.x and current Cell builds
- Keeps the legacy compatibility id/folder as `Cell_UnitFrames`
- Keeps the SavedVariables name as `CUF_DB`
- Focuses on compatibility, maintenance, and practical QoL improvements

This is a continuation fork, not an official upstream release endorsed by the original author.

## Installation

Download the packaged addon from the GitHub **Releases** page for this repository.

Install this addon into:

- `World of Warcraft/_retail_/Interface/AddOns/Cell_UnitFrames`

Important:

- the folder inside `AddOns` must stay `Cell_UnitFrames`
- the `.toc` file must remain `Cell_UnitFrames.toc`
- the in-game addon title is still `Cell_UnitFrame_Continued`

Renaming the folder to `Cell_UnitFrame_Continued` will make WoW ignore the addon because the folder name no longer matches the `.toc` filename.

Do not use GitHub's **Code > Download ZIP** for installation. Use the packaged release asset from **Releases**, because it already ships with the correct addon folder name and release metadata.

## What It Does

Cell_UnitFrame_Continued adds standalone player-oriented unit frames on top of Cell, including:

- `Player`
- `Target`
- `TargetTarget`
- `Focus`
- `Pet`
- `Boss`

The widget system is separate from base Cell indicators, so it does not mirror every native Cell indicator one-to-one.

## Recent Fork Work

- Retail 12.x and Cell Midnight API compatibility updates
- Secret Value-safe handling for health, power, casts, and auras
- Tag fixes for health and power text formatting
- Expanded anchoring support, including external frame targets
- Dummy anchor reuse for migration from other unit frame addons

Technical migration notes for the fork live in [MIDNIGHT_MIGRATION.md](MIDNIGHT_MIGRATION.md).

## Custom Formats

`Health Text`, `Power Text`, and `Custom Text` support tag-based formats.

Examples:

- `[curhp:short] | [curhp:per]`
- `[curhp]/[maxhp]`
- `[perhp:short] | [curhp:short]`

Conditional prefix/suffix examples:

- ` [target< «] [name]`
- `[name] [» >target]`

Conditional color example:

- `[{neg:red}{pos:green}>abs:healabs:merge:short]`

Use `/cuf tags` in game to inspect available tags.

Custom tags can also be added through snippets. See [Snippets/AddCustomTag.lua](Snippets/AddCustomTag.lua).

## Snippets And API

This addon supports Cell snippets and exposes continuation-compatible callbacks:

- `CUF_AddonLoaded`
- `CUF_FramesInitialized`

See [Snippets](Snippets) for examples and [API](API) for addon API helpers.

## Compatibility

Cell_UnitFrame_Continued includes dummy-anchor support so you can migrate from other unit frame addons without re-anchoring every dependent WeakAura or helper addon.

Recent fork additions also include anchor targets for external frames and support for reusing existing frame names such as `ElvUF_Target` when needed.

## Credits

Credits and attribution for the original addon and this continuation fork are documented in [CREDITS.md](CREDITS.md).

## Publishing

Publishing and release setup notes are documented in [PUBLISHING.md](PUBLISHING.md).
