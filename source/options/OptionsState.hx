package options;

import states.MainMenuState;
import backend.StageData;

class OptionsState extends ScriptedState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];
	private static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;
	
	var optionFunctions:Map<String, Void -> Void> = [];
	var grpOptions:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;

	function accept(label:String, idx:Int) {
		if (callOnScripts('onAccept', [label, idx], true) != psychlua.LuaUtils.Function_Stop) {
			var func:Void -> Void = optionFunctions[label];
			if (func != null)
				func();
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create() {
		optionFunctions['Note Colors'] = () -> openSubState(new options.NotesColorSubState());
		optionFunctions['Controls'] = () -> openSubState(new options.ControlsSubState());
		optionFunctions['Graphics'] = () -> openSubState(new options.GraphicsSettingsSubState());
		optionFunctions['Visuals'] = () -> openSubState(new options.VisualsSettingsSubState());
		optionFunctions['Gameplay'] = () -> openSubState(new options.GameplaySettingsSubState());
		optionFunctions['Delay and Combo'] = () -> MusicBeatState.switchState(new options.NoteOffsetState());
		optionFunctions['Language'] = () -> openSubState(new options.LanguageSubState());
		
		rpcDetails = 'Options Menu';
		preCreate();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options) {
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			optionText.y += (92 * (num - (options.length / 2))) + 45;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(onPlayState) {
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else MusicBeatState.switchState(new MainMenuState());
		} else if (controls.ACCEPT) {
			accept(options[curSelected], curSelected);
		}
	}
	
	function changeSelection(change:Int = 0) {
		var next:Int = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		
		if (callOnScripts('onSelectItem', [options[next], next], true) != psychlua.LuaUtils.Function_Stop) {
			if (change != 0)
				FlxG.sound.play(Paths.sound('scrollMenu'));
			
			curSelected = next;
			updateItemsVisibility();
		}
	}
	
	function updateItemsVisibility():Void {
		for (i => item in grpOptions.members) {
			item.targetY = i - curSelected;
			item.alpha = 0.6;
			
			if (item.targetY == 0) {
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}