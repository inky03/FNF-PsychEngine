package backend;

import backend.Song;
import objects.Note;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm(default, set):Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float = 0;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = 0; // is calculated in create(), is safeFrames in milliseconds

	public static var bpmChangeMap:Array<BPMChangeEvent> = defaultBPMChangeMap(bpm);

	public static function judgeNote(arr:Array<Rating>, diff:Float=0):Rating // die
	{
		var data:Array<Rating> = arr;
		for(i in 0...data.length-1) //skips last window (Shit)
			if (diff <= data[i].hitWindow)
				return data[i];

		return data[data.length - 1];
	}

	public static function getStepCrotchetAtTime(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		var lastChange = getBPMFromSeconds(time, bpmChangeMap);
		return lastChange.stepCrochet;
	}
	
	public static function getCrotchetAtTime(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		return getStepCrotchetAtTime(time, bpmChangeMap) * 4;
	}

	public static function getBPMFromSeconds(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		bpmChangeMap ??= Conductor.bpmChangeMap;
		
		var lastChange:BPMChangeEvent = null;
		for (change in bpmChangeMap) {
			if (time >= change.songTime || lastChange == null)
				lastChange = change;
		}

		return lastChange;
	}

	public static function getBPMFromStep(step:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		bpmChangeMap ??= Conductor.bpmChangeMap;
		
		var lastChange:BPMChangeEvent = null;
		for (change in bpmChangeMap) {
			if (change.stepTime <= step || lastChange == null)
				lastChange = change;
		}

		return lastChange;
	}
	
	public static function stepToSeconds(step:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Float {
		var lastChange = getBPMFromStep(step, bpmChangeMap);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60) / 4) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	public static function beatToSeconds(beat:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Float {
		return stepToSeconds(beat * 4, bpmChangeMap);
	}

	public static function getStep(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		var lastChange = getBPMFromSeconds(time, bpmChangeMap);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		var lastChange = getBPMFromSeconds(time, bpmChangeMap);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		return getStep(time, bpmChangeMap)/4;
	}

	public static function getBeatRounded(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Int{
		return Math.floor(getStepRounded(time, bpmChangeMap)/4);
	}

	public static function mapBPMChanges(?song:SwagSong) {
		if (song == null) {
			bpmChangeMap = defaultBPMChangeMap(Conductor.bpm);
			return;
		}
		
		bpmChangeMap = defaultBPMChangeMap(song.bpm);
		
		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM) / 4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		trace('Added ${bpmChangeMap.length} BPM changes');
	}
	public static function copyBPMChanges(?bpmChanges:Array<BPMChangeEvent>):Array<BPMChangeEvent> {
		bpmChanges ??= Conductor.bpmChangeMap;
		
		var newBPMMap:Array<BPMChangeEvent> = [];
		for (change in bpmChanges)
			newBPMMap.push(Reflect.copy(change));
		
		return newBPMMap;
	}
	public static function defaultBPMChangeMap(bpm:Float = 100):Array<BPMChangeEvent> {
		return [{
			bpm: bpm,
			stepTime: 0,
			songTime: 0,
			stepCrochet: calculateCrochet(bpm) * .25
		}];
	}

	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

	public static function set_bpm(newBPM:Float):Float {
		crochet = calculateCrochet(newBPM);
		stepCrochet = crochet / 4;
		bpm = newBPM;
		
		if (bpmChangeMap == null || bpmChangeMap.length == 0) {
			mapBPMChanges();
		} else if (Math.abs(bpm - bpmChangeMap[0].bpm) < 1) {
			bpmChangeMap[0].stepCrochet = stepCrochet;
			bpmChangeMap[0].bpm = bpm;
		}

		return newBPM;
	}
}