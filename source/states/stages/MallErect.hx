package states.stages;

import shaders.AdjustColor;
import states.stages.objects.*;

class MallErect extends Mall {
	public var colorShader:AdjustColor;
	
	var startSantaCutscene:Bool;
	
	override function create() { // -60 everhthing
		var bg:BGSprite = new BGSprite('christmas/erect/bgWalls', -1000, -440, .2, .2);
		bg.setGraphicSize(Std.int(bg.width * .9));
		bg.updateHitbox();
		add(bg);
		
		if (!ClientPrefs.data.lowQuality) {
			upperBoppers = new BGSprite('christmas/erect/upperBop', -240, -40, .33, .33, ['upperBop']);
			upperBoppers.setGraphicSize(Std.int(upperBoppers.width * .85));
			upperBoppers.updateHitbox();
			add(upperBoppers);
			
			var bgEscalator:BGSprite = new BGSprite('christmas/erect/bgEscalator', -1100, -540, .3, .3);
			bgEscalator.setGraphicSize(Std.int(bgEscalator.width * .9));
			bgEscalator.updateHitbox();
			add(bgEscalator);
		}
		
		var tree:BGSprite = new BGSprite('christmas/erect/christmasTree', 370, -250, .4, .4);
		add(tree);
		
		var fog:BGSprite = new BGSprite('christmas/erect/white', -1000, 100, .85, .85);
		fog.setGraphicSize(Std.int(fog.width * .9));
		fog.updateHitbox();
		add(fog);
		
		bottomBoppers = new MallCrowd(-410, 100, 'christmas/erect/bottomBop', 'bottomBop', false);
		add(bottomBoppers);
		
		var snowUnder:FlxSprite = new FlxSprite(-1200, 800).makeGraphic(10, 10, 0xfff3f4f5);
		snowUnder.setGraphicSize(5400, 3000);
		snowUnder.updateHitbox();
		add(snowUnder);
		
		var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -1150, 680);
		add(fgSnow);
		
		Paths.sound('Lights_Shut_off');
		setDefaultGF('gf-christmas');
		
		if (game.songName == 'eggnog')
			startSantaCutscene = true;
		
		if (isStoryMode)
			setEndCallback(eggnogEndCutscene);
		
		colorShader = new AdjustColor(5, 20);
	}
	
	override function createPost():Void {
		super.createPost();
		
		boyfriend.shader = dad.shader = gf.shader = santa.shader = colorShader.shader;
	}
	
	override function eggnogEndCutscene() {
		if (startSantaCutscene) {
			// TODO implement cutscene here
			endSong();
		} else {
			endSong();
		}
	}
}