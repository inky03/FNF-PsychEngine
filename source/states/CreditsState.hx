package states;

import objects.AttachedSprite;

class CreditsState extends ScriptedState
{
	var curSelected:Int = -1;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<AttachedSprite> = [];

	var bg:FlxSprite;
	var descText:FlxText;
	var intendedColor:FlxColor;
	var descBox:AttachedSprite;

	var offsetThing:Float = -75;
	
	public var creditsStuff:Array<Array<String>> = [];
	public var defaultList:Array<Array<String>>;

	override function create() {
		rpcDetails = 'Credits Menu';

		persistentUpdate = true;
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();
		
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled)
			creditsStuff = creditsStuff.concat(parseCredits(mod));
		#end
		
		defaultList = parseCredits();
		
		preCreate();
		
		creditsStuff = creditsStuff.concat(defaultList);
		if (creditsStuff.length == 0) creditsStuff.push(['NO CREDITS FOUND']);
		
		for (i => credit in creditsStuff)
		{
			Mods.currentModDirectory = credit[credit.length - 1];
			
			var isSeparator:Bool = (isSeparator(i));
			var optionText:Alphabet = new Alphabet(FlxG.width / 2, 300, credit[0], isSeparator);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			optionText.changeX = false;
			optionText.snapToPosition();
			grpOptions.add(optionText);

			if (!isSeparator) {
				var str:String = 'credits/missing_icon';
				if(credit[1] != null && credit[1].length > 0)
				{
					var fileName = 'credits/' + credit[1];
					if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;
					else if (Paths.fileExists('images/$fileName-pixel.png', IMAGE)) str = fileName + '-pixel';
				}

				var icon:AttachedSprite = new AttachedSprite(str);
				if(str.endsWith('-pixel')) icon.antialiasing = false;
				icon.xAdd = optionText.width + 25;
				icon.sprTracker = optionText;
	
				// using a FlxGroup is too much fuss!
				iconArray.push(icon);
				add(icon);

				if (curSelected == -1) curSelected = i;
			} else {
				optionText.alignment = CENTERED;
			}
			
			Mods.currentModDirectory = '';
		}
		if (curSelected == -1) curSelected = 0;
		
		descBox = new AttachedSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.xAdd = -10;
		descBox.yAdd = -10;
		descBox.alphaMult = 0.6;
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, FlxG.height + offsetThing - 25, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
		descText.scrollFactor.set();
		//descText.borderSize = 2.4;
		descBox.sprTracker = descText;
		add(descText);

		bg.color = CoolUtil.colorFromString(creditsStuff[curSelected][4] ?? '808080');
		intendedColor = bg.color;
		changeSelection();
		super.create();
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if(!quitting)
		{
			if(creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

				var upP = controls.UI_UP_P;
				var downP = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
				
				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), .2);
					changeSelection(-FlxG.mouse.wheel);
				}
			}

			if(controls.ACCEPT && (creditsStuff[curSelected][3] == null || creditsStuff[curSelected][3].length > 4)) {
				if (callOnScripts('onAccept', [creditsStuff[curSelected], curSelected], true) != psychlua.LuaUtils.Function_Stop) {
					CoolUtil.browserLoad(creditsStuff[curSelected][3]);
				}
			}
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
			}
		}
		
		for (item in grpOptions.members)
		{
			if(!item.bold)
			{
				var lerpVal:Float = Math.exp(-elapsed * 12);
				if(item.targetY == 0)
				{
					var lastX:Float = item.x;
					item.screenCenter(X);
					item.x = FlxMath.lerp(item.x - 85, lastX, lerpVal);
				}
				else
				{
					item.x = FlxMath.lerp(200 + -40 * Math.abs(item.targetY), item.x, lerpVal);
				}
			}
		}
		super.update(elapsed);
		
		postUpdate(elapsed);
	}

	var moveTween:FlxTween = null;
	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		var max:Int = creditsStuff.length;
		do {
			curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);
			max --;
		} while (isSeparator(curSelected) && max >= 0);

		var newColor:FlxColor = CoolUtil.colorFromString(creditsStuff[curSelected][4]);
		if(newColor != intendedColor) {
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpOptions.members) {
			item.targetY = num - curSelected;
			if (!isSeparator(num)) {
				item.alpha = .6;
				if (item.targetY == 0)
					item.alpha = 1;
			}
		}

		descText.text = (creditsStuff[curSelected].length > 3 ? creditsStuff[curSelected][2] : '');
		if (descText.text.trim().length > 0) {
			descText.visible = descBox.visible = true;
			descText.y = FlxG.height - descText.height + offsetThing - 60;
	
			if(moveTween != null) moveTween.cancel();
			moveTween = FlxTween.tween(descText, {y : descText.y + 75}, 0.25, {ease: FlxEase.sineOut});
	
			descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
			descBox.updateHitbox();
		} else {
			descText.visible = descBox.visible = false;
		}
	}
	
	public static function parseCredits(?folder:String):Array<Array<String>> {
		var list:Array<Array<String>> = [];
		var path:String = 'data/credits.txt';
		var creditsFile:String = (#if MODS_ALLOWED folder != null ? Paths.mods('$folder/$path') : #end Paths.getPath(path, TEXT, false));
		
		#if TRANSLATIONS_ALLOWED
		path = 'data/credits-${ClientPrefs.data.language}.txt';
		var translatedCredits:String = (#if MODS_ALLOWED folder != null ? Paths.mods('$folder/$path') : #end Paths.getPath(path, TEXT, false));
		#end

		if (#if TRANSLATIONS_ALLOWED (FileSystem.exists(translatedCredits) && (creditsFile = translatedCredits) == translatedCredits) || #end FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = Paths.getTextFromFile(creditsFile).split('\n');
			for(i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				arr.push(folder ?? '');
				list.push([for (s in arr) s.trim()]);
			}
			list.push(['']);
		}
		
		return list;
	}

	public function isSeparator(num:Int):Bool {
		return (creditsStuff[num].length <= 2);
	}
}
