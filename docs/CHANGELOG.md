# List of differences

The current list of differences from this fork to Psych Engine (1.0.4) are as follows:

## Engine changes

### Chart Editor

- Re-implemented vortex editor functionality that was in versions previous to 1.0
	- The Vortex Editor option has been moved back to the Charting tab
	- Press the up and down arrow keys to scroll with the beat snap constraint
	- Press the keypad digits 1-7 to place notes (also with the beat snap constraint)
- Sustain notes can now be textured instead of using white lines
	- This can be toggled off (classic sustains) in the View > Theme menu
- View Menu
	- Down-Scroll editor can be toggled in this menu
	- "Toys" (based on MoonlightCatalyst's pull request) can be toggled in this menu
		- Like the Buddies in the FPS Plus engine Chart Editor, they play sing animations on notes
- Fixed some bugs
	- Inconsistencies / inaccuracies related to note and hold note timing (related to BPM changes)
	- Ignore notetypes will not play hitsounds and will not make the strums glow
	- Playback rate not behaving correctly on playtesting
	- Chart Editor info desync when adding BPM changes
	- Playtest info not updating correctly
- You can hold A and D to skip sections faster
- Added a waveform view mode for all tracks
- Editor noteskin now changes live

### Menus

- ~~Fixed "Move mod to top" button in the Mods menu~~ *merged in 1.0.4*
- Left / right scrolling on numerical options is more consistent
- Some menus have been adjusted to look cleaner / less cluttered
- Notes will now glow when cycling Note Skins in the Visual Settings menu
- Some Options menus descriptions have been updated to fix mistakes and (hopefully) describe better

### Gameplay

- Changed note input sorting to a (hopefully) faster and better alternative
- "Better" note loop so multiple notes (doubles, triples, quads) are hit the frame they're supposed to

### Other

- Notes
	- Updated RGB shader (to prevent color blending artifacts)
	- Updated note texture to update glows and sustain notes
- ~~Fixed a crash caused by an active video when exiting the state~~ *merged in 1.0.4*
- Cleaner master editor menu

## API changes

### Lua

- ~~Objects can now be returned into tables from `runHaxeCode` and `runHaxeFunction`~~ *merged in 1.0.4*
- Try compiling with `-D UNHOLYWANDERER04` to add an absolutely exquisite, brand new Lua function
- `antialiasing` variable is now available as a default Lua variable
- Miscellaneous fixes related to tags

### HScript

- State Scripting (EXPERIMENTAL)
- Fixed crashes on specific circumstances (errors that previously weren't correctly caught, ex. Null Function Pointer)
- Setting game variables without using `game.` is now allowed (it was previously only allowed for getting)
- `createGlobalCallback` now also makes the callback globally available in HScript scripts
- `trace` will now also print in-game (highlighted cyan), including the line number

### General (Scripting)

- DCE is disabled and [almost] all classes are included, to remove scripting limitations
- FATAL script errors only print at the top left of the screen instead of making a new window alert
	- These errors are highlighted in dark red, and are bigger than the other printed text

### General (Source Code)

- Conductor class
	- BPM change map now has the initial song BPM set as the first BPM change (for consistency and stability)
	- Most functions can now have a custom BPM change array passed to them (for use in Chart Editor)
	- Most functions now have their step & beat equivalents
	- `Conductor.copyBPMChanges` to copy a BPM change array to a new array
	- `Conductor.defaultBPMChangeMap` to make default BPM change array based on an initial BPM value
- Notes
	- Improvements to note scroll direction and sustain note scaling
		- `correctionOffset` is no longer needed due to this and has been removed
	- `onDestroyNote` script API function for note despawning
	- `Note.hitPriority` to edit note priority beyond a boolean
	- `Note.isSustainEnd` to check if a sustain marks the end of a note
	- `Note.followStrumNote` second argument "fakeCrochet" has been removed (as it was useless)
	- Strum **press** animation is now strictly only played on a ghost tap
- Play State
	- Added variable `ghostTapping`, so it can be modified without having to change user preferences
	- `stageUI`, `uiPrefix` and `uiPostfix` behavior has been adjusted (this also affects note textures)
	- `addTextToDebug` function now has an argument for size and returns the text itself
- Changed all libraries to use their latest versions (that previously weren't)

...and more! i think...
