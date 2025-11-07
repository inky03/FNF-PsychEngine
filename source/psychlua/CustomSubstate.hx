package psychlua;

import flixel.FlxObject;

class CustomSubstate extends ScriptedSubState {
	public static var name:String = 'unnamed';
	public static var instance:CustomSubstate;
	
	public var stateName:String;
	public var parentState:ScriptedSubState = null;
	
	#if LUA_ALLOWED
	public static function implement() {
		FunkinLua.registerFunction('openCustomSubstate', openCustomSubstate);
		FunkinLua.registerFunction('closeCustomSubstate', closeCustomSubstate);
		FunkinLua.registerFunction('insertToCustomSubstate', function(tag:String, ?pos:Int = -1) {
			if (instance != null) {
				var object:Dynamic = LuaUtils.getObjectDirectly(tag);
				
				if (object == null) {
					FunkinLua.luaTrace('insertToCustomSubstate: Couldnt find object: $tag', false, false, ERROR);
					return false;
				}
				
				if (pos < 0) instance.add(object);
				else instance.insert(pos, object);
				return true;
			}
			
			FunkinLua.luaTrace('insertToCustomSubstate: Custom sub-state is not open!', false, false, ERROR);
			return false;
		});
	}
	public override function implementLua(lua:FunkinLua):Void {
		lua.addLocalCallback('closeSubstate', function() {
			@:privateAccess parent.closeSubState();
		});
	}
	#end
	
	public static function openCustomSubstate(name:String, pauseGame:Bool = false, ?data:Dynamic):Void {
		var st:Dynamic = FlxG.state;
		
		if (pauseGame) {
			if (st.paused != null)
				st.paused = true;
			
			FlxG.state.persistentDraw = true;
			FlxG.state.persistentUpdate = false;
		}
		
		FlxG.state.openSubState(new CustomSubstate(name, data));
	}
	public static function closeCustomSubstate():Bool {
		if (instance != null) {
			FlxG.state.closeSubState();
			return true;
		}
		return false;
	}
	
	public override function create() {
		CustomSubstate.name = stateName;
		CustomSubstate.instance = this;
		
		if (Std.isOfType(_parentState, ScriptedSubState)) {
			parentState = cast _parentState;
		} else if (Std.isOfType(FlxG.state, ScriptedSubState)) {
			parentState = cast FlxG.state;
		}
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		
		parentState?.setOnHScript('customSubstate', this);
		parentState?.setOnScripts('customSubstateName', stateName);
		parentState?.callOnScripts('onCustomSubstateCreate', [stateName]);
		preCreate();
		super.create();
		parentState?.callOnScripts('onCustomSubstateCreatePost', [stateName]);
	}
	override function _preCreate():Void {
		var loaded:Bool = #if SCRIPTS_ALLOWED startStateScripts() #else false #end;
		
		if (!loaded) { // check if the custom substate functions exist within any script (assume it shouldnt error if that is the case)
			var funcNames:Array<String> = ['onCustomSubstateCreate', 'onCustomSubstateCreatePost', 'onCustomSubstateUpdate', 'onCustomSubstateUpdatePost', 'onCustomSubstateDestroy'];
			
			if (_parentState is ScriptedState) {
				var scriptedState:ScriptedState = cast _parentState;
				
				#if LUA_ALLOWED
				for (lua in scriptedState.luaArray) {
					for (funcName in funcNames)
						loaded = (loaded || lua.exists(funcName));
				}
				#end
				#if HSCRIPT_ALLOWED
				for (hscript in scriptedState.hscriptArray) {
					for (funcName in funcNames)
						loaded = (loaded || hscript.exists(funcName));
				}
				#end
			}
		}
		
		if (!loaded) {
			var e:String = #if SCRIPTS_ALLOWED 'Custom sub-state code was not found / had errors, for "$stateName"' #else 'State scripts are unsupported in this build' #end;
			ScriptedState.debugPrint(e, FlxColor.YELLOW);
			close();
		}
	}
	
	public function new(name:String, ?data:Dynamic) {
		super(data);
		stateName = name;
		multiScript = false;
	}
	
	public override function update(elapsed:Float) {
		preUpdate(elapsed);
		super.update(elapsed);
		postUpdate(elapsed);
	}
	public override function preUpdate(elapsed:Float) {
		parentState?.callOnScripts('onCustomSubstateUpdate', [stateName, elapsed]);
		super.preUpdate(elapsed);
	}
	public override function postUpdate(elapsed:Float) {
		parentState?.callOnScripts('onCustomSubstateUpdatePost', [stateName, elapsed]);
		super.postUpdate(elapsed);
	}
	
	public override function customStateName():String {
		return stateName;
	}
	
	public override function destroy() {
		parentState?.callOnScripts('onCustomSubstateDestroy', [stateName]);
		parentState?.setOnScripts('customSubstateName', null);
		parentState?.setOnHScript('customSubstate', null);
		instance = null;
		name = 'unnamed';
		
		super.destroy();
	}
}