package psychlua;

#if macro

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

class ExtraDataMacro {
	static macro function build():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		fields = fields.concat([{
			pos: pos,
			name: 'extraData',
			access: [APublic],
			kind: FieldType.FProp('default', 'null', macro:Map<String, Dynamic>, macro $v{[]})
		}, {
			pos: pos,
			name: 'getVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Dynamic,
				args: [{type: macro:String, name: 'id'}],
				expr: macro { return extraData.get(id); }
			})
		}, {
			pos: pos,
			name: 'setVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Dynamic,
				args: [{type: macro:String, name: 'id'}, {type: macro:Dynamic, name: 'value'}],
				expr: macro { extraData.set(id, value); return value; }
			})
		}, {
			pos: pos,
			name: 'removeVar',
			access: [APublic],
			kind: FieldType.FFun({
				args: [{type: macro:String, name: 'id'}],
				expr: macro { extraData.remove(id); }
			})
		}, {
			pos: pos,
			name: 'hasVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Bool,
				args: [{type: macro:String, name: 'id'}],
				expr: macro { return extraData.exists(id); }
			})
		}]);
		
		return fields;
	}
}

#else

import backend.WeekData;
import objects.Character;
import backend.StageData;

import openfl.display.BlendMode;
import Type.ValueType;

import substates.GameOverSubstate;

