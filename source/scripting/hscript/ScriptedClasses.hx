package scripting.hscript;

#if HSCRIPT_SCRIPTED_CLASSES

import insanity.IScripted;

class ScriptedFlxStrip extends flixel.FlxStrip implements IScripted {}
class ScriptedFlxBasic extends flixel.FlxBasic implements IScripted {}
class ScriptedFlxObject extends flixel.FlxObject implements IScripted {}
class ScriptedFlxSprite extends flixel.FlxSprite implements IScripted {}
class ScriptedFlxText extends flixel.text.FlxText implements IScripted {}

class ScriptedFlxGroup extends flixel.group.FlxGroup implements IScripted {}
class ScriptedFlxSpriteGroup extends flixel.group.FlxSpriteGroup implements IScripted {}

class ScriptedFlxState extends flixel.FlxState implements IScripted {}
class ScriptedFlxSubState extends flixel.FlxSubState implements IScripted {}

class ScriptedNote extends objects.Note implements IScripted {}
class ScriptedCharacter extends objects.Character implements IScripted {}
class ScriptedHealthIcon extends objects.HealthIcon implements IScripted {}
class ScriptedMusicPlayer extends objects.MusicPlayer implements IScripted {}

#end