package states.editors.content;

import backend.Song;
import backend.Rating;

import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.animation.FlxAnimationController;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

class EditorPlayState extends MusicBeatSubstate
{
	// Borrowed from original PlayState
	var finishTimer:FlxTimer = null;
	var noteKillOffset:Float = 350;
	var spawnTime:Float = 2000;
	var startingSong:Bool = true;

	var playbackRate:Float = 1;
	var inst:FlxSound = new FlxSound();
	var vocals:FlxSound;
	var opponentVocals:FlxSound;
	
	var notes:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var ratingsData:Array<Rating> = Rating.loadDefault();
	
	var comboGroup:FlxSpriteGroup;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrums:FlxTypedGroup<StrumNote>;
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	
	var combo:Int = 0;
	var lastRating:FlxSprite;
	var lastCombo:FlxSprite;
	var lastScore:Array<FlxSprite> = [];
	var keysArray:Array<String> = [
		'note_left',
		'note_down',
		'note_up',
		'note_right'
	];
	
	var songHits:Int = 0;
	var songMisses:Int = 0;
	var songLength:Float = 0;
	var songSpeed:Float = 1;
	
	var showCombo:Bool = false;
	var showComboNum:Bool = true;
	var showRating:Bool = true;

	// Originals
	var startOffset:Float = 0;
	var startPos:Float = 0;
	var timerToStart:Float = 0;
	var downScroll:Bool = false;

	var scoreTxt:FlxText;
	var dataTxt:FlxText;
	var guitarHeroSustains:Bool = false;

	var _noteList:Array<Note>;
	public function new(noteList:Array<Note>, allVocals:Array<FlxSound>, downScroll:Bool = false)
	{
		super();
		
		/* setting up some important data */
		this.vocals = allVocals[0];
		this.opponentVocals = allVocals[1];
		this.downScroll = downScroll;
		this._noteList = noteList;
		this.startPos = Conductor.songPosition;
		Conductor.songPosition = startPos;

		#if FLX_PITCH
		playbackRate = FlxG.sound.music.pitch;
		#end
	}

	override function create()
	{
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * playbackRate;
		Conductor.songPosition -= startOffset;
		
		startOffset = Conductor.crochet * playbackRate;
		timerToStart = startOffset;

		cachePopUpScore();
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;
		if(ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');

		/* setting up Editor PlayState stuff */
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF101010;
		bg.alpha = 0.9;
		add(bg);
		
		/**** NOTES ****/
		comboGroup = new FlxSpriteGroup();
		add(comboGroup);
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		add(strumLineNotes);
		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);
		
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; //cant make it invisible or it won't allow precaching

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();
		
		generateStaticArrows(0);
		generateStaticArrows(1);
		/***************/
		
		scoreTxt = new FlxText(10, FlxG.height - 50, FlxG.width - 20, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		add(scoreTxt);
		
		dataTxt = new FlxText(10, 560, FlxG.width - 20, "Section: 0", 20);
		dataTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		dataTxt.scrollFactor.set();
		dataTxt.borderSize = 1.25;
		add(dataTxt);

		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		FlxG.mouse.visible = false;
		
		generateSong();
		_noteList = null;

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		DiscordClient.changePresence('Playtesting on Chart Editor', PlayState.SONG.song, null, true, songLength);
		#end
		updateScore();
		cachePopUpScore();

		super.create();

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function update(elapsed:Float)
	{
		if(controls.BACK || FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.F12)
		{
			endSong();
			super.update(elapsed);
			return;
		}
		
		if (startingSong)
		{
			timerToStart -= elapsed * 1000 * playbackRate;
			Conductor.songPosition = startPos - timerToStart;
			if(timerToStart < 0) startSong();
		}
		else
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= 0)
			{
				var timeDiff:Float = Math.abs((inst.time + Conductor.offset) - Conductor.songPosition);
				Conductor.songPosition = FlxMath.lerp(inst.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 2.5));
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

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

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		keysCheck();
		if(notes.length > 0)
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

				if(!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
					opponentNoteHit(daNote);

				if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

				// Kill extremely late notes and cause misses
				if (Conductor.songPosition - daNote.strumTime - daNote.sustainLength > noteKillOffset)
				{
					if (daNote.mustPress && !daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit))
						noteMiss(daNote);

					daNote.active = daNote.visible = false;
					invalidateNote(daNote);
				}
				
				if (!daNote.exists || !daNote.alive)
					noteInd --;
			}
		}
		
