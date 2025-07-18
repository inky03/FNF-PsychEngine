package backend.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;
#end

class Defines {
	/**
	 * Mirrored from crowplexus.iris.macro.DefineMacro.hx to use in Lua
	 * 
	 * Based on CodenameCrew's DefinesMacro.hx
	 * Contains defined values in the source
	**/
	public static var list(get, never):Map<String, Dynamic>;
	
	static function get_list() {
		return getDefines();
	}
	
	#if macro
	public static macro function getDefines():Expr {
		return macro $v{#if display [] #else Context.getDefines() #end};
	}
	#else
	public static macro function getDefines():Expr;
	#end
}

#if macro
class ExtraDataMacro {
	/**
	 * Adds extraData to all sprites, and get/set/remove/hasVar methods
	**/
	
	static macro function build():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		fields = fields.concat([{
			pos: pos,
			name: 'extraData',
			access: [APublic],
			kind: FieldType.FProp('default', 'null', macro:Map<String, Dynamic>, macro $v{[]})
		}, {
			pos: pos,
			name: 'getVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Dynamic,
				args: [{type: macro:String, name: 'id'}],
				expr: macro { return extraData.get(id); }
			})
		}, {
			pos: pos,
			name: 'setVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Dynamic,
				args: [{type: macro:String, name: 'id'}, {type: macro:Dynamic, name: 'value'}],
				expr: macro { extraData.set(id, value); return value; }
			})
		}, {
			pos: pos,
			name: 'removeVar',
			access: [APublic],
			kind: FieldType.FFun({
				args: [{type: macro:String, name: 'id'}],
				expr: macro { extraData.remove(id); }
			})
		}, {
			pos: pos,
			name: 'hasVar',
			access: [APublic],
			kind: FieldType.FFun({
				ret: macro:Bool,
				args: [{type: macro:String, name: 'id'}],
				expr: macro { return extraData.exists(id); }
			})
		}]);
		
		return fields;
	}
}
#end