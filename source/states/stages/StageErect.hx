package states.stages;

import shaders.AdjustColor;

class StageErect extends BaseStage {
	var colorShaderDad:AdjustColor;
	var colorShaderGf:AdjustColor;
	var colorShaderBf:AdjustColor;
	
	override function create():Void {
		var sprite:FlxSprite;
		
		add(sprite = new FlxSprite(-500, -1000).makeGraphic(1, 1, 0xff222026));
		sprite.scale.set(2400, 2000);
		sprite.scrollFactor.set();
		sprite.updateHitbox();
		
		add(sprite = new BGSprite('erect/brightLightSmall', 967, -103, 1.2, 1.2));
		sprite.blend = ADD;
		
		add(sprite = new FlxSprite(682, 290));
		sprite.frames = Paths.getSparrowAtlas('erect/crowd');
		sprite.animation.addByPrefix('idle', 'idle', 12);
		sprite.animation.play('idle', true);
		sprite.scrollFactor.set(.8, .8);
		
		add(sprite = new BGSprite('erect/bg', -765, -247, 1, 1));
		add(sprite = new BGSprite('erect/server', -991, 205, 1, 1));
		
		add(sprite = new BGSprite('erect/lightgreen', -171, 242, 1, 1));
		sprite.blend = ADD;
		
		add(sprite = new BGSprite('erect/lightred', -101, 560, 1, 1));
		sprite.blend = ADD;
		
		add(sprite = new BGSprite('erect/orangeLight', 189, -500, 1, 1));
		sprite.scale.set(1, 3);
		sprite.updateHitbox();
		sprite.blend = ADD;
		
		add(sprite = new BGSprite('erect/lights', -847, -245, 1.2, 1.2));
		
		add(sprite = new BGSprite('erect/lightAbove', 804, -117, 1.2, 1.2));
		sprite.blend = ADD;
		
		colorShaderDad = new AdjustColor(-32, 0, -33, -23);
		colorShaderGf = new AdjustColor(-9, 0, -23, -4);
		colorShaderBf = new AdjustColor(12, 0, -23, 7);
	}
	
	override function createPost():Void {
		boyfriend.shader = colorShaderBf.shader;
		dad.shader = colorShaderDad.shader;
		gf.shader = colorShaderGf.shader;
	}
}