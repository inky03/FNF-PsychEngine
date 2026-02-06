package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flxanimate.effects.FlxTint;

class CharacterSelectState extends MusicBeatState
{
    var allowInputs:Bool = true;
    var allowDifficultySwitching:Bool = true;
    var normalSelected:Bool;

    var backspace:FlxSprite;
    var background:FlxSprite;
    var stage:FlxSprite;
    var curtains:FlxSprite;
    var light:FlxSprite;
    var light2:FlxSprite;
    var blur:FlxSprite;
    var backingBlur:FlxSprite;
    var backing:FlxSprite;
    var choose:FlxSprite;
    var cursor:FlxSprite;

    var bfIcon:FlxSprite;
    var picoIcon:FlxSprite;
    var nameTag:FlxSprite;
    var difficultyTag:FlxSprite;

    var crowd:FlxAnimate;
    var barThing:FlxAnimate;
    var speakers:FlxAnimate;
    var man:FlxAnimate;
    var bf:FlxAnimate;
    var gf:FlxAnimate;
    var pico:FlxAnimate;
    var back:FlxAnimate;
    var nene:FlxAnimate;

    var switchTimer:FlxTimer;

    var icons:FlxAnimate;
    var grpIcons:FlxSpriteGroup;

    var colors:Array<FlxColor> = [
        0x31F2A5, 0x20ECCD, 0x24D9E8,
        0x20ECCD, 0x20C8D4, 0x209BDD,
        0x209BDD, 0x2362C9, 0x243FB9
    ]; // lock colors, in a nx3 matrix format

    var currentX:Int = 1; //the default X position. Starts it in the Center. Change the value to 0 to start it at the far left, or 2 to start it at the far right.
    var currentY:Int = 1; //the default Y position. Starts it in the Center. Change the value to 0 to start it at the bottom, or 2 to start it at the top.
    var grpXSpread:Int = 107;
    var grpYSpread:Int = 127;

    var imagePath:String = "charSelect/";

