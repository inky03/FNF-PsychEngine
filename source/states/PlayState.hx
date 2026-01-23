package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
import openfl.filters.ShaderFilter;
#end

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

/*here's some useful tips if you are making a mod in source:

If you want to add your stage to the game, copy states/stages/Template.hx,
and put your stage code there, then, on PlayState, search for
"switch (curStage)", and add your stage to that list.

If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:

"function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
"function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
"function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
"function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for*/

/**
 * This is the main state of the game, where gameplay happens and is managed.
*/
class PlayState extends ScriptedState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	/**
	 * Rating names used on the score text.
	*/
	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	/**
	 * If set to true, the camera focus position won't change every measure.
	*/
	private var isCameraOnForcedPos:Bool = false;

	/**
	 * Map containing all precached characters the player character will change to (with the Change Character event).
	*/
	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	/**
	 * Map containing all precached characters the opponent character will change to (with the Change Character event).
	*/
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	/**
	 * Map containing all precached characters the speakers (middle) character will change to (with the Change Character event).
	*/
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	var BF_X:Float = 770;
	var BF_Y:Float = 100;
	var DAD_X:Float = 100;
	var DAD_Y:Float = 100;
	var GF_X:Float = 400;
	var GF_Y:Float = 130;

	/**
	 * Scroll speed for the current song.
	*/
	public var songSpeed(default, set):Float = 1;
	/**
	 * Scroll speed type, used in Gameplay Modifiers.
	*/
	public var songSpeedType:String = "multiplicative";
	/**
	 * Time (in milliseconds) past a note's hit time at which it will despawn.
	*/
	public var noteKillOffset:Float = 350;
	@:dox(hide) var songSpeedTween:FlxTween;

	/**
	 * The speed multiplier for the song and gameplay. 2x means 200% speed.
	*/
	public var playbackRate(default, set):Float = 1;

	/**
	 * Group containing all precached characters the player character will change to (with the Change Character event).
	*/
	public var boyfriendGroup:FlxSpriteGroup;
	/**
	 * Group containing all precached characters the player character will change to (with the Change Character event). Shorthand for `boyfriendGroup`.
	*/
	public var bfGroup(get, never):FlxSpriteGroup;
	/**
	 * Group containing all precached characters the opponent character will change to (with the Change Character event).
	*/
	public var dadGroup:FlxSpriteGroup;
	/**
	 * Group containing all precached characters the speakers (middle) character will change to (with the Change Character event).
	*/
	public var gfGroup:FlxSpriteGroup;
	
	/**
	 * The name of the current stage, defined in the song's JSON.
	*/
	public static var curStage:String = '';
	/**
	 * The name of the current stage UI, defined in the stage's JSON.
	 * This changes the image path of UI elements such as the notes and the rating pop ups.
	*/
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal" && value != '')
		{
			uiPrefix = value.split("-pixel")[0].trim() + 'UI/';
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}
	public static function formatUI(key:String):String {
		return '$uiPrefix$key$uiPostfix';
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");
	
	@:noCompletion function get_bf():Character
		return boyfriend;
	@:noCompletion function get_bfGroup():FlxSpriteGroup
		return boyfriendGroup;
	
	/**
	 * Holds data of the current song chart.
	*/
	public static var SONG:SwagSong = null;
	/**
	 * Holds data of the current events chart (if available).
	*/
	public static var EVENTS:SwagSong = null;
	/**
	 * Name of the current song, as defined in the chart JSON.
	*/
	public var curSong:String = '';
	/**
	 * Name of the current song, as defined in the chart JSON, formatted to match the data folder.
	*/
	public var songName:String;
	
	/**
	 * Whether this state was entered to from Story Mode.
	*/
	public static var isStoryMode:Bool = false;
	/**
	 * Whether this state was entered to from Story Mode.
	*/
	public static var storyPlaylist:Array<String> = [];
	/**
	 * Holds data of the current story week (if entered to from Story Mode).
	*/
	public static var storyWeekData:WeekData = null;
	/**
	 * Variables that will persist between Story Mode songs.
	 * This map is cleared after a story week.
	*/
	public static var storyVariables:Map<String, Dynamic> = [];
	/**
	 * The ID of the current difficulty selected for this song.
	*/
	public static var storyDifficulty:Int = 1;
	/**
	 * The ID of the current story week (if entered to from Story Mode).
	*/
	public static var storyWeek:Int = 0;
	
	/**
	 * The time (in milliseconds) a note can spawn earlier to it's hit time.
	*/
	public var spawnTime:Float = 2000;
	/**
	 * Whether missing notes should play a sound or not.
	*/
	public var playMissSound:Bool = true;

	/**
	 * The instrumental of the song.
	*/
	public var inst:FlxSound;
	/**
	 * The [player] vocals of the song.
	*/
	public var vocals:FlxSound;
	/**
	 * The opponent vocals of the song (if available).
	*/
	public var opponentVocals:FlxSound;
	
	/**
	 * The player side character.
	*/
	public var boyfriend:Character = null;
	/**
	 * The player side character. Shorthand for `boyfriend`.
	*/
	public var bf(get, never):Character;
	/**
	 * The opponent side character.
	*/
	public var dad:Character = null;
	/**
	 * The speakers (middle) character.
	*/
	public var gf:Character = null;
	
	/**
	 * Group containing all notes currently on-screen.
	*/
	public var notes:FlxTypedGroup<Note>;
	/**
	 * Array containing all notes queued to spawn later.
	*/
	public var unspawnNotes:Array<Note> = [];
	/**
	 * Array containing all events queued to be triggered later.
	*/
	public var eventNotes:Array<EventNote> = [];

	/**
	 * Acts as the camera focus. The game camera will follow this object.
	*/
	public var camFollow:FlxObject;
	@:dox(hide) private static var prevCamFollow:FlxObject;

	/**
	 * Group containing all note receptors.
	*/
	public var strumLineNotes:FlxTypedSpriteGroup<StrumNote> = new FlxTypedSpriteGroup<StrumNote>();
	/**
	 * Group containing the player's note receptors.
	*/
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	/**
	 * Group containing the opponent's note receptors.
	*/
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	/**
	 * Group containing all note splashes.
	*/
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();

	/**
	 * Whether the camera should bop every measure or not.
	 * This is set to true for every opponent note hit, if `camZoomingDisabled` is false.
	*/
	public var camZooming:Bool = false;
	/**
	 * If true, opponent note hits will not set `camZooming` to true.
	*/
	public var camZoomingDisabled:Bool = false;
	/**
	 * Multiplier for the camera bopping.
	*/
	public var camZoomingMult:Float = 1;
	/**
	 * Multiplier for the decay time of the camera bopping.
	*/
	public var camZoomingDecay:Float = 1;

	/**
	 * How frequently the speakers (middle) character should bop every beat.
	 * 1 is every one beat, 2 is every two beats, and so on.
	*/
	public var gfSpeed:Int = 1;
	/**
	 * The health of the player.
	 * 0 is 0% health, and 2 is 100% health.
	*/
	public var health(default, set):Float = 1;
	/**
	 * The note combo of the player.
	*/
	public var combo:Int = 0;

	/**
	 * The current song's length (in milliseconds).
	*/
	public var songLength:Float = 0;
	/**
	 * The current song's progress represented as a `Float`.
	 * 0 is 0% progressed, and 1 is 100% progressed.
	*/
	var songPercent:Float = 0;
	public var healthBar:Bar;
	public var timeBar:Bar;

	/**
	 * Data for the ratings, used to judge note hits.
	*/
	public var ratingsData:Array<Rating> = Rating.loadDefault();

	/**
	 * If the player changed difficulty in the Pause Menu.
	*/
	public static var changedDifficulty:Bool = false;
	/**
	 * If the player is in Charting Mode.
	*/
	public static var chartingMode:Bool = false;
	public var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	public var updateTime:Bool = true;

	//Gameplay settings
	/**
	 * Multiplier for the health gained by hitting a note successfully.
	*/
	public var healthGain:Float = 1;
	/**
	 * Multiplier for the health lost by missing a note.
	*/
	public var healthLoss:Float = 1;

	/**
	 * Whether or not Sustains as One Note is enabled.
	*/
	public var guitarHeroSustains:Bool = false;
	/**
	 * Whether or not the "Instakill on Miss" Gameplay modifier is enabled.
	*/
	public var instakillOnMiss:Bool = false;
	/**
	 * Whether or not Bot Play is enabled.
	*/
	public var cpuControlled:Bool = false;
	/**
	 * Whether or not Practice Mode is enabled.
	*/
	public var practiceMode:Bool = false;
	/**
	 * Whether or not Ghost Tapping is enabled.
	*/
	public var ghostTapping:Bool = false;
	/**
	 * The default damage caused by missing a note.
	*/
	public var pressMissDamage:Float = 0.05;

	public var botplayTxt:FlxText;
	public var botplaySine:Float = 0;

	/**
	 * The player character's healthbar icon.
	*/
	public var iconP1:HealthIcon;
	/**
	 * The opponent character's healthbar icon.
	*/
	public var iconP2:HealthIcon;
	/**
	 * The camera used for the HUD.
	*/
	public var camHUD:FlxCamera;
	/**
	 * The camera used for the game.
	*/
	public var camGame:FlxCamera;
	/**
	 * Speed multiplier for the camera to shift towards its focus.
	*/
	public var cameraSpeed:Float = 1;

	/**
	 * The player's current score.
	*/
	public var songScore:Int = 0;
	/**
	 * How many notes have been successfully hit since the start of the song.
	*/
	public var songHits:Int = 0;
	/**
	 * How many notes have been missed since the start of the song.
	*/
	public var songMisses:Int = 0;
	/**
	 * The text that displays the player's current score and rating.
	*/
	public var scoreTxt:FlxText;
	public var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	/**
	 * The player's accumulated score since the start of the week (in Story Mode).
	*/
	public static var campaignScore:Int = 0;
	/**
	 * The player's accumulated miss count since the start of the week (in Story Mode).
	*/
	public static var campaignMisses:Int = 0;
	/**
	 * The amount of times the player has died in this song.
	*/
	public static var deathCounter:Int = 0;
	/**
	 * Whether or not the player has seen the current song's cutscene.
	*/
	public static var seenCutscene:Bool = false;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	/**
	 * Whether or not the player is currently viewing a cutscene.
	 * Setting to true pauses certain gameplay inputs and logic.
	*/
	public var inCutscene:Bool = false;
	/**
	 * Whether or not the game should skip the countdown sequence.
	 * Only effective if changed during state creation!
	*/
	public var skipCountdown:Bool = false;

	/**
	 * The player character's camera offset, as defined in the stage JSON.
	*/
	public var boyfriendCameraOffset:Array<Float> = null;
	/**
	 * The opponent character's camera offset, as defined in the stage JSON.
	*/
	public var opponentCameraOffset:Array<Float> = null;
	/**
	 * The speakers (middle) character's camera offset, as defined in the stage JSON.
	*/
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	@:dox(hide) var keysPressed:Array<Int> = [];
	@:dox(hide) var boyfriendIdleTime:Float = 0.0;
	@:dox(hide) var boyfriendIdled:Bool = false;

	// Lua shit
	/**
	 * The current PlayState instance.
	*/
	public static var instance:PlayState;
	
	/**
	 * Suffix for the sounds played during the countdown.
	*/
	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;

	// Callbacks for stages
	/**
	 * Function called before the countdown starts.
	*/
	public var startCallback:Void->Void = null;
	/**
	 * Function called before the song finishes.
	*/
	public var endCallback:Void->Void = null;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;
	override public function create()
	{
		//trace('Playback Rate: ' + playbackRate);
		_lastLoadedModDirectory = Mods.currentModDirectory;
		Paths.clearStoredMemory();
		if(nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;

		startCallback = () -> stagesFunc(function(stage:BaseStage) stage.startCountdown());
		endCallback = () -> stagesFunc(function(stage:BaseStage) stage.endSong());

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left',
			'note_down',
			'note_up',
			'note_right'
		];

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		ghostTapping = ClientPrefs.data.ghostTapping;
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		FlxG.cameras.add(camHUD, false);

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) //Backward compatibility
			stageUI = "pixel";

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage) {
			case 'stage': new StageWeek1(); 			//Week 1
			case 'spooky': new Spooky();				//Week 2
			case 'philly': new Philly();				//Week 3
			case 'limo': new Limo();					//Week 4
			case 'mall': new Mall();					//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();			//Week 5 - Winter Horrorland
			case 'school': new School();				//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();		//Week 6 - Thorns
			case 'tank': new Tank();					//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();	//Weekend 1 - Blazin
			default: new BaseStage();
		}
		if(isPixelStage) introSoundsSuffix = '-pixel';

		if (!stageData.hide_girlfriend) {
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if(stageData.objects != null && stageData.objects.length > 0) {
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if(!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else {
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		generateStaticArrows(false);
		generateStaticArrows(true);
		
		preCreate();
		
		#if (SCRIPTS_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					initLuaScript('$folder$file');
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript('$folder$file');
				#end
			}
		#end
			
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		#if (SCRIPTS_ALLOWED)
		// STAGE SCRIPTS
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if(gf != null) startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);
		
		lastBeatHit = -6;
		lastStepHit = lastBeatHit * 4;
		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if(ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = SONG.song;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		if(ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		noteGroup.add(grpNoteSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		uiGroup.add(scoreTxt);

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if(ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		// SONG SPECIFIC SCRIPTS
		#if (SCRIPTS_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					initLuaScript(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end

		if(eventNotes.length > 0)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}
		
		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0001; //cant make it invisible or it won't allow precaching
		
		if (ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
		if (!ghostTapping) for (i in 1...4) Paths.sound('missnote$i');	
		Paths.image('alphabet');
		
		cacheCountdown();
		cachePopUpScore();
		
		startCallback();
		RecalculateRating(false, false);
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		
		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if(Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));
		
		resetRPC();
		
		stagesFunc(function(stage:BaseStage) stage.createPost());
		super.create();
		Paths.clearUnusedMemory();
		
		if(eventNotes.length < 1) checkEventNote();
	}
	
	#if LUA_ALLOWED
	public override function implementLua(lua:FunkinLua):Void {
		// VARIABLES
		// Song/Week shit
		lua.set('curBpm', Conductor.bpm);
		lua.set('bpm', SONG.bpm);
		lua.set('scrollSpeed', SONG.speed);
		lua.set('crochet', Conductor.crochet);
		lua.set('stepCrochet', Conductor.stepCrochet);
		lua.set('songLength', FlxG.sound.music.length);
		lua.set('songName', SONG.song);
		lua.set('songPath', Paths.formatToSongPath(SONG.song));
		lua.set('loadedSongName', Song.loadedSongName);
		lua.set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
		lua.set('chartPath', Song.chartPath);
		lua.set('startedCountdown', false);
		lua.set('curStage', SONG.stage);
		
		lua.set('isStoryMode', isStoryMode);
		lua.set('difficulty', storyDifficulty);
		
		lua.set('difficultyName', Difficulty.getString(false));
		lua.set('difficultyPath', Difficulty.getFilePath());
		lua.set('difficultyNameTranslation', Difficulty.getString(true));
		lua.set('weekRaw', storyWeek);
		lua.set('week', WeekData.weeksList[storyWeek]);
		lua.set('seenCutscene', seenCutscene);
		lua.set('hasVocals', SONG.needsVoices);
		
		// Gameplay variables
		lua.set('score', songScore);
		lua.set('misses', songMisses);
		lua.set('hits', songHits);
		lua.set('combo', combo);
		lua.set('deaths', deathCounter);
		
		lua.set('rating', ratingPercent);
		lua.set('ratingName', ratingName);
		lua.set('ratingFC', ratingFC);
		lua.set('totalPlayed', totalPlayed);
		lua.set('totalNotesHit', totalNotesHit);
		lua.set('inGameOver', false);
		
		var curSection:SwagSection = SONG.notes[curSection];
		lua.set('mustHitSection', curSection != null ? (curSection.mustHitSection == true) : false);
		lua.set('altAnim', curSection != null ? (curSection.altAnim == true) : false);
		lua.set('gfSection', curSection != null ? (curSection.gfSection == true) : false);

		lua.set('healthGainMult', healthGain);
		lua.set('healthLossMult', healthLoss);

		#if FLX_PITCH
		lua.set('playbackRate', playbackRate);
		#else
		lua.set('playbackRate', 1);
		#end

		lua.set('guitarHeroSustains', guitarHeroSustains);
		lua.set('instakillOnMiss', instakillOnMiss);
		lua.set('botPlay', cpuControlled);
		lua.set('practice', practiceMode);
		
		for (i in 0...4) {
			lua.set('defaultPlayerStrumX' + i, 0);
			lua.set('defaultPlayerStrumY' + i, 0);
			lua.set('defaultOpponentStrumX' + i, 0);
			lua.set('defaultOpponentStrumY' + i, 0);
		}
		
		// Default character data
		lua.set('defaultBoyfriendX', BF_X);
		lua.set('defaultBoyfriendY', BF_Y);
		lua.set('defaultOpponentX', DAD_X);
		lua.set('defaultOpponentY', DAD_Y);
		lua.set('defaultGirlfriendX', GF_X);
		lua.set('defaultGirlfriendY', GF_Y);
		
		lua.set('boyfriendName', boyfriend != null ? boyfriend.curCharacter : SONG.player1);
		lua.set('dadName', dad != null ? dad.curCharacter : SONG.player2);
		lua.set('gfName', gf != null ? gf.curCharacter : SONG.gfVersion);
		
		// Other settings
		lua.set('downscroll', ClientPrefs.data.downScroll);
		lua.set('middlescroll', ClientPrefs.data.middleScroll);
		lua.set('framerate', ClientPrefs.data.framerate);
		lua.set('ghostTapping', ClientPrefs.data.ghostTapping);
		lua.set('hideHud', ClientPrefs.data.hideHud);
		lua.set('antialiasing', ClientPrefs.data.antialiasing);
		lua.set('timeBarType', ClientPrefs.data.timeBarType);
		lua.set('scoreZoom', ClientPrefs.data.scoreZoom);
		lua.set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		lua.set('flashingLights', ClientPrefs.data.flashing);
		lua.set('noteOffset', ClientPrefs.data.noteOffset);
		lua.set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		lua.set('noResetButton', ClientPrefs.data.noReset);
		lua.set('lowQuality', ClientPrefs.data.lowQuality);
		lua.set('shadersEnabled', ClientPrefs.data.shaders);

		// Noteskin/Splash
		lua.set('noteSkin', ClientPrefs.data.noteSkin);
		lua.set('noteSkinPostfix', Note.getNoteSkinPostfix());
		lua.set('splashSkin', ClientPrefs.data.splashSkin);
		lua.set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		lua.set('splashAlpha', ClientPrefs.data.splashAlpha);
	}
	#end

	function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			vocals.pitch = value;
			opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if(videoCutscene != null && videoCutscene.videoSprite != null) #if hxvlc videoCutscene.videoSprite.bitmap.rate = value; #end
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	/**
	 * Precaches a character.
	 * 
	 * @param 	type 	Side to precache the character on. 0: Player. 1: Opponent. 2: Speakers (middle)
	*/
	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	@:dox(hide) function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if(FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if(Assets.exists(luaFile)) doPush = true;
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if(doPush) initLuaScript(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		#end
		{
			scriptFile = Paths.getSharedPath(scriptFile);
			if(FileSystem.exists(scriptFile))
				doPush = true;
		}

		if(doPush)
		{
			if(crowplexus.iris.Iris.instances.exists(scriptFile))
				doPush = false;

			if(doPush) initHScript(scriptFile);
		}
		#end
	}
	
	/**
	 * Gets an object defined in the `variables` map (ex. from Lua scripts)
	 * 
	 * @param 	tag 	`String` tag for this object.
	*/
	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	@:dox(hide) function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	/**
	 * Video instance used when playing cutscenes.
	*/
	public var videoCutscene:VideoSprite = null;
	/**
	 * Starts a video cutscene.
	 * 
	 * @param 	name 		Name of the video to play (should be in the `videos/` folder)
	 * @param 	forMidSong  Whether or not the game should be paused until the cutscene finishes.
	 * @param 	canSkip 	Whether this cutscene can be skipped.
	 * @param 	loop 		Whether the cutscene video should loop.
	 * @param 	playOnLoad 	Whether or not the cutscene should be played instantly after loading.
	 * 
	 * @return 	The video cutscene.
	*/
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;
		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			#if hxvlc
			if(forMidSong) videoCutscene.videoSprite.bitmap.rate = playbackRate;
			#end
			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			if (GameOverSubstate.instance != null && isDead) GameOverSubstate.instance.add(videoCutscene);
			else add(videoCutscene);
			#if hxvlc
			if (playOnLoad)
				videoCutscene.play();
			#end
			return videoCutscene;
		}
		#if (SCRIPTS_ALLOWED)
		else addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	@:dox(hide) function startAndEnd() {
		if (endingSong) {
			endSong();
		} else {
			startCountdown();
		}
	}
	
	/**
	 * Restarts this song.
	 * 
	 * @param 	skipTransition 	Whether the fade transition should be skipped when restarting.
	*/
	public static function restartSong(skipTransition:Bool = false):Void {
		if (instance == null || instance.callOnScripts('onRestartSong', null, true) == LuaUtils.Function_Stop) return;
		
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if (skipTransition) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}
	/**
	 * Exits from this song to the menu.
	 * Does not save highscore or any achievements obtained from completing the song.
	 * 
	 * @param 	skipTransition 	Whether the fade transition should be skipped when exiting.
	*/
	public static function exitSong(skipTransition:Bool = false):Void {
		if (instance == null || instance.callOnScripts('onExitSong', null, true) == LuaUtils.Function_Stop) return;
		
		if (skipTransition) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		
		Mods.loadTopMod();
		if (PlayState.isStoryMode) {
			MusicBeatState.switchState(new StoryMenuState());
		} else {
			MusicBeatState.switchState(new FreeplayState());
		}

		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		PlayState.instance.canResync = false;
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	/**
	 * Starts a dialogue cutscene.
	 * 
	 * @param 	dialogueFile 	Dialogue file used to play the cutscene. Use `DialogueBoxPsych.parseDialogue(path)` to parse a file!
	 * @param 	song 			If specified, plays music with this name. Should be in the `music/` folder.
	*/
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	/**
	 * Countdown "Ready" sprite. Useful for Lua scripts.
	*/
	public var countdownReady:FlxSprite;
	/**
	 * Countdown "Set" sprite. Useful for Lua scripts.
	*/
	public var countdownSet:FlxSprite;
	/**
	 * Countdown "Go" sprite. Useful for Lua scripts.
	*/
	public var countdownGo:FlxSprite;
	/**
	 * Time (in milliseconds) for the song to start at. Useful for playtesting.
	*/
	public static var startOnTime:Float = 0;

	@:dox(hide) function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = [formatUI('ready'), formatUI('set'), formatUI('go')];
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	/**
	 * Prepares the game and starts the countdown.
	*/
	public function startCountdown()
	{
		if (startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}
		
		inCutscene = false;
		seenCutscene = true;
		
		strumLineNotes.revive();
		
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if (ret != LuaUtils.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			canPause = true;
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}
			
			if (!skipArrowStartTween && !isStoryMode && startOnTime <= 0)
				tweenInArrows();

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				if (startOnTime > 700) clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 700);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();
		} else {
			strumLineNotes.kill();
		}
		
		return true;
	}
	
	@:dox(hide) static var introAssets:Map<String, Array<String>> = [];
	public function countdownTick(tick:Countdown):Void {
		if (skipCountdown) return;
		
		var introImagesArray:Array<String> = [formatUI('ready'), formatUI('set'), formatUI('go')];
		introAssets.set(stageUI, [formatUI('ready'), formatUI('set'), formatUI('go')]);
		
		var introAlts:Array<String> = introAssets.get(stageUI);
		var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
		
		var counter:Int = switch (tick) {
			case THREE:
				FlxG.sound.play(Paths.sound('intro3$introSoundsSuffix'), .6);
				0;
			case TWO:
				countdownReady = createCountdownSprite(introAlts[0], antialias);
				FlxG.sound.play(Paths.sound('intro2$introSoundsSuffix'), .6);
				1;
			case ONE:
				countdownSet = createCountdownSprite(introAlts[1], antialias);
				FlxG.sound.play(Paths.sound('intro1$introSoundsSuffix'), .6);
				2;
			case GO:
				countdownGo = createCountdownSprite(introAlts[2], antialias);
				FlxG.sound.play(Paths.sound('introGo$introSoundsSuffix'), .6);
				3;
			case START:
				4;
		}

		stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, counter));
		callOnLuas('onCountdownTick', [counter]);
		callOnHScript('onCountdownTick', [tick, counter]);
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	/**
	 * Adds a sprite behind `gfGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	/**
	 * Adds a sprite behind `boyfriendGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	/**
	 * Adds a sprite behind `dadGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	/**
	 * Clears all notes before the specified time (in milliseconds).
	 * 
	 * @param 	time 	The time to clear all notes until.
	*/
	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - ClientPrefs.data.noteOffset < time - 1)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - ClientPrefs.data.noteOffset < time - 1)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	/**
	 * Updates the score and calls `preUpdateScore` and `onUpdateScore` on Lua.
	 * 
	 * @param 	miss 		Whether or not the score was updated from a note miss.
	 * @param 	scoreBop 	Whether or not the score text should have a bopping animation.
	*/
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
			return;

		updateScoreText();
		if (!miss && !cpuControlled && scoreBop)
			doScoreBop();

		callOnScripts('onUpdateScore', [miss]);
	}

	/**
	 * Updates the score text.
	*/
	public dynamic function updateScoreText()
	{
		var str:String = Language.getPhrase('rating_$ratingName', ratingName);
		if(totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
		}

		var tempScore:String;
		if(!instakillOnMiss) tempScore = Language.getPhrase('score_text', 'Score: {1} | Misses: {2} | Rating: {3}', [Std.string(songScore), Std.string(songMisses), str]);
		else tempScore = Language.getPhrase('score_text_instakill', 'Score: {1} | Rating: {2}', [Std.string(songScore), str]);
		scoreTxt.text = tempScore;
	}

	/**
	 * Updates the FC status and saves it in the `ratingFC` variable.
	*/
	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = (ratingsData[1]?.hits ?? 0);
		var bads:Int = (ratingsData[2]?.hits ?? 0);
		var shits:Int = (ratingsData[3]?.hits ?? 0);

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else {
			if (songMisses < 10) ratingFC = 'SDCB';
			else ratingFC = 'Clear';
		}
	}

	/**
	 * Makes the score text do a bopping animation.
	*/
	public function doScoreBop():Void {
		if(!ClientPrefs.data.scoreZoom)
			return;

		if(scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween) {
				scoreTxtTween = null;
			}
		});
	}

	/**
	 * Changes the song time.
	 * 
	 * @param 	time 	The time (in milliseconds) to change the song time to.
	 * @param 	offset 	Whether or not the time should consider the Conductor offset.
	*/
	public function setSongTime(time:Float, offset:Bool = true)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();
		
		if (time >= 0) {
			FlxG.sound.music.time = (time - (offset ? 0 : Conductor.offset));
			#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
			FlxG.sound.music.play();

			if (Conductor.songPosition < vocals.length)
			{
				vocals.time = FlxG.sound.music.time;
				#if FLX_PITCH vocals.pitch = playbackRate; #end
				vocals.play();
			}
			else vocals.pause();

			if (Conductor.songPosition < opponentVocals.length)
			{
				opponentVocals.time = FlxG.sound.music.time;
				#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
				opponentVocals.play();
			}
			else opponentVocals.pause();
		}
		
		Conductor.songPosition = (time + (offset ? Conductor.offset : 0));
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;
		strumLineNotes.revive();

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();
		
		var startPos:Float = Math.max(0, startOnTime - 700);
		setSongTime(startPos, startOnTime <= 0);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if(autoUpdateRPC) DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart', [startPos]);
	}

	/**
	 * Array containing all unique note types found in the chart.
	*/
	public var noteTypes:Array<String> = [];
	/**
	 * Array containing all unique events found in the chart.
	*/
	public var eventsPushed:Array<String> = [];
	/**
	 * The total amount of columns per strumline.
	*/
	public var totalColumns: Int = 4;

	@:dox(hide) private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		try
		{
			EVENTS = Song.getChart('events', songName);
			
			if (EVENTS != null)
				for (event in EVENTS.events) //Event Notes
					for (i in 0...event[1].length)
						makeEvent(event, i);
		} catch(e:Dynamic) {
			EVENTS = null;
		}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (sectionI => section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i => songNotes in section.sectionNotes) {
				var spawnTime: Float = songNotes[0];
				var noteColumn: Int = Std.int(songNotes[1] % totalColumns);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var gottaHitNote:Bool = (songNotes[1] < totalColumns);

				if (i > 0) {
					var matches:Bool = false;
					for (evilNote in unspawnNotes) {
						if (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType) {
							if (Math.abs(spawnTime - evilNote.strumTime + delay) > FlxMath.EPSILON) continue;
							ghostNotesCaught ++;
							matches = true;
							break;
						}
					}
					if (matches)
						continue;
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.sustainLength = holdLength;
				swagNote.mustPress = gottaHitNote;
				swagNote.noteType = noteType;
				swagNote.section = sectionI;
	
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);
				
				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if(roundSus > 0)
				{
					for (susNote in 0...roundSus) {
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.sustainLength = curStepCrochet;
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.scrollFactor.set();
						sustainNote.section = sectionI;
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);
						
						if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
						else if(ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if(noteColumn > 1) //Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if(noteColumn > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if(!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}
		
		if (ghostNotesCaught > 0)
			trace('(${SONG.song}) $ghostNotesCaught duplicate notes ignored');
		
		for (event in songData.events) //Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);
		
		if (!skipArrowStartTween && !isStoryMode) {
			notes.forEachAlive(function(note:Note) {
				if (ClientPrefs.data.opponentStrums || note.mustPress) {
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if(ClientPrefs.data.middleScroll && !note.mustPress)
						note.alpha *= 0.35;
				}
			});
		}

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	/**
	 * Called once every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	*/
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	/**
	 * Called every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	*/
	function eventPushedUnique(event:EventNote) {
		switch(event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if(Math.isNaN(val1)) val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); //Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	/**
	 * Called every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	 * 
	 * @return 	The time (in milliseconds) of how early the event should play to it's chart time.
	*/
	function eventEarlyTrigger(event:EventNote):Float {
		var returnedValue:Dynamic = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true);
		if (returnedValue != null && Std.isOfType(returnedValue, Float) && returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	/**
	 * Sorts two objects by their `strumTime` in ascending order.
	 * 
	 * @param 	a 	First object to sort.
	 * @param 	b 	Second object to sort.
	 * 
	 * @return 	Sort order.
	*/
	public static function sortByTime(a:Dynamic, b:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);

	@:dox(hide) function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.strumTime]);
	}
	
	/**
	 * Whether or not the note fade-in animation should be skipped at the start of a song. Ignored in Story Mode or when `skipCountdown` is true.
	*/
	public var skipArrowStartTween:Bool = false; //for lua
	private function generateStaticArrows(player:Bool):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = 50;
		
		for (i in 0 ... 4) {
			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player ? 1 : 0);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			
			if (babyArrow.downScroll)
				babyArrow.y = (FlxG.height - babyArrow.height - babyArrow.y);
			
			if (!player) {
				if (!ClientPrefs.data.opponentStrums) babyArrow.alpha = 0;
				else if (ClientPrefs.data.middleScroll) babyArrow.alpha = 0.35;
			}

			if (player) {
				playerStrums.add(babyArrow);
			} else {
				if (ClientPrefs.data.middleScroll) {
					babyArrow.x += 310;
					if (i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();
		}
	}
	function tweenInArrows():Void {
		for (group in [playerStrums, opponentStrums]) {
			for (i => strum in group.members) {
				
				var targetY:Float = strum.y;
				var targetAlpha:Float = strum.alpha;
				
				strum.revive();
				strum.alpha = 0;
				strum.y += (ClientPrefs.data.downScroll ? 10 : -10);
				FlxTween.tween(strum, {y: targetY, alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: .5 + .2 * i});
			}
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		
		if (paused) {
			FlxG.sound.music?.pause();
			opponentVocals?.pause();
			vocals?.pause();
			
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void {
		super.onFocus();
		resetRPC(Conductor.songPosition > 0);
	}

	override public function onFocusLost():Void {
		super.onFocusLost();
		if (health > 0)
			resetRPC(false);
	}
	#end
	
	override function updatePresence():Void {
		if (autoUpdateRPC)
			resetRPC(Conductor.songPosition > 0);
	}

	// Updating Discord Rich Presence.
	function resetRPC(showTime:Bool = false) {
		#if DISCORD_ALLOWED
		if (!autoUpdateRPC) return;
		
		var detailsText:String = (paused ? this.detailsPausedText : this.detailsText);
		var stateText:String = SONG.song + ' ($storyDifficultyText)';
		
		if (showTime && !paused) {
			DiscordClient.changePresence(detailsText, stateText, iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		} else {
			DiscordClient.changePresence(detailsText, stateText, iconP2.getCharacter());
		}
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	/**
	 * Whether or not the game is paused.
	*/
	public var paused:Bool = false;
	/**
	 * Whether or not the player can use the Reset button to die.
	*/
	public var canReset:Bool = true;
	/**
	 * Whether or not the countdown has started.
	*/
	public var startedCountdown:Bool = false;
	/**
	 * Whether or not the player can pause.
	*/
	public var canPause:Bool = true;
	/**
	 * Whether or not the camera should be frozen.
	*/
	public var freezeCamera:Bool = false;
	/**
	 * Whether or not the player can use the Debug keys to go to the Chart or Character editors.
	*/
	public var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if(!startingSong && !endingSong && idleAnim) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}
		else FlxG.camera.followLerp = 0;
		
		preUpdate(elapsed);

		if(botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != LuaUtils.Function_Stop) {
				openPauseMenu();
			}
		}

		if(!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			
			if (!startingSong && FlxG.sound.music?.playing)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition- ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;

			if(ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();
		
		super.update(elapsed);

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else
					playerDance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var noteInd:Int = 0;
						while (noteInd < notes.length) {
							var daNote:Note = notes.members[noteInd ++];
							if (daNote == null || !daNote.exists || !daNote.alive)
								continue;
							
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, songSpeed / playbackRate);

							if (daNote.mustPress) {
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							} else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if (daNote.isSustainNote && strum.sustainReduce)
								daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (!daNote.canBeHit && !daNote.tooLate && !daNote.wasGoodHit && daNote.strumTime < Conductor.songPosition - Conductor.safeZoneOffset) {
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong)
									noteMiss(daNote);
								daNote.tooLate = true;
							}
							
							if ((daNote.tooLate || daNote.wasGoodHit) && Conductor.songPosition - daNote.strumTime - daNote.sustainLength > noteKillOffset) {
								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
							
							if (!daNote.exists || !daNote.alive)
								noteInd --;
						}
					}
					else
					{
						for (note in notes)
							note.canBeHit = false;
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end
		
		setOnScripts('botPlay', cpuControlled);

		updateIconsScale(elapsed);
		updateIconsPosition();
		
		postUpdate(elapsed);
	}

	// Health icon updaters
	/**
	 * Updates the scale of the icons.
	 * 
	 * @param 	elapsed 	Elapsed time (in seconds) since last frame.
	*/
	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	/**
	 * Updates the position of the icons.
	*/
	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
		iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
	}

	/**
	 * Whether or not the icons can change their animation frame when setting health.
	*/
	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		value = FlxMath.roundDecimal(value, 5); //Fix Float imprecision
		if(!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		healthBar.percent = (newPercent != null ? newPercent : 0);

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : 0; //If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : 0; //If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}

	/**
	 * Pauses the game and opens the Pause menu.
	*/
	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		
		if(!cpuControlled)
		{
			for (note in playerStrums)
				if(note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	/**
	 * Opens the Chart Editor.
	*/
	function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	/**
	 * Opens the Character Editor.
	*/
	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	/**
	 * Whether or not the player is dead.
	*/
	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	@:dox(hide) var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			stagesFunc((stage:BaseStage) -> stage.onGameOver());
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if(videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.filters = [];

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	/**
	 * Triggers an event.
	 * 
	 * @param 	eventName 	The name of the event.
	 * @param 	value1 		The first value of the event.
	 * @param 	value2 		The second value of the event.
	 * @param 	strumTime 	The time (in milliseconds) this event is triggered on.
	*/
	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		switch(eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35) {
					if(flValue1 == null) flValue1 = 0.015;
					if(flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if(flValue2 == null) flValue2 = 0;
						switch(Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							var lastShader = boyfriend.shader;
							boyfriend.alpha = 0.00001;
							boyfriend.shader = null;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							boyfriend.shader = lastShader;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							var lastShader = dad.shader;
							dad.alpha = 0.00001;
							dad.shader = null;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							dad.shader = lastShader;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								var lastShader = gf.shader;
								gf.alpha = 0.00001;
								gf.shader = null;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
								gf.shader = lastShader;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if(flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try {
					var set:Dynamic = value2.trim();
					
					if (set == 'true' || set == 'false') {
						set = (set == 'true');
					} else if (flValue2 != null) {
						set = flValue2;
					} else {
						set = value2;
					}
					
					LuaUtils.setPropertyLoop(value1, set, false, this);
				} catch(e:haxe.Exception) {
					var mes:String = e.message;
					if (mes.indexOf('\n') >= 0) mes = mes.substr(0, mes.indexOf('\n'));
					
					var message:String = 'Set Property Event: $mes';
					
					#if (SCRIPTS_ALLOWED)
					Log.print(message, ERROR);
					#else
					FlxG.log.warn(message);
					#end
				}

			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void {
		if (sec == null) sec = curSection;
		if (sec < 0) sec = 0;

		if (SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection) {
			moveCameraToGirlfriend();
		} else {
			moveCamera(SONG.notes[sec].mustHitSection != true);	
		}
	}
	
	/**
	 * Focuses the camera on `gf`.
	*/
	public function moveCameraToGirlfriend() {
		moveCamera(false, true);
	}
	
	/**
	 * Focuses the camera on a character.
	 * 
	 * @param 	isDad 	If the camera should be focused on the opponent character.
	 * @param 	isGf 	If the camera should be focused on the speakers (middle) character.
	*/
	public function moveCamera(isDad:Bool, isGf:Bool = false) {
		var character:String;
		if (isGf) {
			if (gf != null) {
				camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
				camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
				camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
			}
			
			character = 'gf';
		} else if (isDad) {
			if (dad != null) {
				camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
				camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
				camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			}
			
			character = 'dad';
		} else {
			if (boyfriend != null) {
				camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
				camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
				camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
			}
			
			character = 'boyfriend';
		}
		
		stagesFunc((stage:BaseStage) -> stage.onMoveCamera(character));
		callOnScripts('onMoveCamera', [character]);
	}

	/**
	 * Finishes the song.
	 * 
	 * @param 	ignoreNoteOffset 	Whether or not to ignore the note delay.
	*/
	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}
	
	var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if(!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			});
			for (daNote in unspawnNotes)
			{
				if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if(ret != LuaUtils.Function_Stop && !transitioning)
		{
			#if !switch
			var percent:Float = ratingPercent;
			if(Math.isNaN(percent)) percent = 0;
			Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);
			#end
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					Mods.loadTopMod();
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;
					MusicBeatState.switchState(new StoryMenuState());

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay')) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();
					
					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				Mods.loadTopMod();
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				canResync = false;
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				changedDifficulty = false;
			}
			transitioning = true;
		}
		
		Highscore.saveScores();
		FlxG.save.flush();
		
		return true;
	}
	
	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}
	
	/**
	 * The total amount of notes hit or missed since the start of the song.
	*/
	public var totalPlayed:Int = 0;
	/**
	 * The rating factor for all notes hit since the start of the song.
	*/
	public var totalNotesHit:Float = 0.0;

	/**
	 * Whether the combo graphic should be shown on combo pop-ups.
	*/
	public var showCombo:Bool = false;
	/**
	 * Whether the combo numbers should be shown on combo pop-ups.
	*/
	public var showComboNum:Bool = true;
	/**
	 * Whether the rating graphic should be shown on combo pop-ups.
	*/
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	/**
	 * Group containing the combo sprites.
	*/
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	/**
	 * Group containing the UI sprites.
	*/
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	/**
	 * Group containing the notes sprites, including the strumlines.
	*/
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	@:dox(hide) private function cachePopUpScore()
	{
		for (rating in ratingsData)
			Paths.image(formatUI(rating.image));
		for (i in 0...10)
			Paths.image(formatUI('num$i'));
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		vocals.volume = 1;

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				if(spr == null) continue;

				comboGroup.remove(spr);
				spr.destroy();
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			note.noteSplash = spawnNoteSplashOnNote(note);

		if(!cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);

		rating.loadGraphic(Paths.image(formatUI(daRating.image)));
		rating.screenCenter();
		rating.x = placement - 40;
		rating.y -= 60;
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.data.hideHud && showRating);
		rating.x += ClientPrefs.data.comboOffset[0];
		rating.y -= ClientPrefs.data.comboOffset[1];
		rating.antialiasing = antialias;

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(formatUI('combo')));
		comboSpr.screenCenter();
		comboSpr.x = placement;
		comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
		comboSpr.x += ClientPrefs.data.comboOffset[0];
		comboSpr.y -= ClientPrefs.data.comboOffset[1];
		comboSpr.antialiasing = antialias;
		comboSpr.y += 60;
		comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
		comboGroup.add(rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var daLoop:Int = 0;
		var xThing:Float = 0;
		if (showCombo)
			comboGroup.add(comboSpr);

		var separatedScore:String = Std.string(combo).lpad('0', 3);
		for (i in 0...separatedScore.length)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(formatUI('num${separatedScore.charAt(i)}')));
			numScore.screenCenter();
			numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
			numScore.y += 80 - ClientPrefs.data.comboOffset[3];

			if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			else numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
			numScore.visible = !ClientPrefs.data.hideHud;
			numScore.antialiasing = antialias;

			//if (combo >= 10 || combo == 0)
			if(showComboNum)
				comboGroup.add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});

			daLoop++;
			if(numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;
		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(tween:FlxTween)
			{
				comboSpr.destroy();
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if(FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if (cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned) return;
		
		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == LuaUtils.Function_Stop) return;
		
		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if (Conductor.songPosition >= 0 && !startingSong && FlxG.sound.music?.playing)
			Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
		
		// obtain notes that the player can hit
		var highestNote:Note = null;
		for (n in notes) {
			if (n != null && !n.isSustainNote && n.noteData == key && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit) {
				if (highestNote == null || n.hitPriority > highestNote.hitPriority || (n.hitPriority == highestNote.hitPriority && n.strumTime < highestNote.strumTime))
					highestNote = n;
			}
		}
		
		if (highestNote != null) {
			goodNoteHit(highestNote);
		} else {
			var spr:StrumNote = playerStrums.members[key];
			if (strumsBlocked[key] != true && spr != null) {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			
			if (ghostTapping) {
				callOnScripts('onGhostTap', [key]);
			} else {
				noteMissPress(key);
			}
		}
		
		// Needed for the  "Just the Two of Us" achievement.  - Shadow Mario
		if(!keysPressed.contains(key)) keysPressed.push(key);
		
		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;
		
		callOnScripts('onKeyPress', [key]);
	}
	
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if(cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length) return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if(key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (n in notes) { // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit
						&& n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote) {
						var released:Bool = !holdArray[n.noteData];

						if (!released)
							goodNoteHit(n);
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	/**
	 * Called whenever a note is missed.
	 * 
	 * @param 	daNote 	The missed note.
	*/
	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		var result:Dynamic = callOnLuas('noteMissPre', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('noteMissPre', [daNote]);
		if (result == LuaUtils.Function_Stop) return;
		
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		noteMissCommon(daNote.noteData, daNote);
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	/**
	 * Called whenever a miss happens by ghost tapping (a key was pressed when there was no notes to hit).
	 * 
	 * @param 	direction 	The direction ID of the miss.
	*/
	function noteMissPress(direction:Int = 1):Void
	{
		if (ghostTapping) return; //fuck it

		noteMissCommon(direction);
		if (playMissSound)
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, ?note:Note)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if(note != null) subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null) {
			if (note.tail.length > 0) {
				note.alpha = 0.35;
				for (childNote in note.tail) {
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -Tahir
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote) {
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != note) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		if (note != null && note.playMissSound)
			FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}
		
		var lastCombo:Int = combo;
		combo = 0;

		health -= subtract * healthLoss;
		if (!endingSong) songMisses ++;
		songScore -= 10;
		totalPlayed ++;
		RecalculateRating(true);

		// play character anims
		var char:Character = getNoteCharacter(note, boyfriend);
		if (char != null) {
			if ((note == null || !note.noMissAnimation) && char.hasMissAnimations) {
				var postfix:String = '';
				if (note != null) postfix = note.animSuffix;

				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
				char.playAnim(animToPlay, true);
			}
			
			if (gf != null && char != gf)
				gf.playComboDropAnim(combo);
			if (dad != null && char != dad)
				dad.playComboDropAnim(combo);
			if (boyfriend != null && char != boyfriend)
				boyfriend.playComboDropAnim(combo);
		}
		vocals.volume = 0;
	}

	/**
	 * Called whenever a note is hit by the opponent.
	 * 
	 * @param 	note 	The note that was hit.
	*/
	function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('opponentNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		if (!camZoomingDisabled)
			camZooming = true;
		
		var char:Character = getNoteCharacter(note, dad);
		if (char != null) {
			if (note.noteType == 'Hey!' && char.hasAnimation('hey')) {
				char.playAnim('hey', true);
				char.specialAnim = true;
				char.heyTimer = 0.6;
			} else if(!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
				
				var canPlay:Bool = true;
				if (note.isSustainNote) {
					var holdAnim:String = animToPlay + '-hold';
					if (char.hasAnimation(holdAnim))
						animToPlay = holdAnim;
					if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop')
						canPlay = false;
				}

				if (canPlay)
					char.playAnim(animToPlay, true);
				
				char.holdTimer = 0;
			}
		}

		if(opponentVocals.length <= 0) vocals.volume = 1;
		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;
		
		stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		if (!note.isSustainNote) invalidateNote(note);
	}

	/**
	 * Called whenever a note is hit by the player.
	 * 
	 * @param 	note 	The note that was hit.
	*/
	public function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;
		if(cpuControlled && note.ignoreNote) return;

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('goodNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);
		
		var char:Character = null;
		if (!note.hitCausesMiss) { //Common notes
			if (!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
				
				char = getNoteCharacter(note, boyfriend);
				if (char != null) {
					var canPlay:Bool = true;
					if (note.isSustainNote) {
						var holdAnim:String = animToPlay + '-hold';
						if (char.hasAnimation(holdAnim))
							animToPlay = holdAnim;
						if (char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop')
							canPlay = false;
					}
	
					if (canPlay) char.playAnim(animToPlay, true);
					char.holdTimer = 0;
					
					if (note.noteType == 'Hey!') {
						for (animCheck in ['hey', 'cheer']) {
							if (char.hasAnimation(animCheck)) {
								char.playAnim(animCheck, true);
								char.specialAnim = true;
								char.heyTimer = 0.6;
								break;
							}
						}
					}
				}
			}

			if (!cpuControlled) {
				var spr = playerStrums.members[note.noteData];
				if (spr != null) spr.playAnim('confirm', true);
			} else {
				strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			}
			vocals.volume = 1;

			if (!note.isSustainNote) {
				combo ++;
				popUpScore(note);
				
				if (gf != null && char != gf)
					gf.playComboAnim(combo);
				if (dad != null && char != dad)
					dad.playComboAnim(combo);
				if (boyfriend != null && char != boyfriend)
					boyfriend.playComboAnim(combo);
			}
			var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			if (gainHealth) health += note.hitHealth * healthGain;

		} else { //Notes that count as a miss if you hit them (Hurt notes for example)
			char = getNoteCharacter(note, boyfriend);
			
			if (!note.noMissAnimation) {
				switch (note.noteType) {
					case 'Hurt Note':
						if (char != null && char.hasAnimation('hurt')) {
							char.playAnim('hurt', true);
							char.specialAnim = true;
						}
				}
			}

			noteMiss(note);
			if (!note.noteSplashData.disabled && !note.isSustainNote)
				note.noteSplash = spawnNoteSplashOnNote(note);
		}

		stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('goodNoteHit', [note]);
		if(!note.isSustainNote) invalidateNote(note);
	}
	
	/**
	 * Gets the character assigned to a note.
	 * 
	 * @param 	note 				The note to check.
	 * @param 	defaultCharacter	The character to fall back to if none is assigned.
	 * 
	 * @return 	The `Character` assigned to a note.
	*/
	public function getNoteCharacter(?note:Note, ?defaultCharacter:Character):Character {
		if (note == null) return defaultCharacter;
		
		if (note.character == null)
			return (note.gfNote ? gf : defaultCharacter);
		
		return note.character;
	}

	/**
	 * Destroys a note. Also calls `onDestroyNote` in Lua.
	 * 
	 * @param 	note 	The note to destroy.
	*/
	public function invalidateNote(note:Note):Void {
		// i dont think preventing the note from being destroyed would do the game any good
		callOnLuas('onDestroyNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		callOnHScript('onDestroyNote', [note]);
		
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	/**
	 * Spawns a note splash on the note's receptor (strum).
	 * 
	 * @param 	note 	The note to use.
	*/
	public function spawnNoteSplashOnNote(note:Note):NoteSplash {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				return spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
		}
		return null;
	}

	/**
	 * Spawns a note splash.
	 * 
	 * @param 	x 		The x position of the note splash.
	 * @param 	y 		The y position of the note splash.
	 * @param 	data 	The note data ID of the note splash.
	 * @param 	note 	The note assigned to the note splash.
	 * @param 	strum 	The note receptor (strum) assigned to the note splash.
	 * 
	 * @return 	A new `NoteSplash` instance.
	*/
	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote):NoteSplash {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);
		grpNoteSplashes.add(splash);
		return splash;
	}

	override function destroy() {
		if (psychlua.CustomSubstate.instance != null) {
			closeSubState();
			resetSubState();
		}
		
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if(videoCutscene != null) {
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.filters = [];

		#if FLX_PITCH if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;
		
		super.destroy();
	}

	var lastStepHit:Int;
	public override function stepHit(step:Int):Void {
		if (step == lastStepHit)
			return;
		
		super.stepHit(step);
		
		lastStepHit = step;
	}
	
	var lastBeatHit:Int;
	public override function beatHit(beat:Int):Void {
		if (lastBeatHit >= beat)
			return;
		
		if (startOnTime <= 0 && !skipCountdown && beat >= -4 && beat <= 0) {
			countdownTick(switch(beat) {
				default: START;
				case -4: THREE;
				case -3: TWO;
				case -2: ONE;
				case -1: GO;
			});
		}
		
		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);
		
		iconP1.updateHitbox();
		iconP2.updateHitbox();
		
		characterBopper(beat);
		
		super.beatHit(beat);
		lastBeatHit = beat;
	}

	/**
	 * Handles the character bopping.
	 * 
	 * @param 	beat 	The current beat.
	*/
	public function characterBopper(beat:Int):Void {
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	function playerDance():Void {
		var anim:String = boyfriend.getAnimationName();
		if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	public override function sectionHit(section:Int):Void {
		if (SONG.notes[section] != null) {
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms) {
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[section].changeBPM) {
				Conductor.bpm = SONG.notes[section].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('altAnim', SONG.notes[section].altAnim);
			setOnScripts('gfSection', SONG.notes[section].gfSection);
			setOnScripts('mustHitSection', SONG.notes[section].mustHitSection);
		}
		
		super.sectionHit(section);
	}

	/**
	 * Plays the confirm animation on a note receptor (strum).
	 * 
	 * @param 	isDad 	Whether the strumline should be the opponent's or the player's.
	 * @param 	id 		The ID of the note receptor in the strumline.
	 * @param 	time 	The time (in seconds) until the animation resets.
	*/
	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	/**
	 * The name of the current rating.
	*/
	public var ratingName:String = '?';
	/**
	 * The player's accuracy, represented as a `Float`.
	 * 0 is 0% accuracy, and 1 is 100% accuracy.
	*/
	public var ratingPercent:Float;
	/**
	 * The player's FC status.
	*/
	public var ratingFC:String;
	/**
	 * Recalculates the rating and updates the score.
	 * 
	 * @param 	badHit 		Whether or not the rating was updated from a note miss.
	 * @param 	scoreBop 	Whether or not the score text should have a bopping animation.
	*/
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	@:dox(hide) private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode || cpuControlled) return;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !usedPractice);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end
}
