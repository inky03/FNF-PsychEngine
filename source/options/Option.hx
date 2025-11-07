package options;

typedef Keybind = {
	keyboard:String,
	gamepad:String
}

enum abstract OptionType(String) to String {
	// Bool will use checkboxes
	// Everything else will use a text
	var BOOL = 'bool';
	var INT = 'int';
	var FLOAT = 'float';
	var PERCENT = 'percent';
	var STRING = 'string';
	var KEYBIND = 'keybind';
}

class Option
{
	public var child:Alphabet;
	public var text(get, set):String;
	public var onChange:Float -> Bool -> Void = null; //Pressed enter (on Bool type options) or pressed/held left/right (on other types)
	public var type:OptionType = BOOL;

	public var scrollSpeed:Float = 50; //Only works on int/float, defines how fast it scrolls per second while holding left/right
	public var variable(default, null):String = null; //Variable from ClientPrefs.hx
	public var defaultValue:Dynamic = null;

	public var value:Dynamic = null;
	public var curOption:Int = 0; //Don't change this
	public var options:Array<String> = null; //Only used in string type
	public var changeValue:Dynamic = 1; //Only used in int/float/percent type, how much is changed when you PRESS
	public var minValue:Dynamic = null; //Only used in int/float/percent type
	public var maxValue:Dynamic = null; //Only used in int/float/percent type
	public var decimals:Int = 1; //Only used in float/percent type

	public var displayFormat:String = '%v'; //How String/Float/Percent/Int values are shown, %v = Current value, %d = Default value
	public var description:String = '';
	public var name:String = 'Unknown';
	public var key:String = 'Unknown';

	public var defaultKeys:Keybind = null; //Only used in keybind type
	public var keys:Keybind = null; //Only used in keybind type

	public function new(name:String, description:String = '', variable:String, type:OptionType = BOOL, ?options:Array<String>, ?translation:String)
	{
		this.key = name;
		this._translationKey = (translation ?? key);
		this.name = Language.getPhrase('setting_$_translationKey', name);
		this.description = Language.getPhrase('description_$_translationKey', description);
		this.variable = variable;
		this.type = type;
		this.options = options;
		
		if (this.type != KEYBIND) this.defaultValue = getDefaultValue;
		switch(type)
		{
			case BOOL:
				if(defaultValue == null) defaultValue = false;
			case INT, FLOAT:
				if(defaultValue == null) defaultValue = 0;
			case PERCENT:
				if(defaultValue == null) defaultValue = 1;
				displayFormat = '%v%';
				changeValue = 0.01;
				minValue = 0;
				maxValue = 1;
				scrollSpeed = 0.5;
				decimals = 2;
			case STRING:
				defaultValue = (options[0] ?? '');

			case KEYBIND:
				defaultValue = '';
				defaultKeys = getDefaultValue();
				keys = {gamepad: 'NONE', keyboard: 'NONE'};
		}

		try
		{
			setValue(getValue() ?? defaultValue);
		}
		catch(e) {}
	}
	
	public static function typeFromString(str:String):OptionType
	{
		switch(str.toLowerCase().trim())
		{
			case 'bool':
				return BOOL;
			case 'int', 'integer':
				return INT;
			case 'float', 'fl':
				return FLOAT;
			case 'percent':
				return PERCENT;
			case 'string', 'str':
				return STRING;
			case 'keybind', 'key':
				return KEYBIND;
		}
		FlxG.log.error("Could not find option type: " + str);
		return BOOL;
	}

	public function change(mod:Float = 0, hold:Bool = false)
	{
		//nothing lol
		if(onChange != null)
			onChange(mod, hold);
	}
	
	public function getDefaultValue():Dynamic {
		if (!psychlua.LuaUtils.hasField(ClientPrefs.defaultData, variable)) return this.defaultValue;
		return Reflect.getProperty(ClientPrefs.defaultData, variable);
	}
	
	public function getDefaultKeys():Keybind {
		if (!psychlua.LuaUtils.hasField(ClientPrefs.defaultData, variable)) return (this.defaultKeys ?? {gamepad: 'NONE', keyboard: 'NONE'});
		return cast Reflect.getProperty(ClientPrefs.defaultData, variable);
	}

	dynamic public function getValue():Dynamic
	{
		if (!psychlua.LuaUtils.hasField(ClientPrefs.data, variable))
			return this.value;
		var value:Dynamic = Reflect.getProperty(ClientPrefs.data, variable);
		if (type == KEYBIND)
			return (Controls.instance.controllerMode ? value.gamepad : value.keyboard);
		return value;
	}

	dynamic public function setValue(value:Dynamic)
	{
		var hasSave:Bool = (psychlua.LuaUtils.hasField(ClientPrefs.data, variable));
		
		switch (type) {
			case KEYBIND:
				if (hasSave) {
					var keys:Dynamic = Reflect.getProperty(ClientPrefs.data, variable);
					if (!Controls.instance.controllerMode) this.value.keyboard = keys.keyboard = value;
					else this.value.gamepad = keys.gamepad = value;
				} else {
					this.value ??= getDefaultKeys();
					if (!Controls.instance.controllerMode) this.value.keyboard = value;
					else this.value.gamepad = value;
				}
				
			default:
				this.value = value;
				if (hasSave) Reflect.setProperty(ClientPrefs.data, variable, value);
				if (type == STRING && options.contains(value)) curOption = options.indexOf(value);
		}
		
		return value;
	}
	
	var _text:String = null;
	var _translationKey:String = null;
	private function get_text()
		return _text;

	private function set_text(newValue:String = '')
	{
		if(child != null)
		{
			_text = newValue;
			child.text = Language.getPhrase('setting_$_translationKey-${getValue()}', _text);
			return _text;
		}
		return null;
	}
}