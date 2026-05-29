package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

import backend.Song;
import states.stages.objects.TankmenBG;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxAnimate
{
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;
	
	public var canPlayComboAnim:Bool = true;
	public var canPlayDropAnim:Bool = true;
	
	public var comboNoteCounts:Array<Int> = [];
	public var dropNoteCounts:Array<Int> = [];

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animation = anim = new PsychAnimateController(this);

		animOffsets = new Map<String, Array<Dynamic>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT);
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			
			if (missingText == null) {
				missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
				missingText.alignment = CENTER;
			}
			missingText.revive();
		} else {
			missingCharacter = false;
			
			missingText?.kill();
		}

		try
		{
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(Paths.getTextFromFile(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		recalculateDanceIdle();
		dance();
	}

	public function loadCharacterFile(json:Dynamic)
	{
		imageFile = json.image;
		jsonScale = json.scale;
		
		#if flixel_animate
		if (#if (MODS_ALLOWED && sys) FileSystem #else Assets #end.exists(Paths.animate(imageFile)))
		{
			Paths.loadAnimateAtlas(this, imageFile);
		}
		else
		#end
		{
			frames = Paths.getMultiAtlas(json.image.split(','));
		}

		scale.set(jsonScale, jsonScale);
		updateHitbox();

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				if (anim.anim == null || anim.name == null) continue;
				
				var animFps:Int = anim.fps;
				var animAnim:String = anim.anim;
				var animName:String = anim.name;
				var animLoop:Bool = (anim.loop == true);
				var animIndices:Array<Int> = anim.indices;

				if(!isAnimateAtlas)
				{
					if(animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
				#if flixel_animate
				else
				{
					final hasSymbol:Bool = (library?.getSymbol(animName) != null);
					
					if (animIndices != null && animIndices.length > 0) {
						if (hasSymbol) {
							this.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
						} else {
							this.anim.addByFrameLabelIndices(animAnim, animName, animIndices, animFps, animLoop);
						}
					} else {
						if (hasSymbol) {
							this.anim.addBySymbol(animAnim, animName, animFps, animLoop);
						} else {
							this.anim.addByFrameLabel(animAnim, animName, animFps, animLoop);
						}
					}
				}
				#end

				if(anim.offsets != null && anim.offsets.length > 1) addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffset(anim.anim, 0, 0);
			}
		}
		
		comboNoteCounts = findCountAnims('combo');
		dropNoteCounts = findCountAnims('drop');
		
		//trace('Loaded file to character ' + curCharacter);
	}

	override function update(elapsed:Float)
	{
		if (debugMode)
		{
			super.update(elapsed);
			return;
		}

		if(heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if(heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if(specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return (animation.curAnim == null);
	}
	
	var _lastPlayedAnimation:String = '';
	inline public function getAnimationName():String
	{
		return (animation.name ?? '');
	}

	public function isAnimationFinished():Bool
	{
		return (animation.curAnim?.finished ?? false);
	}

	public function finishAnimation():Void
	{
		animation.curAnim?.finish();
	}

	public function hasAnimation(anim:String):Bool
	{
		return (animation.exists(anim) || animOffsets.exists(anim));
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		return (animation.curAnim?.paused ?? false);
	}
	private function set_animPaused(value:Bool):Bool
	{
		if (isAnimationNull()) return value;
		
		return animation.curAnim.paused = value;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if(hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix);
		}
	}
	
	public function findCountAnims(prefix:String):Array<Int> {
		var counts:Array<Int> = [];
		
		for (anim => _ in animOffsets) {
			if (anim.startsWith(prefix)) {
				var number:Null<Int> = Std.parseInt(anim.substring(prefix.length));
				if (number != null)
					counts.push(number);
			}
		}
		
		counts.sort((a:Int, b:Int) -> a - b);
		return counts;
	}
	
	public function playComboAnim(combo:Int):Void {
		if (!canPlayComboAnim || comboNoteCounts.length == 0) return;
		
		var animToPlay:String = 'combo$combo';
		
		if (hasAnimation(animToPlay)) {
			playAnim(animToPlay, true);
			specialAnim = true;
		}
	}
	
	public function playComboDropAnim(lastCombo:Int):Void {
		if (!canPlayDropAnim) return;
		
		if (dropNoteCounts.length == 0) { // classic mode
			if (hasAnimation('sad')) {
				playAnim('sad', true);
				specialAnim = true;
			}
			return;
		}
		
		var dropAnim:Null<String> = null;
		for (count in dropNoteCounts) {
			if (count >= lastCombo)
				dropAnim = 'drop$count';
		}
		
		if (dropAnim != null && hasAnimation(dropAnim)) {
			playAnim(dropAnim, true);
			specialAnim = true;
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		specialAnim = false;
		
		animation.play(AnimName, Force, Reversed, Frame);
		_lastPlayedAnimation = AnimName;

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		}
		//else offset.set(0, 0);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;

			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if(songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}
	
	#if flixel_animate
	public var isAnimateAtlas(get, never):Bool;
	inline function get_isAnimateAtlas():Bool { return isAnimate; }
	
	public var atlas:Null<FlxAnimate>;
	inline function get_atlas():Null<FlxAnimate> { return (isAnimate ? this : null); }
	#end
	
	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		
		if(missingCharacter)
		{
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}
		
		super.draw();
		
		if (missingCharacter && visible)
		{
			missingText.alpha = lastAlpha;
			missingText.scrollFactor.copyFrom(scrollFactor);
			missingText.x = getMidpoint().x - 150;
			missingText.y = getMidpoint().y - 10;
			missingText.cameras = cameras;
			missingText.draw();
			alpha = lastAlpha;
			color = lastColor;
		}
	}
}
