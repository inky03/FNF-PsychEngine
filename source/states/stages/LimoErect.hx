package states.stages;

import shaders.AdjustColor;
import states.stages.objects.*;
import flixel.addons.display.FlxBackdrop;

class LimoErect extends Limo {
	public var colorShader:AdjustColor;
	
	public var shootingStar:FlxSprite;
	
	public var mist1:FlxBackdrop;
	public var mist2:FlxBackdrop;
	public var mist3:FlxBackdrop;
	public var mist4:FlxBackdrop;
	public var mist5:FlxBackdrop;
	
	var shootingStarBeat:Int = 0;
	var shootingStarOffset:Int = 2;
	
	override function create() {
		mist1 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
		mist1.setPosition(-650, -100);
		mist1.scrollFactor.set(1.1, 1.1);
		mist1.color = 0xffc6bfde;
		mist1.alpha = .4;
		mist1.velocity.x = 1700;
		
		mist2 = new FlxBackdrop(Paths.image('limo/erect/mistBack'), X);
		mist2.setPosition(-650, -100);
		mist2.scrollFactor.set(1.2, 1.2);
		mist2.color = 0xff6a4da1;
		mist2.velocity.x = 2100;
		mist1.scale.set(1.3, 1.3);
		
		mist3 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
		mist3.scrollFactor.set(.8, .8);
		mist3.setPosition(-650, -100);
		mist3.color = 0xffa7d9be;
		mist3.alpha = .5;
		mist3.velocity.x = 900;
		mist3.scale.set(1.5, 1.5);
		
		mist4 = new FlxBackdrop(Paths.image('limo/erect/mistBack'), X);
		mist4.scrollFactor.set(.6, .6);
		mist4.setPosition(-650, -380);
		mist4.color = 0xff9c77c7;
		mist4.velocity.x = 700;
		mist4.scale.set(1.5, 1.5);
		
		mist5 = new FlxBackdrop(Paths.image('limo/erect/mistMid'), X);
		mist5.scrollFactor.set(.2, .2);
		mist5.setPosition(-650, -400);
		mist5.color = 0xffe7a480;
		mist5.velocity.x = 100;
		mist5.scale.set(1.5, 1.5);
		
		for (mist in [mist1, mist2, mist3, mist4, mist5]) mist.blend = ADD;
		
		var skyBG:BGSprite = new BGSprite('limo/erect/limoSunset', -120, -50, 0.1, 0.1);
		add(skyBG);
		
		add(mist5);
		add(mist4);
		add(mist3);

		if (!ClientPrefs.data.lowQuality) {
			shootingStar = new FlxSprite();
			shootingStar.scrollFactor.set(.12, .12);
			shootingStar.frames = Paths.getSparrowAtlas('limo/erect/shooting star', 'week4');
			shootingStar.animation.addByPrefix('shooting star', 'shooting star', 24, false);
			shootingStar.animation.play('shooting star', true);
			shootingStar.blend = ADD;
			add(shootingStar);
			
			limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
			add(limoMetalPole);

			bgLimo = new BGSprite('limo/erect/bgLimo', -150, 520, 0.4, 0.4, ['Limo stage'], true);
			add(bgLimo);

			limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
			add(limoCorpse);

			limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
			add(limoCorpseTwo);

			grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
			add(grpLimoDancers);

			for (i in 0 ... 5) {
				var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + dancersDiff + bgLimo.x, bgLimo.y - 400);
				dancer.scrollFactor.set(.4, .4);
				grpLimoDancers.add(dancer);
			}

			limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, .4, .4);
			add(limoLight);

			grpLimoParticles = new FlxTypedGroup<BGSprite>();
			add(grpLimoParticles);

			//PRECACHE BLOOD
			var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, .4, .4, ['blood'], false);
			particle.alpha = 0.01;
			grpLimoParticles.add(particle);
			resetLimoKill();

			//PRECACHE SOUND
			Paths.sound('dancerdeath');
			setDefaultGF('gf-car');
		}

		fastCar = new BGSprite('limo/fastCarLol', -300, 160);
		fastCar.active = true;
		
		colorShader = new AdjustColor(-30, -20, -30);
	}
	
	override function createPost():Void {
		add(mist1);
		add(mist2);
		
		super.createPost();
		
		boyfriend.shader = dad.shader = gf.shader = fastCar.shader = colorShader.shader;
		for (dancer in grpLimoDancers) dancer.shader = colorShader.shader;
	}
	
	override function update(elapsed:Float):Void {
		super.update(elapsed);
		
		var time:Float = (Conductor.songPosition * .001);
		mist1.y = (100 + Math.sin(time) * 200);
		mist2.y = (0 + Math.sin(time * .8) * 100);
		mist3.y = (-20 + Math.sin(time * .5) * 200);
		mist4.y = (-180 + Math.sin(time * .4) * 300);
		mist5.y = (-450 + Math.sin(time * .2) * 150);
	}
	
	override function beatHit():Void {
		super.beatHit();
		
		if (FlxG.random.bool(10) && curBeat > shootingStarBeat + shootingStarOffset)
			doShootingStar(curBeat);
	}
	
	function doShootingStar(beat:Int):Void {
		if (shootingStar == null) return;
		
		shootingStar.setPosition(FlxG.random.int(50, 900), FlxG.random.int(-10, 20));
		shootingStar.flipX = FlxG.random.bool(50);
		shootingStar.animation.play('shooting star', true);

		shootingStarBeat = beat;
		shootingStarOffset = FlxG.random.int(4, 8);
	}
}