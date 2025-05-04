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
		rpcDetails = 'Custom State ($stateName)';
		
		preCreate();
		super.create();
	}
	override function _preCreate():Void {
		var loaded:Bool = #if SCRIPTS_ALLOWED startStateScripts() #else false #end;
		
		if (!loaded) {
			FlxTransitionableState.skipNextTransIn = true;
			
			#if SCRIPTS_ALLOWED
			var e:String = 'Custom state script was not found / had errors, for "$stateName"';
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress ACCEPT to attempt to reload the state.\nPress BACK to return to Main Menu.',
				() -> MusicBeatState.switchState(new CustomState(stateName)),
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
			#else
			var e:String = 'Scripts are unsupported in this build';
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress ACCEPT or BACK to return to Main Menu.',
				() -> MusicBeatState.switchState(new states.MainMenuState()),
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
			#end
		}
	}
	
	public override function update(elapsed:Float):Void {
		preUpdate(elapsed);
		super.update(elapsed);
		postUpdate(elapsed);
	}
	
	public override function customStateName():String {
		return stateName;
	}
}