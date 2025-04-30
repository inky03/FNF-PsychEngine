package debug;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

class ScriptTraceDisplay extends Sprite {
	public var texts:Array<TracePopUp> = [];
	public var borderPadding:Float = 10;
	public var textPadding:Float = 2;
	
	public function new() {
		super();
	}
	
	public override function __enterFrame(dt:Float) {
		for (text in texts)
			text.update(dt);
	}
	
	public function print(text:String, color:FlxColor = FlxColor.WHITE, size:Int = 15):TracePopUp {
		var popUp:TracePopUp = null;
		for (text in texts) {
			if (!text.visible) {
				popUp = text;
				break;
			}
		}
		popUp ??= new TracePopUp();
		
		popUp.format.color = color.rgb;
		popUp.format.size = size;
		popUp.visible = true;
		popUp.aliveTime = 0;
		popUp.text = text;
		popUp.alpha = 1;
		
		popUp.defaultTextFormat = popUp.format;
		popUp.hei = popUp.textHeight;
		
		texts.remove(popUp);
		texts.insert(0, popUp);
		
		if (!contains(popUp))
			addChild(popUp);
		
		updateTextsPosition();
		
		Sys.println(text);
		
		return popUp;
	}
	
	public function updateTextsPosition():Void {
		var yy:Float = borderPadding;
		for (text in texts) {
			if (text.visible) {
				if (yy + text.hei - borderPadding > FlxG.stage.window.height) {
					text.aliveTime = 99999;
					text.visible = false;
					break;
				}
				
				text.updateWidth();
				text.y = yy;
				text.x = borderPadding;
				yy += text.hei + textPadding;
			}
		}
	}
}

class TracePopUp extends TextField {
	static var defaultShader:SimpleOutlineShader;
	
	public var format:TextFormat = new TextFormat(Paths.font('vcr.ttf'));
	public var aliveTime:Float = 0;
	public var curWidth:Float = 0;
	public var hei:Float = 0;
	
	public function new() {
		super();
		
		defaultTextFormat = format;
		format.letterSpacing = -.5;
		format.leading = -2;
		multiline = true;
		autoSize = LEFT;
		
		defaultShader ??= new SimpleOutlineShader();
		shader = defaultShader;
	}
	
	public function update(dt:Float) {
		if (!visible) return;
		
		aliveTime += dt;
		
		if (aliveTime >= 5000) {
			if (aliveTime < 5000 + 2000) {
				alpha = 1 - (aliveTime - 5000) / 2000;
			} else {
				visible = false;
			}
		}
		
		updateWidth();
	}
	
	public function updateWidth():Void {
		var targetWidth:Float = FlxG.stage.window.width - x * 2;
		if (curWidth != targetWidth)
			curWidth = width = targetWidth;
	}
}

class SimpleOutlineShader extends openfl.display.GraphicsShader {
	@:glFragmentSource('
		#pragma header
		
		void main() {
			vec2 step = .75 / openfl_TextureSize;
			vec4 outline = texture2D(bitmap, openfl_TextureCoordv);
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(step.x, 0.)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(-step.x, 0.)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(0., step.y)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(0., -step.y)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(step.x, step.y)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(-step.x, step.y)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(step.x, -step.y)).a;
			outline.a += texture2D(bitmap, openfl_TextureCoordv + vec2(-step.x, -step.y)).a;
			outline.a = min(outline.a, 1.);
			
			gl_FragColor = outline * openfl_Alphav;
		}
	')
	
	public function new() {
		super();
	}
}