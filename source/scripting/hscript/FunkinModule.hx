package scripting.hscript;

import insanity.backend.Expr;
import insanity.backend.types.Scripted;

import scripting.hscript.FunkinHscript;

@:access(insanity.backend.Parser)
@:access(insanity.backend.Interp)
class FunkinModule extends insanity.Module {
	public var hash:String;
	
	public override function parse(string:String):Array<ModuleDecl> {
		var types:Array<ModuleDecl> = super.parse(string);
		hash = haxe.crypto.Sha256.encode(string);
		
		for (type in types) {
			if (type is InsanityScriptedClass) {
				var cls:InsanityScriptedClass = cast type;
				
				cls.safe = true;
				cls.onInstanceError = function(e:Dynamic, fun:String, ?instance:IInsanityScripted) {
					var pos:HScriptInfos = cast interp.posInfos();
					pos.funcName = fun;
					
					FunkinHscript.log(Std.string(e), pos, ERROR);
				}
			}
		}
		
		return types;
	}
	
	public override dynamic function onProgramError(e:haxe.Exception):Void {
		FunkinHscript.log(Std.string(e), interp.posInfos(), FATAL);
	}
	public override dynamic function onParsingError(e:haxe.Exception):Void {
		FunkinHscript.log(Std.string(e), cast {fileName: path, lineNumber: parser.line}, FATAL);
	}
	public override dynamic function onTypeError(e:haxe.Exception, type:IInsanityType):Void {
		FunkinHscript.log(Std.string(e), cast {fileName: type.path, showLine: false}, FATAL);
	}
}

@:access(insanity.backend.Parser)
@:access(insanity.backend.Interp)
class FunkinImportModule extends insanity.ImportModule {
	public override dynamic function onProgramError(e:haxe.Exception):Void {
		FunkinHscript.log(Std.string(e), interp.posInfos(), FATAL);
	}
	public override dynamic function onParsingError(e:haxe.Exception):Void {
		FunkinHscript.log(Std.string(e), cast {fileName: name, lineNumber: parser.line}, FATAL);
	}
}