package psychlua;

import Type.ValueType;
import haxe.Constraints;

//
// Functions that use a high amount of Reflections, which are somewhat CPU intensive
// These functions are held together by duct tape
//

class ReflectionFunctions
{
	static final instanceStr:Dynamic = "##PSYCHLUA_STRINGTOOBJ";
	
	public static function implement() {
		FunkinLua.registerFunction("getPropertyFromClass", function(classVar:String, variable:String, allowMaps:Bool = false) {
			var cls:Dynamic = Type.resolveClass(classVar);
			if (cls == null) {
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, ERROR);
				return null;
			}
			
			return LuaUtils.getPropertyLoop(variable, allowMaps, cls);
		});
		FunkinLua.registerFunction("setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic, allowMaps:Bool = false, allowInstances:Bool = false) {
			var cls:Dynamic = Type.resolveClass(classVar);
			if (cls == null) {
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, ERROR);
				return null;
			}
			
			if (allowInstances) value = parseInstances(value);
			return LuaUtils.setPropertyLoop(variable, value, allowMaps, cls);
		});
		FunkinLua.registerFunction("callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic>) {
			return callMethodFromObject(Type.resolveClass(className), funcToRun, parseInstances(args ?? []));
		});

		FunkinLua.registerFunction("createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic>) {
			if (variableToSave.indexOf('.') > -1 || variableToSave.indexOf('[') > -1) {
				FunkinLua.luaTrace('createInstance: Variable name cannot contain dots or brackets, for "$variableToSave"', false, false, ERROR);
			} else if (MusicBeatState.getVariables().get(variableToSave) != null) {
				FunkinLua.luaTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, false, ERROR);
			} else {
				var myType:Class<Dynamic> = Type.resolveClass(className);
				
				if (myType == null) {
					FunkinLua.luaTrace('createInstance: Couldn\'t resolve class $className', false, false, ERROR);
					return null;
				}
				
				try {
					var obj:Dynamic = Type.createInstance(myType, parseInstances(args ?? []));
					MusicBeatState.getVariables().set(variableToSave, obj);
					return '$instanceStr::$variableToSave';
				} catch(e:Dynamic) {
					FunkinLua.luaTrace('createInstance: Failed to create $variableToSave - $e', false, false, ERROR);
				}
			}
			return null;
		});
		FunkinLua.registerFunction("instanceArg", function(instanceName:String, ?className:String) {
			var retStr:String = '$instanceStr::$instanceName';
			if (className != null) retStr += '::$className';
			return retStr;
		});
		
		FunkinLua.registerFunction('switchState', function(type:String, ?args:Array<Dynamic>) {
			var cls:Class<Dynamic> = Type.resolveClass(type);
			
			if (cls != null)
				return MusicBeatState.switchState(Type.createInstance(cls, parseInstances(args ?? [])));
			
			FunkinLua.luaTrace('switchState: Couldn\'t resolve class $type', false, false, ERROR);
		});
	}
	public static function implementLocal(funk:FunkinLua) {
		funk.addLocalCallback("getProperty", function(variable:String, allowMaps:Bool = false) {
			return LuaUtils.getPropertyLoop(variable, allowMaps, funk.parentState);
		});
		funk.addLocalCallback("setProperty", function(variable:String, value:Dynamic, allowMaps:Bool = false, allowInstances:Bool = false) {
			if (allowInstances) value = parseInstances(value);
			LuaUtils.setPropertyLoop(variable, value, allowMaps, funk.parentState);
		});
		funk.addLocalCallback("getPropertyFromGroup", function(group:String, index:Int, variable:String, allowMaps:Bool = false) {
			if (index < 0) {
				FunkinLua.luaTrace('getPropertyFromGroup: Index can\'t be negative!', false, false, ERROR);
				return null;
			}
			
			var groupOrArray:Dynamic = LuaUtils.getPropertyLoop(group, allowMaps, funk.parentState);
			
			if (groupOrArray != null) {
				if (groupOrArray.length != null) {
					if (index >= groupOrArray.length) {
						FunkinLua.luaTrace('getPropertyFromGroup: Index ($index) exceeds length of object $group!', false, false, ERROR);
						return null;
					}
				}
				if (groupOrArray is Array) {
					return LuaUtils.getPropertyLoop(variable, allowMaps, groupOrArray[index]);
				} else {
					return LuaUtils.getPropertyLoop(variable, allowMaps, Reflect.getProperty(groupOrArray, 'members')[index]);
				}
			} else {
				FunkinLua.luaTrace('getPropertyFromGroup: Object $group doesn\'t exist!', false, false, ERROR);
			}
			return null;
		});
		funk.addLocalCallback("setPropertyFromGroup", function(group:String, index:Int, variable:String, value:Dynamic, allowMaps:Bool = false, allowInstances:Bool = false) {
			if (index < 0) {
				FunkinLua.luaTrace('setPropertyFromGroup: Index can\'t be negative!', false, false, ERROR);
				return value;
			}
			
			var groupOrArray:Dynamic = LuaUtils.getPropertyLoop(group, allowMaps, funk.parentState);
			if (allowInstances) value = parseInstances(value);

			if (groupOrArray != null) {
				if (groupOrArray.length != null) {
					if (index >= groupOrArray.length) {
						FunkinLua.luaTrace('setPropertyFromGroup: Index ($index) exceeds length of object $group!', false, false, ERROR);
						return;
					}
				}
				if (groupOrArray is Array) {
					LuaUtils.setPropertyLoop(variable, value, allowMaps, groupOrArray[index]);
				} else {
					LuaUtils.setPropertyLoop(variable, value, allowMaps, Reflect.getProperty(groupOrArray, 'members')[index]);
				}
			} else {
				FunkinLua.luaTrace('setPropertyFromGroup: Object $group doesn\'t exist!', false, false, ERROR);
			}
		});
		funk.addLocalCallback("addToGroup", function(group:String, tag:String, index:Int = -1) {
			var obj:FlxSprite = LuaUtils.getPropertyLoop(tag, false, funk.parentState);
			if (obj == null || obj.destroy == null) {
				FunkinLua.luaTrace('addToGroup: Object $tag is not valid!', false, false, ERROR);
				return;
			}
			
			var groupOrArray:Dynamic = LuaUtils.getPropertyLoop(group, false, funk.parentState);
			if (groupOrArray == null) {
				FunkinLua.luaTrace('addToGroup: Group/Array $group is not valid!', false, false, ERROR);
				return;
			}
			
			if (index < 0) {
				switch (Type.typeof(groupOrArray)) {
					case TClass(Array): //Is Array
						groupOrArray.push(obj);

					default: //Is Group
						groupOrArray.add(obj);
				}
			} else {
				groupOrArray.insert(index, obj);
			}
		});
		funk.addLocalCallback("removeFromGroup", function(group:String, index:Int = -1, ?tag:String, destroy:Bool = true) {
			var obj:FlxSprite = null;
			if (tag != null) {
				obj = LuaUtils.getPropertyLoop(tag, false, funk.parentState);
				if (obj == null || obj.destroy == null) {
					FunkinLua.luaTrace('removeFromGroup: Object $tag is not valid!', false, false, ERROR);
					return;
				}
			}
			
			var groupOrArray:Dynamic = LuaUtils.getPropertyLoop(group, false, funk.parentState);
			if (groupOrArray == null) {
				FunkinLua.luaTrace('removeFromGroup: Group/Array $group is not valid!', false, false, ERROR);
				return;
			}
			
			switch (Type.typeof(groupOrArray)) {
				case TClass(Array): //Is Array
					if (obj != null) {
						groupOrArray.remove(obj);
						if (destroy) obj.destroy();
					} else {
						groupOrArray.remove(groupOrArray[index]);
					}

				default: //Is Group
					if (obj == null) obj = groupOrArray.members[index];
					groupOrArray.remove(obj, true);
					if (destroy) obj.destroy();
			}
		});
		funk.addLocalCallback("callMethod", function(funcToRun:String, args:Array<Dynamic>) {
			return callMethodFromObject(funk.parentState, funcToRun, parseInstances(args ?? []));
		});
		function addInstance(objectName:String, inFront:Bool = false) {
			var obj:Dynamic = (parseSingleInstance(objectName, true) ?? LuaUtils.getObjectDirectly(objectName));
			var instance = funk.parentState;
			
			if (obj != null) {
				if (inFront) {
					instance.add(obj);
				} else {
					var gameover = substates.GameOverSubstate.instance;
					var addToGameover:Bool = ((instance == PlayState.instance && PlayState.instance.isDead) || instance == gameover); // yea whatever bro
					
					if (instance != PlayState.instance || addToGameover) {
						if (addToGameover) {
							gameover.insert(gameover.members.indexOf(gameover.boyfriend), obj);
						} else {
							instance.insert(0, obj);
						}
					} else {
						var pos:Int = instance.members.indexOf(LuaUtils.getLowestCharacterGroup());
						if (pos < 0) pos = 0;
						
						instance.insert(pos, obj);
					}
				}
			} else {
				FunkinLua.luaTrace('addLuaSprite: Can\'t add what doesn\'t exist~ ($objectName)', false, false, ERROR);
			}
		}
		funk.addLocalCallback('addLuaSprite', addInstance);
		funk.addLocalCallback('addInstance', addInstance);
		
		funk.addLocalCallback('openSubstate', function(type:String, ?args:Array<Dynamic>) {
			var cls:Class<Dynamic> = Type.resolveClass(type);
			
			if (cls != null)
				return funk.parentState.openSubState(Type.createInstance(cls, parseInstances(args ?? [])));
			
			FunkinLua.luaTrace('openSubstate: Couldn\'t resolve class $type', false, false, ERROR);
		});
	}

	static function parseInstanceArray(arg:Array<Dynamic>) {
		return [for (v in arg) parseInstances(v)];
	}
	public static function parseInstances(arg:Dynamic):Dynamic {
		if (arg == null) return null;
		
		if (Std.isOfType(arg, Array)) {
			return parseInstanceArray(arg);
		} else {
			return parseSingleInstance(arg);
		}
	}
	public static function parseSingleInstance(arg:Dynamic, nullIfFake:Bool = false) {
		if (!Std.isOfType(arg, String)) return (nullIfFake ? null : arg);
		
		var argStr:String = cast arg;
		if (argStr.length > instanceStr.length) {
			var index:Int = argStr.indexOf('::');
			if (index > -1) {
				argStr = argStr.substring(index + 2);
				
				var lastIndex:Int = argStr.lastIndexOf('::');
				if (lastIndex > -1) {
					var id:String = argStr.substring(index + 2, lastIndex);
					var cls:Class<Dynamic> = Type.resolveClass(argStr.substring(lastIndex));
					
					return LuaUtils.getVariable(cls, id);
				} else {
					return LuaUtils.getObjectDirectly(argStr);
				}
			}
		}
		return (nullIfFake ? null : arg);
	}

	static function callMethodFromObject(object:Dynamic, funcStr:String, args:Array<Dynamic>) {
		var funcToRun:Dynamic = LuaUtils.getPropertyLoop(funcStr, false, object);
		
		return (funcToRun != null ? Reflect.callMethod(object, funcToRun, args) : null);
	}
}
