package backend;

class MusicBeatSubstate extends flixel.FlxSubState {
	var stepsToDo:Int = 0;
	
	public var curSection:Int = 0;
	public var curStep:Int = 0;
	public var curBeat:Int = 0;
	
	public var curDecStep:Float = 0;
	public var curDecBeat:Float = 0;
	
	var _pre:Bool = false;
	var _psychCameraInitialized:Bool = false;
	
	public var stages:Array<BaseStage> = [];
	public var variables:Map<String, Dynamic> = [];
	
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
	}
	public function preCreate():Void {
		_pre = true;
	}
	
	public function updatePresence():Void {
		#if DISCORD_ALLOWED
		if (autoUpdateRPC && (rpcDetails != null || rpcState != null))
			DiscordClient.changePresence(rpcDetails, rpcState);
		#end
	}
	
	public var controls(get, never):Controls;
	function get_controls() {
		return Controls.instance;
	}
	
	public override function update(elapsed:Float) {
		MusicBeatState.timePassedOnState += elapsed;
		
		var oldStep:Int = curStep;
		updateCurStep();
		updateBeat();
		
		if (oldStep != curStep) {
			if (curStep > 0)
				stepHit();

			if (PlayState.SONG != null) {
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}
		
		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;
			
		stagesFunc((stage:BaseStage) -> stage.update(elapsed));
		
		if (FlxG.keys.justPressed.F5) // add keybind?
			reset();
		
		super.update(elapsed);
	}
	public function reset():Void {
		MusicBeatState.switchState(FlxG.state);
	}
	
	function updateSection():Void {
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		
		while (curStep >= stepsToDo) {
			curSection ++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
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

		if (curSection > lastSection) sectionHit();
	}
	public function getBeatsOnSection() {
		var val:Null<Float> = 4;
		
		if (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null)
			val = PlayState.SONG.notes[curSection].sectionBeats;
		
		return (val == null ? 4 : val);
	}
	
	function updateBeat():Void {
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}
	function updateCurStep():Void {
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public function stepHit():Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}
	public function beatHit():Void {
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}
	public function sectionHit():Void {
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}
	
	public function stagesFunc(func:BaseStage->Void) {
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}
}