    override function create() {

        Conductor.bpm = 90;

        normalSelected = (ClientPrefs.data.savedDifficulty != 'erect');

        #if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Character Select", null);
		#end

        background = new FlxSprite(-153, -140).loadGraphic(Paths.image(imagePath + 'charSelectBG'));
        background.scrollFactor.set(0.1, 0.1);
        add(background);

        crowd = new FlxAnimate(0, 230);
		Paths.loadAnimateAtlas(crowd, imagePath + 'crowd');
		crowd.anim.addBySymbol('idle', 'crowd', 24, true);
        crowd.anim.play('idle', true, false, 0);
        crowd.scrollFactor.set(0.3, 0.3);
		add(crowd);

        stage = new FlxSprite(-40, 391).loadGraphic(Paths.image(imagePath + 'charSelectStage'));
        stage.frames = Paths.getSparrowAtlas(imagePath + 'charSelectStage');
        stage.animation.addByPrefix("idle", "stage full instance 1", 24, true);
        stage.animation.play('idle');
        stage.scrollFactor.set(1, 1);
        add(stage);

        curtains = new FlxSprite(-47, -49).loadGraphic(Paths.image(imagePath + 'curtains'));
        curtains.scrollFactor.set(1.4, 1.4);
        add(curtains);

        barThing = new FlxAnimate(-20, 0);
		Paths.loadAnimateAtlas(barThing, imagePath + 'barThing');
		barThing.anim.addBySymbol('idle', 'name bar animated', 24, true);
        barThing.scrollFactor.set(0, 0);
        barThing.anim.play('idle');
		add(barThing);
        barThing.y += 80;
        FlxTween.tween(barThing, {y: barThing.y - 80}, 1.3, {ease: FlxEase.expoOut});

        light = new FlxSprite(800, 250).loadGraphic(Paths.image(imagePath + 'charLight'));
        add(light);

        light2 = new FlxSprite(180, 240).loadGraphic(Paths.image(imagePath + 'charLight'));
        add(light2);

        //WHERE THE CHARS SHOULD GO. SAVE THIS SPOT

        //This man is commented out bc the way it tries to load causes a memory leak
        /*
        man = new FlxAnimate(670, 350);
		Paths.loadAnimateAtlas(man, imagePath + 'lockedChill');
		//man.anim.addBySymbol('idle', 'cannot select\\', 24, true);
        man.anim.addByFrameLabel('idle', 'idle', 24, true);
        man.anim.play('idle', true, false, 0);
        man.scrollFactor.set(1, 1);
		add(man);
        */

        bf = new FlxAnimate(600, 350);
		Paths.loadAnimateAtlas(bf, imagePath + 'bfChill');
		bf.anim.addBySymbol('idle', 'bf cs idle\\', 24, false);
        bf.anim.addBySymbol('confirm', 'bf cs confirm\\', 24, false);
        bf.anim.play('idle', true, false, 0);
        bf.scrollFactor.set(1, 1);
		add(bf);

        gf = new FlxAnimate(600, 350);
		Paths.loadAnimateAtlas(gf, imagePath + 'gfChill');
		gf.anim.addBySymbol('idle', 'Partner GF idle\\', 24, true);
        gf.anim.play('idle', true, false, 0);
        gf.scrollFactor.set(1, 1);
		add(gf);

        pico = new FlxAnimate(1050, 250);
		Paths.loadAnimateAtlas(pico, imagePath + 'picoChill');
		pico.anim.addBySymbol('idle', 'pico cs idle\\', 24, false);
        pico.anim.addBySymbol('confirm', 'pico cs confirm\\', 24, false, 323, 165);
        pico.anim.play('idle', true, false, 0);
        pico.flipX = true;
        pico.scrollFactor.set(1, 1);
		add(pico);

        back = new FlxAnimate(150, 220); //this is literally only used one time idfk why it wasn't just included with the entire damn atlas animation for nene
		Paths.loadAnimateAtlas(back, imagePath + 'neneChill');
		back.anim.addBySymbol('idle', 'speaker backing\\', 24, true);
        back.anim.play('idle', true, false, 0);
        back.scrollFactor.set(1, 1);
		add(back);

        nene = new FlxAnimate(700, 400);
		Paths.loadAnimateAtlas(nene, imagePath + 'neneChill');
		nene.anim.addBySymbol('idle', 'nene cs idle\\', 24, true);
        nene.anim.play('idle', true, false, 0);
        nene.scrollFactor.set(1, 1);
		add(nene);

        pico.alpha = 0.0001;
        nene.alpha = 0.0001;
        back.alpha = 0.0001;
        //

        speakers = new FlxAnimate(0, 0);
		Paths.loadAnimateAtlas(speakers, imagePath + 'charSelectSpeakers');
		speakers.anim.addBySymbol('idle', 'G', 24, true);
        speakers.anim.play('idle', true, false, 0);
        speakers.scrollFactor.set(1.8, 1.8);
		add(speakers);

        blur = new FlxSprite(-125, 170).loadGraphic(Paths.image(imagePath + 'foregroundBlur'));
        blur.blend = MULTIPLY;
        add(blur);

        backingBlur = new FlxSprite(419, -65);
        backingBlur.frames = Paths.getSparrowAtlas(imagePath + 'dipshitBlur');
        backingBlur.animation.addByPrefix("idle", "CHOOSE vertical offset instance 1", 24, true);
        backingBlur.animation.play('idle');
        backingBlur.blend = ADD;
        add(stage);

        backing = new FlxSprite(423, -17);
        backing.frames = Paths.getSparrowAtlas(imagePath + 'dipshitBacking');
        backing.animation.addByPrefix("idle", "CHOOSE horizontal offset instance 1", 24, true);
        backing.animation.play('idle');
        backing.blend = ADD;
        add(stage);
        backing.y += 210;
        FlxTween.tween(backing, {y: backing.y - 210}, 1.1, {ease: FlxEase.expoOut});

        choose = new FlxSprite(426, -13).loadGraphic(Paths.image(imagePath + 'chooseDipshit'));
        add(choose);
        choose.y += 200;
        FlxTween.tween(choose, {y: choose.y - 200}, 1, {ease: FlxEase.expoOut});
        backingBlur.y += 220;
        FlxTween.tween(backingBlur, {y: backingBlur.y - 220}, 1.2, {ease: FlxEase.expoOut});

        backingBlur.scrollFactor.set();
        backing.scrollFactor.set();
        choose.scrollFactor.set();

        cursor = new FlxSprite(0, 0).loadGraphic(Paths.image(imagePath + 'charSelector'));
        cursor.scrollFactor.set(0, 0);
        cursor.screenCenter();
        cursor.x -= 25;
        cursor.y -= 25;
        add(cursor);
        FlxTween.color(cursor, 0.2, 0xFFFFFF00, 0xFFFFCC00, {type: PINGPONG});

        backspace = new FlxSprite(0, 560);
        backspace.frames = Paths.getSparrowAtlas(imagePath + 'backspace');
        backspace.animation.addByPrefix('white', "backspace to exit white0", 24);
        backspace.animation.play('white');
        backspace.updateHitbox();
        add(backspace);

        nameTag = new FlxSprite(900, -10).loadGraphic(Paths.image(imagePath + 'boyfriendNametag'));
        nameTag.scale.set(0.7, 0.7);
        nameTag.updateHitbox();
        add(nameTag);

        difficultyTag = new FlxSprite(100, 15).loadGraphic(Paths.image(imagePath + 'difficulties/' + (ClientPrefs.data.savedDifficulty == 'normal' ? 'normal' : 'erect')));
        add(difficultyTag);

        var bottomBG:FlxSprite = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

        var leText:String = Language.getPhrase("characterSelect_tip", "Press TAB to change difficulty / Press BACKSPACE to exit the Menu / Press ACCEPT on a character to play their songs.");
		var size:Int = 16;
		var bottomText:FlxText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

        FlxG.sound.playMusic(Paths.music('charSelect/stayFunky'), 0);
        FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);

