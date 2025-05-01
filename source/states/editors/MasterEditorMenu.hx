package states.editors;

import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;

class MasterEditorMenu extends ScriptedSubState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Stage Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Editor'
	];
	var optionFunctions:Map<String, Void -> Void> = [];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	public static var curSelected = 0;
	private var directoryTxt:FlxText;
	private var curDirectory = 0;
	private var fadeIn:Bool;
	
	var textBG:FlxSprite;
	var bg:FlxSprite;
	
	public function new(fadeIn:Bool = false) {
		super();
		this.fadeIn = fadeIn;
	}
	
	override function create() {
		preCreate();
		
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.alpha = 0;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length) {
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.scrollFactor.set();
			leText.isMenuItem = true;
			leText.targetY = i - curSelected;
			leText.snapToPosition();
			grpTexts.add(leText);
		}
		
		optionFunctions['Chart Editor'] = () -> LoadingState.loadAndSwitchState(new ChartingState(), false);
		optionFunctions['Character Editor'] = () -> LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
		optionFunctions['Stage Editor'] = () -> LoadingState.loadAndSwitchState(new StageEditorState());
		optionFunctions['Week Editor'] = () -> MusicBeatState.switchState(new WeekEditorState());
		optionFunctions['Menu Character Editor'] = () -> MusicBeatState.switchState(new MenuCharacterEditorState());
		optionFunctions['Dialogue Editor'] = () -> LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
		optionFunctions['Dialogue Portrait Editor'] = () -> LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
		optionFunctions['Note Splash Editor'] =  () -> MusicBeatState.switchState(new NoteSplashEditorState());
		
		#if MODS_ALLOWED
		textBG = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.scrollFactor.set();
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getModDirectories()) {
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection(true);
		
		if (fadeIn) {
			bg.alpha = .6;
			
			openSubState(new CustomFadeTransition(.5, true));
		} else {
			FlxTween.tween(bg, {alpha: .6}, .4, {ease: FlxEase.quartInOut});
		}
		
		persistentUpdate = persistentDraw = true;
		FlxG.mouse.visible = false;
		super.create();
	}

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (controls.BACK)
		{
			close();
			return;
		}
		
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}
		#if MODS_ALLOWED
		if(controls.UI_LEFT_P)
		{
			changeDirectory(-1);
		}
		if(controls.UI_RIGHT_P)
		{
			changeDirectory(1);
		}
		#end

		if (controls.ACCEPT)
		{
			var option:String = options[curSelected];
			var optionFunc:Void -> Void = optionFunctions[option];
			
			if (callOnScripts('onAccept', [option], true) != psychlua.LuaUtils.Function_Stop) {
				if (optionFunc != null) {
					optionFunc();
					FlxG.sound.music.volume = 0;
					FreeplayState.destroyFreeplayVocals();
				} else {
					trace('Option "$option" doesn\'t do anything');
				}
			}
		}
		
		for (num => item in grpTexts.members) {
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;
		}
		super.update(elapsed);
		
		postUpdate(elapsed);
	}

	function changeSelection(change:Int = 0, forced:Bool = false) {
		var next:Int = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		
		if (callOnScripts('onSelectItem', [options[next], next], true) != psychlua.LuaUtils.Function_Stop) {
			if (change != 0)
				FlxG.sound.play(Paths.sound('scrollMenu'), .4);
			curSelected = next;
		}
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0) {
		var next:Int = FlxMath.wrap(curDirectory + change, 0, directories.length - 1);
		curDirectory = next;
		
		FlxG.sound.play(Paths.sound('scrollMenu'), .4);
		
		WeekData.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1) {
			directoryTxt.text = '< No Mod Directory Loaded >';
		} else {
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
		
		callOnScripts('onSelectDirectory', [directories[curDirectory], next]);
	}
	#end
}