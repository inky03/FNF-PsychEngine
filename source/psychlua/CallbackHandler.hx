#if LUA_ALLOWED
package psychlua;

class CallbackHandler {
	public static inline function call(l:State, fname:String):Int {
		try {
			var cbf:Dynamic = Lua_helper.callbacks.get(fname);
			
			if (cbf == null) {
				var last:FunkinLua = FunkinLua.lastCalledScript;
				
				if ((last == null || last.lua != l) && FlxG.state is ScriptedSubState) {
					var st:ScriptedSubState = cast FlxG.state;
					for (script in st.luaArray) {
						if (script != FunkinLua.lastCalledScript && script != null && script.lua == l) {
							cbf = script.callbacks.get(fname);
							break;
						}
					}
				} else {
					cbf = last.callbacks.get(fname);
				}
			}
			
			if (cbf == null) return 0;
			
			var args:Array<Dynamic> = [for (i in 0 ... Lua.gettop(l) /* number of params */) Convert.fromLua(l, i + 1)];
			var ret:Dynamic = Reflect.callMethod(null, cbf, args);
			
			Convert.toLua(l, ret);
			return 1;
		} catch (e:haxe.Exception) {
			if (Lua_helper.sendErrorsToLua) {
				LuaL.error(l, 'Callback ${e.details()}');
				return 0;
			}
			throw e;
		}
		return 0;
	}
}
#end