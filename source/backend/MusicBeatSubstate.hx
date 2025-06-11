package backend;

import shaders.ErrorHandledShader;
import psychlua.GlobalScriptHandler;

class MusicBeatSubstate extends flixel.FlxSubState {
	var stepsToDo:Int = 0;
	
	public var curSection:Int = 0;
	public var curStep:Int = 0;
	public var curBeat:Int = 0;
	
	public var curDecSection:Float = 0;
	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;
	
	var _pre:Bool = false;
	var _psychCameraInitialized:Bool = false;
	
	public var stages:Array<BaseStage> = [];
	
	public var rpcDetails:Null<String> = null;
	public var rpcState:Null<String> = null;
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	
	public function new() {
		super();
	}
	
	public override function create() {
		subStateClosed.add((_) -> updatePresence());
		
		if (!_pre) preCreate();
		super.create();
		
		updatePresence();
		postCreate();
	}
	public function preCreate():Void {
		_pre = true;
		
		_preCreate();
	}
	public function postCreate():Void {
		_postCreate();
	}
	function _preCreate():Void {
		GlobalScriptHandler.call('onCreateSubState', [this, Type.getClass(this)]);
	}
	function _postCreate():Void {
		GlobalScriptHandler.call('onCreateSubStatePost', [this, Type.getClass(this)]);
	}
	
	public function updatePresence():Void {
		#if DISCORD_ALLOWED
		if (autoUpdateRPC && (rpcDetails != null || rpcState != null))
			DiscordClient.changePresence(rpcDetails, rpcState);
		#end
	}
	
	public var controls(get, never):Controls;
	function get_controls():Controls {
		return Controls.instance;
	}
	
	public var variables(get, never):Map<String, Dynamic>;
	function get_variables():Map<String, Dynamic> {
		return extraData;
	}
	
	public override function update(elapsed:Float) {
		if (subState == null) {
			MusicBeatState.timePassedOnState += elapsed;
			
			if (FlxG.keys.justPressed.F5 && !GlobalScriptHandler.resetting) { // add keybind?
				reset();
			} else {
				GlobalScriptHandler.resetting = false;
			}
		}
		
		var oldStep:Int = curStep;
		updateStep();
		updateBeat();
		updateSection();
		
		if (oldStep != curStep) {
			stepHit(curStep);

			if (PlayState.SONG != null) {
				if (oldStep < curStep) {
					forwardSection();
				} else {
					rollbackSection();
				}
			}
		}
		
		if (FlxG.save.data != null)
			FlxG.save.data.fullscreen = FlxG.fullscreen;
			
		stagesFunc((stage:BaseStage) -> stage.update(elapsed));
		super.update(elapsed);
	}
	public function reset():Void {
		GlobalScriptHandler.refreshScripts(FlxG.keys.pressed.SHIFT);
		MusicBeatState.switchState(FlxG.state);
	}
	
	function forwardSection():Void {
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		
		if (curStep == 0) sectionHit(0); // idgaf
		
		while (curStep >= stepsToDo) {
			curSection ++;
			updateSection();
			sectionHit(curSection);
			
			stepsToDo += Math.round(getBeatsOnSection() * 4);
		}
	}
	function rollbackSection():Void {
		if (curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (section in PlayState.SONG.notes) {
			if (section != null) {
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep)
					break;
				
				curSection ++;
			}
		}
		
		if (curSection > lastSection) {
			updateSection();
			sectionHit(curSection);
		}
	}
	public function getBeatsOnSection(?section:Int):Null<Float> {
		var val:Null<Float> = 4;
		section ??= curSection;
		
		if (PlayState.SONG != null && PlayState.SONG.notes[section] != null)
			val = PlayState.SONG.notes[section].sectionBeats;
		
		return (val == null ? 4 : val);
	}
	
	function updateStep():Void {
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = Math.floor(curDecStep);
	}
	function updateBeat():Void {
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
	}
	function updateSection():Void {
		if (PlayState.SONG == null) return;
		
		var lastSectionTime:Float = 0;
		var curCrochet:Float = Conductor.crochet;
		
		for (i => section in PlayState.SONG.notes) {
			curCrochet = Conductor.getBPMFromSeconds(lastSectionTime).stepCrochet * 4;
			var nextSectionTime = lastSectionTime + getBeatsOnSection(i) * curCrochet;
			
			if (nextSectionTime >= Conductor.songPosition - ClientPrefs.data.noteOffset)
				break;
			
			lastSectionTime = nextSectionTime;
		}
		
		curDecSection = curSection + (Conductor.songPosition - ClientPrefs.data.noteOffset - lastSectionTime) / curCrochet / getBeatsOnSection(curSection);
	}

	public function stepHit(step:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curDecStep = curDecStep;
			stage.curStep = step;
			stage.stepHit();
		});

		if (step % 4 == 0)
			beatHit(curBeat);
		
		GlobalScriptHandler.call('onStepHit', [step]);
	}
	public function beatHit(beat:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curDecBeat = curDecBeat;
			stage.curBeat = beat;
			stage.beatHit();
		});
		
		GlobalScriptHandler.call('onBeatHit', [beat]);
	}
	public function sectionHit(section:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = section;
			stage.sectionHit();
		});
		
		GlobalScriptHandler.call('onSectionHit', [section]);
	}
	
	public function stagesFunc(func:BaseStage->Void) {
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}
	
	public function addTextToDebug(text:String, ?color:FlxColor, ?size:Int) {
		ScriptedState.debugPrint(text, color, size);
	}
	
	public override function openSubState(subState:flixel.FlxSubState):Void {
		if (GlobalScriptHandler.call('onOpenSubState', [subState, Type.getClass(subState)]) != psychlua.LuaUtils.Function_Stop)
			super.openSubState(subState);
	}
	
	// shaders
	#if sys
	public var runtimeShaders:Map<String, Array<String>> = [];
	
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader {
		if (!ClientPrefs.data.shaders)
			return new ErrorHandledRuntimeShader(shaderName);
		
		if (!runtimeShaders.exists(shaderName) && !initRuntimeShader(shaderName)) {
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}
		
		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
	}
	
	public function initLuaShader(name:String, ?glslVersion:Int):Bool { return initRuntimeShader(name, glslVersion); }
	public function initRuntimeShader(name:String, glslVersion:Int = 120):Bool {
		if (!ClientPrefs.data.shaders)
			return false;
		
		if (runtimeShaders.exists(name)) {
			FlxG.log.warn('Shader $name is already initialized!');
			return true;
		}
		
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders')) {
			var frag:String = '$folder/$name.frag';
			var vert:String = '$folder/$name.vert';
			
			if (FileSystem.exists(frag)) {
				frag = File.getContent(frag);
			} else {
				frag = null;
			}
			if (FileSystem.exists(vert)) {
				vert = File.getContent(vert);
			} else {
				vert = null;
			}

			if (frag != null || vert != null) {
				runtimeShaders.set(name, [frag, vert]);
				return true;
			}
		}
		#if (SCRIPTS_ALLOWED)
		Log.print('No .frag or .vert code found for shader "$name"!', ERROR);
		#else
		FlxG.log.warn('No .frag or .vert code found for shader "$name"!');
		#end
		
		return false;
	}
	#end
}