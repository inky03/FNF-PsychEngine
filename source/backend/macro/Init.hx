#if macro
package backend.macro;

import haxe.macro.Context;
import haxe.macro.Compiler;

class Init {
	public static function includeClasses():Void {
		Compiler.include('flixel', true, ['flixel.addons.nape', 'flixel.addons.editors.spine', 'flixel.system.macros']);
		Compiler.include('haxe', true, ['haxe.atomic', 'haxe.macro']);
		Compiler.include('shaders', true);
		
		if (Context.defined('sys') && Context.defined('SCRIPTS_ALLOWED')) {
			if (Context.defined('hl')) {
				Compiler.include('sys', true, ['sys.db', 'sys.ssl', 'sys.net']);
			} else {
				Compiler.include('sys', true);
			}
		}
		
		if (Context.defined('HSCRIPT_ALLOWED'))
			Compiler.addMetadata('@:build(psychlua.HScript.HScriptMacro.buildInterp())', 'crowplexus.hscript.Interp');
	}
	
	public static function init():Void {
		Compiler.addMetadata('@:build(backend.macro.Scripting.ExtraDataMacro.build())', 'flixel.FlxBasic');
		Compiler.addMetadata('@:build(backend.macro.Flixel.FlixelMacro.buildFlxText())', 'flixel.text.FlxText');
	}
}
#end