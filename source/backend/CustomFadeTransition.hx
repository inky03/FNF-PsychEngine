package backend;

import flixel.util.FlxGradient;

class CustomFadeTransition extends ScriptedSubState {
	public static var finishCallback:Void->Void;
	var useDefault:Bool = true;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;
	
	var time:Float = 0;
	var duration:Float;
	public function new(duration:Float, isTransIn:Bool) {
		this.duration = duration;
		this.isTransIn = isTransIn;
		this.multiScript = false;
		super();
	}

	override function create() {
		preCreate();
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		
		if (useDefault) {
			var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, .25));
			var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, .25));
			transGradient = FlxGradient.createGradientFlxSprite(1, height, [FlxColor.BLACK, 0x0]);
			transGradient.flipY = isTransIn;
			transGradient.scale.x = width;
			transGradient.updateHitbox();
			transGradient.scrollFactor.set();
			transGradient.screenCenter(X);
			add(transGradient);

			transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			transBlack.scale.set(width, height + 400);
			transBlack.updateHitbox();
			transBlack.scrollFactor.set();
			transBlack.screenCenter(X);
			add(transBlack);

			updateGradientPosition();
		}

		super.create();
	}

	override function update(elapsed:Float) {
		preUpdate(elapsed);
		
		super.update(elapsed);
		
		time += elapsed;
		
		if (useDefault)
			updateGradientPosition();
		
		postUpdate(elapsed);
		
		if (duration <= 0 || time >= duration)
			close();
	}
	
	function updateGradientPosition():Void {
		if (transBlack == null && transGradient == null)
			return;
		
		var totalHeight:Float = transBlack.height + transGradient.height;
		transBlack.y = FlxMath.lerp(isTransIn ? 0 : -totalHeight, isTransIn ? totalHeight : 0, Math.min(time / duration, 1));
		
		if (isTransIn) {
			transGradient.y = transBlack.y - transGradient.height;
		} else {
			transGradient.y = transBlack.y + transBlack.height;
		}
	}
	
	override function close():Void {
		super.close();

		if (finishCallback != null) {
			finishCallback();
			finishCallback = null;
		}
	}
}
