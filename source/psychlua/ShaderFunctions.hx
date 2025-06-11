package psychlua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

class ShaderFunctions
{
	public static function implementLocal(funk:FunkinLua)
	{
		// shader shit
		funk.addLocalCallback("initLuaShader", function(name:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && MODS_ALLOWED && sys)
			return funk.initLuaShader(name);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			#end
			return false;
		});
		
		funk.addLocalCallback("setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;

			#if (!flash && sys)
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader)) {
				FunkinLua.luaTrace('setSpriteShader: Shader $shader is missing!', false, false, ERROR);
				return false;
			}
			
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(obj);
			
			if(leObj != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				leObj.shader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				return true;
			}
			#else
			FunkinLua.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			#end
			return false;
		});
		funk.addLocalCallback("removeSpriteShader", function(obj:String) {
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(obj);
			
			if(leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});

		// I am actually killing you
		funk.addLocalCallback("getShaderBool", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderBool: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getBool(prop);
			#else
			FunkinLua.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});
		funk.addLocalCallback("getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getBoolArray(prop);
			#else
			FunkinLua.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});
		funk.addLocalCallback("getShaderInt", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderInt: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getInt(prop);
			#else
			FunkinLua.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});
		funk.addLocalCallback("getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderIntArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getIntArray(prop);
			#else
			FunkinLua.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});
		funk.addLocalCallback("getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderFloat: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getFloat(prop);
			#else
			FunkinLua.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});
		funk.addLocalCallback("getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if (shader == null) {
				FunkinLua.luaTrace("getShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return null;
			}
			return shader.getFloatArray(prop);
			#else
			FunkinLua.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return null;
			#end
		});


		funk.addLocalCallback("setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderBool: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}
			shader.setBool(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
		funk.addLocalCallback("setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderBoolArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}
			shader.setBoolArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
		funk.addLocalCallback("setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderInt: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}
			shader.setInt(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
		funk.addLocalCallback("setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderIntArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}
			shader.setIntArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
		funk.addLocalCallback("setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderFloat: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}
			shader.setFloat(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
		funk.addLocalCallback("setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderFloatArray: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}

			shader.setFloatArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return true;
			#end
		});

		funk.addLocalCallback("setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj);
			if(shader == null) {
				FunkinLua.luaTrace("setShaderSampler2D: Shader is not FlxRuntimeShader!", false, false, ERROR);
				return false;
			}

			// trace('bitmapdatapath: $bitmapdataPath');
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null)
			{
				// trace('Found bitmapdata. Width: ${value.bitmap.width} Height: ${value.bitmap.height}');
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			return false;
			#else
			FunkinLua.luaTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!", false, false, ERROR);
			return false;
			#end
		});
	}
	
	#if (!flash && MODS_ALLOWED && sys)
	public static function getShader(obj:String):FlxRuntimeShader {
		var target:FlxSprite = LuaUtils.getObjectDirectly(obj);

		if (target == null) {
			FunkinLua.luaTrace('Error on getting shader: Object $obj not found', false, false, ERROR);
			return null;
		}
		return cast (target.shader, FlxRuntimeShader);
	}
	#end
}