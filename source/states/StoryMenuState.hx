package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;

import objects.MenuItem;
import objects.MenuCharacter;

import options.GameplayChangersSubState;
import substates.ResetScoreSubState;

import backend.StageData;

class StoryMenuState extends ScriptedState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	var txtWeekTitle:FlxText;
	var blackBar:FlxSprite;
	var bgYellow:FlxSprite;
	var bgSprite:FlxSprite;

	private static var curWeek:Int = 0;

	var txtTracklist:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;

	var loadedWeeks:Array<WeekData> = [];

	override function create()
	{	
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);
		
		rpcDetails = 'Story Menu';

		if (WeekData.weeksList.length < 1) {
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		if (curWeek >= WeekData.weeksList.length)
			curWeek = WeekData.weeksList.length - 1;
		
		preCreate();

		scoreText = new FlxText(10, 10, 0, Language.getPhrase('week_score', 'WEEK SCORE: {1}', [Std.string(lerpScore)]), 36);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		bgYellow = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		blackBar = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBar);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if(!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, bgSprite.y + 396, WeekData.weeksList[i]);
				weekThing.y += ((weekThing.height + 20) * num);
				weekThing.ID = num;
				weekThing.targetY = itemTargetY;
				itemTargetY += Math.max(weekThing.height, 110) + 10;
				grpWeekText.add(weekThing);

				weekThing.screenCenter(X);
				// weekThing.updateHitbox();

				// Needs an offset thingie
				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
					lock.antialiasing = ClientPrefs.data.antialiasing;
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = i;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		leftArrow = new FlxSprite(850, grpWeekText.members[0].y + 10);
		leftArrow.antialiasing = ClientPrefs.data.antialiasing;
		leftArrow.frames = ui_tex;
		leftArrow.animation.addByPrefix('idle', "arrow left");
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		difficultySelectors.add(leftArrow);

		Difficulty.resetList();
		if (lastDifficultyName == '')
			lastDifficultyName = Difficulty.getDefault();
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
		
		sprDifficulty = new FlxSprite(0, leftArrow.y);
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(leftArrow.x + 376, leftArrow.y);
		rightArrow.antialiasing = ClientPrefs.data.antialiasing;
		rightArrow.frames = ui_tex;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
		rightArrow.animation.play('idle');
		difficultySelectors.add(rightArrow);

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07 + 100, bgSprite.y + 425).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		tracksSprite.x -= tracksSprite.width/2;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(scoreText);
		add(txtWeekTitle);

		changeWeek();
		changeDifficulty();

		super.create();
	}

	override function closeSubState() {
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if(WeekData.weeksList.length < 1) {
			if (controls.BACK && !movedBack && !selectedWeek) {
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			super.update(elapsed);
			return;
		}
		
		if(intendedScore != lerpScore) {
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;
	
			scoreText.text = Language.getPhrase('week_score', 'WEEK SCORE: {1}', [Std.string(lerpScore)]);
		}
		
		// FlxG.watch.addQuick('font', scoreText.font);

		if (!movedBack && !selectedWeek)
		{
			var changeDiff = false;
			if (controls.UI_UP_P) {
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if (controls.UI_DOWN_P) {
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if(FlxG.mouse.wheel != 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeWeek(-FlxG.mouse.wheel);
				changeDifficulty();
			}

			if (controls.UI_RIGHT) {
				rightArrow.animation.play('press');
			} else {
				rightArrow.animation.play('idle');
			}

			if (controls.UI_LEFT) {
				leftArrow.animation.play('press');
			} else {
				leftArrow.animation.play('idle');
			}

			if (controls.UI_RIGHT_P) {
				changeDifficulty(1);
			} else if (controls.UI_LEFT_P) {
				changeDifficulty(-1);
			} else if (changeDiff) {
				changeDifficulty();
			}
			
			if(FlxG.keys.justPressed.CONTROL) {
				persistentUpdate = false;
				openSubState(new GameplayChangersSubState());
			} else if(controls.RESET) {
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
				//FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			else if (controls.ACCEPT)
				selectWeek();
		}

		if (controls.BACK && !movedBack && !selectedWeek) {
			movedBack = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
		
		var offY:Float = grpWeekText.members[curWeek].targetY;
		for (num => item in grpWeekText.members)
			item.y = FlxMath.lerp(item.targetY - offY + 480, item.y, Math.exp(-elapsed * 10.2));

		for (num => lock in grpLocks.members)
			lock.y = grpWeekText.members[lock.ID].y + grpWeekText.members[lock.ID].height/2 - lock.height/2;
		
		postUpdate(elapsed);
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;

	function selectWeek() {
		if (callOnScripts('onAccept', [loadedWeeks[curWeek], curWeek], true) != psychlua.LuaUtils.Function_Stop) {
			if (!weekIsLocked(loadedWeeks[curWeek].fileName)) {
				if (loadWeek(loadedWeeks[curWeek], curDifficulty)) {
					selectedWeek = true;
					grpWeekText.members[curWeek].isFlashing = true;
					
					for (char in grpWeekCharacters.members) {
						if (char.character != '' && char.hasConfirmAnimation)
							char.animation.play('confirm');
					}
					
					FlxG.sound.play(Paths.sound('confirmMenu'));
				}
			} else {
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		}
	}
	
	static function prepareWeek(week:WeekData, difficultyIdx:Int = -1) {
		if (difficultyIdx == -1)
			difficultyIdx = PlayState.storyDifficulty;
		
		var diffName:String = Difficulty.getFilePath(difficultyIdx) ?? '';
		
		PlayState.storyWeekData = week;
		PlayState.storyDifficulty = difficultyIdx;
		PlayState.storyPlaylist = [for (song in week.songs) song[0]];
		
		Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffName, PlayState.storyPlaylist[0].toLowerCase());
		PlayState.isStoryMode = true;
		PlayState.campaignMisses = 0;
		PlayState.campaignScore = 0;
		
		PlayState.storyVariables.clear();
	}
	
	public static function getWeek(fileName:String):WeekData {
		var weekPath:String = Paths.getPath('weeks/$fileName.json');
		var weekFile:WeekFile = WeekData.getWeekFile(weekPath);
		if (weekFile != null) {
			var weekData:WeekData = new WeekData(weekFile, fileName);
			return weekData;
		}
		return null;
	}
	
	public static function loadWeek(?weekData:WeekData, difficultyIdx:Int = -1):Bool {
		try {
			prepareWeek(weekData ?? PlayState.storyWeekData, difficultyIdx);
		} catch(e:Dynamic) {
			trace('ERROR! $e');
			return false;
		}
		
		var directory = StageData.forceNextDirectory;
		LoadingState.loadNextDirectory();
		StageData.forceNextDirectory = directory;

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory) {
			trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
			Paths.freeGraphicsFromMemory();
		}
		LoadingState.prepareToSong();
		new FlxTimer().start(1, (_) -> {
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			LoadingState.loadAndSwitchState(new PlayState(), true);
			FreeplayState.destroyFreeplayVocals();
		});
		
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
		
		return true;
	}
	
	public static function loadSong(?name:String, difficultyIdx:Int = -1):Void {
		if (name == null || name.length < 1)
			name = Song.loadedSongName;
		if (difficultyIdx == -1)
			difficultyIdx = PlayState.storyDifficulty;

		var formattedSong:String = Highscore.formatSong(name, difficultyIdx);
		FlxG.state.persistentUpdate = false;
		Song.loadFromJson(formattedSong, name);
		PlayState.storyDifficulty = difficultyIdx;
		LoadingState.loadAndSwitchState(new PlayState());
		
		if (FlxG.sound.music != null) {
			FlxG.sound.music.volume = 0;
			FlxG.sound.music.pause();
		}
		var game:PlayState = PlayState.instance;
		if (game != null && game.vocals != null) {
			game.vocals.volume = 0;
			game.vocals.pause();
		}
		FlxG.camera.followLerp = 0;
	}

	function changeDifficulty(change:Int = 0):Void
	{
		var next:Int = curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		
		if (callOnScripts('onChangeDifficulty', [Difficulty.getString(next), next], true) != psychlua.LuaUtils.Function_Stop) {
			curDifficulty = next;

			WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

			var diff:String = Difficulty.getString(curDifficulty, false);
			var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));
			//trace(Mods.currentModDirectory + ', menudifficulties/' + Paths.formatToSongPath(diff));

			if(sprDifficulty.graphic != newImage)
			{
				sprDifficulty.loadGraphic(newImage);
				sprDifficulty.x = leftArrow.x + 60;
				sprDifficulty.x += (308 - sprDifficulty.width) / 3;
				sprDifficulty.alpha = 0;
				sprDifficulty.y = leftArrow.y - sprDifficulty.height + 50;

				FlxTween.cancelTweensOf(sprDifficulty);
				FlxTween.tween(sprDifficulty, {y: sprDifficulty.y + 30, alpha: 1}, 0.07);
			}
			lastDifficultyName = diff;

			#if !switch
			intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
			#end
			
			callOnScripts('onChangeDifficultyPost', [Difficulty.getString(curDifficulty), curDifficulty]);
		}
	}

	var lerpScore:Int = 49324858;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void {
		var next:Int = FlxMath.wrap(curWeek + change, 0, loadedWeeks.length - 1);
		
		if (callOnScripts('onSelectItem', [loadedWeeks[next], next], true) != psychlua.LuaUtils.Function_Stop) {
			curWeek = next;
			
			var leWeek:WeekData = loadedWeeks[curWeek];
			WeekData.setDirectoryFromWeek(leWeek);

			var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
			txtWeekTitle.text = leName.toUpperCase();
			txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

			var unlocked:Bool = !weekIsLocked(leWeek.fileName);
			for (num => item in grpWeekText.members) {
				item.alpha = 0.6;
				if (num - curWeek == 0 && unlocked)
					item.alpha = 1;
			}

			bgSprite.visible = true;
			var assetName:String = leWeek.weekBackground;
			if(assetName == null || assetName.length < 1) {
				bgSprite.visible = false;
			} else {
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
			}
			PlayState.storyWeek = curWeek;

			Difficulty.loadFromWeek();
			difficultySelectors.visible = unlocked;

			if (Difficulty.list.contains(Difficulty.getDefault())) {
				curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
			} else {
				curDifficulty = 0;
			}

			var newPos:Int = Difficulty.list.indexOf(lastDifficultyName);
			//trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
			if(newPos > -1)
				curDifficulty = newPos;
			updateText();
			
			callOnScripts('onSelectItemPost', [leWeek.fileName, curWeek]);
		}
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length) {
			stringThing.push(leWeek.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.text = txtTracklist.text.toUpperCase();

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}
}
