package;

#if android
import android.content.Context;
#end

import debug.FPSCounter;
import debug.ScriptTraceDisplay;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;
import psychlua.GlobalScriptHandler;
import psychlua.HScript;

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;
import backend.ScriptedState;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static final game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};
	public static var appName(default, null):String;
	
	public static var fpsVar:FPSCounter;
	public static var traces:ScriptTraceDisplay;
	
	// You can pretty much ignore everything from here on - your code should go in your states.
	
	public function new()
	{
		super();
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
		
		appName = (FlxG.stage.application.meta.get('file') ?? 'PsychEngineMint');
		
		#if (cpp && windows)
		backend.Native.fixScaling();
		#end
		
		// Credits to MAJigsaw77 (he's the og author for this code)
		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end
		
		#if hxvlc
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end
		
		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		
		FlxG.signals.postGameReset.add(function() {
			#if (!html5 && !switch) FlxG.autoPause = ClientPrefs.data.autoPause; #end
			FlxG.fixedTimestep = false;
		});
		
		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Controls.instance = new Controls();
		Language.reloadPhrases();
		Difficulty.resetList();
		
		#if HSCRIPT_ALLOWED HScript.init(); #end
		#if GLOBAL_SCRIPTS GlobalScriptHandler.init(); #end
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		addChild(new #if UNHOLYWANDERER04 UnholyGame #else FlxGame #end(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		
		ClientPrefs.loadPrefs();
		Highscore.load();
		
		substates.OutdatedSubState.updateVersion = CoolUtil.checkForUpdates();
		
		traces = new ScriptTraceDisplay();
		addChild(traces);
		
		#if !mobile
		fpsVar = new FPSCounter(12, 4, 0xffffff);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		#end
		
		#if (linux || mac) // fix the app icon not showing up on the Linux Panel / Mac Dock
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end
		
		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		
		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end
		
		// shader coords fix
		FlxG.signals.gameResized.add((w:Int, h:Int) -> {
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});
	}
	
	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}
	
	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var gh:String = 'https://github.com/inky03/FNF-PsychEngineMint'; // change this link to your actual repository if you're modding !
		var dateNow:String = Date.now().toString().replace(' ', '_').replace(':', "'"); // yayyyy
		
		var errMsg:String = 'UNCAUGHT EXCEPTION: ${e.error}\n\nSTACK TRACEBACK:';
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		
		function stackItemToString(stackItem:haxe.CallStack.StackItem) {
			return switch (stackItem) {
				case FilePos(s, file, line, col):
					'$file:${col == null ? '' : ':$col'}$line (${stackItemToString(s)})';
				case CFunction:
					'Function from C';
				case Module(m):
					'Module $m';
				case Method(cls, method):
					'Method ${cls ?? '<unknown>'}.$method';
				case LocalFunction(n):
					'Local function #$n';
			}
		}
		
		for (stackItem in callStack)
			errMsg += ('\n' + stackItemToString(stackItem));
		
		var errText:String = '$appName ${states.MainMenuState.modVersion}\n\n$errMsg\n\n$gh\n';
		
		#if sys
		var path:String = './crash/${appName}_$dateNow.txt';
		errMsg += '\n\nA crash dump has been saved in ${Path.normalize(path)}';
		#end
		
		#if officialBuild
		errMsg += '\n\nIf you believe this error was caused by the engine, report this issue at $gh';
		#end
		errMsg += '\n\n> Crash Handler written by sqirra-rng';
		
		#if sys
		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		
		File.saveContent(path, errText);
		Sys.println(errText);
		#end
		
		Application.current.window.alert(errMsg, 'Oops...');
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		#if sys
		Sys.exit(1);
		#end
	}
	#end
}

#if UNHOLYWANDERER04
class UnholyGame extends flixel.FlxGame {
	public var frameCounter:Int = 0;
	
	override function onEnterFrame(_) {
		super.onEnterFrame(_);
		frameCounter ++;
	}
}
#end