package psychlua;

import openfl.utils.Assets;
import backend.Controls;

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
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		FunkinLua.registerFunction("keyPressed", function(name:String = '') {
			name = name.toLowerCase().trim();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		FunkinLua.registerFunction("keyReleased", function(name:String = '') {
			name = name.toLowerCase().trim();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		// Save data management
		FunkinLua.registerFunction("initSaveData", LuaUtils.initSaveData);
		FunkinLua.registerFunction("flushSaveData", LuaUtils.flushSaveData);
		FunkinLua.registerFunction("getDataFromSave", LuaUtils.getDataFromSave);
		FunkinLua.registerFunction("setDataFromSave", LuaUtils.setDataFromSave);
		FunkinLua.registerFunction("eraseSaveData", LuaUtils.eraseSaveData);

		// File management
		FunkinLua.registerFunction("checkFileExists", function(filename:String, absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);

			return FileSystem.exists(Paths.getPath(filename, TEXT));

			#else
			if(absolute) return Assets.exists(filename, TEXT);

			return Assets.exists(Paths.getPath(filename, TEXT));
			#end
		});
		FunkinLua.registerFunction("saveFile", function(path:String, content:String, absolute:Bool = false)
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
		FunkinLua.registerFunction("deleteFile", function(path:String, ignoreModFolders:Bool = false, absolute:Bool = false)
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
		FunkinLua.registerFunction("getTextFromFile", function(path:String, ignoreModFolders:Bool = false, absolute:Bool = false) {
			if (!absolute)
				return Paths.getTextFromFile(path, ignoreModFolders);
			
			if (FileSystem.exists(path))
				return Paths.getTextFromFile(path);
			
			return null;
		});
		FunkinLua.registerFunction("directoryFileList", function(folder:String, ignoreModFolders:Bool = false, absolute:Bool = true) {
			var list:Array<String> = [];
			#if sys
			if (!absolute) folder = Paths.getPath(folder, TEXT, !ignoreModFolders);
			if (FileSystem.exists(folder)) {
				for (folder in FileSystem.readDirectory(folder)) {
					if (!list.contains(folder)) {
						list.push(folder);
					}
				}
			}
			#end
			return list;
		});
		FunkinLua.registerFunction('getPath', function(path:String, ignoreModFolders:Bool = false, neverNull:Bool = false) {
			var path:String = Paths.getPath(path, TEXT, !ignoreModFolders);
			
			if (FileSystem.exists(path) || neverNull)
				return path;
			
			return null;
		});

		// String tools
		FunkinLua.registerFunction("stringStartsWith", StringTools.startsWith);
		FunkinLua.registerFunction("stringEndsWith", StringTools.endsWith);
		FunkinLua.registerFunction("stringTrim", StringTools.trim);
		FunkinLua.registerFunction("stringSplit", function(str:String, split:String) {
			return str.split(split);
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
		FunkinLua.registerFunction("getRandomBool", FlxG.random.bool);
	}
}
