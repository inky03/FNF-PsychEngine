package psychlua;

class TextFunctions
{
	public static function implement() {
		FunkinLua.registerFunction("makeLuaText", function(tag:String, ?text:String = '', ?width:Int = 0, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');

			LuaUtils.destroyObject(tag);
			var leText:FlxText = new FlxText(x, y, width, text, 16);
			if (PlayState.instance != null) leText.cameras = [PlayState.instance.camHUD];
			leText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			leText.scrollFactor.set();
			leText.borderSize = 2;
			MusicBeatState.getVariables().set(tag, leText);
		});

		FunkinLua.registerFunction("setTextString", function(tag:String, text:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.text = text;
				return true;
			}
			FunkinLua.luaTrace("setTextString: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextSize", function(tag:String, size:Int) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.size = size;
				return true;
			}
			FunkinLua.luaTrace("setTextSize: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextWidth", function(tag:String, width:Float) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.fieldWidth = width;
				return true;
			}
			FunkinLua.luaTrace("setTextWidth: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextHeight", function(tag:String, height:Float) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.fieldHeight = height;
				return true;
			}
			FunkinLua.luaTrace("setTextHeight: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextAutoSize", function(tag:String, value:Bool) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.autoSize = value;
				return true;
			}
			FunkinLua.luaTrace("setTextAutoSize: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextBorder", function(tag:String, size:Float, color:String, ?style:String = 'outline') {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				CoolUtil.setTextBorderFromString(obj, (size > 0 ? style : 'none'));
				if(size > 0)
					obj.borderSize = size;
				
				obj.borderColor = CoolUtil.colorFromString(color);
				return true;
			}
			FunkinLua.luaTrace("setTextBorder: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextColor", function(tag:String, color:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.color = CoolUtil.colorFromString(color);
				return true;
			}
			FunkinLua.luaTrace("setTextColor: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextFont", function(tag:String, newFont:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.font = Paths.font(newFont);
				return true;
			}
			FunkinLua.luaTrace("setTextFont: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextItalic", function(tag:String, italic:Bool) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.italic = italic;
				return true;
			}
			FunkinLua.luaTrace("setTextItalic: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});
		FunkinLua.registerFunction("setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null) {
				obj.alignment = (switch (alignment.trim().toLowerCase()) {
					default: LEFT;
					case 'right': RIGHT;
					case 'center': CENTER;
					case 'justify': JUSTIFY;
				});
				return true;
			}
			FunkinLua.luaTrace("setTextAlignment: Object " + tag + " doesn't exist!", false, false, ERROR);
			return false;
		});

		FunkinLua.registerFunction("getTextString", function(tag:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null)
				return obj.text;
			
			FunkinLua.luaTrace("getTextString: Object " + tag + " doesn't exist!", false, false, ERROR);
			return null;
		});
		FunkinLua.registerFunction("getTextSize", function(tag:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null)
				return obj.size;
			
			FunkinLua.luaTrace("getTextSize: Object " + tag + " doesn't exist!", false, false, ERROR);
			return -1;
		});
		FunkinLua.registerFunction("getTextFont", function(tag:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null)
				return obj.font;
			
			FunkinLua.luaTrace("getTextFont: Object " + tag + " doesn't exist!", false, false, ERROR);
			return null;
		});
		FunkinLua.registerFunction("getTextWidth", function(tag:String) {
			var obj:FlxText = LuaUtils.getObjectDirectly(tag);
			if (obj != null)
				return obj.fieldWidth;
			
			FunkinLua.luaTrace("getTextWidth: Object " + tag + " doesn't exist!", false, false, ERROR);
			return 0;
		});

		FunkinLua.registerFunction("addLuaText", function(tag:String) {
			var text:FlxText = LuaUtils.getObjectDirectly(tag);
			if (text != null) LuaUtils.getTargetInstance().add(text);
		});
		FunkinLua.registerFunction("removeLuaText", function(tag:String, destroy:Bool = true) {
			var text:FlxText = LuaUtils.getObjectDirectly(tag);
			if (text == null) return;

			var instance:Dynamic = (CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance());
			instance.remove(text, true);
			if (destroy) {
				text.destroy();
				instance.removeVar(tag);
			}
		});
	}
}
