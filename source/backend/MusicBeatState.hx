package backend;

import flixel.FlxState;
import backend.PsychCamera;
import psychlua.CustomState;

class MusicBeatState extends MusicBeatSubstate {
	public var camOther:FlxCamera = null;
	public static var timePassedOnState:Float = 0;
	
	public function new() {
		super();
	}
	
	public static function getState():MusicBeatSubstate {
		return cast (FlxG.state, MusicBeatSubstate);
	}
	public static function getVariables() {
		return getState().variables;
	}
	
	public override function create() {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut)
			openSubState(new CustomFadeTransition(0.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		timePassedOnState = 0;
	}
	public override function preCreate():Void {
		if (camOther == null) {
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		
		if (!_psychCameraInitialized)
			initPsychCamera();
		
		super.preCreate();
	}

	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	public static function switchState(nextState:FlxState = null) {
		if (nextState == null) nextState = FlxG.state;
		if (nextState == FlxG.state) {
			resetState();
			return;
		}

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState() {
		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null) {
		if (nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		if (nextState == FlxG.state) {
			if (nextState is CustomState) {
				var customState:CustomState = cast nextState;
				CustomFadeTransition.finishCallback = () -> FlxG.switchState(new CustomState(customState.stateName));
			} else {
				CustomFadeTransition.finishCallback = () -> FlxG.resetState();
			}
		} else {
			CustomFadeTransition.finishCallback = () -> FlxG.switchState(nextState);
		}
	}
}