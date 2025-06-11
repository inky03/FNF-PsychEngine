package psychlua;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

class HScriptMacro {
	static macro function buildInterp():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		for (field in fields) {
			if (field.name == 'setVar' && field.access != null) // DE-INLINE METHOD
				field.access.remove(Access.AInline);
		}
		
		return fields;
	}
}

#else

import flixel.FlxState;
import flixel.FlxSubState;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import psychlua.LuaUtils;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
}

class HScript extends Iris {
	public var closed:Bool = false;
	public var filePath:String;
	public var modFolder:String;
	public var returnValue:Dynamic;
	public var parentState:FlxState = null;
	
	public static var globalStatic(default, never):Map<String, Dynamic> = [];

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	public static function initHaxeModule(parent:FunkinLua) {
		if (parent.hscript == null) {
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent, null, null, null, parent.parentState);
		}
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null) {
		var hs:HScript = try parent.hscript catch (e) null;
		if (hs == null) {
			trace('initializing haxe interp for: ${parent.scriptName}');
			try {
				parent.hscript = new HScript(parent, code, varsToBring, null, parent.parentState);
			} catch(e:Dynamic) {
				catchError(hs, e, parent.lastCalledFunction);
				parent.hscript = null;
			}
		}
		else
		{
			try {
				hs.scriptCode = code;
				hs.varsToBring = varsToBring;
				hs.parse(true);
				var ret:Dynamic = hs.execute();
				hs.returnValue = ret;
			} catch(e:Dynamic) {
				catchError(hs, e, parent.lastCalledFunction);
				parent.hscript = null;
			}
		}
	}
	#end
	
	public static function init():Void {
		Iris.logLevel = (level:ErrorSeverity, x:Dynamic, ?pos:haxe.PosInfos) -> {
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			
			Log.print('$msgInfo $x', errorSeverityToLog(level));
		}
	}
	
	static function errorSeverityToLog(level:ErrorSeverity):LogType {
		return switch (level) {
			case NONE: INFO;
			case WARN: WARN;
			case ERROR: ERROR;
			case FATAL: FATAL;
		}
	}
	
	public var origin:String;
	public var unsafe:Bool = false;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false, ?state:FlxState) {
		parentState = state ?? FlxG.state;
		
		if (file == null)
			file = '';

		filePath = file;
		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
			#if MODS_ALLOWED
			var myFolder:Array<String> = filePath.split('/');
			if(myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
				this.modFolder = myFolder[1];
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = File.getContent(f);
				scriptName = f;
			}
		}
		#if LUA_ALLOWED
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;
		#end
		
		super(scriptThing, new IrisConfig(scriptName, false, false));
		Iris.instances.set(scriptName, this); // idgaf
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = getParent();
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null)
		{
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end
		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:Dynamic) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}
	
	public static function initFromFile(file:String, ?parent:FlxState, ?base:Class<HScript>) {
		var newScript:HScript = null;
		
		try {
			newScript = Type.createInstance(base ?? HScript, [null, file, null, true, parent]);
			newScript.unsafe = true;
			newScript.execute();
			
			if (newScript.exists('onCreate'))
				newScript.call('onCreate');
			
			trace('initialized hscript interp successfully: $file');
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

	var varsToBring(default, set):Any = null;
	override function preset() {
		super.preset();
		
		// Some very commonly used classes
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('PsychCamera', backend.PsychCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('Countdown', backend.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		set('Character', objects.Character);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('FunkinLua', FunkinLua);
		set('CustomState', CustomState);
		set('CustomSubstate', CustomSubstate);
		set('MusicBeatState', MusicBeatState);
		set('MusicBeatSubstate', MusicBeatSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		#end

		// Functions & Variables
		var variableMap:Map<String, Dynamic> = getVariables();
		
		if (parentState != null) {
			var cls = Type.getClass(parentState);
			var clsName:String = Type.getClassName(cls);
			var stateName:String = clsName.substr(clsName.indexOf('.') + 1);
			
			set('game', parentState);
			set(stateName, cls);
		}
		
		set('global', variableMap);
		set('globalStatic', HScript.globalStatic);
		set('setVar', function(name:String, value:Dynamic) {
			variableMap?.set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			return variableMap?.get(name);
		});
		set('hasVar', function(name:String) {
			return variableMap?.exists(name);
		});
		set('removeVar', function(name:String) {
			if (variableMap?.exists(name) ?? false) {
				variableMap.remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, color:FlxColor = FlxColor.WHITE) {
			return ScriptedState.debugPrint(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					Iris.error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', this.interp.posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});
		
		set('parentLua', null);
		
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			if (!Reflect.isFunction(func)) {
				Iris.error('createGlobalCallback ($name): 2nd argument is not a function', this.interp.posInfos());
				return;
			}
			
			for (script in PlayState.instance.luaArray) {
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);
			}
			
			FunkinLua.customFunctions.set(name, func);
		});
		
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null)
		{
			if (!Reflect.isFunction(func)) {
				Iris.error('createCallback ($name): 2nd argument is not a function', this.interp.posInfos());
				return;
			}
			
			if(funk == null) funk = parentLua;
			
			if(funk != null) funk.addLocalCallback(name, func);
			else Iris.error('createCallback ($name): 3rd argument is null', this.interp.posInfos());
		});
		
		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			} catch (e:Dynamic) {
				catchError(this, e);
			}
		});
		#end
		
		set('this', this);
		set('controls', Controls.instance);

		set('buildTarget', LuaUtils.getBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua); //doesnt do much cuz HScript has a lower priority than Lua
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
	}
	
	public function getParent():Dynamic {
		return parentState;
	}
	public function getVariables():Map<String, Dynamic> {
		return parentState?.extraData;
	}

	#if LUA_ALLOWED
	public static function implementLocal(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if (funk.hscript.returnValue != null)
				{
					return funk.hscript.returnValue;
				}
			}
			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: funk.scriptName, showLine: false};
				if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		// This function is unnecessary because import already exists in HScript as a native feature
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if (libPackage.length > 0)
				str = libPackage + '.';
			else if (libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (funk.hscript == null)
				initHaxeModule(funk);

			var pos:HScriptInfos = cast funk.hscript.interp.posInfos();
			pos.showLine = false;
			if (funk.lastCalledFunction != '')
				 pos.funcName = funk.lastCalledFunction;

			try {
				if (c != null)
					funk.hscript.set(libName, c);
			} catch (e:Dynamic) {
				catchError(funk.hscript, e);
			}
			FunkinLua.lastCalledScript = funk;
			if (FunkinLua.getBool('luaDebugMode') && FunkinLua.getBool('luaDeprecatedWarnings'))
				Iris.warn("addHaxeLibrary is deprecated! Import classes through \"import\" in HScript!", pos);
		});
	}
	#end

	override function call(funcToRun:String, ?args:Array<Dynamic>):IrisCall {
		if (funcToRun == null || interp == null) return null;

		if (!exists(funcToRun)) {
			Iris.error('No function named: $funcToRun', this.interp.posInfos());
			return null;
		}
		
		try {
			var func:Dynamic = interp.variables.get(funcToRun); // function signature
			final ret = Reflect.callMethod(null, func, args ?? []);
			
			return {funName: funcToRun, signature: func, returnValue: ret};
		} catch(e:Dynamic) {
			catchError(this, e, funcToRun);
		}
		return null;
	}
	
	public static function catchError(hs:HScript, e:Dynamic, ?funcToRun:String):Void {
		if (hs.unsafe) {
			throw e;
			return;
		}
		
		var pos:HScriptInfos = cast hs.interp.posInfos();
		pos.funcName = funcToRun;
		#if LUA_ALLOWED
		if (hs.parentLua != null) {
			pos.isLua = true;
			if (hs.parentLua.lastCalledFunction != '')
				pos.funcName = hs.parentLua.lastCalledFunction;
		}
		#end
		
		var errorString:String = 'Unknown Error';
		if (Std.isOfType(e, IrisError)) {
			errorString = Printer.errorToString(e, false);
		} else if (e != null) {
			errorString = Std.string(e);
		}
		
		(hs.unsafe ? Iris.fatal : Iris.error) (errorString, pos);
	}

	override public function destroy() {
		origin = null;
		closed = true;
		#if LUA_ALLOWED parentLua = null; #end
		super.destroy();
	}

	function set_varsToBring(values:Any) {
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				if (exists(key.trim()))
					interp.variables.remove(key.trim());

		if (values != null)
		{
			for (key in Reflect.fields(values))
			{
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}

class CustomInterp extends crowplexus.hscript.Interp {
	public var parentInstance(default, set):Dynamic = null;
	var _instanceFields:Array<String> = [];
	
	function set_parentInstance(inst:Dynamic):Dynamic {
		if (inst == null) {
			_instanceFields = [];
			return parentInstance = inst;
		}
		
		if (inst is Class) {
			_instanceFields = Type.getClassFields(inst);
		} else {
			_instanceFields = Type.getInstanceFields(Type.getClass(inst));
		}
		return parentInstance = inst;
	}

	public function new() {
		super();
	}
	
	override function get(o:Dynamic, id:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(id));
		
		var val:Dynamic = Reflect.getProperty(o, id);
		val ??= Reflect.field(o, id);
		
		if (val == null && !LuaUtils.hasField(o, id) && o is FlxBasic) {
			return cast(o, FlxBasic).getVar(id);
		} else {
			return val;
		}
	}
	override function set(o:Dynamic, id:String, v:Dynamic):Dynamic {
		if (o == null)
			error(EInvalidAccess(id));
		
		try {
			Reflect.setProperty(o, id, v);
		} catch (e:Dynamic) {
			if (o.setVar != null) {
				o.setVar(id, v);
			} else {
				throw e;
			}
		}
		return v;
	}
	override function resolve(id:String):Dynamic {
		if (locals.exists(id)) 
			return locals.get(id).r;
		if (variables.exists(id))
			return variables.get(id);
		if (imports.exists(id))
			return imports.get(id);
		
		#if LUA_ALLOWED
		if (FunkinLua.customFunctions.exists(id))
			return FunkinLua.customFunctions.get(id);
		#end
		if (parentInstance != null) {
			if (_instanceFields.contains(id)) {
				return Reflect.getProperty(parentInstance, id);
			} else if (parentInstance is FlxBasic) {
				var basic:FlxBasic = cast parentInstance;
				if (basic.hasVar(id))
					return basic.getVar(id);
			}
		}
		
		error(EUnknownVariable(id));
		return null;
	}
	override function setVar(id:String, v:Dynamic):Void {
		if (parentInstance != null) {
			if (_instanceFields.contains(id)) {
				return Reflect.setProperty(parentInstance, id, v);
			} else if (parentInstance is FlxBasic) {
				var basic:FlxBasic = cast parentInstance;
				if (basic.hasVar(id)) {
					basic.setVar(id, v);
					return;
				}
			}
		}
		
		variables.set(id, v);
		
		// error(EUnknownVariable(id));
		// having "global variables" is pretty pointless,
		// but i figure disabling it would cause issues on existing scripts
	}
}
#else
class HScript
{
	public static function init():Void {}
	
	#if LUA_ALLOWED
	public static function implement() {
		FunkinLua.registerFunction("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
		FunkinLua.registerFunction("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
		FunkinLua.registerFunction("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
	}
	#end
}
#end
#end