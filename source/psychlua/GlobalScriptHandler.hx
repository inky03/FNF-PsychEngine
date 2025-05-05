package psychlua;

import flixel.FlxState;

class GlobalScriptHandler {
	public static var game(get, never):FlxState;
	public static var subState(get, never):FlxState;
	
	public static var resetting:Bool = false;
	
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
	public static var hscriptArray:Array<HScript> = []; // TODO: lua... also...
	public static function initHScript(file:String):HScript {
		var hs:HScript = HScript.initFromFile(file, null, HScriptGlobal);
		if (hs != null) hscriptArray.push(hs);
		
		return hs;
	}
	#end
	
	public static function init():Void {
		FlxG.signals.preUpdate.add(() -> call('onUpdate', [FlxG.elapsed]));
		FlxG.signals.postUpdate.add(() -> call('onUpdatePost', [FlxG.elapsed]));
	}
	public static function refreshScripts(complete:Bool = false):Void {
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
		
		var cleanup:Array<HScript> = [];
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
	
	static function findScript(path:String):HScript {
		return Lambda.find(hscriptArray, (hs:HScript) -> (hs.filePath == path));
	}
	static function destroyScript(hs:HScript):Void {
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

class HScriptGlobal extends HScript {
	public override function preset():Void {
		parentState = null;
		super.preset();
	}
	
	public override function getParent():Dynamic {
		return GlobalScriptHandler;
	}
	public override function getVariables():Map<String, Dynamic> {
		return HScript.globalStatic;
	}
}