package states.editors.content;

import objects.Note;
import shaders.RGBPalette;
import flixel.util.FlxDestroyUtil;
import states.editors.ChartingState;

@:access(states.editors.ChartingState)
class MetaNote extends Note
{
	public static var noteTypeTexts:Map<Int, FlxText> = [];
	public var isEvent:Bool = false;
	public var songData:Array<Dynamic>;
	public var downScroll:Bool = false;
	public var sustainSprite:EditorSustain;
	public var chartY:Float = 0;
	public var chartNoteData:Int = 0;
	public var chartingState:ChartingState;
	public var useBlandSustains(default, set):Bool = false;

	public function new(time:Float, data:Int, songData:Array<Dynamic>, state:ChartingState)
	{
		super(time, data, null, false, true);
		this.chartingState = state;
		this.songData = songData;
		this.strumTime = time;
		this.chartNoteData = data;
	}
	
	public override function reloadNote(tex:String = '', postfix:String = '') {
		super.reloadNote(tex, postfix);
		if (sustainSprite != null)
			sustainSprite.reloadNote(tex, postfix);
	}
	public function changeNoteData(v:Int)
	{
		this.chartNoteData = v; //despite being so arbitrary its sadly needed to fix a bug on moving notes
		this.songData[1] = v;
		this.noteData = v % ChartingState.GRID_COLUMNS_PER_PLAYER;
		this.mustPress = (v < ChartingState.GRID_COLUMNS_PER_PLAYER);
		
		if(!PlayState.isPixelStage)
			loadNoteAnims();
		else
			loadPixelNoteAnims();

		if(Note.globalRgbShaders.contains(rgbShader.parent)) //Is using a default shader
			rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(noteData));

		animation.play(Note.colArray[this.noteData % Note.colArray.length] + 'Scroll');
		updateHitbox();
		if(width > height)
			setGraphicSize(ChartingState.GRID_SIZE);
		else
			setGraphicSize(0, ChartingState.GRID_SIZE);

		updateHitbox();
		if (sustainSprite != null)
			sustainSprite.changeNoteData(this.noteData);
	}
	
	override function set_noteType(value:String):String {
		if (noteType == value) return value;
		
		songData[3] = value;
		hitsoundChartEditor = true;
		gfNote = ignoreNote = false;
		
		super.set_noteType(value);
		
		if (noteType == null || noteType == '') {
			if (_noteTypeText != null) _noteTypeText.visible = false;
		} else {
			var txt:FlxText = findNoteTypeText(value != null ? chartingState.noteTypes.indexOf(value) : 0);
			if (txt != null) txt.visible = chartingState.showNoteTypeLabels;
		}
		
		return noteType = value;
	}

	public function setStrumTime(v:Float)
	{
		this.songData[0] = v;
		this.strumTime = v;
	}

	var _lastZoom:Float = -1;
	public function setSustainLength(newLength:Float, zoom:Float = 1)
	{
		_lastZoom = zoom;
		songData[2] = sustainLength = Math.max(newLength, 0);

		if(sustainLength > 0)
		{
			if(sustainSprite == null)
			{
				sustainSprite = new EditorSustain(noteData);//new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
				sustainSprite.scrollFactor.x = 0;
			}
			sustainSprite.sustainHeight = Math.max((Conductor.getStep(strumTime + newLength) - Conductor.getStep(strumTime)) * ChartingState.GRID_SIZE * zoom - ChartingState.GRID_SIZE * .5, 0);
			sustainSprite.useBlandSustains = useBlandSustains;
			sustainSprite.updateHitbox();
		}
	}

	public var hasSustain(get, never):Bool;
	function get_hasSustain() return (!isEvent && sustainLength > 0);

	public function updateSustainToZoom(zoom:Float = 1)
	{
		if(_lastZoom == zoom) return;
		setSustainLength(sustainLength, zoom);
	}
	
	var _noteTypeText:FlxText;
	public function findNoteTypeText(num:Int)
	{
		var txt:FlxText = null;
		if(num != 0)
		{
			if(!noteTypeTexts.exists(num))
			{
				txt = new FlxText(0, 0, ChartingState.GRID_SIZE, (num > 0) ? Std.string(num) : '?', 16);
				txt.autoSize = false;
				txt.alignment = CENTER;
				txt.borderStyle = SHADOW;
				txt.shadowOffset.set(2, 2);
				txt.borderColor = FlxColor.BLACK;
				txt.scrollFactor.x = 0;
				noteTypeTexts.set(num, txt);
			}
			else txt = noteTypeTexts.get(num);
		}
		return (_noteTypeText = txt);
	}

	override function draw()
	{
		if(sustainSprite != null && sustainSprite.exists && sustainSprite.visible && sustainLength > 0)
		{
			if (sustainSprite.shader != shader) sustainSprite.shader = shader;
			sustainSprite.setColorTransform(colorTransform.redMultiplier, sustainSprite.colorTransform.blueMultiplier, colorTransform.redMultiplier);
			sustainSprite.scale.copyFrom(this.scale);
			sustainSprite.updateHitbox();
			sustainSprite.y = this.y + this.height / 2 - (downScroll ? sustainSprite.sustainHeight : 0);
			sustainSprite.x = this.x + (this.width - sustainSprite.width) / 2;
			sustainSprite.downScroll = downScroll;
			sustainSprite.alpha = this.alpha;
			sustainSprite.draw();
		}
		super.draw();

		if(_noteTypeText != null && _noteTypeText.exists && _noteTypeText.visible)
		{
			_noteTypeText.x = this.x + this.width/2 - _noteTypeText.width/2;
			_noteTypeText.y = this.y + this.height/2 - _noteTypeText.height/2;
			_noteTypeText.alpha = this.alpha;
			_noteTypeText.draw();
		}
	}
	
	function set_useBlandSustains(value:Bool):Bool {
		if (sustainSprite != null)
			sustainSprite.useBlandSustains = value;
		return useBlandSustains = value;
	}

	override function destroy()
	{
		sustainSprite = FlxDestroyUtil.destroy(sustainSprite);
		super.destroy();
	}
}

