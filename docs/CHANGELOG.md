# List of differences

The current list of differences from this fork to Psych Engine *as of 1.0.3* are as follows:

## Game changes

### Chart Editor

- Re-implemented vortex editor functionality that was previously available in 0.7.3
	- Press the up and down arrow keys to scroll with the beat snap constraint
	- Press the keypad digits 1-7 to place notes (also with the beat snap constraint)
- Sustain notes are now textured instead of white lines
- Added a waveform view mode for all tracks
- Editor noteskin changes live now

### Menus

- Fixed "Move mod to top" button in the Mods menu
- Left / right scrolling on numerical options is more consistent

### Gameplay

- Improvements to note scroll direction
- "Better" note loop so multiple notes (doubles, triples, quads) are hit at once instead of across different frames

### Other

- Fixed a crash caused by an active video when exiting the state
- Updated note RGB shader (to prevent color blending artifacts)

## API changes

### LUA

- Objects can now be returned into tables from `runHaxeCode` and `runHaxeFunction`

### HScript

- `trace` now prints in-game too (including the line number)

### General

- Changed all libraries to use their latest versions (that previously weren't)
- The second argument "fakeCrochet" has been removed in `Note` class function `followStrumNote`
- Added variable "ghostTapping" in `PlayState`, so it can be changed without having to modify user preference

...and more! i think...