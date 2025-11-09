package flxanimate;

import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.SpriteMapData;
import flxanimate.data.AnimationData;
import flxanimate.FlxAnimate as OriginalFlxAnimate;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	public function loadAtlasEx(img:FlxGraphicAsset, ?pathOrStr:String, ?myJson:Dynamic) {
		if (myJson is String) {
			var data:String = myJson;
			var ext:String = data.trim();
			ext = ext.substr(ext.length - 5).toLowerCase();
			
			if (ext == '.json') data = Paths.getTextFromFile(data); //is a path
			anim._loadAtlas(haxe.Json.parse(_removeBOM(data)));
		} else {
			anim._loadAtlas(myJson);
		}
		
		var data:String = pathOrStr;
		
		var ext:String = pathOrStr.trim();
		ext = ext.substr(ext.length - 5).toLowerCase();
		
		if (ext == '.json') {
			frames = spriteMapFrames(haxe.Json.parse(_removeBOM(Paths.getTextFromFile(data))), img);
		} else if (ext.substr(1) == '.xml') {
			frames = FlxAnimateFrames.fromSparrow(Xml.parse(_removeBOM(Paths.getTextFromFile(data))), img);
		} else {
			frames = try spriteMapFrames(haxe.Json.parse(_removeBOM(data)), img)
				catch (e:Dynamic) FlxAnimateFrames.fromSparrow(Xml.parse(_removeBOM(data)), img);
		}
		
		origin = anim.curInstance.symbol.transformationPoint;
	}
	
	public static function spriteMapFrames(atlas:AnimateAtlas, graphic:FlxGraphicAsset):FlxAtlasFrames {
		var frames = new FlxAtlasFrames(FlxG.bitmap.add(graphic));
		
		for (sprite in atlas.ATLAS.SPRITES) {
			var limb = sprite.SPRITE;
			var rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (limb.rotated) rect.setSize(rect.height, rect.width);
			
			FlxAnimateFrames.sliceFrame(limb.name, limb.rotated, rect, frames);
		}
		
		return frames;
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		super.draw();
	}

	override function destroy()
	{
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
		}
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}