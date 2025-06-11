package shaders;

import flixel.system.FlxAssets.FlxShader;
import flixel.addons.display.FlxRuntimeShader;
import lime.graphics.opengl.GLProgram;
import lime.app.Application;

import psychlua.LuaUtils;

class ErrorHandledShader extends FlxShader implements IErrorHandler
{
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}
	public function new(?shaderName:String)
	{
		this.shaderName = shaderName;
		super();
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
	
	public static function crashSave(shaderName:String, error:Dynamic, onError:Dynamic) // prevent the app from dying immediately
	{
		if(shaderName == null) shaderName = 'unnamed';
		var alertTitle:String = 'Error on Shader: "$shaderName"';

		#if !debug
		// Save a crash log on Release builds
		var errMsg:String = "";
		var dateNow:String = Date.now().toString().replace(" ", "_").replace(":", "'");

		if (!FileSystem.exists('./crash/'))
			FileSystem.createDirectory('./crash/');

		var crashLogPath:String = './crash/shader_${shaderName}_${dateNow}.txt';
		File.saveContent(crashLogPath, error);
		Log.print('$alertTitle\nError log saved at: $crashLogPath', FATAL);
		#else
		Log.print('$alertTitle\nError logs aren\'t created on debug builds, check the trace log instead!', FATAL);
		#end

		// Sys.println(error);

		onError(error);
	}
}

class ErrorHandledRuntimeShader extends FlxRuntimeShader implements IErrorHandler
{
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}
	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String)
	{
		this.shaderName = shaderName;
		super(fragmentSource, vertexSource);
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
}

interface IErrorHandler
{
	public var shaderName:String;
	public dynamic function onError(error:Dynamic):Void;
}