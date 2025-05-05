package options;

import psychlua.CustomSubstate;

class CustomOptionsMenu extends BaseOptionsMenu {
	public var stateName:String;
	public var parentState:ScriptedSubState = null;
	
	public function new(name:String) {
		super();
		stateName = name;
		multiScript = false;
	}
	
	public override function create():Void {
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
		super.create();
		parentState?.callOnScripts('onCustomSubstateCreatePost', [stateName]);
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
	
	public override function destroy():Void {
		parentState?.callOnScripts('onCustomSubstateDestroy', [stateName]);
		parentState?.setOnScripts('customSubstateName', null);
		parentState?.setOnHScript('customSubstate', null);
		CustomSubstate.instance = null;
		CustomSubstate.name = 'unnamed';
		
		super.destroy();
	}
}