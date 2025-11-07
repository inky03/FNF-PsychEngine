package backend;

import openfl.utils.Assets;

class JSFileSystem {
	public static inline function exists(path:String):Bool {
		return Assets.exists(path);
	}
	
	public static inline function rename(path:String, newPath:String):Void {
		throw 'FileSystem.rename unsupported in this platform';
	}
	
	public static inline function stat(path:String):Void {
		throw 'FileSystem.stat unsupported in this platform';
	}
	
	public static inline function createDirectory(path:String):Void {
		throw 'FileSystem.createDirectory unsupported in this platform';
	}
	
	public static inline function deleteFile(path:String):Void {
		throw 'FileSystem.deleteFile unsupported in this platform';
	}
	
	public static inline function deleteDirectory(path:String):Void {
		throw 'FileSystem.deleteDirectory unsupported in this platform';
	}
	
	public static inline function fullPath(relPath:String):String {
		return relPath;
	}
	
	public static inline function absolutePath(relPath:String):String {
		return relPath;
	}
	
	public static inline function isDirectory(path:String):Bool {
		return false; // TODO
	}
	
	public static inline function readDirectory(path:String):Array<String> {
		return []; // TODO
	}
}