package scripting;

interface FunkinScript {
	public var parentState:flixel.FlxState;
	
	public function call(func:String, ?args:Array<Dynamic>):Any;
	
	public function exists(field:String):Bool;
	public function get(field:String):Dynamic;
	public function set(field:String, v:Dynamic):Dynamic;
}