class EditorSustain extends Note {
	var sustainTile:FlxSprite;
	var basicSustainTile:FlxSprite;
	public var downScroll:Bool = false;
	public var sustainHeight:Float = 0;
	public var useBlandSustains:Bool = false;
	
	public function new(data:Int) {
		basicSustainTile = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		sustainTile = new FlxSprite();
		sustainTile.scrollFactor.x = 0;
		clipRect = new flixel.math.FlxRect(0, 0);
		sustainTile.clipRect = new flixel.math.FlxRect();
		
		super(0, data, null, true, true);
		
		animation.play(Note.colArray[noteData] + 'holdend');
		scale.set(scale.x, scale.x);
		updateHitbox();
		flipY = false;
	}
	override function update(elapsed:Float) {
		sustainTile.update(elapsed);
		super.update(elapsed);
	}
	override function draw() {
		if (!visible) return;
		
		if (useBlandSustains) {
			basicSustainTile.scale.set(8, sustainHeight);
			basicSustainTile.updateHitbox();
			basicSustainTile.alpha = alpha;
			basicSustainTile.setPosition(x + (width - basicSustainTile.width) * .5, y);
			basicSustainTile.draw();
		} else {
			var tileY:Float = (downScroll ? 0 : sustainHeight - height);
			flipY = sustainTile.flipY = downScroll;
			
			if (sustainTile.shader != shader) sustainTile.shader = shader;
			sustainTile.setColorTransform(colorTransform.redMultiplier, colorTransform.blueMultiplier, colorTransform.redMultiplier);
			sustainTile.scale.copyFrom(scale);
			sustainTile.updateHitbox();
			sustainTile.alpha = alpha;
			
			if (scale.y <= 0) return;
			
			sustainTile.clipRect.set(0, 1, sustainTile.frameWidth, sustainTile.frameHeight - 2);
			sustainTile.clipRect = sustainTile.clipRect;
			clipRect.set(0, 0, frameWidth, frameHeight);
			clipRect = clipRect;
			var stop:Bool = false;
			
			if (downScroll) {
				function clipTile(tile:FlxSprite, y:Float) {
					if (tileY + tile.height >= sustainHeight) {
						var clip:Float = (tileY + tile.height - sustainHeight) / tile.scale.y + 1;
						tile.clipRect.set(0, clip, tile.frameWidth, tile.frameHeight - clip);
						tile.clipRect = tile.clipRect;
						stop = true;
					}
				}
				
				clipTile(this, 0);
				super.draw();
				tileY += height - scale.y;
				
				while (tileY < sustainHeight) {
					clipTile(sustainTile, tileY);
					
					sustainTile.setPosition(this.x, y + tileY);
					sustainTile.draw();
					
					if (stop) break;
					
					tileY += sustainTile.clipRect.height * sustainTile.scale.y;
				}
			} else {
				function clipTile(tile:FlxSprite, y:Float) {
					if (tileY <= 0) {
						var clip:Float = -tileY / tile.scale.y + 1;
						tile.clipRect.set(0, clip, tile.frameWidth, tile.frameHeight - clip);
						tile.clipRect = tile.clipRect;
						stop = true;
					}
				}
				
				y += tileY;
				clipTile(this, sustainHeight);
				super.draw();
				y -= tileY;
				tileY -= scale.y;
				
				while (tileY > 0) {
					tileY -= sustainTile.clipRect.height * sustainTile.scale.y;
					clipTile(sustainTile, tileY);
					
					sustainTile.setPosition(this.x, y + tileY);
					sustainTile.draw();
					
					if (stop) break;
				}
			}
		}
	}
	
