package psychlua;

import flixel.util.FlxSave;
import openfl.utils.Assets;

//
// Things to trivialize some dumb stuff like splitting strings on older Lua
//

class ExtraFunctions {
	public static function implement() {
		// Keyboard & Gamepads
		FunkinLua.registerFunction("keyboardJustPressed", function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		FunkinLua.registerFunction("keyboardPressed", function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		FunkinLua.registerFunction("keyboardReleased", function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		FunkinLua.registerFunction("anyGamepadJustPressed", function(name:String) return FlxG.gamepads.anyJustPressed(name));
		FunkinLua.registerFunction("anyGamepadPressed", function(name:String) FlxG.gamepads.anyPressed(name));
		FunkinLua.registerFunction("anyGamepadReleased", function(name:String) return FlxG.gamepads.anyJustReleased(name));
		
		FunkinLua.registerFunction('mouseClicked', function(?button:String) {
			return switch(button?.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.justPressedMiddle;
				case 'right': FlxG.mouse.justPressedRight;
				default: FlxG.mouse.justPressed;
			}
		});
		FunkinLua.registerFunction('mousePressed', function(?button:String) {
			return switch(button?.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.pressedMiddle;
				case 'right': FlxG.mouse.pressedRight;
				default: FlxG.mouse.pressed;
			}
		});
		FunkinLua.registerFunction('mouseReleased', function(?button:String) {
			return switch(button?.trim().toLowerCase()) {
				case 'middle': FlxG.mouse.justReleasedMiddle;
				case 'right': FlxG.mouse.justReleasedRight;
				default: FlxG.mouse.justReleased;
			}
		});
		FunkinLua.registerFunction('getMouseX', function(camera:String = 'game') {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).x;
		});
		FunkinLua.registerFunction('getMouseY', function(camera:String = 'game') {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getViewPosition(cam).y;
		});

		FunkinLua.registerFunction("gamepadAnalogX", function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		FunkinLua.registerFunction("gamepadAnalogY", function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		FunkinLua.registerFunction("gamepadJustPressed", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		FunkinLua.registerFunction("gamepadPressed", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		FunkinLua.registerFunction("gamepadReleased", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		FunkinLua.registerFunction("keyJustPressed", function(name:String = '') {
			name = name.toLowerCase().trim();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_P;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_P;
				case 'up': return PlayState.instance.controls.NOTE_UP_P;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_P;
				default: return PlayState.instance.controls.justPressed(name);
			}
			return false;
		});
		FunkinLua.registerFunction("keyPressed", function(name:String = '') {
			name = name.toLowerCase().trim();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT;
				case 'down': return PlayState.instance.controls.NOTE_DOWN;
				case 'up': return PlayState.instance.controls.NOTE_UP;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT;
				default: return PlayState.instance.controls.pressed(name);
			}
			return false;
		});
		FunkinLua.registerFunction("keyReleased", function(name:String = '') {
			name = name.toLowerCase().trim();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_R;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_R;
				case 'up': return PlayState.instance.controls.NOTE_UP_R;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_R;
				default: return PlayState.instance.controls.justReleased(name);
			}
			return false;
		});

		// Save data management
		FunkinLua.registerFunction("initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name'))
			{
				var save:FlxSave = new FlxSave();
				// folder goes unused for flixel 5 users. @BeastlyGhost
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			FunkinLua.luaTrace('initSaveData: Save file already initialized: ' + name, WARN);
		});
		FunkinLua.registerFunction("flushSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				variables.get('save_$name').flush();
				return;
			}
			FunkinLua.luaTrace('flushSaveData: Save file not initialized: ' + name, false, false, ERROR);
		});
		FunkinLua.registerFunction("getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			FunkinLua.luaTrace('getDataFromSave: Save file not initialized: ' + name, false, false, ERROR);
			return defaultValue;
		});
		FunkinLua.registerFunction("setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name'))
			{
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			FunkinLua.luaTrace('setDataFromSave: Save file not initialized: ' + name, false, false, ERROR);
		});
		FunkinLua.registerFunction("eraseSaveData", function(name:String)
		{
			var variables = MusicBeatState.getVariables();
			if (variables.exists('save_$name'))
			{
				variables.get('save_$name').erase();
				return;
			}
			FunkinLua.luaTrace('eraseSaveData: Save file not initialized: ' + name, false, false, ERROR);
		});

		// File management
		FunkinLua.registerFunction("checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);

			return FileSystem.exists(Paths.getPath(filename, TEXT));

			#else
			if(absolute) return Assets.exists(filename, TEXT);

			return Assets.exists(Paths.getPath(filename, TEXT));
			#end
		});
		FunkinLua.registerFunction("saveFile", function(path:String, content:String, ?absolute:Bool = false)
		{
			try {
				#if MODS_ALLOWED
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
				#end
					File.saveContent(path, content);

				return true;
			} catch (e:Dynamic) {
				FunkinLua.luaTrace("saveFile: Error trying to save " + path + ": " + e, false, false, ERROR);
			}
			return false;
		});
		FunkinLua.registerFunction("deleteFile", function(path:String, ?ignoreModFolders:Bool = false, ?absolute:Bool = false)
		{
			try {
				var lePath:String = path;
				if(!absolute) lePath = Paths.getPath(path, TEXT, !ignoreModFolders);
				if(FileSystem.exists(lePath))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				FunkinLua.luaTrace("deleteFile: Error trying to delete " + path + ": " + e, false, false, ERROR);
			}
			return false;
		});
		FunkinLua.registerFunction("getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		FunkinLua.registerFunction("directoryFileList", function(folder:String) {
			var list:Array<String> = [];
			#if sys
			if(FileSystem.exists(folder)) {
				for (folder in FileSystem.readDirectory(folder)) {
					if (!list.contains(folder)) {
						list.push(folder);
					}
				}
			}
			#end
			return list;
		});

		// String tools
		FunkinLua.registerFunction("stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		FunkinLua.registerFunction("stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});
		FunkinLua.registerFunction("stringSplit", function(str:String, split:String) {
			return str.split(split);
		});
		FunkinLua.registerFunction("stringTrim", function(str:String) {
			return str.trim();
		});

		// Randomization
		FunkinLua.registerFunction("getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var toExclude:Array<Int> = null;
			
			if (exclude != null) {
				toExclude = [];
				var excludeArray:Array<String> = exclude.split(',');
				for (int in excludeArray) {
					var n:Null<Int> = Std.parseInt(int);
					if (n != null) toExclude.push(n);
				}
			}
			
			return FlxG.random.int(min, max, toExclude);
		});
		FunkinLua.registerFunction("getRandomFloat", function(min:Float, max:Float = 1, ?exclude:String) {
			var toExclude:Array<Float> = null;
			
			if (exclude != null) {
				toExclude = [];
				var excludeArray:Array<String> = exclude.split(',');
				for (float in excludeArray) {
					var f:Float = Std.parseFloat(float);
					if (f != Math.NaN) toExclude.push(f);
				}
			}
			
			return FlxG.random.float(min, max, toExclude);
		});
		FunkinLua.registerFunction("getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
	}
}
