package backend;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

class ScriptedState extends MusicBeatState {
	#if SCRIPTS_ALLOWED
	private var luaDebugGroup:FlxTypedSpriteGroup<DebugLuaText>;
	
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end
	
	public function addTextToDebug(text:String, color:FlxColor, size:Int = 16):DebugLuaText {
		var newText:DebugLuaText = luaDebugGroup.recycle(DebugLuaText);
		newText.size = size;
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
		return newText;
	}
	#end
	
	public override function preCreate():Void {
		super.preCreate();
		
		#if (SCRIPTS_ALLOWED)
		luaDebugGroup = new FlxTypedSpriteGroup();
		luaDebugGroup.scrollFactor.set();
		#end
		
		#if SCRIPTS_ALLOWED startStateScripts(); #end
	}
	public override function create():Void {
		super.create();
		callOnScripts('onCreatePost');
		
		#if (SCRIPTS_ALLOWED)
		luaDebugGroup.cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		add(luaDebugGroup);
		trace(luaDebugGroup.cameras);
		trace(members.indexOf(luaDebugGroup));
		#end
	}
	
	public function preUpdate(elapsed:Float):Void {
		callOnScripts('onUpdate', [elapsed]);
	}
	public function postUpdate(elapsed:Float):Void {
		callOnScripts('onUpdatePost', [elapsed]);
	}
	
	public override function destroy():Void {
		#if SCRIPTS_ALLOWED destroyScripts(); #end
		super.destroy();
	}
	
	#if SCRIPTS_ALLOWED
	public function startStateScripts():Void {
		var clsName:String = Type.getClassName(Type.getClass(this));
		var stateName:String = clsName.substr(clsName.indexOf('.') + 1);
		
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts')) {
			var file:String = '$folder/states/$stateName.hx';
			if (FileSystem.exists(file))
				initHScript(file);
		}
	}
	public function destroyScripts():Void {
		#if LUA_ALLOWED
		for (lua in luaArray) {
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray) {
			if (script != null) {
				if (script.exists('onDestroy')) script.call('onDestroy');
				script.destroy();
			}
		}
		hscriptArray = null;
		#end
	}
	#end
	
	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
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
	public function initLuaScript(scriptFile:String) {
		var newScript:FunkinLua = null;
		try {
			newScript = new FunkinLua(scriptFile, this);
			newScript.call('onCreate', []);
			trace('lua file loaded succesfully:' + scriptFile);
			luaArray.push(newScript);
		} catch(e:Dynamic) {
			addTextToDebug('FATAL: $e', 0xffbb0000, 18);
			newScript = null;
		}
		
		return newScript;
	}
	#end
	
	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
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
	public function initHScript(file:String) {
		var newScript:HScript = null;
		try {
			newScript = new HScript(null, file, null, true, this);
			newScript.unsafe = true;
			newScript.execute();
			
			if (newScript.exists('onCreate'))
				newScript.call('onCreate');
			
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
			newScript.unsafe = false;
		} catch(e:Dynamic) {
			var script:HScript = cast (Iris.instances.get(file), HScript);
			if (Std.isOfType(e, IrisError)) {
				var pos:HScriptInfos = cast {showLine: true, isLua: false, fileName: e.origin, lineNumber: e.line};
				Iris.fatal(Printer.errorToString(e, false), pos);
			} else {
				var pos:HScriptInfos = @:privateAccess { cast script.interp.posInfos(); }
				Iris.fatal(Std.string(e), pos);
			}
			
			script?.destroy();
			newScript = null;
		}
		
		return newScript;
	}
	#end
	
	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}
	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if(script.closed)
			{
				arr.push(script);
				continue;
			}

			if(exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if(myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if(script.closed) arr.push(script);
		}

		if(arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}
	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = new Array();
		if(excludeValues == null) excludeValues = new Array();
		excludeValues.push(LuaUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;

		for(script in hscriptArray)
		{
			@:privateAccess
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if(callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if(myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}
	
	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}
	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}
	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}
}