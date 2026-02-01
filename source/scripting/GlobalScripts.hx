package scripting;

#if GLOBAL_SCRIPTS
import flixel.FlxState;

import insanity.Environment;

import scripting.lua.LuaUtils;
import scripting.hscript.FunkinHscript;

class GlobalScripts {
	public static var game(get, never):FlxState;
	public static var subState(get, never):FlxState;
	
	public static var resetting:Bool = false;
	
	public static var environment:Environment = new Environment();
	
	static function get_game():FlxState {
		return FlxG.state;
	}
	static function get_subState():FlxState {
		var subState:FlxState = FlxG.state;
		
		while (subState.subState != null)
			subState = subState.subState;
		
		return subState;
	}
	
	#if HSCRIPT_ALLOWED
	public static var hscriptArray:Array<FunkinHscript> = []; // TODO: lua... also...
	public static function initHScript(file:String):FunkinHscript {
		var hs:FunkinHscript = FunkinHscript.initFromFile(file, null, FunkinGlobalHscript);
		if (hs != null) hscriptArray.push(hs);
		
		return hs;
	}
	#end
	
	public static function init():Void {
		FlxG.signals.preUpdate.add(() -> call('onUpdate', [FlxG.elapsed]));
		FlxG.signals.postUpdate.add(() -> call('onUpdatePost', [FlxG.elapsed]));
		FlxG.signals.preDraw.add(() -> call('onDraw'));
		FlxG.signals.postDraw.add(() -> call('onDrawPost'));
	}
	public static function refresh(complete:Bool = false):Void {
		var tracked:Array<String> = [];
		resetting = true;
		
		if (complete)
			destroyScripts();
		
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/global')) {
			for (file in FileSystem.readDirectory(folder)) {
				var path:String = '$folder/$file';
				
				if (FileSystem.exists(path)) {
					if (findScript(path) != null || initHScript(path) != null)
						tracked.push(path);
				}
			}
		}
		
		var cleanup:Array<FunkinHscript> = [];
		for (hs in hscriptArray) {
			if (!tracked.contains(hs.filePath)) {
				destroyScript(hs);
				cleanup.push(hs);
			}
		}
		while (cleanup.length > 0)
			hscriptArray.remove(cleanup.shift());
	}
	public static function destroyScripts():Void {
		#if HSCRIPT_ALLOWED
		for (hs in hscriptArray)
			destroyScript(hs);
		hscriptArray.resize(0);
		#end
	}
	
	static function findScript(path:String):FunkinHscript {
		return Lambda.find(hscriptArray, (hs:FunkinHscript) -> (hs.filePath == path));
	}
	static function destroyScript(hs:FunkinHscript):Void {
		if (hs.exists('onDestroy'))
			hs.call('onDestroy');
		hs.destroy();
	}
	
	public static function call(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>):Dynamic {
		return callOnHScript(func, args, excludeValues);
	}
	public static function callOnHScript(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return returnVal;
		
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		for (script in hscriptArray) {
			if (script == null || !script.exists(func))
				continue;
			
			var callValue:Dynamic = script.call(func, args);
			if (callValue != null) {
				var myValue:Dynamic = callValue.returnValue;
				
				if (myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) {
					return LuaUtils.Function_Stop;
				} else if (myValue != null && !excludeValues.contains(myValue)) {
					return myValue;
				}
			}
		}
		#end
		
		return returnVal;
	}
	
	public static function set(variable:String, args:Dynamic):Void {
		setOnHScript(variable, args);
	}
	public static function setOnHScript(variable:String, args:Dynamic):Void {
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return;
		
		for (script in hscriptArray)
			script.set(variable, args);
		#end
	}
}

class FunkinGlobalHscript extends FunkinHscript {
	public override function setDefaults():Void {
		parentState = null;
		super.setDefaults();
	}
	
	public override function getParent():Dynamic {
		return GlobalScripts;
	}
	public override function getVariables():Map<String, Dynamic> {
		return FunkinHscript.globalStatic;
	}
}
#end