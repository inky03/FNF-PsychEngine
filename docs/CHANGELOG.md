# List of differences

The current list of differences from this fork to Psych Engine (v1.0.3) are as follows:

- Improvements to note scroll direction
- Tried to prevent a crash when exiting PlayState while a video is playing
- Changed to use all libraries on their latest versions (that were not)
- Tiny fixes to LUA and HScript
- Other small adjustments

## API changes

- The second argument "fakeCrochet" has been removed in `followStrumNote`, in the `Note` class
- Added variable "ghostTapping" in `PlayState`, so it can be changed without modifying user preferences

(That's all for now, but more things will be changed eventually)