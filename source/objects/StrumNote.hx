package objects;

import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	
	public var loadedTexture:String = null;
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote(value);
		}
		return value;
	}

	public var useRGBShader:Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[leData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[leData];
		
		if(leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);
		
		var skin:String = null;
		if (PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;

		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if (Paths.fileExists('images/$customSkin.png', IMAGE)) {
			skin = customSkin;
		} else {
			skin = '';
		}
		
		texture = skin;
		scrollFactor.set();
		playAnim('static');
	}

	public function reloadNote(texture:String = '', postfix:String = '') {
		var skin:String = texture + postfix;
		
		if (texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if (skin == null || skin.length < 1)
				skin = Note.defaultNoteSkin + postfix;
		}
		
		var lastAnim:String = animation.curAnim?.name;
		
		var skinPostfix:String = '';
		var checkSkin:String = '';
		var validSkin:String = null;
		
		for (path in [PlayState.uiPrefix + skin, skin]) {
			skinPostfix = Note.getNoteSkinPostfix();
			checkSkin = path + skinPostfix;
			
			if (!Paths.fileExists('images/$checkSkin.png', IMAGE)) {
				skinPostfix = '';
				checkSkin = path;
			}
			
			if (Paths.fileExists('images/$checkSkin.png', IMAGE)) {
				validSkin = path;
				break;
			}
		}
		
		if (validSkin != null) {
			loadedTexture = validSkin;
			
			var data:Int = Std.int(Math.abs(noteData) % 4);
			if (PlayState.isPixelStage) {
				loadGraphic(Paths.image('$validSkin$skinPostfix'));
				width = (width / 4);
				height = (height / 5);
				loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
				
				antialiasing = false;
				setGraphicSize(Std.int(width * PlayState.daPixelZoom));
				
				animation.add('static', [data]);
				animation.add('green', [6]);
				animation.add('red', [7]);
				animation.add('blue', [5]);
				animation.add('purple', [4]);
				animation.add('pressed', [data + 4, data + 8], 12, false);
				animation.add('confirm', [data + 12, data + 16], 12, false);
			} else {
				frames = Paths.getSparrowAtlas('$validSkin$skinPostfix');
				animation.addByPrefix('green', 'arrowUP');
				animation.addByPrefix('blue', 'arrowDOWN');
				animation.addByPrefix('purple', 'arrowLEFT');
				animation.addByPrefix('red', 'arrowRIGHT');

				antialiasing = ClientPrefs.data.antialiasing;
				setGraphicSize(Std.int(width * 0.7));
				
				var name:String = (Note.dirArray[data] ?? 'down');
				animation.addByPrefix('static', 'arrow${name.toUpperCase()}');
				animation.addByPrefix('pressed', '$name press', 24, false);
				animation.addByPrefix('confirm', '$name confirm', 24, false);
			}
			updateHitbox();

			if (lastAnim != null)
				playAnim(lastAnim, true);
		}
	}

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		if (useRGBShader) rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
	}
}