typedef LuaTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class LuaUtils
{
	public static final Function_Stop:String = "##PSYCHLUA_FUNCTIONSTOP";
	public static final Function_Continue:String = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static final Function_StopLua:String = "##PSYCHLUA_FUNCTIONSTOPLUA";
	public static final Function_StopHScript:String = "##PSYCHLUA_FUNCTIONSTOPHSCRIPT";
	public static final Function_StopAll:String = "##PSYCHLUA_FUNCTIONSTOPALL";
	
	public static function getLuaTween(options:Dynamic) {
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		} : null;
	}
	
	public static function getModSetting(saveTag:String, ?modName:String = null) {
		#if MODS_ALLOWED
		if(FlxG.save.data.modSettings == null) FlxG.save.data.modSettings = new Map<String, Dynamic>();

		var settings:Map<String, Dynamic> = FlxG.save.data.modSettings.get(modName);
		var path:String = Paths.mods('$modName/data/settings.json');
		if(FileSystem.exists(path))
		{
			if(settings == null || !settings.exists(saveTag))
			{
				if(settings == null) settings = new Map<String, Dynamic>();
				var data:String = File.getContent(path);
				try
				{
					//FunkinLua.luaTrace('getModSetting: Trying to find default value for "$saveTag" in Mod: "$modName"');
					var parsedJson:Dynamic = tjson.TJSON.parse(data);
					for (i in 0...parsedJson.length)
					{
						var sub:Dynamic = parsedJson[i];
						if(sub != null && sub.save != null && !settings.exists(sub.save))
						{
							if(sub.type != 'keybind' && sub.type != 'key')
							{
								if(sub.value != null)
								{
									//FunkinLua.luaTrace('getModSetting: Found unsaved value "${sub.save}" in Mod: "$modName"');
									settings.set(sub.save, sub.value);
								}
							}
							else
							{
								//FunkinLua.luaTrace('getModSetting: Found unsaved keybind "${sub.save}" in Mod: "$modName"');
								settings.set(sub.save, {keyboard: (sub.keyboard != null ? sub.keyboard : 'NONE'), gamepad: (sub.gamepad != null ? sub.gamepad : 'NONE')});
							}
						}
					}
					FlxG.save.data.modSettings.set(modName, settings);
				}
				catch(e:Dynamic)
				{
					var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
					var errorMsg = 'An error occurred: $e';
					#if windows
					lime.app.Application.current.window.alert(errorMsg, errorTitle);
					#end
					trace('$errorTitle - $errorMsg');
				}
			}
		}
		else
		{
			FlxG.save.data.modSettings.remove(modName);
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			Log.print('getModSetting: $path could not be found!', ERROR);
			#else
			FlxG.log.warn('getModSetting: $path could not be found!');
			#end
			return null;
		}

		if(settings.exists(saveTag)) return settings.get(saveTag);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		Log.print('getModSetting: "$saveTag" could not be found inside $modName\'s settings!', ERROR);
		#else
		FlxG.log.warn('getModSetting: "$saveTag" could not be found inside $modName\'s settings!');
		#end
		#end
		return null;
	}
	
	static function isQuote(string:String, pos:Int):Bool { // it isnt that deep bro
		var char:String = string.charAt(pos);
		return (char == '\'' || char == '"');
	}
	public static function getVariable(object:Dynamic, id:String, allowMaps:Bool = false):Dynamic {
		if (object == FlxG.state && (id == 'game' || id == 'this' || id == 'instance'))
			return FlxG.state;
		
		if (object == null) {
			throw 'Null Object Reference';
			return null;
		}
		
		function getVariableFR(id:String):Dynamic {
			if (allowMaps && isMap(object))
				return object.get(id);
			if (object.hasVar != null && object.hasVar(id))
				return object.getVar(id);
			return Reflect.getProperty(object, id);
		}
		
		if (id.indexOf('[') == -1) {
			return getVariableFR(id);
		} else { // array / map access
			if (id.indexOf('[') == 0) {
				throw 'Malformed variable "$id"';
				return null;
			}
			
			var access:Array<String> = id.split('[');
			var gotObj:Dynamic = getVariableFR(access.shift());
			
			for (i => item in access) {
				if (item.indexOf(']') < item.length - 1) {
					throw 'Malformed variable "$id"';
					return null;
				}
				
				var keyID:String = item.substr(0, -1);
				
				if (Std.isOfType(gotObj, Array)) {
					gotObj = gotObj[Std.parseInt(keyID)];
				} else if (isMap(gotObj) && isQuote(keyID, 0) && isQuote(keyID, keyID.length - 1)) {
					var keyID:Dynamic = keyID.substring(1, keyID.length - 1);
					switch (Type.typeof(gotObj)) {
						case TClass(haxe.ds.IntMap): keyID = Std.parseInt(keyID);
						default:
					}
					
					gotObj = gotObj.get(keyID);
				} else {
					throw 'Array access is not allowed on ${Type.getClassName(Type.getClass(gotObj))}';
					return null;
				}
			}
			return gotObj;
		}
	}
	public static function setVariable(object:Dynamic, id:String, value:Dynamic, allowMaps:Bool = false):Dynamic {
		if (object == null) {
			throw 'Null Object Reference';
			return value;
		}
		
		if (id.indexOf('[') == -1) {
			if (allowMaps && isMap(object)) {
				object.set(id, value);
				return value;
			}
			if (object.hasVar != null && object.hasVar(id))
				return object.setVar(id, value);
			Reflect.setProperty(object, id, value);
		} else { // array / map access
			if (id.indexOf('[') == 0) {
				throw 'Malformed variable "$id"';
				return value;
			}
			
			var access:Array<String> = id.split('[');
			var gotObj:Dynamic = getVariable(object, access.shift());
			
			for (i => item in access) {
				if (item.indexOf(']') < item.length - 1) {
					throw 'Malformed variable "$id"';
					return value;
				}
				
				var keyID:String = item.substr(0, -1);
				var isLast:Bool = (i == access.length - 1);
				
				if (Std.isOfType(gotObj, Array)) {
					if (isLast) {
						gotObj[Std.parseInt(keyID)] = value;
					} else {
						gotObj = gotObj[Std.parseInt(keyID)];
					}
				} else if (isMap(gotObj) && isQuote(keyID, 0) && isQuote(keyID, keyID.length - 1)) {
					var keyID:Dynamic = keyID.substring(1, keyID.length - 1);
					switch (Type.typeof(gotObj)) {
						case TClass(haxe.ds.IntMap): keyID = Std.parseInt(keyID);
						default:
					}
					
					if (isLast) {
						gotObj.set(keyID, value);
					} else {
						gotObj = gotObj.get(keyID);
					}
				} else {
					throw 'Array access is not allowed on ${Type.getClassName(Type.getClass(gotObj))}';
					return null;
				}
			}
		}
		
		return value;
	}
	
	public static function getPropertyLoop(variable:String, allowMaps:Bool = false, ?base:Dynamic):Dynamic {
		if (variable.indexOf('.') != -1) {
			var obj:Dynamic = base;
			for (id in variable.split('.'))
				obj = getVariable(obj, id);
			
			return obj;
		} else {
			return getVariable(base, variable);
		}
	}
	public static function setPropertyLoop(variable:String, value:Dynamic, allowMaps:Bool = false, ?base:Dynamic):Dynamic {
		if (variable.indexOf('.') != -1) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = base;
			for (i => id in split) {
				if (i < split.length - 1) {
					obj = getVariable(obj, id);
				} else {
					setVariable(obj, id, value);
				}
			}
			
			return value;
		} else {
			return setVariable(base, variable, value);
		}
	}
	
	public static function getObjectDirectly(objectName:String, allowMaps:Bool = false):Dynamic {
		return getPropertyLoop(objectName, allowMaps, FlxG.state);
	}
	
	public static var fieldCache:Map<String, Array<String>> = [];
	public static function hasField(o:Dynamic, id:String):Bool {
		if (o == null)
			return false;
		if (Reflect.hasField(o, id) || Reflect.field(o, id) != null || Type.typeof(o) == TObject)
			return true;
		
		var name:String;
		var cls:Class<Dynamic>;
		
		if (o is Class) {
			cls = o;
			name = '##CLASS_${Type.getClassName(cls)}';
			
			if (!fieldCache.exists(name))
				fieldCache.set(name, Type.getClassFields(cls));
		} else {
			cls = Type.getClass(o);
			name = '##INST_${Type.getClassName(cls)}';
			
			if (!fieldCache.exists(name))
				fieldCache.set(name, Type.getInstanceFields(cls));
		}
		
		return fieldCache[name].contains(id);
	}
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}
	public static function isLuaSupported(value:Any):Bool {
		return (value == null || isOfTypes(value, [Bool, Int, Float, String, Array]) || Type.typeof(value) == TObject);
	}
	public static function isMap(variable:Dynamic):Bool {
		return switch (Type.typeof(variable)) {
			case TClass(haxe.ds.StringMap) | TClass(haxe.ds.ObjectMap) | TClass(haxe.ds.IntMap) | TClass(haxe.ds.EnumValueMap): true;
			default: false;
		}
	}
	
	public static function getTargetInstance():MusicBeatSubstate {
		if (PlayState.instance != null) return (PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance);
		return MusicBeatState.getState();
	}

	public static inline function getLowestCharacterGroup():FlxSpriteGroup {
		if (PlayState.instance == null) return null;
		
		var stageData:StageFile = StageData.getStageFile(PlayState.SONG.stage);
		var group:FlxSpriteGroup = (stageData.hide_girlfriend ? PlayState.instance.boyfriendGroup : PlayState.instance.gfGroup);

		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}
		
		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}
	
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Float = 24, loop:Bool = false)
	{
		var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
		if(obj != null && obj.animation != null)
		{
			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			if(prefix != null) obj.animation.addByIndices(name, prefix, indices, '', framerate, loop);
			else obj.animation.add(name, indices, framerate, loop);

			if(obj.animation.curAnim == null)
			{
				var dyn:Dynamic = cast obj;
				if(dyn.playAnim != null) dyn.playAnim(name, true);
				else dyn.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
	
	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().replace(' ', ''))
		{
			//case "texture" | "textureatlas" | "tex":
				//spr.frames = AtlasFrameMaker.construct(image);

			//case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				//spr.frames = AtlasFrameMaker.construct(image, null, true);

			case 'aseprite', 'ase', 'json', 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);

			case "packer", 'packeratlas', 'pac':
				spr.frames = Paths.getPackerAtlas(image);

			case 'sparrow', 'sparrowatlas', 'sparrowv2':
				spr.frames = Paths.getSparrowAtlas(image);

			default:
				spr.frames = Paths.getAtlas(image);
		}
	}

	public static function destroyObject(tag:String) {
		var variables = MusicBeatState.getVariables();
		var obj:FlxSprite = variables.get(tag);
		if(obj == null || obj.destroy == null)
			return;

		LuaUtils.getTargetInstance().remove(obj, true);
		obj.destroy();
		variables.remove(tag);
	}

	public static function cancelTween(tag:String) {
		if(!tag.startsWith('tween_')) tag = 'tween_' + LuaUtils.formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var twn:FlxTween = variables.get(tag);
		if(twn != null)
		{
			twn.cancel();
			twn.destroy();
			variables.remove(tag);
		}
	}

	public static function cancelTimer(tag:String) {
		if(!tag.startsWith('timer_')) tag = 'timer_' + LuaUtils.formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var tmr:FlxTimer = variables.get(tag);
		if(tmr != null)
		{
			tmr.cancel();
			tmr.destroy();
			variables.remove(tag);
		}
	}

	public static function formatVariable(tag:String)
		return tag.trim().replace(' ', '_').replace('.', '');

	public static function tweenPrepare(tag:String, object:String) {
		if (tag != null) cancelTween(tag);
		return getObjectDirectly(object);
	}

	public static function getBuildTarget():String
	{
		#if windows
		#if x86_BUILD
		return 'windows_x86';
		#else
		return 'windows';
		#end
		#elseif linux
		return 'linux';
		#elseif mac
		return 'mac';
		#elseif html5
		return 'browser';
		#elseif android
		return 'android';
		#elseif switch
		return 'switch';
		#else
		return 'unknown';
		#end
	}

	//buncho string stuffs
	public static function getTweenTypeByString(?type:String = '') {
		switch(type.toLowerCase().trim())
		{
			case 'backward': return FlxTweenType.BACKWARD;
			case 'looping'|'loop': return FlxTweenType.LOOPING;
			case 'persist': return FlxTweenType.PERSIST;
			case 'pingpong': return FlxTweenType.PINGPONG;
		}
		return FlxTweenType.ONESHOT;
	}

	public static function getTweenEaseByString(?ease:String = '') {
		switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	public static function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}
	
	public static function typeToString(type:Int):String {
		#if LUA_ALLOWED
		switch(type) {
			case Lua.LUA_TBOOLEAN: return "boolean";
			case Lua.LUA_TNUMBER: return "number";
			case Lua.LUA_TSTRING: return "string";
			case Lua.LUA_TTABLE: return "table";
			case Lua.LUA_TFUNCTION: return "function";
		}
		if (type <= Lua.LUA_TNIL) return "nil";
		#end
		return "unknown";
	}

	public static function cameraFromString(cam:String):FlxCamera {
		var game:PlayState = PlayState.instance;
		var camera:Dynamic;
		if (game != null) {
			switch (cam.toLowerCase()) {
				case 'camother' | 'other': return game.camOther;
				case 'camgame' | 'game': return game.camGame;
				case 'camhud' | 'hud': return game.camHUD;
				default:
			}
			
			camera = MusicBeatState.getVariables().get(cam);
			if (camera == null || !Std.isOfType(camera, FlxCamera))
				camera = game.camGame;
		} else {
			switch (cam.toLowerCase()) {
				case 'camgame' | 'game': return FlxG.camera;
				default:
			}
			
			camera = MusicBeatState.getVariables().get(cam);
			if (camera == null || !Std.isOfType(camera, FlxCamera))
				camera = FlxG.camera;
		}
		return camera;
	}
	
	public static function cameraString(cam:String):String {
		switch(cam.toLowerCase()) {
			case 'camgame' | 'game': return 'camGame';
			case 'camhud' | 'hud': return 'camHUD';
			case 'camother' | 'other': return 'camOther';
		}
		var customCamera:FlxCamera = MusicBeatState.getVariables().get(cam);
		if (customCamera != null && Std.isOfType(customCamera, FlxCamera)) return cam;
		return 'camGame';
	}
}
#end