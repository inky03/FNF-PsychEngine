package backend;

import openfl.utils.Assets;

import haxe.Json;

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	available:Array<String>,
	all:Array<String>
};

class Mods
{
	static public var currentModDirectory:String = '';
	public static final ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];

	public static var globalMods:Array<String> = [];

	inline public static function getGlobalMods()
		return globalMods;

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		for (mod in parseList().enabled) {
			var pack:Dynamic = getPack(mod);
			if (pack != null && pack.runsGlobally) globalMods.push(mod);
		}
		return globalMods;
	}

	inline public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		
		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();
		
		if (FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				if (directoryIsMod(folder))
					list.push(folder);
			}
		}
		#end
		
		return list;
	}
	
	inline public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if(paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		var foldersToCheck:Array<String> = [];
		//Main folder
		#if sys
		if (FileSystem.exists(path + fileToFind))
		#else
		if (Assets.exists(path + fileToFind))
		#end
			foldersToCheck.push(path + fileToFind);

		// Week folder
		if(Paths.currentLevel != null && Paths.currentLevel != path)
		{
			var pth:String = Paths.getFolderPath(fileToFind, Paths.currentLevel);
			if(!foldersToCheck.contains(pth) && FileSystem.exists(pth))
				foldersToCheck.push(pth);
		}

		#if MODS_ALLOWED
		if(mods)
		{
			// Global mods first
			for(mod in Mods.getGlobalMods())
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			// Then "PsychEngine/mods/" main folder
			var folder:String = Paths.mods(fileToFind);
			if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(Paths.mods(fileToFind));

			// And lastly, the loaded mod's folder
			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				var folder:String = Paths.mods(Mods.currentModDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = Paths.getTextFromFile(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		return null;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList {
		var list:ModsList = {enabled: [], disabled: [], all: [], available: []};
		
		#if MODS_ALLOWED
		#if sys if (FileSystem.exists('modsList.txt')) {
			try {
				for (mod in CoolUtil.coolTextFile('modsList.txt')) {
					if (mod.trim().length < 1) continue;
					
					var dat = mod.split('|');
					var folder:String = dat[0];
					var modEnabled:Bool = (dat[1] == '1');
					
					list.all.push(folder);
					(modEnabled ? list.enabled : list.disabled).push(folder);
					if (directoryIsMod(folder)) list.available.push(folder);
					
					ClientPrefs.modsEnabled.set(folder, modEnabled);
				}
			} catch(e) {
				trace(e);
				
				FileSystem.deleteFile('modsList.txt');
			}
		} else #end {
			for (mod => enabled in ClientPrefs.modsEnabled) {
				list.all.push(mod);
				(enabled ? list.enabled : list.disabled).push(mod);
				if (directoryIsMod(mod)) list.available.push(mod);
			}
		}
		#end
		
		if (!updatedOnState) updateModList(list);
		
		return list;
	}
	
	public static function updateModList(?list:ModsList) {
		#if MODS_ALLOWED
		var list:ModsList = (list ?? parseList());
		
		for (folder in getModDirectories()) {
			if (!list.all.contains(folder) && directoryIsMod(folder)) {
				list.all.push(folder);
				list.enabled.push(folder);
				list.available.push(folder);
				
				ClientPrefs.modsEnabled.set(folder, true);
			}
		}
		
		#if sys
		var content:String = '';
		for (mod in list.available)
			content += '$mod|${list.enabled.contains(mod) ? 1 : 0}\n';
		
		File.saveContent('modsList.txt', content);
		#end
		
		updatedOnState = true;
		#end
	}
	
	private static function directoryIsMod(dir:String):Bool {
		if (dir.trim().length == 0 || ignoreModFolders.contains(dir.toLowerCase())) return false;
		
		dir = Paths.mods(dir);
		
		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
			if (FileSystem.exists('$dir/.notamod'))
				return false;
			
			for (sub in ignoreModFolders) {
				if (FileSystem.exists('$dir/$sub'))
					return true;
			}
		}
		
		return false;
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';
		
		#if MODS_ALLOWED
		var list:ModsList = Mods.parseList();
		
		for (mod in list.available) {
			if (list.enabled.contains(mod)) {
				Mods.currentModDirectory = mod;
				return;
			}
		}
		#end
	}
}