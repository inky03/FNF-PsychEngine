package states.editors.content;

class Toy extends objects.Character {
	public var side:ToySide;
	public var holdSingTimer:Float = 0;
	public var autoCharacter:Bool = false;
	
	public var dropdown:PsychUIDropDownMenu;
	
	public function new(x:Float, y:Float, ?character:String, side:ToySide = PLAYER) {
		this.side = side;
		this.autoCharacter = (character == null);
		
		super(x, y, character);
		
		@:privateAccess var list:Array<String> = states.editors.ChartingState.instance.playerDropDown.list.copy();
		list.unshift('Auto.');
		
		dropdown = new PsychUIDropDownMenu(0, 0, list, function(ind:Int, character:String) {
			autoCharacter = (ind == 0);
			
			changeCharacter(character);
			dropdown.kill();
		});
		dropdown.unfocus = function() {
			dropdown.kill();
		}
		dropdown.kill();
		dropdown.button.visible = false;
	}
	
	public override function changeCharacter(newCharacter:String):Void {
		if (autoCharacter) newCharacter = getDefaultCharacter(side);
		if (curCharacter == newCharacter && frames != null) return;
		
		x += (width * .5);
		y += height;
		
		super.changeCharacter(newCharacter);
		
		flipX = (side != PLAYER == flipX);
		scaleTo(.35, .35);
		x -= (width * .5);
		y -= height;
	}
	
	public function getDefaultCharacter(side:ToySide) {
		return switch (side) {
			case GF: (PlayState.SONG.gfVersion ?? 'gf-nospeak');
			case PLAYER: (PlayState.SONG.player1 ?? 'bf');
			case OPPONENT: (PlayState.SONG.player2 ?? 'bf-pixel-opponent');
		}
	}
	
	public function scaleTo(x:Float = 1, ?y:Float):Void {
		scale.set(jsonScale * x, jsonScale * (y ?? x));
		updateHitbox();
		origin.set();
		
		x -= (width * .5);
		y -= height;

		for (anim in animOffsets) {
			anim[0] *= (scale.x / jsonScale);
			anim[1] *= (scale.y / jsonScale);
		}
		offset.set();
		dance();
	}
	
	public function showDropDown():Void {
		dropdown.revive();
		
		var mousePos:FlxPoint = FlxG.mouse.getScreenPosition(dropdown.camera, FlxPoint.weak());
		
		dropdown.text = (autoCharacter ? 'Auto.' : curCharacter);
		dropdown.setPosition(mousePos.x, mousePos.y);
		dropdown.showDropDown(true);
	}
	
	public override function update(elapsed:Float):Void {
		if (holdSingTimer > 0) {
			holdSingTimer -= elapsed;
			
			if (holdSingTimer <= 0)
				holdSingTimer = 0;
			
			holdTimer = 0;
		}
		
		super.update(elapsed);
		dropdown.update(elapsed);
	}
	
	public override function draw():Void {
		super.draw();
		dropdown.draw();
	}
	
	public function holdSing(anim:String, time:Float = 0):Void {
		holdSingTimer = Math.max(holdSingTimer, time);
		holdTimer = 0;
		
		playAnim(anim, true);
	}
	
	public override function destroy():Void {
		super.destroy();
		dropdown.destroy();
	}
}

typedef ToyHoldData = {
	var anim:String;
	var endBeat:Float;
	var startBeat:Float;
}

enum abstract ToySide(String) to String {
	var GF = 'gf';
	var PLAYER = 'player';
	var OPPONENT = 'opponent';
}