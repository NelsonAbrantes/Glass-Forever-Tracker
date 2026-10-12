# Changelog

Versions are named `X.Y.Z-forever`: `0.x` while in beta.

## 0.1.0-forever (beta, unreleased)

### Added
- Fade: the tracker fades out when you're not using it, and comes back on mouse over, when an objective changes, when you track a quest, and in Edit Mode (`Fade.lua`).
- Glass look: no game header bars or panel background, a soft Glass background that fades out on every side and covers only the tracker's content, a chosen font, and Glass icons for quests ("?" and "...") and minimize buttons, with an optional dark outline (`Skin.lua`, `Background.lua`, `Icons.lua`).
- Options page (`/gft`): fade timings, font, outline, sizes, line spacing, section title, quest name and icon colors, hidden titles, quest count ("Quests 12/25"), dimmed completed objectives, Glass progress bars, background opacity, color and size (`Options.lua`).
- Edit Mode: fade, delay, faded visibility, Glass look, title size, line spacing, background size and color, title and icon colors in the game's Objective Tracker entry; its own Opacity and Text Size drive the Glass background and the text sizes (`EditMode.lua`).
- Only quests in this zone: tracks the quests of the current zone and switches when you change zone (off by default) (`ZoneFilter.lua`).
- In dungeons and raids: like outside, hide the tracker, always show it, or show only that dungeon's quests (`Fade.lua`, `ZoneFilter.lua`).
- Width: a wider or narrower tracker, from the Options or Edit Mode (`Width.lua`).
- Sound on complete: a sound when an objective is done and another when a quest is ready to turn in; with "Orc voice on quest complete" (on by default) an orc peon says "Work complete!" instead (`Sounds.lua`).
- Animations (Glass, Game or Off): titles light up with a thin line and a shine, objective progress line, completed objectives flash white, the "?" of quests ready to turn in pulses, the tracker slides in, and new quests slide in, write their name, pop their icon with a ring and show their objectives one by one; an abandoned quest turns to dust and blows away (`Skin.lua`, `Icons.lua`, `Animations.lua`, `Fade.lua`, `Dust.lua`).
- Update notice: the addon quietly tells other players in your guild and group which version it has; if someone has a newer one, a message in chat says so (once per session) (`VersionCheck.lua`).
- `/gft debug` and `/gft testanim` to help find problems.

### Fixed
- Switching the quest name color back to "Game colors" now restores the game's colors (and inline colors) right away (`Icons.lua`).
- The game's growing animations go wrong in this game version: the check of a completed objective flew at the screen, huge. Those animations are stopped and done by the addon instead, capped (`Skin.lua`, `Icons.lua`).
- Smoother animations: icons, lines and specks no longer move pixel by pixel, a new quest's entrance no longer restarts halfway or slides twice, and its objectives show in order (`Core.lua`, `Animations.lua`, `Fade.lua`).
- Animated names count letters, not bytes, so accented or non-Latin names take the right time (`Animations.lua`, `Dust.lua`).
- The tracker showed up with the mouse over the empty part of its box (down to its Edit Mode height) or over a window on top of it, like the bags. Now only the quests themselves count (`Fade.lua`).
- After a /reload inside a dungeon, "Dungeon quests only" showed every quest: the game puts them back a few seconds after loading, so the filter is applied again then (`ZoneFilter.lua`).
- Quest icons no longer go back to the game's art, and the gold ring no longer stays after accepting a quest (`Icons.lua`).