		var time:Float = CoolUtil.floorDecimal((Conductor.songPosition - ClientPrefs.data.noteOffset) / 1000, 1);
		var songLen:Float = CoolUtil.floorDecimal(songLength / 1000, 1);
		dataTxt.text = 'Time: $time / $songLen' +
						'\n\nSection: $curSection' +
						'\nBeat: $curBeat' +
						'\nStep: $curStep';
		super.update(elapsed);
	}

	var lastBeatHit:Int = -1;
	override function beatHit(beat:Int):Void {
		if (lastBeatHit >= beat)
			return;
		
		notes.members.sort((a:Note, b:Note) -> Std.int(b.strumTime) - Std.int(a.strumTime));

		super.beatHit(beat);
		lastBeatHit = beat;
	}
	
	override function sectionHit(section:Int):Void {
		if (PlayState.SONG.notes[section] != null) {
			if (PlayState.SONG.notes[section].changeBPM)
				Conductor.bpm = PlayState.SONG.notes[section].bpm;
		}
		
		super.sectionHit(section);
	}

	override function destroy()
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		FlxG.mouse.visible = true;
		NoteSplash.configs.clear();
		FlxG.sound.list.remove(inst);
		flixel.util.FlxDestroyUtil.destroy(inst);
		super.destroy();
	}
	
	function startSong():Void
	{
		startingSong = false;
		@:privateAccess inst.loadEmbedded(FlxG.sound.music._sound);
		inst.looped = false;
		inst.onComplete = finishSong;
		inst.volume = vocals.volume = opponentVocals.volume = 1;
		inst.pitch = playbackRate;
		FlxG.sound.list.add(inst);

		FlxG.sound.music.pause();
		inst.play();
		vocals.play();
		opponentVocals.play();
		inst.time = vocals.time = opponentVocals.time = startPos - Conductor.offset;

		// Song duration in a float, useful for the time left feature
		songLength = inst.length;
	}

	// Borrowed from PlayState
	function generateSong()
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		var songSpeedType:String = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);

		var songData = PlayState.SONG;
		Conductor.bpm = songData.bpm;

		inst.volume = vocals.volume = opponentVocals.volume = 0;

		notes = new FlxTypedGroup<Note>();
		add(notes);

		var daBpm:Float = (PlayState.SONG.notes[0].changeBPM == true) ? PlayState.SONG.notes[0].bpm : PlayState.SONG.bpm;
		var oldNote:Note = null;

		// Section Time/Crochet
		var noteSec:Int = 0;
		var secTime:Float = 0;
		var cachedSectionTimes:Array<Float> = [];
		var cachedSectionCrochets:Array<Float> = [];
		if(PlayState.SONG != null)
		{
			var tempBpm:Float = daBpm;
			for (secNum => section in PlayState.SONG.notes)
			{
				if(PlayState.SONG.notes[noteSec].changeBPM == true)
					tempBpm = PlayState.SONG.notes[noteSec].bpm;

				secTime += Conductor.calculateCrochet(tempBpm) * (Math.round(4 * section.sectionBeats) / 4);
				cachedSectionTimes.push(secTime);
			}
		}

		// Load Notes
		for (note in _noteList)
		{
			if(note == null || note.strumTime < startPos - 2) continue;
			
			while(cachedSectionTimes.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime)
			{
				noteSec++;
				if(PlayState.SONG.notes[noteSec].changeBPM == true)
					daBpm = PlayState.SONG.notes[noteSec].bpm;
			}

			var idx: Int = _noteList.indexOf(note);
			if (idx != 0) {
				// CLEAR ANY POSSIBLE GHOST NOTES
				for (evilNote in unspawnNotes) {
					var matches: Bool = note.noteData == evilNote.noteData && note.mustPress == evilNote.mustPress && note.noteType == evilNote.noteType;
					if (matches && Math.abs(note.strumTime - evilNote.strumTime) < flixel.math.FlxMath.EPSILON) {
						if (evilNote.tail.length > 0)
							for (tail in evilNote.tail)
							{
								tail.destroy();
								unspawnNotes.remove(tail);
							}
						evilNote.destroy();
						unspawnNotes.remove(evilNote);
						//continue;
					}
				}
			}

			var swagNote:Note = new Note(note.strumTime, note.noteData, oldNote, false, this);
			swagNote.sustainLength = note.sustainLength;
			swagNote.mustPress = note.mustPress;
			swagNote.noteType = note.noteType;
			swagNote.gfNote = note.gfNote;
			swagNote.section = noteSec;

			swagNote.scrollFactor.set();
			unspawnNotes.push(swagNote);

			var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
			final roundSus:Int = Math.round(swagNote.sustainLength / Conductor.stepCrochet);
			if(roundSus > 0)
			{
				for (susNote in 0...roundSus)
				{
					oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

					var sustainNote:Note = new Note(swagNote.strumTime + (curStepCrochet * susNote), note.noteData, oldNote, true, this);
					sustainNote.sustainLength = curStepCrochet;
					sustainNote.mustPress = swagNote.mustPress;
					sustainNote.noteType = swagNote.noteType;
					sustainNote.gfNote = swagNote.gfNote;
					sustainNote.scrollFactor.set();
					sustainNote.section = noteSec;
					sustainNote.parent = swagNote;
					unspawnNotes.push(sustainNote);
					swagNote.tail.push(sustainNote);
					
					if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
					else if(ClientPrefs.data.middleScroll)
					{
						sustainNote.x += 310;
						if(sustainNote.noteData > 1) //Up and Right
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
				if(swagNote.noteData > 1) //Up and Right
				{
					swagNote.x += FlxG.width / 2 + 25;
				}
			}
			oldNote = swagNote;
		}
		unspawnNotes.sort(PlayState.sortByTime);
	}
	
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
		var strumLineY:Float = downScroll ? (FlxG.height - 150) : 50;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = downScroll;
			babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
			{
				if(ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();
		}
	}

	public function finishSong():Void
	{
		if(ClientPrefs.data.noteOffset <= 0) {
			endSong();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endSong();
			});
		}
	}

	public function endSong()
	{
		notes.forEachAlive(function(note:Note) invalidateNote(note));
		for (note in unspawnNotes)
			if(note != null) invalidateNote(note);

		inst.pause();
		vocals.pause();
		opponentVocals.pause();

		if(finishTimer != null)
			finishTimer.destroy();

		Conductor.songPosition = FlxG.sound.music.time = vocals.time = opponentVocals.time = startPos - Conductor.offset;
		close();
	}
	
	private function cachePopUpScore()
	{
		var uiFolder:String = "";
		if (PlayState.stageUI != "normal")
			uiFolder = PlayState.uiPrefix + "UI/";

		for (rating in ratingsData)
			Paths.image(uiFolder + rating.image + PlayState.uiPostfix);
		for (i in 0...10)
			Paths.image(uiFolder + 'num' + i + PlayState.uiPostfix);
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

		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if(!note.ratingDisabled) {
			songHits++;
			updateScore();
		}

		var uiFolder:String = "";
		var antialias:Bool = ClientPrefs.data.antialiasing;
		if (PlayState.stageUI != "normal")
		{
			uiFolder = PlayState.uiPrefix + "UI/";
			antialias = !PlayState.isPixelStage;
		}

		rating.loadGraphic(Paths.image(uiFolder + daRating.image + PlayState.uiPostfix));
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

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'combo' + PlayState.uiPostfix));
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
			rating.setGraphicSize(Std.int(rating.width * PlayState.daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * PlayState.daPixelZoom * 0.85));
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
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'num' + Std.parseInt(separatedScore.charAt(i)) + PlayState.uiPostfix));
			numScore.screenCenter();
			numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
			numScore.y += 80 - ClientPrefs.data.comboOffset[3];

			if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			else numScore.setGraphicSize(Std.int(numScore.width * PlayState.daPixelZoom));
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

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);
		//trace('Pressed: ' + eventKey);

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
		if(key < 0) return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if(Conductor.songPosition >= 0) Conductor.songPosition = inst.time + Conductor.offset;

		// obtain notes that the player can hit
		var highestNote:Note = null;
		for (n in notes) {
			if (n != null && !n.isSustainNote && n.noteData == key && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit) {
				if (highestNote == null || n.hitPriority > highestNote.hitPriority || (n.hitPriority == highestNote.hitPriority && n.strumTime < highestNote.strumTime))
					highestNote = n;
			}
		}

		if (highestNote != null) {
			goodNoteHit(highestNote);
		} else {
			var spr:StrumNote = playerStrums.members[key];
			if (spr != null) {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
		}

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);
		//trace('Pressed: ' + eventKey);

		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
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
				if(pressArray[i])
					keyPressed(i);

		// rewritten inputs???
		if (notes.length > 0) {
			for (n in notes) { // I can't do a filter here, that's kinda awesome
				var canHit:Bool = (n != null && n.canBeHit && n.mustPress &&
					!n.tooLate && !n.wasGoodHit && !n.blockHit);

				if (guitarHeroSustains)
					canHit = canHit && n.parent != null && n.parent.wasGoodHit;

				if (canHit && n.isSustainNote) {
					var released:Bool = !holdArray[n.noteData];
					
					if (!released)
						goodNoteHit(n);
				}
			}
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i])
					keyReleased(i);
	}

	
	function opponentNoteHit(note:Note):Void
	{
		if (PlayState.SONG.needsVoices && opponentVocals.length <= 0)
			vocals.volume = 1;

		var strum:StrumNote = opponentStrums.members[Std.int(Math.abs(note.noteData))];
		if(strum != null) {
			strum.playAnim('confirm', true);
			strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / playbackRate;
		}
		note.hitByOpponent = true;

		if (!note.isSustainNote)
			invalidateNote(note);
	}

	function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;

		note.wasGoodHit = true;
		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);

		if(note.hitCausesMiss) {
			noteMiss(note);
			if(!note.noteSplashData.disabled && !note.isSustainNote)
				spawnNoteSplashOnNote(note);

			if (!note.isSustainNote)
				invalidateNote(note);
			return;
		}

		if (!note.isSustainNote)
		{
			combo++;
			if(combo > 9999) combo = 9999;
			popUpScore(note);
		}

		var spr:StrumNote = playerStrums.members[note.noteData];
		if(spr != null) spr.playAnim('confirm', true);
		vocals.volume = 1;

		if (!note.isSustainNote)
			invalidateNote(note);
	}
	
	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(daNote);
		});

		if (daNote != null && guitarHeroSustains && daNote.parent == null) {
			if(daNote.tail.length > 0) {
				daNote.alpha = 0.35;
				for(childNote in daNote.tail) {
					childNote.alpha = daNote.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				daNote.missed = true;
				daNote.canBeHit = false;
			}

			if (daNote.missed)
				return;
		}

		if (daNote != null && guitarHeroSustains && daNote.parent != null && daNote.isSustainNote) {
			if (daNote.missed)
				return; 
			
			var parentNote:Note = daNote.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != daNote) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		// score and data
		songMisses++;
		updateScore();
		vocals.volume = 0;
		combo = 0;
	}

	public function invalidateNote(note:Note):Void {
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
		}
	}

	function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null, strum:StrumNote) {
		var splash:NoteSplash = new NoteSplash();
		splash.babyArrow = strum;
		splash.spawnSplashNote(note);
		grpNoteSplashes.add(splash);
	}

	function updateScore()
		scoreTxt.text = 'Hits: $songHits | Misses: $songMisses';
}
