# List of differences

The current list of differences from this fork to Psych Engine *as of 1.0.3* are as follows:

## Engine changes

### Chart Editor

- Re-implemented vortex editor functionality that was previously available in 0.7.3
	- Press the up and down arrow keys to scroll with the beat snap constraint
	- Press the keypad digits 1-7 to place notes (also with the beat snap constraint)
- Sustain notes are now textured instead of white lines
	- This can be toggled off (classic sustains) in the View > Theme menu
- Fixed some bugs
	- Playback rate not behaving correctly on playtesting
	- Chart Editor info desync when adding BPM changes
	- Playtest info not updating correctly
- You can hold A and D to skip sections faster
- Added a waveform view mode for all tracks
- Editor noteskin changes live now

### Menus

- Fixed "Move mod to top" button in the Mods menu
- Left / right scrolling on numerical options is more consistent
- Some menus have been adjusted to look cleaner / less cluttered

### Gameplay

- Improvements to note scroll direction
- "Better" note loop so multiple notes (doubles, triples, quads) are hit at once instead of across different frames

### Other

- Fixed a crash caused by an active video when exiting the state
- Updated note RGB shader (to prevent color blending artifacts)
- Cleaner master editor menu

## API changes

### LUA

- Objects can now be returned into tables from `runHaxeCode` and `runHaxeFunction`
- `antialiasing` variable is now available as a default Lua variable

### HScript

- Setting game variables without using `game.` is now allowed (it was previously only allowed for getting)
- `createGlobalCallback` now also makes the callback globally available in HScript scripts
- `trace` now prints in-game too (including the line number)

### General

- `onDestroyNote` function for note despawning
- "stageUI", "uiPrefix" and "uiPostfix" behavior has been adjusted
- Changed all libraries to use their latest versions (that previously weren't)
- DCE is disabled and [almost] all classes are included to remove scripting limitations
- The second argument "fakeCrochet" has been removed in `Note` class function `followStrumNote`
- Added variable "ghostTapping" in `PlayState`, so it can be changed without having to modify user preference
- FATAL script errors only print at the top left of the screen instead of making a new window alert
	- They are also bigger than the default print messages
- PlayState function `addTextToDebug` now has an argument for size and returns the text itself

...and more! i think...