	public function reloadSustainTile() {
		sustainTile.frames = frames;
		sustainTile.antialiasing = antialiasing;
		sustainTile.animation.copyFrom(animation);
		sustainTile.animation.play(Note.colArray[this.noteData % Note.colArray.length] + 'hold');
		sustainTile.clipRect = new flixel.math.FlxRect(0, 1, sustainTile.frameWidth, 1);
	}
	public function changeNoteData(v:Int) {
		this.noteData = v;
		
		if (!PlayState.isPixelStage)
			loadNoteAnims();
		else
			loadPixelNoteAnims();
		
		reloadSustainTile();
		animation.play(Note.colArray[this.noteData % Note.colArray.length] + 'holdend');
	}
	public override function reloadNote(tex:String = '', postfix:String = '') {
		super.reloadNote(tex, postfix);
		reloadSustainTile();
	}
}

class EventMetaNote extends MetaNote
{
	public var eventText:FlxText;
	public function new(time:Float, eventData:Dynamic, state:ChartingState)
	{
		super(time, -1, eventData, state);
		this.isEvent = true;
		events = eventData[1];
		//trace('events: $events');
		
		loadGraphic(Paths.image('editors/eventIcon'));
		setGraphicSize(ChartingState.GRID_SIZE);
		updateHitbox();

		eventText = new FlxText(0, 0, 400, '', 12);
		eventText.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.WHITE, RIGHT);
		eventText.scrollFactor.x = 0;
		updateEventText();
	}
	
	override function draw()
	{
		if(eventText != null && eventText.exists && eventText.visible)
		{
			eventText.y = this.y + this.height/2 - eventText.height/2;
			eventText.alpha = this.alpha;
			eventText.draw();
		}
		super.draw();
	}

	override function setSustainLength(newLength:Float, zoom:Float = 1) {}
	public override function updateSustainToZoom(zoom:Float = 1) {}

	public var events:Array<Array<String>>;
	public function updateEventText()
	{
		var myTime:Float = Math.floor(this.strumTime);
		if(events.length == 1)
		{
			var event = events[0];
			eventText.text = 'Event: ${event[0]} ($myTime ms)\nValue 1: ${event[1]}\nValue 2: ${event[2]}';
		}
		else if(events.length > 1)
		{
			var eventNames:Array<String> = [for (event in events) event[0]];
			eventText.text = '${events.length} Events ($myTime ms):\n${eventNames.join(', ')}';
		}
		else eventText.text = 'ERROR FAILSAFE';
	}

	override function destroy()
	{
		eventText = FlxDestroyUtil.destroy(eventText);
		super.destroy();
	}
}
