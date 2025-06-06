package states.editors.content;

class Toy extends objects.Character {
	public var holdSingTimer:Float = 0;
	
	public override function update(elapsed:Float):Void {
		if (holdSingTimer > 0) {
			holdSingTimer -= elapsed;
			
			if (holdSingTimer <= 0)
				holdSingTimer = 0;
			
			holdTimer = 0;
		}
		
		super.update(elapsed);
	}
	
	public function holdSing(anim:String, time:Float = 0):Void {
		holdSingTimer = Math.max(holdSingTimer, time);
		holdTimer = 0;
		
		playAnim(anim, true);
	}
}