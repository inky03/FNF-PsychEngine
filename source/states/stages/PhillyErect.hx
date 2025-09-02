package states.stages;

import shaders.AdjustColor;
import states.stages.objects.*;

class PhillyErect extends Philly {
	public var colorShader:AdjustColor;
	
	override function create() {
		if (!ClientPrefs.data.lowQuality) {
			var bg:BGSprite = new BGSprite('philly/erect/sky', -100, 0, .1, .1);
			add(bg);
		}

		var city:BGSprite = new BGSprite('philly/erect/city', -10, 0, .3, .3);
		city.setGraphicSize(Std.int(city.width * .85));
		city.updateHitbox();
		add(city);

		phillyLightsColors = [0xff31a2fd, 0xff31fd8c, 0xfffb33f5, 0xfffd4531, 0xfffba633];
		phillyWindow = new BGSprite('philly/erect/window', city.x, city.y, .3, .3);
		phillyWindow.setGraphicSize(Std.int(phillyWindow.width * .85));
		phillyWindow.updateHitbox();
		add(phillyWindow);
		phillyWindow.alpha = 0;

		if (!ClientPrefs.data.lowQuality) {
			var streetBehind:BGSprite = new BGSprite('philly/erect/behindTrain', -40, 50);
			add(streetBehind);
		}

		phillyTrain = new PhillyTrain(2000, 360);
		add(phillyTrain);

		phillyStreet = new BGSprite('philly/erect/street', -40, 50);
		add(phillyStreet);
		
		colorShader = new AdjustColor(-26, -16, 0, -5);
	}
	
	override function createPost():Void {
		boyfriend.shader = dad.shader = gf.shader = colorShader.shader;
	}
}