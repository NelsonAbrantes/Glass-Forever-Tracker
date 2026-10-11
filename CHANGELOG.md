# Changelog

Versions are named `X.Y.Z-forever`: `0.x` while in beta.

## 0.1.0-forever (beta, unreleased)

### Added
- Fade: the tracker fades out when you're not using it, and comes back on mouse over, when an objective changes, when you track a quest, and in Edit Mode (`Fade.lua`).
- Glass look: no game header bars or panel background, a soft Glass background that fades out on every side and covers only the tracker's content, a chosen font, and Glass icons for quests ("?" and "...") and minimize buttons (`Skin.lua`, `Background.lua`, `Icons.lua`).
- Options page (`/gft`): fade timings, font, outline, sizes, line spacing, section title, quest name and icon colors, hidden titles, quest count ("Quests 12/25"), dimmed completed objectives, Glass progress bars, background opacity, color and size (`Options.lua`).
- Edit Mode: fade, delay and Glass look in the game's Objective Tracker entry; its own Opacity and Text Size drive the Glass background and the text sizes (`EditMode.lua`).
- Only quests in this zone: tracks the quests of the current zone and switches when you change zone (off by default) (`ZoneFilter.lua`).
- In dungeons and raids: like outside, hide the tracker, or always show it (`Fade.lua`).
- Sound on complete: a sound when an objective is done and another when a quest is ready to turn in (`Sounds.lua`).
- Animations (Glass, Game or Off, each Glass one on its own): titles light up with a thin line and a shine, objective progress line, completed objectives flash white, the "?" of quests ready to turn in pulses, the tracker slides in, and new quests slide in, write their name, pop their icon with a ring and show their objectives one by one (`Skin.lua`, `Icons.lua`, `Animations.lua`, `Fade.lua`).
- `/gft debug` and `/gft testanim` to help find problems.
