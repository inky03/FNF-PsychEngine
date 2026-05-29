package psychlua;

import openfl.utils.Assets;

#if (LUA_ALLOWED && flixel_animate)
class FlxAnimateFunctions {
	public static function implement() {
		FunkinLua.registerFunction("makeFlxAnimateSprite", function(tag:String, ?x:Float = 0, ?y:Float = 0, ?loadFolder:String = null) {
			tag = tag.replace('.', '');
			var lastSprite = MusicBeatState.getVariables().get(tag);
			if(lastSprite != null) {
				lastSprite.kill();
				PlayState.instance.remove(lastSprite);
				lastSprite.destroy();
			}

			var mySprite:ModchartSprite = new ModchartSprite(x, y);
			if(loadFolder != null) Paths.loadAnimateAtlas(mySprite, loadFolder);
			MusicBeatState.getVariables().set(tag, mySprite);
			mySprite.active = true;
		});

		FunkinLua.registerFunction("loadAnimateAtlas", function(tag:String, path:String) {
			var spr:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (spr != null) Paths.loadAnimateAtlas(spr, path);
		});
		
		FunkinLua.registerFunction("addAnimationBySymbol", function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false) {
			var obj:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (obj == null) return false;

			cast (obj.animation, FlxAnimateController).addBySymbol(name, symbol, framerate, loop);
			
			if (obj.animation.curAnim == null) {
				if (obj is ModchartSprite) cast (obj, ModchartSprite).playAnim(name, true);
				else obj.animation.play(name, true);
			}
			
			return true;
		});

		FunkinLua.registerFunction("addAnimationBySymbolIndices", function(tag:String, name:String, symbol:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false) {
			var obj:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (obj == null) return false;

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

			cast (obj.animation, FlxAnimateController).addBySymbolIndices(name, symbol, indices, framerate, loop);
			
			if (obj.animation.curAnim == null) {
				if (obj is ModchartSprite) cast (obj, ModchartSprite).playAnim(name, true); //is ModchartAnimateSprite
				else obj.animation.play(name, true);
			}
			
			return true;
		});
	}
}
#end