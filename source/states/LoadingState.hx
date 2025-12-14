package states;

#if (target.threaded)
import sys.thread.FixedThreadPool;
import sys.thread.Thread;
import sys.thread.Mutex;
#end

import haxe.Json;
import lime.app.Future;
import lime.utils.Assets;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;
import flixel.FlxState;

import openfl.display.BitmapData;
import flash.media.Sound;

import backend.Song;
import backend.StageData;
import objects.Character;

import objects.Note;
import objects.NoteSplash;

#if LUA_ALLOWED
import psychlua.FunkinLua;
import psychlua.LuaUtils;
#end
#if SCRIPTS_ALLOWED
import psychlua.GlobalScriptHandler;
#end

#if cpp
@:headerCode('
#include <iostream>
#include <thread>
')
#end
class LoadingState extends ScriptedState
{
	public static var loaded:Int = 0;
	public static var loadMax:Int = 0;

	static var originalBitmapKeys:Map<String, String> = [];
	static var requestedBitmaps:Map<String, BitmapData> = [];
	
	public static var maxJobs:Int = 1;
	
	#if (target.threaded)
	static var mutex:Mutex;
	static var threadPool:FixedThreadPool = null;
	#end
	
	public static var threaded:Bool = #if (target.threaded) true #else false #end ;
	static var futures:Array<Future<Dynamic>> = [];
	static var jobs:Array<LoaderJob> = [];

	function new(target:FlxState, stopMusic:Bool)
	{
		this.target = target;
		this.multiScript = false;
		this.stopMusic = stopMusic;
		
		super();
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false, intrusive:Bool = true)
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));
	
	var target:FlxState = null;
	var stopMusic:Bool = false;
	var dontUpdate:Bool = false;

	var barGroup:FlxSpriteGroup;
	var bar:FlxSprite;
	var loadingInfo:FlxText;
	var barBack:FlxSprite;
	var barWidth:Int = 0;
	var intendedPercent:Float = 0;
	var curPercent:Float = 0;
	var stateChangeDelay:Float = 0;
	
	var bg:FlxSprite;
	#if PSYCH_WATERMARKS
	var logo:FlxSprite;
	var pessy:FlxSprite;
	var loadingText:FlxText;
	
	var timePassed:Float;
	var shakeFl:Float;
	var shakeMult:Float = 0;
	
	var isSpinning:Bool = false;
	var spawnedPessy:Bool = false;
	var pressedTimes:Int = 0;
	#else
	var funkay:FlxSprite;
	#end
	
	override function create()
	{	
		persistentUpdate = true;
		barGroup = new FlxSpriteGroup();
		add(barGroup);
		
		barBack = new FlxSprite(0, 660).makeGraphic(1, 1, FlxColor.BLACK);
		barBack.scale.set(FlxG.width - 300, 25);
		barBack.updateHitbox();
		barBack.screenCenter(X);
		barGroup.add(barBack);
		
		bar = new FlxSprite(barBack.x + 5, barBack.y + 5).makeGraphic(1, 1, FlxColor.WHITE);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		barGroup.add(bar);
		barWidth = Std.int(barBack.width - 10);
		
		loadingInfo = new FlxText((FlxG.width - 200) * .5, bar.y + bar.height * .5 - 9, 200, '1 / 2', 32);
		loadingInfo.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		loadingInfo.borderSize = 1.5;
		add(loadingInfo);
		
		#if PSYCH_WATERMARKS // PSYCH LOADING SCREEN
		bg = new FlxSprite(0, 0, Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(FlxG.width));
		bg.color = 0xff3fffa5;
		bg.updateHitbox();
		addBehindBar(bg);
	
		loadingText = new FlxText((FlxG.width - 400) * .5, 600, 400, Language.getPhrase('now_loading', 'Now Loading'), 32);
		loadingText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		loadingText.borderSize = 2;
		addBehindBar(loadingText);
	
		logo = new FlxSprite(0, 0).loadGraphic(Paths.image('loading_screen/icon'));
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.scale.set(0.75, 0.75);
		logo.screenCenter();
		logo.y -= 40;
		addBehindBar(logo);

		#else // BASE GAME LOADING SCREEN
		bg = new FlxSprite().makeGraphic(1, 1, 0xffcaff4d);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		addBehindBar(bg);

		funkay = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay'));
		funkay.antialiasing = ClientPrefs.data.antialiasing;
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		addBehindBar(funkay);
		#end
		
		preCreate();
		
		loadingInfo.visible = bar.visible;
		
		super.create();

		if (stateChangeDelay <= 0 && checkLoaded()) {
			dontUpdate = true;
			onLoad();
		}
	}
	
	public function getLoaded():Int {
		return loaded;
	}
	public function getLoadMax():Int {
		return loadMax;
	}
	
	var folderNameLol:String = '';
	var stateNameLol:String = 'LoadingScreen';
	override function getFolderName():String {
		return folderNameLol;
	}
	override function customStateName():String {
		return stateNameLol;
	}
	override function _preCreate():Void {
		#if SCRIPTS_ALLOWED
		scriptFolder = 'data';
		startStateScripts(); // try data/LoadingScreen.hx
		
		if (!loadedScripts) {
			scriptFolder = 'scripts';
			folderNameLol = 'states';
			stateNameLol = 'LoadingState';
			startStateScripts(); // try scripts/states/LoadingState.hx
		}
		#end
		
		backend.MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	#if LUA_ALLOWED
	public override function implementLua(lua:FunkinLua):Void {
		lua.addLocalCallback('getLoaded', function() return loaded);
		lua.addLocalCallback('getLoadMax', function() return loadMax);
		lua.addLocalCallback('addBehindBar', function(tag:String) {
			var sprite:FlxBasic = LuaUtils.getObjectDirectly(tag);
			if (sprite == null) {
				FunkinLua.luaTrace('addBehindBar: Couldnt find object: $tag', false, false, ERROR);
				return;
			}
			
			addBehindBar(sprite);
		});
	}
	#end

	function addBehindBar(obj:flixel.FlxBasic)
	{
		insert(members.indexOf(barGroup), obj);
	}

	var transitioning:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (dontUpdate) return;
		
		preUpdate(elapsed);
		updateJobs();

		if (!transitioning)
		{
			if (!finishedLoading && checkLoaded())
			{
				if(stateChangeDelay <= 0)
				{
					transitioning = true;
					onLoad();
					return;
				}
				else stateChangeDelay = Math.max(0, stateChangeDelay - elapsed);
			}
			intendedPercent = loaded / loadMax;
		}

		if (curPercent != intendedPercent)
		{
			if (Math.abs(curPercent - intendedPercent) < 0.001) curPercent = intendedPercent;
			else curPercent = FlxMath.lerp(intendedPercent, curPercent, Math.exp(-elapsed * 15));

			bar.scale.x = barWidth * curPercent;
			bar.updateHitbox();
		}

		#if PSYCH_WATERMARKS // PSYCH LOADING SCREEN
		timePassed += elapsed;
		shakeFl += elapsed * 3000;
		loadingText.text = Language.getPhrase('now_loading', 'Now Loading');
		loadingInfo.text = '$loaded / $loadMax';

		if(!spawnedPessy)
		{
			if(!transitioning && controls.ACCEPT)
			{
				shakeMult = 1;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				pressedTimes++;
			}
			shakeMult = Math.max(0, shakeMult - elapsed * 5);
			logo.offset.x = Math.sin(shakeFl * Math.PI / 180) * shakeMult * 100;

			if(pressedTimes >= 5)
			{
				FlxG.camera.fade(0xAAFFFFFF, 0.5, true);
				logo.visible = false;
				spawnedPessy = true;
				stateChangeDelay = 5;
				FlxG.sound.play(Paths.sound('secret'));

				pessy = new FlxSprite(700, 140);
				pessy.frames = Paths.getSparrowAtlas('loading_screen/pessy');
				pessy.animation.addByPrefix('run', 'run', 24, true);
				pessy.animation.addByPrefix('spin', 'spin', 24, true);
				pessy.antialiasing = ClientPrefs.data.antialiasing;
				pessy.flipX = (logo.offset.x > 0);
				pessy.visible = false;

				new FlxTimer().start(0.01, function(tmr:FlxTimer) {
					pessy.x = FlxG.width + 200;
					pessy.velocity.x = -1100;
					if(pessy.flipX)
					{
						pessy.x = -pessy.width - 200;
						pessy.velocity.x *= -1;
					}
		
					pessy.visible = true;
					pessy.animation.play('run', true);
					#if ACHIEVEMENTS_ALLOWED Achievements.unlock('pessy_easter_egg'); #end
					
					insert(members.indexOf(loadingText), pessy);
				});
			}
		}
		else if(!isSpinning && (pessy.flipX && pessy.x > FlxG.width) || (!pessy.flipX && pessy.x < -pessy.width))
		{
			isSpinning = true;
			pessy.animation.play('spin', true);
			pessy.flipX = false;
			pessy.x = 500;
			pessy.y = FlxG.height + 500;
			pessy.velocity.x = 0;
			FlxTween.tween(pessy, {y: 10}, 0.65, {ease: FlxEase.quadOut});
		}
		#end
		
		postUpdate(elapsed);
	}
	
	static function updateJobs():Void {
		while (futures.length < maxJobs && jobs.length > 0)
			startJob(jobs.shift());
	}
	
	var finishedLoading:Bool = false;
	function onLoad()
	{
		_loaded();
		
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		FlxG.camera.visible = false;
		MusicBeatState.switchState(target);
		transitioning = true;
		finishedLoading = true;
	}

	static function _loaded()
	{
		loaded = 0;
		loadMax = 0;
		initialThreadCompleted = true;
		isIntrusive = false;
		
		StageData.forceNextDirectory = null;
		FlxTransitionableState.skipNextTransIn = true;
		
		#if (target.threaded)
		if (threadPool != null) threadPool.shutdown(); // kill all workers safely
		threadPool = null;
		mutex = null;
		#end
	}

	public static function checkLoaded():Bool
	{
		for (key => bitmap in requestedBitmaps)
		{
			if (bitmap != null && Paths.cacheBitmap(originalBitmapKeys.get(key), bitmap) != null) {}
			else trace('failed to cache image $key');
		}
		requestedBitmaps.clear();
		originalBitmapKeys.clear();
		// trace('we checked if loaded');
		return (loaded >= loadMax && initialThreadCompleted);
	}

	public static function loadNextDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);
	}

	static var isIntrusive:Bool = false;
	static function getNextState(target:FlxState, stopMusic = false, intrusive:Bool = true):FlxState
	{
		#if !SHOW_LOADING_SCREEN
		intrusive = false;
		#end

		LoadingState.isIntrusive = intrusive;
		_startPool();

		if(intrusive)
			return new LoadingState(target, stopMusic);
		
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		#if sys
		while(true)
		{
			if(checkLoaded())
			{
				_loaded();
				break;
			}
			else Sys.sleep(0.001);
		}
		#else
		checkLoaded();
		#end
		
		return target;
	}

	static var imagesToPrepare:Array<String> = [];
	static var soundsToPrepare:Array<String> = [];
	static var musicToPrepare:Array<String> = [];
	static var songsToPrepare:Array<String> = [];
	
	static var initialThreadCompleted:Bool = true;
	static var dontPreloadDefaultVoices:Bool = false;
	static function _startPool()
	{
		maxJobs = 10;
		
		#if (target.threaded) if (threaded && threadPool == null) {
			var multiThreaded:Bool = #if (MULTITHREADED_LOADING && sys) true #else false #end ;
			maxJobs = (multiThreaded ? Std.int(Math.max(1, getCPUThreadsCount() - #if DISCORD_ALLOWED 2 #else 1 #end)) : 1 );
			threadPool = new FixedThreadPool(maxJobs);
		} #end
	}

	public static function prepareToSong()
	{
		imagesToPrepare.resize(0);
		soundsToPrepare.resize(0);
		musicToPrepare.resize(0);
		songsToPrepare.resize(0);
		futures.resize(0);
		jobs.resize(0);
		
		if(PlayState.SONG == null) {
			loaded = 0;
			loadMax = 0;
			initialThreadCompleted = true;
			isIntrusive = false;
			return;
		}

		_startPool();

		initialThreadCompleted = false;
		var threadsCompleted:Int = 0;
		var threadsMax:Int = 0;
		function completedThread() {
			threadsCompleted++;
			if (threadsCompleted == threadsMax) {
				initialThreadCompleted = true;
				clearInvalids();
				startThreads();
			}
		}

		var song:SwagSong = PlayState.SONG;
		var folder:String = Paths.formatToSongPath(Song.loadedSongName);
		new Future<Bool>(() -> {
			// LOAD NOTE IMAGE
			var noteSkin:String = Note.defaultNoteSkin;
			if(PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) noteSkin = PlayState.SONG.arrowSkin;
	
			var customSkin:String = noteSkin + Note.getNoteSkinPostfix();
			if(Paths.fileExists('images/$customSkin.png', IMAGE)) noteSkin = customSkin;
			imagesToPrepare.push(noteSkin);
			//

			// LOAD NOTE SPLASH IMAGE
			var noteSplash:String = NoteSplash.defaultNoteSplash;
			if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) noteSplash = PlayState.SONG.splashSkin;
			else noteSplash += NoteSplash.getSplashSkinPostfix();
			imagesToPrepare.push(noteSplash);

			try
			{
				var path:String = Paths.json('$folder/preload');
				var json:Dynamic = null;

				#if MODS_ALLOWED
				var moddyFile:String = Paths.modsJson('$folder/preload');
				if (FileSystem.exists(moddyFile)) json = Json.parse(Paths.getTextFromFile(moddyFile));
				else json = Json.parse(Paths.getTextFromFile(path));
				#else
				json = Json.parse(Assets.getText(path));
				#end

				if(json != null)
				{
					for (asset in Reflect.fields(json))
					{
						var filters:Int = Reflect.field(json, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imagesToPrepare.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								soundsToPrepare.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								musicToPrepare.push(asset.substr('music/'.length));
						}
					}
				}
			}
			catch(e:Dynamic) {}
			return true;
		}, isIntrusive)
		.then((_) -> new Future<Bool>(() -> {
			if (song.stage == null || song.stage.length < 1)
				song.stage = StageData.vanillaSongStage(folder);

			var stageData:StageFile = StageData.getStageFile(song.stage);
			if (stageData != null)
			{
				if(stageData.preload != null)
				{
					for (asset in Reflect.fields(stageData.preload))
					{
						var filters:Int = Reflect.field(stageData.preload, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imagesToPrepare.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								soundsToPrepare.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								musicToPrepare.push(asset.substr('music/'.length));
						}
					}
				}
				
				if (stageData.objects != null)
				{
					for (sprite in stageData.objects)
					{
						if(sprite.type == 'sprite' || sprite.type == 'animatedSprite')
							if((sprite.filters < 0 || StageData.validateVisibility(sprite.filters)) && !imagesToPrepare.contains(sprite.image))
								imagesToPrepare.push(sprite.image);
					}
				}
				
				StageData.forceNextDirectory = stageData.directory;
			}
			
			loadNextDirectory();
			
			songsToPrepare.push('$folder/Inst');

			var player1:String = song.player1;
			var player2:String = song.player2;
			var gfVersion:String = song.gfVersion;
			var prefixVocals:String = song.needsVoices ? '$folder/Voices' : null;
			if (gfVersion == null) gfVersion = 'gf';

			dontPreloadDefaultVoices = false;
			if (!dontPreloadDefaultVoices && prefixVocals != null)
			{
				if(Paths.fileExists('$prefixVocals-Player.${Paths.SOUND_EXT}', SOUND, false, 'songs') && Paths.fileExists('$prefixVocals-Opponent.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
				{
					songsToPrepare.push('$prefixVocals-Player');
					songsToPrepare.push('$prefixVocals-Opponent');
				}
				else if(Paths.fileExists('$prefixVocals.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
					songsToPrepare.push(prefixVocals);
			}
			
			#if (target.threaded) if (threaded) {
				threadsMax ++;
				threadPool.run(() -> { try { preloadCharacter(player1, prefixVocals); } catch (e:Dynamic) {} completedThread(); });
			} else #end
			preloadCharacter(player1, prefixVocals);
			if (player2 != player1) {
				#if (target.threaded) if (threaded) {
					threadsMax ++;
					threadPool.run(() -> { try { preloadCharacter(player2, prefixVocals); } catch (e:Dynamic) {} completedThread(); });
				} else #end
				preloadCharacter(player2, prefixVocals);
			}
			if (!stageData.hide_girlfriend && gfVersion != player2 && gfVersion != player1) {
				#if (target.threaded) if (threaded) {
					threadsMax ++;
					threadPool.run(() -> { try { preloadCharacter(gfVersion); } catch (e:Dynamic) {} completedThread(); });
				} else #end
				preloadCharacter(gfVersion, prefixVocals);
			}
			
			threadsMax ++;
			completedThread();
			
			return true;
		}, isIntrusive))
		.onError((err:Dynamic) -> {
			trace('ERROR! while preparing song: $err');
		});
	}

	public static function clearInvalids()
	{
		clearInvalidFrom(imagesToPrepare, 'images', '.png', IMAGE);
		clearInvalidFrom(soundsToPrepare, 'sounds', '.${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(musicToPrepare, 'music',' .${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(songsToPrepare, 'songs', '.${Paths.SOUND_EXT}', SOUND, 'songs');

		for (arr in [imagesToPrepare, soundsToPrepare, musicToPrepare, songsToPrepare])
			while (arr.contains(null))
				arr.remove(null);
	}

	static function clearInvalidFrom(arr:Array<String>, prefix:String, ext:String, type:AssetType, ?parentFolder:String = null)
	{
		for (folder in arr.copy())
		{
			var nam:String = folder.trim();
			if(nam.endsWith('/'))
			{
				for (subfolder in Mods.directoriesWithFile(Paths.getSharedPath(), '$prefix/$nam'))
				{
					for (file in FileSystem.readDirectory(subfolder))
					{
						if(file.endsWith(ext))
						{
							var toAdd:String = nam + haxe.io.Path.withoutExtension(file);
							if(!arr.contains(toAdd)) arr.push(toAdd);
						}
					}
				}

				//trace('Folder detected! ' + folder);
			}
		}

		var i:Int = 0;
		while(i < arr.length)
		{

			var member:String = arr[i];
			var myKey = '$prefix/$member$ext';
			if(parentFolder == 'songs') myKey = '$member$ext';

			//trace('attempting on $prefix: $myKey');
			var doTrace:Bool = false;
			if(member.endsWith('/') || (!Paths.fileExists(myKey, type, false, parentFolder) && (doTrace = true)))
			{
				arr.remove(member);
				if(doTrace) trace('Removed invalid $prefix: $member');
			}
			else i++;
		}
	}

	public static function startThreads()
	{
		#if (target.threaded) if (threaded) mutex = new Mutex(); #end
		
		// trace('${imagesToPrepare.length} images');
		// trace('${soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length} sounds');
		loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length;
		loaded = 0;

		//then start threads
		_threadFunc();
	}

	static function _threadFunc()
	{
		_startPool();
		
		for (sound in soundsToPrepare) jobs.push(SOUND('sounds/$sound'));
		for (music in musicToPrepare) jobs.push(SOUND('music/$music'));
		for (song in songsToPrepare) jobs.push(SOUND(song, 'songs', true));
		for (image in imagesToPrepare) jobs.push(BMD(image));
	}
	
	#if (target.threaded)
	static function initThread(func:Void -> Dynamic, traceData:String) {
		// trace('scheduled $func in threadPool');
		#if debug
		var threadSchedule = Sys.time();
		#end
		threadPool.run(() -> {
			#if debug
			var threadStart = Sys.time();
			trace('$traceData took ${threadStart - threadSchedule}s to start preloading');
			#end

			try {
				if (func() != null) {
					#if debug
					var diff = Sys.time() - threadStart;
					trace('finished preloading $traceData in ${diff}s');
					#end
				} else trace('ERROR! fail on preloading $traceData ');
			}
			catch(e:Dynamic) {
				trace('ERROR! fail on preloading $traceData: $e');
			}
			// mutex.acquire();
			loaded ++;
			// mutex.release();
		});
	}
	#end
	
	static function startJob(job:LoaderJob) {
		#if (target.threaded) if (threaded) {
			switch (job) {
				case SOUND(key, path, ignoreMods): initThread(() -> preloadSound(key, path, ignoreMods), 'sound $key');
				case BMD(key): initThread(() -> preloadGraphic(key), 'image $key');
			}
		} else #end {
			var future:Future<Dynamic> = switch (job) {
				case SOUND(key, path, ignoreMods): preloadSound(key, path, ignoreMods);
				case BMD(key): preloadGraphic(key);
			}
			
			if (future != null) {
				function forward(_:Dynamic) { futures.remove(future); loaded ++; }
				
				futures.push(future);
				future.onComplete(forward).onError(forward);
			} else {
				loaded ++;
			}
		}
	}

	inline private static function preloadCharacter(char:String, ?prefixVocals:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			var character:Dynamic = Json.parse(Paths.getTextFromFile(path));
			
			var isAnimateAtlas:Bool = false;
			var img:String = character.image;
			img = img.trim();
			#if flxanimate
			var animToFind:String = Paths.getPath('images/$img/Animation.json', TEXT);
			if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
				isAnimateAtlas = true;
			#end

			if(!isAnimateAtlas)
			{
				var split:Array<String> = img.split(',');
				for (file in split)
				{
					imagesToPrepare.push(file.trim());
				}
			}
			#if flxanimate
			else
			{
				for (i in 0...10)
				{
					var st:String = '$i';
					if(i == 0) st = '';
	
					if(Paths.fileExists('images/$img/spritemap$st.png', IMAGE))
					{
						//trace('found Sprite PNG');
						imagesToPrepare.push('$img/spritemap$st');
						break;
					}
				}
			}
			#end
	
			if (prefixVocals != null && character.vocals_file != null && character.vocals_file.length > 0)
			{
				songsToPrepare.push(prefixVocals + "-" + character.vocals_file);
				if(char == PlayState.SONG.player1) dontPreloadDefaultVoices = true;
			}
		}
		catch(e:haxe.Exception)
		{
			trace(e.details());
		}
	}
	
	static function preloadSound(key:String, ?path:String, ?modsAllowed:Bool = true):Dynamic {
		var file:String = Paths.getPath(Language.getFileTranslation(key) + '.${Paths.SOUND_EXT}', SOUND, path, modsAllowed);
		
		if (!Paths.currentTrackedSounds.exists(file)) {
			#if (target.threaded) if (threaded) {
			
			if (#if sys FileSystem.exists(file) || #end OpenFlAssets.exists(file, SOUND)) {
				var sound:Sound = #if sys Sound.fromFile(file) #else OpenFlAssets.getSound(file, false) #end ;
				
				mutex.acquire();
				Paths.currentTrackedSounds.set(file, sound);
				Paths.localTrackedAssets.push(file);
				mutex.release();
				return sound;
			} else {
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
			}
			
			return null;
			
			} #end
			
			return OpenFlAssets.loadSound(file).onComplete(function(sound) {
				Paths.currentTrackedSounds.set(file, sound);
				Paths.localTrackedAssets.push(file);
			}).onError(function(err) {
				trace('ERROR! fail on preloading sound $file -> $err');
			});
		}
		
		Paths.localTrackedAssets.push(file);
		
		return (threaded ? Paths.currentTrackedSounds.get(file) : null);
	}
	
	static function preloadGraphic(key:String):Dynamic {
		var requestKey:String = 'images/$key';
		#if TRANSLATIONS_ALLOWED requestKey = Language.getFileTranslation(requestKey); #end
		if (requestKey.lastIndexOf('.') < 0) requestKey += '.png';
		var file:String = Paths.getPath(requestKey, IMAGE);
		
		if (!Paths.currentTrackedAssets.exists(requestKey)) {
			#if (target.threaded) if (threaded) {
			
			try {
				if (#if sys FileSystem.exists(file) || #end OpenFlAssets.exists(file, IMAGE)) {
					var bitmap:BitmapData = #if sys BitmapData.fromFile(file) #else OpenFlAssets.getBitmapData(file, false) #end ;

					mutex.acquire();
					Paths.localTrackedAssets.push(file);
					originalBitmapKeys.set(file, requestKey);
					requestedBitmaps.set(file, bitmap);
					mutex.release();
					return bitmap;
				}
				
				trace('no such image $key exists');
			} catch(e:haxe.Exception) {
				trace('ERROR! fail on preloading image $key');
			}
			
			return null;
			
			} #end
			
			var file:String = Paths.getPath(requestKey, IMAGE);
			return OpenFlAssets.loadBitmapData(file).onComplete(function(bmd) {
				Paths.localTrackedAssets.push(file);
				originalBitmapKeys.set(file, requestKey);
				requestedBitmaps.set(file, bmd);
			}).onError(function(err) {
				trace('ERROR! fail on preloading image $file -> $err');
			});
		}
		
		Paths.localTrackedAssets.push(file);
		
		return (threaded ? Paths.currentTrackedAssets.get(requestKey)?.bitmap : null);
	}
	
	#if (cpp || hl)
	@:functionCode('
		return std::thread::hardware_concurrency();
	')
	@:noCompletion
    	public static function getCPUThreadsCount():Int
    	{
        	return -1;
    	}
    #end
}

@:dox(hide) enum LoaderJob {
	SOUND(key:String, ?path:String, ?ignoreMods:Bool);
	BMD(key:String);
}