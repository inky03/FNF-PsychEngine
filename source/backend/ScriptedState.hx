package backend;

import debug.ScriptTraceDisplay;
import psychlua.GlobalScriptHandler;

class ScriptedState extends ScriptedSubState {
	public var camOther:FlxCamera = null;
	
	public static function debugPrint(text:String, ?color:FlxColor, ?size:Int):TracePopUp {
		Sys.println(text);
		
		return Main.traces.print(text, color, size);
	}
	
	public override function create():Void {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		GlobalScriptHandler.refreshScripts();
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut)
			openSubState(new CustomFadeTransition(0.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		MusicBeatState.timePassedOnState = 0;
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
	override function _preCreate():Void {
		#if SCRIPTS_ALLOWED startStateScripts(); #end
		
		GlobalScriptHandler.call('onCreateState', [this]);
	}
	override function _postCreate():Void {
		callOnScripts('onCreatePost');
		
		GlobalScriptHandler.call('onCreateStatePost', [this]);
	}
	
	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}
	
	override function getFolderName():String {
		return 'states';
	}
}