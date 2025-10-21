package backend.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

class FlixelMacro {
	/**
	 * un-implement FlxText feature introduced in 6.1.1
	**/
	
	static macro function buildFlxText():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		for (field in fields) {
			if (field.name == 'set_antialiasing')
				fields.remove(field);
		}
		
		return fields;
		
		// ummm yeah,  thats all
	}
}
#end