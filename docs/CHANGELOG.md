# List of differences

The current list of differences from this fork (0.0.4) to Psych Engine (1.0.4) are as follows:

## Engine changes

### Chart Editor

- Re-implemented vortex editor functionality that was in versions previous to 1.0
	- The Vortex Editor option has been moved back to the Charting tab
	- Press the up and down arrow keys to scroll with the beat snap constraint
	- Press the keypad digits 1-7 to place notes (also with the beat snap constraint)
- Sustain notes can now be textured instead of using white lines
	- This can be toggled off (Textured Hold Notes checkbox) in the View > Theme menu
- View Menu
	- Down-Scroll editor can be toggled in this menu
	- "Toys" (based on MoonlightCatalyst's pull request) can be toggled in this menu
		- Like the Buddies in the FPS Plus engine Chart Editor, they play sing animations on notes
		- You can drag them around (doesn't save currently)
- Fixed some bugs
	- Inconsistencies / inaccuracies related to note and hold note timing (related to BPM changes)
	- Ignore notetypes will not play hitsounds and will not make the strums glow
	- Copied - pasted sections are now adapted to the correct BPM
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
- "De-hardcoded" some specific behaviors
	- Tutorial camera (behavior now in stage class rather than PlayState, can be disabled)
	- Captain game over lines (behavior now in stage class rather than Game Over class)
- ~~Fixed a crash caused by an active video when exiting the state~~ *merged in 1.0.4*
- Set Property event should work better (probably)
- F5 key to reload the current state
- Cleaner master editor menu

## API changes

### Lua

- EXTENDED Scripting (VERY EXPERIMENTAL)
	- Lua scripting unsupported on Global scripts (and will probably remain this way because of its shortcomings)
	- Custom State and Sub-state code now also admits Lua scripting!!
- New functions
	- Switch to a custom state in Lua with `openCustomState('stateName')`
	- `loadWeek(weekFilename:String, ?difficultyIndex:Int)` to load a custom week
- Backend rewrite
	- Some function code previously stuck in Lua API functions is now available in other classes for more convenience
		- ex. `PlayState.exitSong`, `StoryMenuState.loadSong`
		- This also makes them easily available for HScript to use
	- You can now use the map accessor in `getProperty`, `setProperty` (and variants)
		- ex. `debugPrint(getProperty('boyfriend.animOffsets["singLEFT"]'))` to get bf's left pose animation offsets
	- All API functions have been "modernized" to be able to take objects within objects
		- ex. `playAnim('strumLineNotes.members[0]', 'confirm', true)` to play confirm animation in the first strum note
- ~~Objects can now be returned into tables from `runHaxeCode` and `runHaxeFunction`~~ *merged in 1.0.4*
- Try compiling with `-D UNHOLYWANDERER04` to add an absolutely exquisite, brand new Lua function
- `antialiasing` variable is now available as a default Lua variable
- Miscellaneous fixes related to tags

### HScript

- EXTENDED Scripting (EXPERIMENTAL)
	- Global Scripts
		- Run absolutely everywhere
		- `onCreate` is called when the mod is initialized and `onDestroy` when the mod is unloaded (ex. disabled in Mods menu)
		- Register custom Lua API functions in `onRegisterLuaAPI`
			- like `createGlobalCallback` but better? i guess?
			- Example:
				```haxe
				function onRegisterLuaAPI() {
					FunkinLua.registerFunction('testFunction', function() {
						debugPrint('hi!!', 0xffff00)
					});
				}
				```
				```lua
				function onCreate()
					testFunction() -- will print "hi!!"
				end
				```
	- Custom States
		- Switch to a custom state in HScript with `MusicBeatState.switchState(new CustomState('stateName'))`
		- Will only admit the highest priority script (to prevent major code conflicts)
		- All features **scriptable states** have
	- Custom Sub-states
		- Now admit script files; loads from `scripts/substates/SubStateName.hx`
	- Scriptable States (OUTDATED, WILL PROBABLY MAKE API PAGE?)
		- MainMenuState
			- Adapted for scripting flexibility
			- Functions
				```haxe
				function onSelectItem(item, index) {}
				function onAccept(item, index) {}
				```
		- FreeplayState
			- Functions
				```haxe
				function onMusicPlayer(playing, item) {}
				function onMusicPlayerPost(playing, item) {}
				function onSelectItem(item, index) {}
				function onAccept(item, index) {}
				```
		- LoadingState
			- Now admits Lua scripts
			- Behavior more consistent with other scriptable states
			- Loading screen scripts can now be loaded from global mods too (and the base mods folder)
			- Can load script from `data/LoadingScreen` or now also `scripts/states/LoadingState` (.hx or .lua)
		- Options Sub-states
			- Functions
				```haxe
				function onSelectItem(item, index) {}
				function onAccept(item) {}
				```
		- General
			- Most states now admit scripts; loads from `scripts/states/StateName.hx`
				- Search `extends ScriptableState` to see all scriptable states as of currently
			- Functions
				```haxe
				function onCreate() {}
				function onCreatePost() {}
				function onUpdate(elapsed) {}
				function onUpdatePost(elapsed) {}
				function onDraw() {}
				function onDrawPost() {}
				function onStepHit(step) {}
				function onBeatHit(beat) {}
				function onSectionHit(section) {}
				function onDestroy() {}
				```
- Custom variables defined with `setVar` on objects can be accessed like regular fields
	- Example:
		```haxe
		boyfriend.setVar('penisInches', {flaccid: 3, erect: 9});
		boyfriend.penisInches.erect; // 9
		boyfriend.penisInches.flaccid = 1.5;
		```
- More default imports
	- `FunkinLua`, `MusicBeatState`, `MusicBeatSubstate` and variants, for convenience
- `luaDebugMode` and `luaDeprecatedWarnings` (although that one is useless here) can now be set in HScript, true by default
- Fixed crashes on specific circumstances (errors that previously weren't correctly caught, ex. Null Function Pointer)
- Setting game variables without using `game.` is now allowed (it was previously only allowed for getting)
- `createGlobalCallback` now also makes the callback globally available in HScript scripts
- `trace` will now also print in-game (highlighted cyan), including the line number

### General (Scripting)

- DCE is disabled and [almost] all classes are included, to remove scripting limitations
- Added `curDecSection`
- `onStepHit`, `onBeatHit` and `onSectionHit` callbacks
	- Will now also trigger in 0 and negative time marks
	- Now have the respective step, beat or section passed as the first function argument
- New callbacks
	- `onGameOverLoop`, when the game over loop starts
	- `onDraw`, `onDrawPost` - the former can be stopped to use custom state / substate drawing behavior (very smart, but also very dangerous)
- FATAL script errors only print at the top left of the screen instead of making a new window alert
	- These errors are highlighted in dark red, and are bigger than the other printed text
- Logging
	- `debugPrint` is now colorful in the console (because its funny)
	- Shader errors, and Lua fatal errors are now logged as a debug message instead of showing window alerts
	- Script trace messages are now rendered in OpenFL instead of HaxeFlixel
		- The messages will remain on top of the screen at any time
		- The messages will also persist between states
		- "luaDebugGroup" has been removed in PlayState

### General (Source Code)

- Conductor
	- BPM change map now has the initial song BPM set as the first BPM change (for consistency and stability)
	- Most functions can now have a custom BPM change array passed to them (for use in Chart Editor)
	- Most functions now have their step & beat equivalents
	- `Conductor.copyBPMChanges` to copy a BPM change array to a new array
	- `Conductor.defaultBPMChangeMap` to make default BPM change array based on an initial BPM value
- Dialogue
	- Useful for mid-song dialogue
	- If closed, will not stop the song if it's already playing
	- `canContinue` and `canSkip` variables to disable certain inputs during dialogue
	- `advanceDialog(finishText:Bool = false)` and `finishDialog()` to force the dialogue to advance and end, respectively
- MusicBeatState
	- Unified with MusicBeatSubstate (`MusicBeatState` extends `MusicBeatSubstate`)
	- Now contains the runtime shaders map, instead of only PlayState (useful for scripting purposes)
	- Added `curDecSection`
	- `stepHit`, `beatHit` and `sectionHit` functions
		- Will now also trigger in 0 and negative time marks
		- Now have the respective step, beat or section passed as the first function argument
- Psychlua package
	- (a lot actually.)
	- FunkinLua
		- Most functions are now registered only once (per state creation), to speed up function loading times (`registeredFunctions` map)
	- LuaUtils
		- `getVarInArray` and `setVarInArray` have been replaced by `getVariable` and `setVariable`
		- Functions `initSaveData`, `flushSaveData`, `getDataFromSave`, `setDataFromSave` and `eraseSaveData` have been moved to this class
			- They can now be accessed with HScript due to this, if you're into that
	- HScript
		- `callOnScriptsEx` (to provide diff. arguments for Lua and HScript function calls)
- Character
	- Combo and combo drop animations (from base game)
- Notes
	- Improvements to note scroll direction and sustain note scaling
		- `correctionOffset` is no longer needed due to this and has been removed
	- `onDestroyNote` script API function for note despawning
	- `Note.section` ... I wonder what this is
	- `Note.character` ... I wonder what this is, too
	- `Note.hitPriority` to edit note priority beyond a boolean
	- `Note.isSustainEnd` to check if a sustain marks the end of a note
	- `Note.followStrumNote` second argument "fakeCrochet" has been removed (as it was useless)
	- Strum **press** animation is now strictly only played on a ghost tap
- States
	- PlayState
		- Added variable `ghostTapping`, so it can be modified without having to change user preferences
		- `stageUI`, `uiPrefix` and `uiPostfix` behavior has been adjusted (this also affects note textures)
		- `addTextToDebug` function now has an argument for size and returns the text itself
		- `storyVariables` for static variables useful for scripting - will remain intact until next week played
		- `storyWeekData` for well, the data for the current week.
	- BaseStage
		- Added `onMoveCamera` and `onGameOver [Loop / Start / Confirm]` functions
- Changed all libraries to use their latest versions (that previously weren't)
	- HScript Iris (1.1.3 used in release -> git used in fork)
		- Fixed increment / decrement operator `var ++` `var --`
		- String concatenation (from yours truly I guess!)

...and more! i think...
