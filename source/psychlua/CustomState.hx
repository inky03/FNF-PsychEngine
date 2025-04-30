package psychlua;

class CustomState extends ScriptedState {
	public var stateName:String;
	
	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua) {
		Lua_helper.add_callback(funk.lua, 'openCustomState', (name:String) -> MusicBeatState.switchState(new CustomState(name)));
	}
	#end
	
	public function new(name:String) {
		super();
		stateName = name;
		multiScript = false;
	}
	
	public override function create():Void {
		trace('started $stateName');
		preCreate();
		super.create();
	}
	override function _preCreate():Void {
		var loaded:Bool = #if SCRIPTS_ALLOWED startStateScripts() #else false #end;
		
		if (!loaded) {
			var e:String = #if SCRIPTS_ALLOWED 'Custom state script was not found / had errors, for "$stateName"' #else 'State scripts are unsupported in this build' #end;
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress BACK to return to Main Menu.',
				() -> {},
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
		}
	}
	
	public override function update(elapsed:Float):Void {
		preUpdate(elapsed);
		super.update(elapsed);
		postUpdate(elapsed);
	}
	
	public override function getStateName():String {
		return stateName;
	}
}