package scripting.hscript;

#if HSCRIPT_SCRIPTED_CLASSES

import insanity.tools.Tools;

import scripting.hscript.FunkinModule;

using Lambda;

typedef PackageInfo = {
	var subPackages:Array<PackageInfo>;
	var modules:Array<ModuleInfo>;
	var ?importModule:ModuleInfo;
	var path:Array<String>;
}
typedef ModuleInfo = {
	var path:String;
	var name:String;
	var ?importModule:Bool;
}

class FunkinModuleCollection extends insanity.Environment {
	public static var instance:FunkinModuleCollection = new FunkinModuleCollection();
	
	public static function refresh(hard:Bool = false):Void {
		var low:PackageInfo = { subPackages: [], modules: [], path: [] };
		var tracked:Array<String> = [];
		
		var removed:Int = 0, added:Int = 0, changed:Int = 0, total:Int = 0;
		
		function readModules(dir:String, pack:PackageInfo) {
			for (file in FileSystem.readDirectory(dir)) {
				var path:String = '$dir/$file';
				
				if (FileSystem.isDirectory(file)) {
					var newPath:Array<String> = pack.path.copy(); newPath.push(file);
					
					pack.subPackages.push(readModules(path, { subPackages: [], modules: [], path: newPath }));
				} else if (file.endsWith('.hx')) {
					var name:String = file.replace('.hx', '');
					if (name == 'import') {
						if (pack.importModule != null) {
							pack.importModule.path = path;
						} else {
							pack.importModule = { path: path, name: name };
						}
					} else if ((~/^[A-Z_]?[a-zA-Z0-9_]+/).match(name)) {
						var foundModule:ModuleInfo = pack.modules.find(function(info:ModuleInfo) return (info.name == name));
						
						if (foundModule != null) { // allows module shadowing and stuff
							foundModule.path = path;
						} else {
							pack.modules.push({ path: path, name: name });
						}
					} else {
						Log.print('Invalid module identifier: $name', WARN);
					}
				}
			}
			
			return pack;
		}
		
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/modules'))
			readModules(folder, low);
		
		function loadModules(pack:PackageInfo, ?importModules:Array<FunkinImportModule>) {
			importModules ??= [];
			
			var modules:Array<FunkinModule> = [];
			
			if (pack.importModule != null) {
				var mod:ModuleInfo = pack.importModule;
				importModules.push(new FunkinImportModule(File.getContent(mod.path), mod.path));
			}
			
			for (mod in pack.modules) {
				var path:String = Tools.pathToString(mod.name, pack.path);
				var string:String = File.getContent(mod.path);
				
				if (!tracked.contains(path))
					tracked.push(path);
				
				if (instance.modules.exists(path)) {
					if (!hard && cast(instance.modules.get(path), FunkinModule).hash == haxe.crypto.Sha256.encode(string)) {
						continue;
					} else {
						changed ++;
					}
				} else {
					added ++;
				}
				
				var module:FunkinModule = new FunkinModule(string, mod.name, pack.path, mod.path);
				module.importModules = cast importModules;
				
				instance.modules.set(module.path, module);
				modules.push(module);
			}
			
			for (module in modules) {
				if (!module.types.exists(module.path)) continue;
				var main = module.types.get(module.path);
				
				for (module in modules)
					module.interp.imports.set(main.name, main);
			}
			
			for (pack in pack.subPackages)
				loadModules(pack, importModules.copy());
		}
		
		loadModules(low);
		
		for (mod => _ in instance.modules) {
			if (!tracked.contains(mod)) {
				instance.modules.remove(mod);
				removed ++;
			}
		}
		
		total = instance.modules.count();
		
		instance.rebuildTypes();
		instance.start();
		
		// trace('$total modules (added $added, reloaded $changed, removed $removed)');
	}
}

#else

class FunkinModuleCollection {
	public static var instance:Dynamic = null;
	
	public static function refresh(hard:Bool = false):Void {}
}

#end