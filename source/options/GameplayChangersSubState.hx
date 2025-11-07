package options;

import objects.AttachedText;
import objects.CheckboxThingie;

class GameplayChangersSubState extends BaseOptionsMenu
{
	var scrollType:GameplayOption;
	var scrollSpeed:GameplayOption;
	
	public function new() {
		super(Language.getPhrase('gameplay_modifiers', 'Gameplay Modifiers'), 'Gameplay Modifiers Menu');
		
		bg.alpha = 0.75;
		bg.color = FlxColor.WHITE;
		
		scrollType = new GameplayOption(
			'Scroll Type',
			'Changes how the song\'s scroll speed should behave with the Scroll Speed gameplay modifier.',
			'scrolltype',
			STRING,
			["multiplicative", "constant"]
		);
		scrollType.onChange = onChangeScrollType;
		addOption(scrollType);

		scrollSpeed = new GameplayOption('Scroll Speed', 'Modifier for the song\'s scroll speed.', 'scrollspeed', FLOAT);
		scrollSpeed.scrollSpeed = 2.0;
		scrollSpeed.minValue = 0.35;
		scrollSpeed.changeValue = 0.05;
		scrollSpeed.decimals = 2;
		addOption(scrollSpeed);

		#if FLX_PITCH
		var option:GameplayOption = new GameplayOption('Playback Rate', 'Multiplier for the song playback speed.\nAlso affects the song\'s pitch.', 'songspeed', FLOAT);
		option.scrollSpeed = 1;
		option.minValue = 0.5;
		option.maxValue = 3.0;
		option.changeValue = 0.05;
		option.displayFormat = '%vX';
		option.decimals = 2;
		addOption(option);
		#end

		var option:GameplayOption = new GameplayOption('Health Gain Multiplier', 'Multiplier for the health gain by hitting notes successfully.', 'healthgain', FLOAT);
		option.scrollSpeed = 2.5;
		option.minValue = 0;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		addOption(option);

		var option:GameplayOption = new GameplayOption('Health Loss Multiplier', 'Multiplier for the health loss caused by miss penalties.', 'healthloss', FLOAT);
		option.scrollSpeed = 2.5;
		option.minValue = 0.5;
		option.maxValue = 5;
		option.changeValue = 0.1;
		option.displayFormat = '%vX';
		addOption(option);

		addOption(new GameplayOption('Instakill on Miss', 'If checked, a miss penalty will kill the player immediately.', 'instakill', BOOL));
		addOption(new GameplayOption('Practice Mode', 'If checked, you won\'t die when your health drops to zero.\nYour score won\' be saved with this modifier enabled.', 'practice', BOOL));
		addOption(new GameplayOption('Botplay', 'If checked, the player side is played automatically.\nYour score won\' be saved with this modifier enabled.', 'botplay', BOOL));
	}
	
	public override function create():Void {
		super.create();
		onChangeScrollType();
	}
	
	function onChangeScrollType(?_, ?_):Void {
		if (scrollSpeed == null) return;
		
		scrollType.text = switch (scrollType.text) {
			case 'multiplicative': 'Multiplicative';
			case 'constant': 'Constant';
			default: scrollType.text;
		}
		
		if (scrollType.getValue() != "constant") {
			scrollSpeed.displayFormat = '%vX';
			scrollSpeed.maxValue = 3;
		} else {
			scrollSpeed.displayFormat = "%v";
			scrollSpeed.maxValue = 6;
		}
		updateTextFrom(scrollSpeed);
	}
}

class GameplayOption extends Option {
	var gameplaySettings(get, null):Map<String, Dynamic>;
	
	public override function getDefaultValue():Dynamic {
		if (!ClientPrefs.defaultData.gameplaySettings.exists(variable)) return this.defaultValue;
		return ClientPrefs.defaultData.gameplaySettings.get(variable);
	}
	
	dynamic public override function getValue():Dynamic {
		if (!gameplaySettings.exists(variable))
			return this.value;
		var value = gameplaySettings.get(variable);
		if (type == KEYBIND)
			return (Controls.instance.controllerMode ? value.gamepad : value.keyboard);
		return value;
	}

	dynamic public override function setValue(value:Dynamic) {
		var hasSave:Bool = gameplaySettings.exists(variable);
		
		switch (type) {
			case KEYBIND:
				if (hasSave) {
					var keys:Dynamic = gameplaySettings.get(variable);
					if (!Controls.instance.controllerMode) this.value.keyboard = keys.keyboard = value;
					else this.value.gamepad = keys.gamepad = value;
				} else {
					this.value ??= defaultKeys;
					if (!Controls.instance.controllerMode) this.value.keyboard = value;
					else this.value.gamepad = value;
				}
				
			default:
				this.value = value;
				if (hasSave) gameplaySettings.set(variable, value);
				if (type == STRING && options.contains(value)) curOption = options.indexOf(value);
		}
		
		return value;
	}
	
	function get_gameplaySettings():Map<String, Dynamic> {
		return ClientPrefs.data.gameplaySettings;
	}
}