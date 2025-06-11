#if LUA_ALLOWED
package psychlua;

import backend.Song;
import backend.WeekData;
import backend.Highscore;
import backend.ScriptedState;

import openfl.Lib;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import cutscenes.DialogueBoxPsych;

import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.Character;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;

import substates.PauseSubState;
import substates.GameOverSubstate;

import psychlua.LuaUtils;
import psychlua.ModchartSprite;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import haxe.Json;

class FunkinLua {
	public var lua:State = null;
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var parentState:FlxState;
	public var closed:Bool = false;

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = [];
	public static var customFunctions:Map<String, Dynamic> = [];
	
	public static function initFromFile(file:String, ?parent:FlxState):FunkinLua {
		var newScript:FunkinLua = null;
		
		try {
			newScript = new FunkinLua(file, parent);
			newScript.call('onCreate');
			
			trace('lua file loaded succesfully:' + file);
		} catch(e:Dynamic) {
			Log.print(e, FATAL);
			newScript = null;
		}
		
		return newScript;
	}

	public function new(scriptName:String, ?state:FlxState) { // TODO: allat
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		//LuaL.dostring(lua, CLENSE);

		this.scriptName = scriptName.trim();
		
		var myFolder:Array<String> = this.scriptName.split('/');
		#if MODS_ALLOWED
		if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
			this.modFolder = myFolder[1];
		#end

		// Lua shit
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('version', MainMenuState.psychEngineVersion.trim());
		set('modFolder', this.modFolder);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		
		parentState = state ?? FlxG.state;
		var game:PlayState = PlayState.instance;
		if (state is PlayState) // PlayState-only variables
		@:privateAccess {
			var game:PlayState = cast state;
			
			// Song/Week shit
			set('curBpm', Conductor.bpm);
			set('bpm', PlayState.SONG.bpm);
			set('scrollSpeed', PlayState.SONG.speed);
			set('crochet', Conductor.crochet);
			set('stepCrochet', Conductor.stepCrochet);
			set('songLength', FlxG.sound.music.length);
			set('songName', PlayState.SONG.song);
			set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
			set('loadedSongName', Song.loadedSongName);
			set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
			set('chartPath', Song.chartPath);
			set('startedCountdown', false);
			set('curStage', PlayState.SONG.stage);

			set('isStoryMode', PlayState.isStoryMode);
			set('difficulty', PlayState.storyDifficulty);

			set('difficultyName', Difficulty.getString(false));
			set('difficultyPath', Difficulty.getFilePath());
			set('difficultyNameTranslation', Difficulty.getString(true));
			set('weekRaw', PlayState.storyWeek);
			set('week', WeekData.weeksList[PlayState.storyWeek]);
			set('seenCutscene', PlayState.seenCutscene);
			set('hasVocals', PlayState.SONG.needsVoices);
			
			// Gameplay variables
			var curSection:SwagSection = PlayState.SONG.notes[game.curSection];
			set('curSection', game.curSection);
			set('curBeat', game.curBeat);
			set('curStep', game.curStep);
			set('curDecBeat', game.curDecBeat);
			set('curDecStep', game.curDecStep);
	
			set('score', game.songScore);
			set('misses', game.songMisses);
			set('hits', game.songHits);
			set('combo', game.combo);
			set('deaths', PlayState.deathCounter);
	
			set('rating', game.ratingPercent);
			set('ratingName', game.ratingName);
			set('ratingFC', game.ratingFC);
			set('totalPlayed', game.totalPlayed);
			set('totalNotesHit', game.totalNotesHit);

			set('inGameOver', GameOverSubstate.instance != null);
			set('mustHitSection', curSection != null ? (curSection.mustHitSection == true) : false);
			set('altAnim', curSection != null ? (curSection.altAnim == true) : false);
			set('gfSection', curSection != null ? (curSection.gfSection == true) : false);

			set('healthGainMult', game.healthGain);
			set('healthLossMult', game.healthLoss);
	
			#if FLX_PITCH
			set('playbackRate', game.playbackRate);
			#else
			set('playbackRate', 1);
			#end
	
			set('guitarHeroSustains', game.guitarHeroSustains);
			set('instakillOnMiss', game.instakillOnMiss);
			set('botPlay', game.cpuControlled);
			set('practice', game.practiceMode);
	
			for (i in 0...4) {
				set('defaultPlayerStrumX' + i, 0);
				set('defaultPlayerStrumY' + i, 0);
				set('defaultOpponentStrumX' + i, 0);
				set('defaultOpponentStrumY' + i, 0);
			}
	
			// Default character data
			set('defaultBoyfriendX', game.BF_X);
			set('defaultBoyfriendY', game.BF_Y);
			set('defaultOpponentX', game.DAD_X);
			set('defaultOpponentY', game.DAD_Y);
			set('defaultGirlfriendX', game.GF_X);
			set('defaultGirlfriendY', game.GF_Y);

			set('boyfriendName', game.boyfriend != null ? game.boyfriend.curCharacter : PlayState.SONG.player1);
			set('dadName', game.dad != null ? game.dad.curCharacter : PlayState.SONG.player2);
			set('gfName', game.gf != null ? game.gf.curCharacter : PlayState.SONG.gfVersion);
			
			// Other settings
			set('downscroll', ClientPrefs.data.downScroll);
			set('middlescroll', ClientPrefs.data.middleScroll);
			set('framerate', ClientPrefs.data.framerate);
			set('ghostTapping', ClientPrefs.data.ghostTapping);
			set('hideHud', ClientPrefs.data.hideHud);
			set('antialiasing', ClientPrefs.data.antialiasing);
			set('timeBarType', ClientPrefs.data.timeBarType);
			set('scoreZoom', ClientPrefs.data.scoreZoom);
			set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
			set('flashingLights', ClientPrefs.data.flashing);
			set('noteOffset', ClientPrefs.data.noteOffset);
			set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
			set('noResetButton', ClientPrefs.data.noReset);
			set('lowQuality', ClientPrefs.data.lowQuality);
			set('shadersEnabled', ClientPrefs.data.shaders);
			set('scriptName', scriptName);
			set('currentModDirectory', Mods.currentModDirectory);

			// Noteskin/Splash
			set('noteSkin', ClientPrefs.data.noteSkin);
			set('noteSkinPostfix', Note.getNoteSkinPostfix());
			set('splashSkin', ClientPrefs.data.splashSkin);
			set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
			set('splashAlpha', ClientPrefs.data.splashAlpha);
		}

		// build target (windows, mac, linux, etc.)
		set('buildTarget', LuaUtils.getBuildTarget());

		addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnScripts(varName, arg, exclusions);
		});
		addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnHScript(varName, arg, exclusions);
		});
		addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});

		// mod settings
		addLocalCallback("getModSetting", function(saveTag:String, ?modName:String = null) {
			#if MODS_ALLOWED
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					FunkinLua.luaTrace('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, ERROR);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
			#else
			luaTrace("getModSetting: Mods are disabled in this build!", false, false, ERROR);
			#end
		});
		//
		
		addLocalCallback('close', function() {
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});
		
		implementLocal();
		ShaderFunctions.implementLocal(this);
		ReflectionFunctions.implementLocal(this);
		#if HSCRIPT_ALLOWED HScript.implementLocal(this) #else HScript.implement() #end; // haha
		
		if (parentState is ScriptedSubState) {
			var scripted:ScriptedSubState = cast parentState;
			scripted.implementLua(this);
		}
		
		for (name => func in customFunctions) {
			if (func != null)
				Lua_helper.add_callback(lua, name, func);
		}
		for (name => func in registeredFunctions) {
			if (func != null)
				Lua_helper.add_callback(lua, name, func);
		}

		try {
			var isString:Bool = !FileSystem.exists(scriptName);
			var result:Dynamic = null;
			if(!isString) {
				result = LuaL.dofile(lua, scriptName);
			} else {
				result = LuaL.dostring(lua, scriptName);
			}

			var resultStr:String = Lua.tostring(lua, result);
			if (resultStr != null && result != 0)
				throw resultStr;
			
			if (isString) scriptName = 'unknown';
		} catch(e:Dynamic) {
			trace(e);
			throw e;
		}
	}

	//main
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:FunkinLua = null;
	public function call(func:String, ?args:Array<Dynamic>):Dynamic {
		if(closed) return LuaUtils.Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		args ??= [];
		try {
			if(lua == null) return LuaUtils.Function_Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION) {
				if (type > Lua.LUA_TNIL)
					luaTrace("ERROR (" + func + "): attempt to call a " + LuaUtils.typeToString(type) + " value", false, false, ERROR);

				Lua.pop(lua, 1);
				return LuaUtils.Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK) {
				var error:String = getErrorMessage(status);
				luaTrace("ERROR (" + func + "): " + error, false, false, ERROR);
				return LuaUtils.Function_Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null) result = LuaUtils.Function_Continue;

			Lua.pop(lua, 1);
			if(closed) stop();
			return result;
		}
		catch (e:Dynamic) {
			trace(e);
		}
		return LuaUtils.Function_Continue;
	}
	
	public function exists(variable:String):Bool {
		if (lua == null)
			return false;
		
		Lua.getglobal(lua, variable);
		var type:Int = Lua.type(lua, -1);
		
		return (type != Lua.LUA_TNONE && type != Lua.LUA_TNIL);
	}

	public function set(variable:String, data:Dynamic):Void {
		if (lua == null)
			return;
		
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}
	
	public function get(variable:String):Dynamic {
		if (lua == null)
			return null;
		
		Lua.getglobal(lua, variable);
		return Convert.fromLua(lua, -1);
	}

	public function stop() {
		closed = true;

		if(lua == null) {
			return;
		}
		Lua.close(lua);
		lua = null;
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
	}

	static function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String) {
		var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null) {
			if (tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						luaCallGlobal('onTweenCompleted', [originalTag, vars]);
					}
				}));
			}
			else FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			return tag;
		}
		else luaTrace('$funcName: Couldnt find object: $vars', false, false, ERROR);
		return null;
	}
	static function noteTweenFunction(tag:String, note:Int, data:Dynamic, duration:Float, ease:String) {
		if(PlayState.instance == null) return null;
		
		var strumNote:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];
		if(strumNote == null) return null;

		if(tag != null)
		{
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);

			var variables = MusicBeatState.getVariables();
			variables.set(tag, FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween)
				{
					variables.remove(tag);
					luaCallGlobal('onTweenCompleted', [originalTag]);
				}
			}));
			return tag;
		}
		else FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
		return null;
	}

	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, ?color:FlxColor, ?level:LogType) {
		if (ignoreCheck || getBool('luaDebugMode')) {
			if (deprecated && !getBool('luaDeprecatedWarnings'))
				return;
			
			if (level == null)
				level = (color == null ? NONE : CUSTOM(color));
			
			Log.print(text, level);
		}
	}

	public static function getBool(variable:String) {
		if(lastCalledScript == null) return false;

		var lua:State = lastCalledScript.lua;
		if(lua == null) return false;

		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
	}

	static function findScript(scriptFile:String, ext:String = '.lua') {
		if(!scriptFile.endsWith(ext)) scriptFile += ext;
		var path:String = Paths.getPath(scriptFile, TEXT);
		#if MODS_ALLOWED
		if(FileSystem.exists(path))
		#else
		if(Assets.exists(path, TEXT))
		#end
		{
			return path;
		}
		#if MODS_ALLOWED
		else if(FileSystem.exists(scriptFile))
		#else
		else if(Assets.exists(scriptFile, TEXT))
		#end
		{
			return scriptFile;
		}
		return null;
	}

	public function getErrorMessage(status:Int):String {
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
			switch(status) {
				case Lua.LUA_ERRRUN: return "Runtime Error";
				case Lua.LUA_ERRMEM: return "Memory Allocation Error";
				case Lua.LUA_ERRERR: return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
		return null;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		callbacks.set(name, myFunction);
		Lua_helper.add_callback(lua, name, null); //just so that it gets called
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end

	public function initLuaShader(name:String)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			var shaderData:Array<String> = runtimeShaders.get(name);
			if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
			{
				luaTrace('Shader already initialized: $name', WARN);
				return true;
			}
		}

		var foldersToCheck:Array<String> = [Paths.getSharedPath('shaders/')];
		#if MODS_ALLOWED
		foldersToCheck.push(Paths.mods('shaders/'));
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		luaTrace('Missing shader $name .frag AND .vert files!', false, false, ERROR);
		#else
		luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, ERROR);
		#end
		return false;
	}
	
	public static function luaCallGlobal(func:String, args:Array<Dynamic>):Void {
		var state:FlxState = FlxG.state;
		do {
			if (state is ScriptedSubState)
				cast(state, ScriptedSubState).callOnLuas(func, args);
			state = state.subState;
		} while (state != null);
	}
	
	public static var registeredFunctions:Map<String, Dynamic> = [];
	public static function registerFunctions():Void {
		registeredFunctions.clear();
		
		implement();
		CustomState.implement();
		TextFunctions.implement();
		ExtraFunctions.implement();
		CustomSubstate.implement();
		ReflectionFunctions.implement();
		DeprecatedFunctions.implement();
		#if flxanimate FlxAnimateFunctions.implement(); #end
		
		#if DISCORD_ALLOWED DiscordClient.implement(); #end
		#if TRANSLATIONS_ALLOWED Language.implement(); #end
		#if ACHIEVEMENTS_ALLOWED Achievements.implement(); #end
	}
	
	public function implementLocal():Void {
		var st:ScriptedSubState = null;
		if (st is ScriptedSubState)
			st = cast FlxG.state;
		
		if (st != null) {
			addLocalCallback('callScript', function(luaFile:String, funcName:String, ?args:Array<Dynamic>) {
				args ??= [];

				var luaPath:String = findScript(luaFile);
				if(luaPath != null)
					for (luaInstance in st.luaArray)
						if(luaInstance.scriptName == luaPath)
							return luaInstance.call(funcName, args);

				return null;
			});
			addLocalCallback('isRunning', function(scriptFile:String) {
				var luaPath:String = findScript(scriptFile);
				if (luaPath != null) {
					for (luaInstance in st.luaArray)
						if (luaInstance.scriptName == luaPath)
							return true;
				}

				#if HSCRIPT_ALLOWED
				var hscriptPath:String = findScript(scriptFile, '.hx');
				if (hscriptPath != null) {
					for (hscriptInstance in st.hscriptArray)
						if (hscriptInstance.origin == hscriptPath)
							return true;
				}
				#end
				return false;
			});
			addLocalCallback('getRunningScripts', function() {
				var runningScripts:Array<String> = [];
				for (script in st.luaArray)
					runningScripts.push(script.scriptName);

				return runningScripts;
			});
			
			registerFunction('addLuaScript', function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
				var luaPath:String = findScript(luaFile);
				if (luaPath != null) {
					if (!ignoreAlreadyRunning) {
						for (luaInstance in st.luaArray) {
							if(luaInstance.scriptName == luaPath) {
								luaTrace('addLuaScript: The script "' + luaPath + '" is already running!', WARN);
								return;
							}
						}
					}

					st.initLuaScript(luaPath);
					return;
				}
				luaTrace("addLuaScript: Script doesn't exist!", false, false, ERROR);
			});
			registerFunction('addHScript', function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
				#if HSCRIPT_ALLOWED
				var scriptPath:String = findScript(scriptFile, '.hx');
				if (scriptPath != null) {
					if (!ignoreAlreadyRunning) {
						for (script in st.hscriptArray) {
							if(script.origin == scriptPath) {
								luaTrace('addHScript: The script "' + scriptPath + '" is already running!', WARN);
								return;
							}
						}
					}

					st.initHScript(scriptPath);
					return;
				}
				luaTrace("addHScript: Script doesn't exist!", false, false, ERROR);
				#else
				luaTrace("addHScript: HScript is not supported on this platform!", false, false, ERROR);
				#end
			});
			registerFunction('removeLuaScript', function(luaFile:String) {
				var luaPath:String = findScript(luaFile);
				if (luaPath != null) {
					var foundAny:Bool = false;
					for (luaInstance in st.luaArray) {
						if (luaInstance.scriptName == luaPath) {
							trace('Closing lua script $luaPath');
							luaInstance.stop();
							foundAny = true;
						}
					}
					if (foundAny) return true;
				}
				
				luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, WARN);
				return false;
			});
			registerFunction('removeHScript', function(scriptFile:String) {
				#if HSCRIPT_ALLOWED
				var scriptPath:String = findScript(scriptFile, '.hx');
				if (scriptPath != null) {
					var foundAny:Bool = false;
					for (script in st.hscriptArray) {
						if (script.origin == scriptPath) {
							trace('Closing hscript $scriptPath');
							script.destroy();
							foundAny = true;
						}
					}
					if (foundAny) return true;
				}
				
				luaTrace('removeHScript: Script $scriptFile isn\'t running!', false, false, WARN);
				return false;
				#else
				luaTrace("removeHScript: HScript is not supported on this platform!", false, false, ERROR);
				#end
			});
		}
	}
	
	public static function registerFunction(name:String, func:Dynamic):Void {
		registeredFunctions.set(name, func);
	}
	public static function implement():Void {
		var game:PlayState = PlayState.instance;
		if (game != null) implementGame(game);
		
		registerFunction('debugPrint', function(?text:Dynamic, color:String = 'WHITE') ScriptedState.debugPrint(text, CoolUtil.colorFromString(color)));

		registerFunction('setVar', (varName:String, value:Dynamic) -> {
			MusicBeatState.getVariables().set(varName, ReflectionFunctions.parseInstances(value));
			return value;
		});
		registerFunction('getVar', (varName:String) -> MusicBeatState.getVariables().get(varName));

		registerFunction('loadSong', (?name:String, difficultyNum:Int = -1) -> StoryMenuState.loadSong(name, difficultyNum));
		registerFunction('loadWeek', (?name:String, difficultyNum:Int = -1) -> {
			var week:WeekData = (name == null ? PlayState.storyWeekData : StoryMenuState.getWeek(name));
			if (week == null) {
				luaTrace('loadWeek: Week ${name == null ? 'is null!' : '$name not found!'}', false, false, ERROR);
			} else {
				StoryMenuState.loadWeek(week, difficultyNum);
			}
		});
		
		registerFunction('loadGraphic', function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var object:Dynamic = LuaUtils.getObjectDirectly(variable);
			if (object == null) {
				luaTrace('loadGraphic: Object $object doesn\'t exist!', false, false, ERROR);
			} else {
				var animated:Bool = (gridX != 0 || gridY != 0);
				if (image != null && image.length > 0)
					object.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		registerFunction('loadFrames', function(variable:String, image:String, spriteType:String = 'auto') {
			var object:FlxSprite = LuaUtils.getObjectDirectly(variable);

			if (object != null && image != null && image.length > 0)
				LuaUtils.loadFrames(object, image, spriteType);
		});
		registerFunction('loadMultipleFrames', function(variable:String, images:Array<String>) {
			var object:FlxSprite = LuaUtils.getObjectDirectly(variable);

			if (object != null && images != null && images.length > 0)
				object.frames = Paths.getMultiAtlas(images);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		registerFunction('getObjectOrder', function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			
			if (leObj != null) {
				if (group != null) {
					var groupOrArray:Dynamic = LuaUtils.getObjectDirectly(group);
					if (groupOrArray != null) {
						switch (Type.typeof(groupOrArray)) {
							case TClass(Array): //Is Array
								return groupOrArray.indexOf(leObj);
							default: //Is Group
								return Reflect.getProperty(groupOrArray, 'members').indexOf(leObj); //Has to use a Reflect here because of FlxTypedSpriteGroup
						}
					} else {
						luaTrace('getObjectOrder: Group $group doesn\'t exist!', false, false, ERROR);
						return -1;
					}
				}
				var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
				return groupOrArray.members.indexOf(leObj);
			}
			
			luaTrace('getObjectOrder: Object $obj doesn\'t exist!', false, false, ERROR);
			return -1;
		});
		registerFunction('setObjectOrder', function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			
			if (leObj != null) {
				if (group != null) {
					var groupOrArray:Dynamic = LuaUtils.getObjectDirectly(group);
					if (groupOrArray != null) {
						switch (Type.typeof(groupOrArray)) {
							case TClass(Array): //Is Array
								groupOrArray.remove(leObj);
								groupOrArray.insert(position, leObj);
							default: //Is Group
								groupOrArray.remove(leObj, true);
								groupOrArray.insert(position, leObj);
						}
					}
					else luaTrace('setObjectOrder: Group $group doesn\'t exist!', false, false, ERROR);
				}
				else {
					var groupOrArray:Dynamic = (CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance());
					groupOrArray.remove(leObj, true);
					groupOrArray.insert(position, leObj);
				}
				return;
			}
			
			luaTrace('setObjectOrder: Object $obj doesn\'t exist!', false, false, ERROR);
		});

		// gay ass tweens
		registerFunction('startTween', function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if (penisExam != null) {
				if (values != null) {
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if (tag != null) {
						var originalTag:String = tag;
						var variables = MusicBeatState.getVariables();
						tag = LuaUtils.formatVariable('tween_$tag');
						variables.set(tag, FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
	
							onUpdate: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobal(myOptions.onUpdate, [originalTag, vars])),
							onStart: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobal(myOptions.onStart, [originalTag, vars])),
							onComplete: function(twn:FlxTween) {
								if (twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if (myOptions.onComplete != null) luaCallGlobal(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					} else {
						FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							
							onComplete: (myOptions.onComplete == null ? null : function(twn:FlxTween) luaCallGlobal(myOptions.onComplete, [null, vars])),
							onUpdate: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobal(myOptions.onUpdate, [null, vars])),
							onStart: (myOptions.onStart == null ? null : function(twn:FlxTween) luaCallGlobal(myOptions.onStart, [null, vars])),
						} : null);
					}
				} else {
					luaTrace('startTween: No values provided on 2nd argument!', false, false, ERROR);
				}
			}
			else luaTrace('startTween: Couldnt find object: ' + vars, false, false, ERROR);
			return null;
		});

		registerFunction('doTweenX', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX'));
		registerFunction('doTweenY', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY'));
		registerFunction('doTweenAngle', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle'));
		registerFunction('doTweenAlpha', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha'));
		registerFunction('doTweenZoom', function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, LuaUtils.cameraString(camera), {zoom: value}, duration, ease, 'doTweenZoom'));
		registerFunction('doTweenColor', function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if (penisExam != null) {
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				
				if(tag != null) {
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							luaCallGlobal('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				} else {
					FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
				}
			}
			else luaTrace('doTweenColor: Couldnt find object: ' + vars, false, false, ERROR);
			return null;
		});

		registerFunction('cancelTween', function(tag:String) LuaUtils.cancelTween(tag));
		registerFunction('cancelTimer', function(tag:String) LuaUtils.cancelTimer(tag));
		
		registerFunction('runTimer', function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if (tmr.finished) variables.remove(tag);
				luaCallGlobal('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
			return tag;
		});
		
		// yippee!
		registerFunction('resetState', function() {
			FlxG.state.persistentUpdate = false;
			MusicBeatState.resetState();
		});

		//Identical functions
		registerFunction('FlxColor', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromName', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromString', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromHex', function(color:String) return FlxColor.fromString('#$color'));

		// precaching
		registerFunction('precacheImage', function(name:String, ?allowGPU:Bool = true) Paths.image(name, allowGPU));
		registerFunction('precacheSound', function(name:String) Paths.sound(name));
		registerFunction('precacheMusic', function(name:String) Paths.music(name));
		
		registerFunction('getSongPosition', () -> Conductor.songPosition);

		registerFunction('setCameraScroll', function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width/2, y - FlxG.height/2));
		registerFunction('addCameraScroll', function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		registerFunction('getCameraScrollX', () -> FlxG.camera.scroll.x + FlxG.width/2);
		registerFunction('getCameraScrollY', () -> FlxG.camera.scroll.y + FlxG.height/2);

		registerFunction('cameraShake', function(camera:String, intensity:Float, duration:Float) LuaUtils.cameraFromString(camera).shake(intensity, duration));
		registerFunction('cameraFlash', function(camera:String, color:String, duration:Float,forced:Bool) LuaUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null, forced));
		registerFunction('cameraFade', function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced));

		registerFunction('getMidpointX', function(variable:String) {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getMidpoint().x;

			return 0;
		});
		registerFunction('getMidpointY', function(variable:String) {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getMidpoint().y;

			return 0;
		});
		registerFunction('getGraphicMidpointX', function(variable:String) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		registerFunction('getGraphicMidpointY', function(variable:String) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		registerFunction('getScreenPositionX', function(variable:String, ?camera:String = 'game') {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).x;

			return 0;
		});
		registerFunction('getScreenPositionY', function(variable:String, ?camera:String = 'game') {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).y;

			return 0;
		});
		registerFunction('characterDance', function(character:String) {
			if (game != null) {
				switch (character.toLowerCase()) {
					case 'gf' | 'girlfriend': return game.gf?.dance();
					case 'boyfriend': return game.boyfriend.dance();
					case 'dad': return game.dad.dance();
				}
			}
			
			var char:Dynamic = LuaUtils.getObjectDirectly(character);
			if (char != null && char.dance != null) {
				char.dance();
				return;
			}
			
			game?.boyfriend.dance();
		});

		registerFunction('makeLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			if (image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		registerFunction('makeAnimatedLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			if (image != null && image.length > 0)
				LuaUtils.loadFrames(leSprite, image, spriteType);
			
			MusicBeatState.getVariables().set(tag, leSprite);
		});

		registerFunction('makeGraphic', function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			
			if (spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		registerFunction('addAnimationByPrefix', function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			
			if (obj != null) {
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if (obj.animation.curAnim == null) {
					if (obj.playAnim != null) obj.playAnim(name, true);
					else obj.animation.play(name, true);
				}
				return true;
			}
			return false;
		});

		registerFunction('addAnimation', function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop));
		registerFunction('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop));

		registerFunction('playAnim', function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj.playAnim != null) {
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			} else {
				if (obj.anim != null) obj.anim.play(name, forced, reverse, startFrame); //FlxAnimate
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		registerFunction('addOffset', function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null && obj.addOffset != null) {
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		registerFunction('setScrollFactor', function(obj:String, ?scrollX:Float, ?scrollY:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.scrollFactor.set(scrollX, scrollY);
				return;
			}
			luaTrace('setScrollFactor: Couldnt find object: ' + obj, false, false, ERROR);
		});
		registerFunction('addLuaSprite', function(tag:String, inFront:Bool = false) {
			var mySprite:FlxBasic = LuaUtils.getObjectDirectly(tag);
			if (mySprite == null) {
				luaTrace('addLuaSprite: Couldnt find object: $tag', false, false, ERROR);
				return;
			}

			var instance = LuaUtils.getTargetInstance();
			if (inFront) {
				instance.add(mySprite);
			} else {
				if (game == null) {
					instance.insert(0, mySprite);
					return;
				}
				
				var pos:Int = instance.members.indexOf(LuaUtils.getLowestCharacterGroup());
				if (pos < 0) pos = 0;
				
				if (game == null || !game.isDead) {
					instance.insert(pos, mySprite);
				} else {
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), mySprite);
				}
			}
		});
		registerFunction('setGraphicSize', function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.setGraphicSize(x, y);
				if (updateHitbox) obj.updateHitbox();
				return;
			}
			luaTrace('setGraphicSize: Couldnt find object: ' + obj, false, false, ERROR);
		});
		registerFunction('scaleObject', function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.scale.set(x, y);
				if (updateHitbox) obj.updateHitbox();
				return;
			}
			luaTrace('scaleObject: Couldnt find object: ' + obj, false, false, ERROR);
		});
		registerFunction('updateHitbox', function(obj:String) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.updateHitbox();
				return;
			}
			luaTrace('updateHitbox: Couldnt find object: ' + obj, false, false, ERROR);
		});

		registerFunction('removeLuaSprite', function(tag:String, destroy:Bool = true, ?group:String = null) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
			if (obj == null || obj.destroy == null)
				return;
			
			var groupObj:Dynamic = LuaUtils.getObjectDirectly(group);
			
			groupObj.remove(obj, true);
			if (destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});

		registerFunction('luaSpriteExists', function(tag:String) {
			var obj:FlxSprite = MusicBeatState.getVariables().get(tag);
			return (obj != null && (Std.isOfType(obj, ModchartSprite) || Std.isOfType(obj, ModchartAnimateSprite)));
		});
		registerFunction('luaTextExists', function(tag:String) {
			var obj:FlxText = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, FlxText));
		});
		registerFunction('luaSoundExists', function(tag:String) {
			var obj:FlxSound = MusicBeatState.getVariables().get(LuaUtils.formatVariable('sound_$tag'));
			return (obj != null && Std.isOfType(obj, FlxSound));
		});

		registerFunction('setObjectCamera', function(obj:String, camera:String = 'game') {
			var object:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if (object != null) {
				object.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			
			luaTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, false, ERROR);
			return false;
		});
		registerFunction('setBlendMode', function(obj:String, blend:String = '') {
			var object:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if (object != null) {
				object.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			
			luaTrace("setBlendMode: Object " + obj + " doesn't exist!", false, false, ERROR);
			return false;
		});
		registerFunction('screenCenter', function(obj:String, pos:String = 'xy') {
			var object:FlxObject = LuaUtils.getObjectDirectly(obj);

			if (object != null) {
				object.screenCenter(switch (pos.trim().toLowerCase()) {
					case 'none': NONE; // are you stupid
					case 'x': X;
					case 'y': Y;
					default: XY;
				});
				return;
			}
			luaTrace("screenCenter: Object " + obj + " doesn't exist!", false, false, ERROR);
		});
		registerFunction('objectsOverlap', function(obj1:String, obj2:String) {
			var objectsArray:Array<FlxBasic> = [LuaUtils.getObjectDirectly(obj1), LuaUtils.getObjectDirectly(obj2)];
			
			return (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]));
		});
		registerFunction('getPixelColor', function(obj:String, x:Int, y:Int) {
			var object:FlxSprite = LuaUtils.getObjectDirectly(obj);

			if (object != null) return object.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		
		// Sounds
		function getSound(tag:String):FlxSound {
			if (tag == null || tag.length < 1) {
				return FlxG.sound.music;
			} else {
				return MusicBeatState.getVariables().get(LuaUtils.formatVariable('sound_$tag'));
			}
		}
		registerFunction('playMusic', function(sound:String, ?volume:Float = 1, ?loop:Bool = false) FlxG.sound.playMusic(Paths.music(sound), volume, loop));
		registerFunction('playSound', function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false):String {
			if (tag != null && tag.length > 0) {
				var originalTag:String = tag;
				
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd = variables.get(tag);
				if (oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}

				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, () -> {
					if (!loop) variables.remove(tag);
					luaCallGlobal('onSoundFinished', [originalTag]);
				}));
				
				return tag;
			} else {
				FlxG.sound.play(Paths.sound(sound), volume);
			}
			return null;
		});
		registerFunction('stopSound', function(tag:String) {
			var snd:FlxSound = getSound(tag);
			snd?.stop();
			
			if (tag != null && tag.length > 0) {
				tag = LuaUtils.formatVariable('sound_$tag');
				MusicBeatState.getVariables().remove(tag);
			}
		});
		registerFunction('pauseSound', function(tag:String) getSound(tag)?.pause());
		registerFunction('resumeSound', function(tag:String) getSound(tag)?.resume());
		registerFunction('soundFadeIn', function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) getSound(tag)?.fadeIn(duration, fromValue, toValue));
		registerFunction('soundFadeOut', function(tag:String, duration:Float, toValue:Float = 0) getSound(tag)?.fadeOut(duration, toValue));
		registerFunction('soundFadeCancel', function(tag:String) getSound(tag)?.fadeTween?.cancel());
		registerFunction('getSoundVolume', function(tag:String) return (getSound(tag)?.volume ?? 0));
		registerFunction('setSoundVolume', function(tag:String, value:Float) {
			var snd:FlxSound = getSound(tag);
			if (snd != null) snd.volume = value;
		});
		registerFunction('getSoundTime', function(tag:String) return (getSound(tag)?.time ?? 0));
		registerFunction('setSoundTime', function(tag:String, value:Float) {
			var snd:FlxSound = getSound(tag);
			if (snd != null) snd.time = value;
		});
		registerFunction('getSoundPitch', function(tag:String) {
			#if FLX_PITCH
			return (getSound(tag)?.pitch ?? 1);
			#else
			luaTrace("getSoundPitch: Sound Pitch is not supported on this platform!", false, false, ERROR);
			return 1;
			#end
		});
		registerFunction('setSoundPitch', function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			var snd:FlxSound = getSound(tag);
			if (snd != null) {
				var wasResumed:Bool = snd.playing;
				if (doPause) snd.pause();
				snd.pitch = value;
				if (doPause && wasResumed) snd.play();
			}
			#else
			luaTrace("setSoundPitch: Sound Pitch is not supported on this platform!", false, false, ERROR);
			#end
		});
	}
	public static function implementGame(game:PlayState):Void {
		// trace('implement game functions');
		
		#if UNHOLYWANDERER04
		var unholyed:Bool = false;
		registerFunction(lua, 'unholywanderer04', function() {
			var fgame:Main.UnholyGame = cast FlxG.game;
			if (fgame.frameCounter % 2 == 1) {
				FlxG.resetGame();
			} else if (!unholyed) {
				var unholy:FlxSprite = new FlxSprite().loadGraphic(Paths.image('unholywanderer04', 'embed'));
				unholy.antialiasing = ClientPrefs.data.antialiasing;
				unholy.setGraphicSize(FlxG.width, FlxG.height);
				unholy.updateHitbox();
				unholy.alpha = 0;
				unholyed = true;
				game.uiGroup.insert(0, unholy);
				FlxTween.tween(unholy, {alpha: 1}, 3);
			}
		});
		#end
		
		registerFunction('addScore', function(value:Int = 0) {
			game.songScore += value;
			game.RecalculateRating();
		});
		registerFunction('addMisses', function(value:Int = 0) {
			game.songMisses += value;
			game.RecalculateRating();
		});
		registerFunction('addHits', function(value:Int = 0) {
			game.songHits += value;
			game.RecalculateRating();
		});
		registerFunction('setScore', function(value:Int = 0) {
			game.songScore = value;
			game.RecalculateRating();
		});
		registerFunction('setMisses', function(value:Int = 0) {
			game.songMisses = value;
			game.RecalculateRating();
		});
		registerFunction('setHits', function(value:Int = 0) {
			game.songHits = value;
			game.RecalculateRating();
		});
		registerFunction('setHealth', function(value:Float = 1) game.health = value);
		registerFunction('addHealth', function(value:Float = 0) game.health += value);
		registerFunction('getHealth', function() return game.health);
		registerFunction('setRatingPercent', function(value:Float) {
			game.ratingPercent = value;
			game.setOnScripts('rating', game.ratingPercent);
		});
		registerFunction('setRatingName', function(value:String) {
			game.ratingName = value;
			game.setOnScripts('ratingName', game.ratingName);
		});
		registerFunction('setRatingFC', function(value:String) {
			game.ratingFC = value;
			game.setOnScripts('ratingFC', game.ratingFC);
		});
		registerFunction('updateScoreText', function() game.updateScoreText());
		
		// precaching
		registerFunction('addCharacterToList', function(name:String, type:String) {
			game.addCharacterToList(name, switch (type.toLowerCase()) {
				case 'gf' | 'girlfriend': 2;
				case 'dad': 1;
				default: 0;
			});
		});
		
		// others
		registerFunction('triggerEvent', function(name:String, ?value1:String = '', ?value2:String = '') {
			game.triggerEvent(name, value1, value2, Conductor.songPosition);
			return true;
		});
		registerFunction('startCountdown', function() {
			game.startCountdown();
			return true;
		});
		registerFunction('endSong', function() {
			game.KillNotes();
			game.endSong();
			return true;
		});
		registerFunction('restartSong', function(skipTransition:Bool = false) {
			game.persistentUpdate = false;
			FlxG.camera.followLerp = 0;
			PlayState.restartSong(skipTransition);
			return true;
		});
		registerFunction('exitSong', function(skipTransition:Bool = false) {
			PlayState.exitSong(skipTransition);
			return true;
		});
		
		// idk bro
		registerFunction('setHealthBarColors', function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.healthBar.setColors(left_color, right_color);
		});
		registerFunction('setTimeBarColors', function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.timeBar.setColors(left_color, right_color);
		});
		registerFunction('startDialogue', function(dialogueFile:String, ?music:String = null) {
			var path:String;
			var songPath:String = Paths.formatToSongPath(Song.loadedSongName);
			#if TRANSLATIONS_ALLOWED
			path = Paths.getPath('data/$songPath/${dialogueFile}_${ClientPrefs.data.language}.json', TEXT);
			#if MODS_ALLOWED
			if(!FileSystem.exists(path))
			#else
			if(!Assets.exists(path, TEXT))
			#end
			#end
				path = Paths.getPath('data/$songPath/$dialogueFile.json', TEXT);

			// luaTrace('startDialogue: Trying to load dialogue: ' + path);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path, TEXT))
			#end
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if (shit.dialogue.length > 0) {
					game.startDialogue(shit, music);
					// luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				} else {
					luaTrace('startDialogue: Dialogue file is badly formatted', false, false, ERROR);
				}
			} else {
				luaTrace('startDialogue: Dialogue file not found', false, false, ERROR);
				if (game.endingSong) {
					game.endSong();
				} else {
					game.startCountdown();
				}
			}
			return false;
		});
		registerFunction('startVideo', function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true) {
			#if VIDEOS_ALLOWED
			if (FileSystem.exists(Paths.video(videoFile))) {
				if (game.videoCutscene != null) {
					game.remove(game.videoCutscene);
					game.videoCutscene.destroy();
				}
				game.videoCutscene = game.startVideo(videoFile, forMidSong, canSkip, shouldLoop, playOnLoad);
				return true;
			} else {
				luaTrace('startVideo: Video file not found: ' + videoFile, false, false, ERROR);
			}
			return false;

			#else
			PlayState.instance.inCutscene = true;
			new FlxTimer().start(0.1, function(tmr:FlxTimer) {
				PlayState.instance.inCutscene = false;
				if (game.endingSong) {
					game.endSong();
				} else {
					game.startCountdown();
				}
			});
			return true;
			#end
		});
		
		// character
		registerFunction('getCharacterX', function(type:String) {
			return switch(type.toLowerCase()) {
				case 'dad' | 'opponent': game.dadGroup.x;
				case 'gf' | 'girlfriend': game.gfGroup.x;
				default: game.boyfriendGroup.x;
			}
		});
		registerFunction('getCharacterY', function(type:String) {
			return switch(type.toLowerCase()) {
				case 'dad' | 'opponent': game.dadGroup.y;
				case 'gf' | 'girlfriend': game.gfGroup.y;
				default: game.boyfriendGroup.y;
			}
		});
		registerFunction('setCharacterX', function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': game.dadGroup.x = value;
				case 'gf' | 'girlfriend': game.gfGroup.x = value;
				default: game.boyfriendGroup.x = value;
			}
		});
		registerFunction('setCharacterY', function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': game.dadGroup.y = value;
				case 'gf' | 'girlfriend': game.gfGroup.y = value;
				default: game.boyfriendGroup.y = value;
			}
		});
		registerFunction('cameraSetTarget', function(target:String) {
			switch(target.trim().toLowerCase()) {
				case 'gf' | 'girlfriend': game.moveCamera(false, true);
				case 'dad' | 'opponent': game.moveCamera(true);
				default: game.moveCamera(false);
			}
		});
		
		// camfollow
		registerFunction('setCameraFollowPoint', function(x:Float, y:Float) game.camFollow.setPosition(x, y));
		registerFunction('addCameraFollowPoint', function(?x:Float = 0, ?y:Float = 0) {
			game.camFollow.x += x;
			game.camFollow.y += y;
		});
		registerFunction('getCameraFollowX', () -> game.camFollow.x);
		registerFunction('getCameraFollowY', () -> game.camFollow.y);
		
		//Tween shit, but for strums
		registerFunction('noteTweenX', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {x: value}, duration, ease));
		registerFunction('noteTweenY', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {y: value}, duration, ease));
		registerFunction('noteTweenAngle', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {angle: value}, duration, ease));
		registerFunction('noteTweenAlpha', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {alpha: value}, duration, ease));
		registerFunction('noteTweenDirection', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {direction: value}, duration, ease));
	}
}
#end
