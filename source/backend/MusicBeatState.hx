package backend;

import flixel.FlxState;
import backend.PsychCamera;
import psychlua.CustomState;
import psychlua.GlobalScriptHandler;

class MusicBeatState extends MusicBeatSubstate {
	public var camOther:FlxCamera = null;
	public static var timePassedOnState:Float = 0;
	
	public function new() {
		super();
	}
	
	public static function getState():MusicBeatSubstate {
		return cast (FlxG.state, MusicBeatSubstate);
	}
	public static function getVariables():Map<String, Dynamic> {
		return FlxG.state.extraData;
	}
	
	public override function create() {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		FlxG.fixedTimestep = false;
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut)
			openSubState(new CustomFadeTransition(.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		timePassedOnState = 0;
	}
	public override function preCreate():Void {
		GlobalScriptHandler.refreshScripts();
		
		if (camOther == null) {
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		
		if (!_psychCameraInitialized)
			initPsychCamera();
		
		super.preCreate();
	}
	override function _preCreate():Void {
		GlobalScriptHandler.call('onCreateState', [this, Type.getClass(this)]);
	}
	override function _postCreate():Void {
		GlobalScriptHandler.call('onCreateStatePost', [this, Type.getClass(this)]);
	}
	
	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}

	public static function switchState(?nextState:FlxState):Void {
		if (GlobalScriptHandler.call('onSwitchState', [nextState, Type.getClass(nextState)]) != psychlua.LuaUtils.Function_Stop) {
			if (nextState == null)
				return resetState();
			
			if (FlxTransitionableState.skipNextTransIn) {
				FlxG.switchState(nextState); // actually just cant rid of this deprecated implementation or everything dies
			} else {
				startTransition(nextState);
			}
			
			FlxTransitionableState.skipNextTransIn = false;
		}
	}

	public static function resetState():Void {
		if (FlxTransitionableState.skipNextTransIn) {
			FlxG.resetState();
		} else {
			startTransition();
		}
		
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(?nextState:FlxState):Void {
		FlxG.state.openSubState(new CustomFadeTransition(.5, false));
		
		nextState ??= FlxG.state;
		
		if (nextState is CustomState) {
			var customState:CustomState = cast nextState;
			CustomFadeTransition.finishCallback = () -> FlxG.switchState(() -> new CustomState(customState.stateName));
		} else {
			if (nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = () -> FlxG.resetState();
			} else {
				CustomFadeTransition.finishCallback = () -> FlxG.switchState(nextState);
			}
		}
	}
}