package backend;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;

class InputFormatter {
	public static function getKeyName(?key:FlxKey):String {
		switch (key) {
			case BACKSPACE:
				return "Backspace";
			case CONTROL:
				return "Ctrl";
			case ALT:
				return "Alt";
			case CAPSLOCK:
				return "Caps";
			case PAGEUP:
				return "Page Up";
			case PAGEDOWN:
				return "Page Down";
			case ZERO:
				return "0";
			case ONE:
				return "1";
			case TWO:
				return "2";
			case THREE:
				return "3";
			case FOUR:
				return "4";
			case FIVE:
				return "5";
			case SIX:
				return "6";
			case SEVEN:
				return "7";
			case EIGHT:
				return "8";
			case NINE:
				return "9";
			case NUMPADZERO:
				return "#0";
			case NUMPADONE:
				return "#1";
			case NUMPADTWO:
				return "#2";
			case NUMPADTHREE:
				return "#3";
			case NUMPADFOUR:
				return "#4";
			case NUMPADFIVE:
				return "#5";
			case NUMPADSIX:
				return "#6";
			case NUMPADSEVEN:
				return "#7";
			case NUMPADEIGHT:
				return "#8";
			case NUMPADNINE:
				return "#9";
			case NUMPADMULTIPLY:
				return "#*";
			case NUMPADPLUS:
				return "#+";
			case NUMPADMINUS:
				return "#-";
			case NUMPADPERIOD:
				return "#.";
			case SEMICOLON:
				return ";";
			case COMMA:
				return ",";
			case PERIOD:
				return ".";
			//case SLASH:
			//	return "/";
			case GRAVEACCENT:
				return "`";
			case LBRACKET:
				return "[";
			//case BACKSLASH:
			//	return "\\";
			case RBRACKET:
				return "]";
			case QUOTE:
				return "'";
			case PRINTSCREEN:
				return "Print Screen";
			case NONE | null:
				return '---';
			default:
				var label:String = (Std.string(key) ?? '---'); // umm, yea okay
				if (label == '---') return label;
				
				var arr:Array<String> = label.split('_');
				for (i in 0...arr.length) arr[i] = CoolUtil.capitalize(arr[i]);
				return arr.join(' ');
		}
	}

	public static function getGamepadName(key:FlxGamepadInputID)
	{
		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;

		switch(key)
		{
			// Analogs
			case LEFT_STICK_DIGITAL_LEFT:
				return "L. Stick Left";
			case LEFT_STICK_DIGITAL_RIGHT:
				return "L. Stick Right";
			case LEFT_STICK_DIGITAL_UP:
				return "L. Stick Up";
			case LEFT_STICK_DIGITAL_DOWN:
				return "L. Stick Down";
			case LEFT_STICK_CLICK:
				switch (model) {
					case PS4: return "L3";
					case XINPUT: return "LS";
					default: return "L. Stick Click";
				}

			case RIGHT_STICK_DIGITAL_LEFT:
				return "R. Stick Left";
			case RIGHT_STICK_DIGITAL_RIGHT:
				return "R. Stick Right";
			case RIGHT_STICK_DIGITAL_UP:
				return "R. Stick Up";
			case RIGHT_STICK_DIGITAL_DOWN:
				return "R. Stick Down";
			case RIGHT_STICK_CLICK:
				switch (model) {
					case PS4: return "R3";
					case XINPUT: return "RS";
					default: return "R. Stick Click";
				}

			// Directional
			case DPAD_LEFT:
				return "D-Pad Left";
			case DPAD_RIGHT:
				return "D-Pad Right";
			case DPAD_UP:
				return "D-Pad Up";
			case DPAD_DOWN:
				return "D-Pad Down";

			// Top buttons
			case LEFT_SHOULDER:
				switch(model) {
					case PS4: return "L1";
					case XINPUT: return "LB";
					default: return "L. Bumper";
				}
			case RIGHT_SHOULDER:
				switch(model) {
					case PS4: return "R1";
					case XINPUT: return "RB";
					default: return "R. Bumper";
				}
			case LEFT_TRIGGER, LEFT_TRIGGER_BUTTON:
				switch(model) {
					case PS4: return "L2";
					case XINPUT: return "LT";
					default: return "L. Trigger";
				}
			case RIGHT_TRIGGER, RIGHT_TRIGGER_BUTTON:
				switch(model) {
					case PS4: return "R2";
					case XINPUT: return "RT";
					default: return "R. Trigger";
				}

			// Buttons
			case A:
				switch (model) {
					case PS4: return "X";
					case XINPUT: return "A";
					default: return "Action Down";
				}
			case B:
				switch (model) {
					case PS4: return "O";
					case XINPUT: return "B";
					default: return "Action Right";
				}
			case X:
				switch (model) {
					case PS4: return "["; //This gets its image changed through code
					case XINPUT: return "X";
					default: return "Action Left";
				}
			case Y:
				switch (model) { 
					case PS4: return "]"; //This gets its image changed through code
					case XINPUT: return "Y";
					default: return "Action Up";
				}

			case BACK:
				switch(model) {
					case PS4: return "Share";
					case XINPUT: return "Back";
					default: return "Select";
				}
			case START:
				switch(model) {
					case PS4: return "Options";
					default: return "Start";
				}

			case NONE:
				return '---';

			default:
				var label:String = Std.string(key);
				if(label.toLowerCase() == 'null') return '---';

				var arr:Array<String> = label.split('_');
				for (i in 0...arr.length) arr[i] = CoolUtil.capitalize(arr[i]);
				return arr.join(' ');
		}
	}
}