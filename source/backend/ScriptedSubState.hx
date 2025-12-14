package backend;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

#if SCRIPTS_ALLOWED
import psychlua.GlobalScriptHandler;
#end

/**
 * ScriptedSubState is the base for scripted states and sub-states in the game.
 * It automatically handles script initialization and most generic script calls.
 * 
 * ## Generic script calls
 * ```haxe
 * function onCreate() {}
 * function onCreatePost() {}
 * 
 * function onUpdate(elapsed:Float) {}
 * function onUpdatePost(elapsed:Float) {}
 * 
 * function onDraw() {}
 * function onDrawPost() {}
 * 
 * function onStepHit(step:Int) {}
 * function onBeatHit(beat:Int) {}
 * function onSectionHit(measure:Int) {}
 * 
 * function onClose() {}
 * ```
*/
class ScriptedSubState extends MusicBeatSubstate {
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end
	
	var multiScript:Bool = true;
	var loadedScripts:Bool = false;
	
	public var data:Dynamic = null;
	public var scriptFolder:String = 'scripts';
	
	public function new(?data:Dynamic) {
		super();
		this.data = data;
	}
	public override function create():Void {
		super.create();
	}
	override function _preCreate():Void {
		#if SCRIPTS_ALLOWED startStateScripts(); #end
		
		#if GLOBAL_SCRIPTS GlobalScriptHandler.call('onCreateSubState', [this]); #end
	}
	override function _postCreate():Void {
		callOnScripts('onCreatePost');
		
		#if GLOBAL_SCRIPTS GlobalScriptHandler.call('onCreateSubStatePost', [this]); #end
	}
	
	var _shouldUpdate:Bool = true;
	public function preUpdate(elapsed:Float):Void {
		_shouldUpdate = (callOnScripts('onUpdate', [elapsed], true) != LuaUtils.Function_Stop);
	}
	public override function update(elapsed:Float):Void {
		if (_shouldUpdate)
			super.update(elapsed);
		_shouldUpdate = true;
	}
	public function postUpdate(elapsed:Float):Void {
		callOnScripts('onUpdatePost', [elapsed]);
	}
	
	public override function updatePresence():Void {
		if (callOnScripts('onUpdatePresence', [rpcDetails, rpcState], true) != LuaUtils.Function_Stop)
			super.updatePresence();
	}
	
	public override function draw():Void {
		if (callOnScripts('onDraw', true) == LuaUtils.Function_Stop) return;
		super.draw();
		callOnScripts('onDrawPost');
	}
	
	public override function openSubState(subState:flixel.FlxSubState):Void {
		var stopped:Bool = (callOnHScript('onOpenSubState', [subState], true) == LuaUtils.Function_Stop);
		stopped = (stopped || callOnLuas('onOpenSubState', [getStateName(subState)], true) == LuaUtils.Function_Stop);
		
		if (!stopped)
			super.openSubState(subState);
	}
	
