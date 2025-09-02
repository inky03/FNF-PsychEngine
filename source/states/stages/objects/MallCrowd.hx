package states.stages.objects;

class MallCrowd extends BGSprite
{
	public var canCheer:Bool;
	public var heyTimer:Float = 0;
	public function new(x:Float = 0, y:Float = 0, sprite:String = 'christmas/bottomBop', idle:String = 'Bottom Level Boppers Idle', hey:String = 'Bottom Level Boppers HEY', cheer:Bool = true)
	{
		super(sprite, x, y, 0.9, 0.9, [idle]);
		if (cheer) animation.addByPrefix('hey', hey, 24, false);
		antialiasing = ClientPrefs.data.antialiasing;
		canCheer = cheer;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (heyTimer > 0) {
			heyTimer -= elapsed;
			if(heyTimer <= 0) {
				dance(true);
				heyTimer = 0;
			}
		}
	}

	override function dance(?forceplay:Bool = false)
	{
		if (canCheer && heyTimer > 0) return;
		super.dance(forceplay);
	}
}