        createLocks();

        Paths.image(imagePath + 'picoNametag', true);
        Paths.image(imagePath + 'lockedNametag', true);

        super.create();
    }

    function createLocks() {
        grpIcons = new FlxSpriteGroup();
        add(grpIcons);

        bfIcon = new FlxSprite(590, 300);
        bfIcon.frames = Paths.getSparrowAtlas(imagePath + 'pixelIcons/bfpixel');
        bfIcon.animation.addByPrefix("idle", "idle", 24, false);
        bfIcon.animation.addByPrefix("confirm", "confirm", 24, false);
        bfIcon.animation.play('idle');
        bfIcon.setGraphicSize(128, 128);
        add(bfIcon);

        picoIcon = new FlxSprite(495, 305);
        picoIcon.frames = Paths.getSparrowAtlas(imagePath + 'pixelIcons/picopixel');
        picoIcon.animation.addByPrefix("idle", "idle", 24, false);
        picoIcon.animation.addByPrefix("confirm", "confirm", 24, false);
        picoIcon.animation.play('idle');
        picoIcon.setGraphicSize(64, 64);
        add(picoIcon);

        for (i in 0...9) {
            icons = new FlxAnimate(i, 0);
		    Paths.loadAnimateAtlas(icons, imagePath + 'lock');
            icons.anim.addBySymbol('full', 'LOCK FULL 1\\', 24, false);
            icons.anim.addBySymbolIndices('idle', 'LOCK FULL 1', [0], 0, false);
            icons.anim.play('idle', true, false, 0);
            icons.scrollFactor.set(0, 0);
		    grpIcons.add(icons);

            switch(i) {
                case 3 | 4:
                    icons.alpha = 0.0001;
            }

            var tint:FlxTint = new FlxTint(colors[i], 1);
            var arr:Array<String> = ["lock", "lock top 1", "lock top 2", "lock top 3", "lock base fuck it"];

            var func = function(name) {
                var symbol = icons.anim.symbolDictionary[name];
                if (symbol != null && symbol.timeline.get("color") != null) symbol.timeline.get("color").get(0).colorEffect = tint;
            }

            for (symbol in arr)
            {
                func(symbol);
            }
        }
        updateIconPositions();
    }

    function updateIconPositions() {
        grpIcons.x = 420;
        grpIcons.y = 100;
        for (index => member in grpIcons.members) {
            var posX:Float = (index % 3);
            var posY:Float = Math.floor(index / 3);

            member.x = posX * grpXSpread;
            member.y = posY * grpYSpread;

            member.x += grpIcons.x;
            member.y += grpIcons.y;
        }
    }

    override function update(elapsed:Float):Void {
        if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
        
        if (controls.BACK && allowInputs) {
            allowInputs = false;
            MusicBeatState.switchState(new FreeplayState());
            FlxG.sound.play(Paths.sound('cancelMenu'));
        }
        
        if (controls.ACCEPT && allowInputs) {
            if (currentY == 1 && (currentX == 0 || currentX == 1)) {
                allowInputs = false;

                var selectedIcon = ((currentX == 1 && currentY == 1) ? bfIcon : (currentX == 0 && currentY == 1) ? picoIcon : null);
                var selectedChar = ((currentX == 1 && currentY == 1) ? bf : (currentX == 0 && currentY == 1) ? pico : null);

                selectedChar.anim.play('confirm', true, false, 0);
                selectedIcon.animation.play('confirm', true, false, 0);

                FlxG.sound.music.stop();
                FlxG.sound.play(Paths.sound("charSelect/CS_confirm"));

                ClientPrefs.data.savedCharacter = ((currentX == 1 && currentY == 1) ? 'bf' : (currentX == 0 && currentY == 1) ? 'pico' : '');
                ClientPrefs.saveSettings();
                
                switchTimer = new FlxTimer().start(2, function(_){
                    FlxG.switchState(new FreeplayState());
                    switchTimer = null;
                });
            } else {
                FlxG.sound.play(Paths.sound("charSelect/CS_locked"));
            }
        }

        if (allowInputs) {

            if(controls.UI_LEFT_P) changeSelection('x', -1);
            if(controls.UI_RIGHT_P) changeSelection('x', 1);
            if(controls.UI_DOWN_P) changeSelection('y', 1);
            if(controls.UI_UP_P) changeSelection('y', -1);

            if (FlxG.keys.justPressed.TAB && allowDifficultySwitching) {
                normalSelected = !normalSelected;

                ClientPrefs.data.savedDifficulty = (normalSelected ? 'normal' : 'erect');
                difficultyTag.loadGraphic(Paths.image(imagePath + 'difficulties/' + (normalSelected ? 'normal' : 'erect')));
                ClientPrefs.saveSettings();
                FlxG.sound.play(Paths.sound("cancelMenu"));
            }

            currentX = Std.int(Math.max(0, Math.min(2, currentX)));
            currentY = Std.int(Math.max(0, Math.min(2, currentY)));

            var targetX = 445 + (currentX * 110);
            var targetY = 150 + (currentY * 125);
            var smooth = 1 - Math.exp(-elapsed * 10);

            cursor.x = FlxMath.lerp(cursor.x, targetX, smooth);
            cursor.y = FlxMath.lerp(cursor.y, targetY, smooth);
        }

        super.update(elapsed);
    }

    function changeSelection(direction:String, value:Int) {
        if (direction == 'x' && (currentX >= 0 && currentX <= 2)) {
            currentX += value;
            currentX = Std.int(Math.max(0, Math.min(2, currentX)));
            FlxG.sound.play(Paths.sound('charSelect/CS_select'));
        }
        if (direction == 'y' && (currentY >= 0 && currentY <= 2)) {
            currentY += value;
            currentY = Std.int(Math.max(0, Math.min(2, currentY)));
            FlxG.sound.play(Paths.sound('charSelect/CS_select'));
        }

        allowDifficultySwitching = ((currentX == 1 && currentY == 1) ? true : false);
        difficultyTag.alpha = ((currentX == 1 && currentY == 1) ? 1 : 0.0001);

        bfIcon.setGraphicSize((currentX == 1 && currentY == 1) ? 128 : 88, (currentX == 1 && currentY == 1) ? 128 : 88);
        picoIcon.setGraphicSize((currentX == 0 && currentY == 1) ? 88 : 64, (currentX == 0 && currentY == 1) ? 88 : 64);

        for (obj in [bf, gf]) {
            obj.alpha = ((currentY == 1 && currentX == 1) ? 1 : 0.0001);
        }

        for (objs in [pico, nene, back]) {
            objs.alpha = ((currentY == 1 && currentX == 0) ? 1 : 0.0001);
        }

        //man.alpha = ((currentY != 1 && currentX != 0) && (currentY != 1 && currentX != 1) ? 1 : 0.0001);

        nameTag.loadGraphic(Paths.image(imagePath + ((currentY == 1 && currentX == 1) ? 'boyfriendNametag' : (currentY == 1 && currentX == 0) ? 'picoNametag' : 'lockedNameTag')));
        nameTag.updateHitbox();

        for (i in 0...grpIcons.members.length) {
            var icon = cast(grpIcons.members[i], FlxAnimate);
            var xIndex = i % 3;
            var yIndex = Std.int(i / 3);

            if (xIndex == currentX && yIndex == currentY) {
                icon.anim.play("full", true);
            } else {
                icon.anim.play("idle", true);
            }
        } 

        trace('X Position: ' + currentX + ' Y Position: ' + currentY);
    }

    override function beatHit(beat:Int) {
        super.beatHit(beat);

        bf.anim.play('idle', true, false, 0);
        pico.anim.play('idle', true, false, 0);
    }

    override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;

		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
        FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
	}
}