	public override function close():Void {
		if (callOnScripts('onClose', true) != LuaUtils.Function_Stop #if GLOBAL_SCRIPTS && GlobalScriptHandler.call('onCloseSubState', [this]) != LuaUtils.Function_Stop #end)
			super.close();
	}
	
	public override function sectionHit(section:Int):Void {
		super.sectionHit(section);
		
		callOnScripts('onSectionHit', [section]);
	}
	public override function beatHit(beat:Int):Void {
		super.beatHit(beat);
		
		callOnScripts('onBeatHit', [beat]);
	}
	public override function stepHit(step:Int):Void {
		super.stepHit(step);
		
		callOnScripts('onStepHit', [step]);
	}
	
	override function updateSection():Void {
		super.updateSection();
		
		setOnLuas('curSection', curSection);
		setOnLuas('curDecSection', curDecSection);
	}
	override function updateBeat():Void {
		super.updateBeat();
		
		setOnLuas('curBeat', curBeat);
		setOnLuas('curDecBeat', curDecBeat);
	}
	override function updateStep():Void {
		super.updateStep();
		
		setOnLuas('curStep', curStep);
		setOnLuas('curDecStep', curDecStep);
	}
	
	public override function destroy():Void {
		#if SCRIPTS_ALLOWED destroyScripts(); #end
		super.destroy();
	}
	
	/**
	 * Gets the name used in a [scripted] state to find and load scripts.
	 * 
	 * @return 	Custom state name.
	*/
	public static function getStateName(state:flixel.FlxState):String { // Used to load the appropriate substate script
		if (state is ScriptedSubState) {
			return cast(state, ScriptedSubState).customStateName();
		} else {
			var clsName:String = Type.getClassName(Type.getClass(state));
			return clsName.substr(clsName.lastIndexOf('.') + 1);
		}
	}
	/**
	 * Used to find and load state scripts.
	*/
	public function customStateName():String { 
		var clsName:String = Type.getClassName(Type.getClass(this));
		return clsName.substr(clsName.lastIndexOf('.') + 1);
	}
	function getFolderName():String {
		return 'substates';
	}
	
	#if SCRIPTS_ALLOWED
	@:dox(hide) function startStateScripts():Bool {
		loadedScripts = false;
		
		#if HSCRIPT_ALLOWED
		loadedScripts = startHScripts();
		#end
		#if LUA_ALLOWED
		if (multiScript || !loadedScripts)
			loadedScripts = (startLuas() || loadedScripts);
		#end
		
		return loadedScripts;
	}
	
	@:dox(hide) function destroyScripts():Void {
		#if LUA_ALLOWED
		for (lua in luaArray) {
			lua.call('onDestroy');
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray) {
			if (script.exists('onDestroy'))
				script.call('onDestroy');
			script.destroy();
		}
		hscriptArray = null;
		#end
	}
	#end
	
	#if LUA_ALLOWED
	@:dox(hide) function startLuas():Bool {
		var loaded:Bool = false;
		
		if (multiScript) {
			for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), scriptFolder)) {
				var prefix:String = getFolderName();
				if (prefix.length > 0) prefix += '/';
				
				var path:String = '$folder/$prefix${customStateName()}.lua';
				if (FileSystem.exists(path))
					loaded = (initLuaScript(path) != null || loaded);
			}
		} else {
			var prefix:String = getFolderName();
			if (prefix.length > 0) prefix += '/';
			
			var file:String = 'scripts/$prefix${customStateName()}.lua';
			var path:String = Paths.modFolders(file);
			if (FileSystem.exists(path))
				loaded = (initLuaScript(path) != null);
		}
		
		return loaded;
	}
	/**
	 * Initializes Lua scripts with a matching name and adds them to the state.
	 * 
	 * @param 	file 	The mod folder path to the Lua scripts.
	 * 
	 * @return 	Whether or not any scripts of that name were found and initialized.
	*/
	public function startLuasNamed(luaFile:String) {
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if(script.scriptName == luaToLoad) return false;

			initLuaScript(luaToLoad);
			return true;
		}
		return false;
	}
	/**
	 * Initializes a Lua script and adds it to the state.
	 * 
	 * @param 	file 	The relative path to the Lua script.
	 * 
	 * @return 	A new `FunkinLua` instance if successful, otherwise `null`.
	*/
	public function initLuaScript(file:String):FunkinLua {
		var lua:FunkinLua = FunkinLua.initFromFile(file, this);
		if (lua != null) luaArray.push(lua);
		
		return lua;
	}
	
	/**
	 * Called when a Lua script is initialized in this state.
	 * You can use this function to implement custom API functions or set custom variables per state.
	 * 
	 * ```haxe
	 * public override function implementLua(lua:FunkinLua):Void {
	 * 	lua.set("customVariable", 1234);
	 * 	lua.addLocalCallback("customFunction", function() {
	 * 		return "Hi!!";
	 * 	});
	 * }
	 * ```
	*/
	public function implementLua(lua:FunkinLua):Void {}
	#end
	
	#if HSCRIPT_ALLOWED
	function startHScripts():Bool {
		var loaded:Bool = false;
		
		if (multiScript) {
			for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), scriptFolder)) {
				var prefix:String = getFolderName();
				if (prefix.length > 0) prefix += '/';
				
				var path:String = '$folder/$prefix${customStateName()}.hx';
				if (FileSystem.exists(path))
					loaded = (initHScript(path) != null || loaded);
			}
		} else {
			var prefix:String = getFolderName();
			if (prefix.length > 0) prefix += '/';
			
			var file:String = '$scriptFolder/$prefix${customStateName()}.hx';
			var path:String = Paths.modFolders(file);
			if (FileSystem.exists(path))
				loaded = (initHScript(path) != null);
		}
		
		return loaded;
	}
	public function startHScriptsNamed(scriptFile:String) {
		#if MODS_ALLOWED
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);
		#else
		var scriptToLoad:String = Paths.getSharedPath(scriptFile);
		#end

		if(FileSystem.exists(scriptToLoad)) {
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}
	public function initHScript(file:String):HScript {
		var hs:HScript = HScript.initFromFile(file, this);
		if (hs != null) hscriptArray.push(hs);
		
		return hs;
	}
	#end
	
	/**
	 * Calls a function on all scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnScripts(func:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		var result:Dynamic = callOnLuas(func, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(func, args, ignoreStops, exclusions, excludeValues);
		
		return result;
	}
	/**
	 * Calls a function on all scripts. Separates Lua and HScript arguments.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	argsLua 		An `Array` with the parameters to use in the function call in Lua scripts.
	 * @param 	argsHScript 	An `Array` with the parameters to use in the function call in HScript scripts.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnScriptsExt(func:String, ?argsLua:Array<Dynamic>, ?argsHScript:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		var result:Dynamic = callOnLuas(func, argsLua, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(func, argsHScript, ignoreStops, exclusions, excludeValues);
		
		return result;
	}
	/**
	 * Calls a function on all Lua scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnLuas(func:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if (luaArray == null) return returnVal;
		
		exclusions ??= [];
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);

		var arr:Array<FunkinLua> = [];
		for (script in luaArray) 	{
			if (script.closed) {
				arr.push(script);
				continue;
			}

			if (exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(func, args);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed) arr.push(script);
		}

		if (arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}
	/**
	 * Calls a function on all HScript scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnHScript(funcToCall:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return returnVal;
		
		exclusions ??= [];
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		for (script in hscriptArray) {
			if (script.closed || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if (callValue != null) {
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
					returnVal = myValue;
					break;
				}

				if (myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}
	
	/**
	 * Sets a variable on all scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnScripts(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		setOnLuas(variable, value, exclusions);
		setOnHScript(variable, value, exclusions);
	}
	/**
	 * Sets a variable on all Lua scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnLuas(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		#if LUA_ALLOWED
		if (luaArray == null) return;
		
		exclusions ??= [];
		for (script in luaArray) {
			if (script.closed || exclusions.contains(script.scriptName))
				continue;

			script.set(variable, value);
		}
		#end
	}
	/**
	 * Sets a variable on all HScript scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnHScript(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return;
		
		exclusions ??= [];
		for (script in hscriptArray) {
			if (script.closed || exclusions.contains(script.origin))
				continue;

			script.set(variable, value);
		}
		#end
	}
}