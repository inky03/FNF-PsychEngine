package backend;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if GLOBAL_SCRIPTS
import psychlua.GlobalScriptHandler;
#end

class ScriptedState extends ScriptedSubState {
	public var camOther:FlxCamera = null;
	
	@:dox(hide) var _psychCameraInitialized:Bool = false;
	
	/**
	 * Shows a text string at the top-left of the game screen. Useful for debugging.
	 * 
	 * @param 	text 	The text to add.
	 * @param 	color 	The color of the text to add.
	 * @param 	size 	Optional parameter for the size of the text to add.
	*/
	public static function debugPrint(text:String, ?color:FlxColor, ?size:Int):Void {
		Log.print(text, (color == null ? NONE : CUSTOM(color)), size);
	}
	
	public override function create():Void {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
			openSubState(new CustomFadeTransition(0.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		MusicBeatState.timePassedOnState = 0;
	}
	public override function preCreate():Void {
		#if GLOBAL_SCRIPTS GlobalScriptHandler.refreshScripts(); #end
		
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
		
		MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	override function _postCreate():Void {
		callOnScripts('onCreatePost');
		
		MusicBeatSubstate.callGlobal('onCreateStatePost', [this, Type.getClass(this)]);
	}
	#if SCRIPTS_ALLOWED
	public override function startStateScripts():Bool {
		var loaded:Bool = false;
		
		#if HSCRIPT_ALLOWED
		loaded = startHScripts();
		#end
		#if LUA_ALLOWED
		FunkinLua.registerFunctions();
		MusicBeatSubstate.callGlobal('onRegisterLuaAPI');
		callOnHScript('onRegisterLuaAPI');
		loaded = (startLuas() || loaded);
		#end
		
		return loaded;
	}
	#end
	
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