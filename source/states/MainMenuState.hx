package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

using Lambda;

enum abstract MainMenuColumn(String) to String {
	var LEFT = 'left';
	var CENTER = 'center';
	var RIGHT = 'right';
}

class MainMenuState extends ScriptedState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var modVersion = '0.0.5';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedSpriteGroup<MenuItem>;
	var selectedItem:MenuItem = null;
	var itemYPadding:Float = 25;
	var itemSpacing:Float = 140;
	var rightItem:MenuItem;
	var leftItem:MenuItem;
	var psychVer:FlxText;
	var emiVer:FlxText;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits',
		'options'
	];
	var menuFunctions:Map<String, MenuItem -> Void> = [];

	var rightOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var leftOption:String = null;
	
	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	
	var justEntered:Bool = true;

	static var showOutdatedWarning:Bool = true;
	var openDebugMenu:Bool = false;
	public function new(debug:Bool = false) {
		super();
		openDebugMenu = debug;
	}
	override function create() {
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		
		rpcDetails = 'In the Menus';

		persistentUpdate = persistentDraw = true;
		
		preCreate();
		
		bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		add(camFollow = new FlxObject(0, 0, 1, 1));
		FlxG.camera.follow(camFollow, null, .2);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedSpriteGroup();
		menuFunctions['story_mode'] ??= (item:MenuItem) -> MusicBeatState.switchState(new StoryMenuState());
		menuFunctions['freeplay'] ??= (item:MenuItem) -> MusicBeatState.switchState(new FreeplayState());
		menuFunctions['mods'] ??= (item:MenuItem) -> MusicBeatState.switchState(new ModsMenuState());
		menuFunctions['credits'] ??= (item:MenuItem) -> MusicBeatState.switchState(new CreditsState());
		menuFunctions['options'] ??= (item:MenuItem) -> {
			MusicBeatState.switchState(new OptionsState());
			OptionsState.onPlayState = false;
			if (PlayState.SONG != null) {
				PlayState.SONG.arrowSkin = null;
				PlayState.SONG.splashSkin = null;
				PlayState.stageUI = 'normal';
			}
		};
		#if ACHIEVEMENTS_ALLOWED menuFunctions['achievements'] ??= (item:MenuItem) -> MusicBeatState.switchState(new AchievementsMenuState()); #end
		
		for (option in optionShit)
			addMenuItem(option);

		emiVer = new FlxText(12, FlxG.height - 24, 0, 'Built on Psych Engine $psychEngineVersion', 11);
		emiVer.scrollFactor.set();
		emiVer.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(emiVer);
		psychVer = new FlxText(12, FlxG.height - 40, 0, 'Psych Engine Mint $modVersion', 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end
		
		subStateClosed.add((sub:flixel.FlxSubState) -> {
			if (sub is CustomFadeTransition) return;
			
			fade(true);
			pause(false);
		});
		subStateOpened.add((sub:flixel.FlxSubState) -> pause(true));
		if (openDebugMenu) {
			openSubState(new MasterEditorMenu(true));
			FlxTransitionableState.skipNextTransOut = true;
		}

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion > modVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end
		
		if (rightOption != null)
			rightItem = addMenuItem(rightOption, null, RIGHT);
		if (leftOption != null)
			leftItem = addMenuItem(leftOption, null, LEFT);
		
		add(menuItems);
		
		super.create();
		
		changeItem(true);
		FlxG.camera.snapToTarget();
	}
	
	function pause(yea:Bool):Void {
		if (justEntered && !openDebugMenu)
			yea = false;
		
		FlxG.mouse.visible = !yea;
		selectedSomethin = yea;
		justEntered = false;
	}

	function addMenuItem(name:String, ?onAccept:MenuItem -> Void, column:MainMenuColumn = CENTER):MenuItem {
		var item:MenuItem = new MenuItem(0, 0, name, onAccept ?? menuFunctions[name]);
		item.column = column;
		
		switch (column) {
			case CENTER:
				menuItems.add(item);
				positionMenuItems();
				
			case LEFT:
				if (leftItem != null) {
					trace('left slot already occupied by ${leftItem.name}!');
					return item;
				}
				
				item.setPosition(50, FlxG.height - item.height - 50);
				leftItem = item;
				add(item);
				updateYScroll();
				
			case RIGHT:
				if (rightItem != null) {
					trace('right slot already occupied by ${rightItem.name}!');
					return item;
				}
				
				item.setPosition(FlxG.width - item.width - 50, FlxG.height - item.height - 50);
				rightItem = item;
				add(item);
				updateYScroll();
		}
		
		return item;
	}
	
	function positionMenuItems():Void {
		for (i => item in menuItems.members) {
			item.setPosition(0, i * itemSpacing + (FlxG.height - menuItems.length * itemSpacing) * .5);
			item.screenCenter(X);
		}
		
		updateYScroll();
	}
	
	function getAllMenuItems():Array<MenuItem> {
		var items:Array<MenuItem> = [];
		
		for (item in menuItems) items.push(item);
		if (leftItem != null) items.push(leftItem);
		if (rightItem != null) items.push(rightItem);
		
		return items;
	}
	
	function updateYScroll():Void {
		var itemYScroll:Float = Math.min(1, Math.max(menuItems.height - FlxG.height + itemYPadding, 0) / FlxG.height * .35 + .25);
		menuItems?.scrollFactor.set(.04, itemYScroll);
		
		var yScroll:Float = (.7 / menuItems.length);
		leftItem?.scrollFactor.set(0, yScroll * .25);
		rightItem?.scrollFactor.set(0, yScroll * .25);
		
		bg.scrollFactor.set(0, yScroll * .75);
		magenta.scrollFactor.copyFrom(bg.scrollFactor);
	}
	
	var selectedSomethin:Bool = false;
	
	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0 || FlxG.mouse.justPressed)) {
				FlxG.mouse.visible = true;
				allowMouse = false;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn) {
					case LEFT:
						selectedItem = leftItem;
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case RIGHT:
						selectedItem = rightItem;
				}

				if (rightItem != null && FlxG.mouse.overlaps(rightItem)) {
					allowMouse = true;
					if (selectedItem != rightItem)
						changeItem(RIGHT);
				} else if (leftItem != null && FlxG.mouse.overlaps(leftItem)) {
					allowMouse = true;
					if (selectedItem != leftItem)
						changeItem(LEFT);
				} else {
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i => memb in menuItems.members) {
						if (memb.column != CENTER) continue;
						
						if (FlxG.mouse.overlaps(memb)) {
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.viewX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.viewY, 2));
							if (dist < 0 || distance < dist) {
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if (distItem != -1 && selectedItem != menuItems.members[distItem])
						changeItem(distItem - curSelected);
				}
			} else {
				timeNotMoving += elapsed;
				if (timeNotMoving > 2)
					FlxG.mouse.visible = false;
			}

			switch(curColumn) {
				case LEFT:
					if (controls.UI_RIGHT_P)
						changeItem(CENTER);
					
				case CENTER:
					if (controls.UI_RIGHT_P && rightItem != null) {
						changeItem(RIGHT);
					} else if (controls.UI_LEFT_P && leftItem != null) {
						changeItem(LEFT);
					}

				case RIGHT:
					if (controls.UI_LEFT_P)
						changeItem(CENTER);
			}

			if (controls.BACK) {
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse)) {
				var item:MenuItem = switch(curColumn) {
					case LEFT: leftItem;
					case CENTER: menuItems.members[curSelected];
					case RIGHT: rightItem;
				}
				
				if (callOnScriptsExt('onAccept', [curSelected], [item, curSelected], true) != psychlua.LuaUtils.Function_Stop) {
					FlxG.sound.play(Paths.sound('confirmMenu'));
					selectedSomethin = true;
					FlxG.mouse.visible = false;
					
					if (ClientPrefs.data.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);
					
					FlxFlicker.flicker(item, 1, 0.06, false, false, (flick:FlxFlicker) -> {
						if (item.onAccept != null) {
							item.onAccept(item);
						} else {
							trace('Menu Item "${item.name}" doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
							
							fade(true, item);
						}
					});
					
					fade(false, item);
				}
			}
			if (controls.justPressed('debug_1')) {
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				openSubState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
		
		postUpdate(elapsed);
	}
	
	function fade(fadeIn:Bool = false, ?ignore:MenuItem):Void {
		for (item in getAllMenuItems()) {
			if (item == ignore)
				continue;
			
			if (fadeIn)
				item.visible = true;
			FlxTween.cancelTweensOf(item);
			FlxTween.tween(item, {alpha: fadeIn ? 1 : 0}, 0.4, {ease: FlxEase.quadOut});
		}
	}

	function changeItem(change:Int = 0, column:MainMenuColumn = CENTER, forced:Bool = false)
	{
		var oldColumn:MainMenuColumn = curColumn;
		var oldSelected:Int = curSelected;
		
		if (column == CENTER)
			curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		
		if (change != 0) {
			curColumn = CENTER;
		} else {
			curColumn = column;
		}

		var newSelectedItem:MenuItem;
		switch(curColumn) {
			case LEFT:
				newSelectedItem = leftItem;
			case CENTER:
				newSelectedItem = menuItems.members[curSelected];
			case RIGHT:
				newSelectedItem = rightItem;
		}
		
		if (forced || callOnScriptsExt('onSelectItem', [curSelected], [selectedItem, curSelected], true) != psychlua.LuaUtils.Function_Stop) {
			if (selectedItem != null)
				selectedItem.selected = false;
			newSelectedItem.selected = true;
			selectedItem = newSelectedItem;
			
			if (change != 0 || curColumn != oldColumn)
				FlxG.sound.play(Paths.sound('scrollMenu'));
			
			if (leftItem != null) {
				FlxTween.cancelTweensOf(leftItem.scrollFactor, ['x']);
				FlxTween.tween(leftItem.scrollFactor, {x: (column == LEFT ? .08 : .01)}, .2, {ease: FlxEase.quartOut});
			}
			if (rightItem != null) {
				FlxTween.cancelTweensOf(rightItem.scrollFactor, ['x']);
				FlxTween.tween(rightItem.scrollFactor, {x: (column == RIGHT ? .08 : .01)}, .2, {ease: FlxEase.quartOut});
			}
			
			if (column == CENTER)
				camFollow.y = selectedItem.getGraphicMidpoint().y;
			camFollow.x = selectedItem.getGraphicMidpoint().x;
			
			callOnScriptsExt('onSelectItemPost', [curSelected], [selectedItem, curSelected]);
		} else {
			curColumn = oldColumn;
			curSelected = oldSelected;
		}
	}
}

class MenuItem extends FlxSprite {
	public var name:String;
	public var column:MainMenuColumn;
	public var onAccept:MenuItem -> Void = null;
	public var selected(default, set):Bool = false;
	
	public function new(x:Float = 0, y:Float = 0, name:String = '', ?onAccept:MenuItem -> Void) {
		this.onAccept = onAccept;
		this.name = name;
		super(x, y);
		
		loadSprite(name);
		
		antialiasing = ClientPrefs.data.antialiasing;
	}
	
	public function loadSprite(name:String) {
		frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		animation.addByPrefix('idle', '$name idle', 24, true);
		animation.addByPrefix('selected', '$name selected', 24, true);
		animation.play('idle');
		updateHitbox();
		
		selected = selected;
	}
	
	function set_selected(yea:Bool):Bool {
		animation.play(yea ? 'selected' : 'idle');
		centerOffsets();
		
		return selected = yea;
	}
}