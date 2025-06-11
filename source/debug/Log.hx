package debug;

class Log {
	public static function print(message:String, level:LogType = ERROR, ?size:Int):Void {
		message = getLogHeader(level) + message;
		
		Sys.println(formatLog(message, level));
		Main.traces?.print(message, getLogColor(level), (level == FATAL ? 17 : 15));
	}
	
	static function formatLog(message:String, level:LogType):String { // this sucks lol
		var esc:String = '\033[';
		
		var code:Int = switch (level) {
			default: 39;
			case INFO: 36;
			case WARN: 33;
			case ERROR | FATAL: 31;
		}
		
		var prefix:String = (switch (level) {
			default:
				(esc + code + 'm');
			case FATAL:
				(esc + code + ';1m');
			case CUSTOM(color):
				(esc + '38;2;${color.red};${color.green};${color.blue}m');
		});
		
		return prefix + message + (esc + '0m');
	}
	static function getLogHeader(level:LogType):String {
		return switch (level) {
			default: '';
			case INFO: 'TRACE: ';
			case WARN: 'WARNING: ';
			case ERROR: 'ERROR: ';
			case FATAL: 'FATAL: ';
		}
	}
	static function getLogColor(level:LogType):FlxColor {
		return switch (level) {
			default: FlxColor.WHITE;
			case INFO: FlxColor.CYAN;
			case WARN: FlxColor.YELLOW;
			case ERROR: FlxColor.RED;
			case FATAL: 0xffbb0000;
			case CUSTOM(color): color;
		}
	}
}

enum LogType {
	NONE;
	INFO;
	WARN;
	ERROR;
	FATAL;
	CUSTOM(color:FlxColor);
}