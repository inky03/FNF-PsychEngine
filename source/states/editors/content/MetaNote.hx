package states.editors.content;

import objects.Note;
import shaders.RGBPalette;
import flixel.util.FlxDestroyUtil;
import states.editors.ChartingState;

@:access(states.editors.ChartingState)
class MetaNote extends Note
{
	public static var noteTypeTexts:Map<Int, FlxText> = [];
	public var isEvent(default, null):Bool = false;
	public var songData:Array<Dynamic>;
	public var downScroll:Bool = false;
	public var sustainSprite:EditorSustain;
	public var chartY:Float = 0;
	public var chartNoteData:Int = 0;
	public var chartingState:ChartingState;
	public var useBlandSustains(default, set):Bool = false;
	
	public var dragging:Bool = false;

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
				txt.borderColor = FlxColor.BLACK;
				txt.borderStyle = SHADOW_XY(2, 2);
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
			sustainSprite.setColorTransform();
			sustainSprite.colorTransform.concat(colorTransform);
			sustainSprite.scale.copyFrom(this.scale);
			sustainSprite.updateHitbox();
			sustainSprite.y = this.y + this.height / 2 - (downScroll ? sustainSprite.sustainHeight : 0);
			sustainSprite.x = this.x + (this.width - sustainSprite.width) / 2;
			sustainSprite.downScroll = downScroll;
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
			basicSustainTile.setColorTransform();
			basicSustainTile.colorTransform.concat(colorTransform);
			basicSustainTile.scale.set(8, sustainHeight);
			basicSustainTile.updateHitbox();
			basicSustainTile.alpha = alpha;
			basicSustainTile.setPosition(x + (width - basicSustainTile.width) * .5, y);
			basicSustainTile.draw();
		} else {
			var tileY:Float = (downScroll ? 0 : sustainHeight - height);
			flipY = sustainTile.flipY = downScroll;
			
			if (sustainTile.shader != shader) sustainTile.shader = shader;
			sustainTile.setColorTransform();
			sustainTile.colorTransform.concat(colorTransform);
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

@:access(states.editors.ChartingState)
class EventMetaNote extends MetaNote
{
	public var events:Array<Array<String>>;
	public var eventText:FlxText;
	public var gui:EventNoteGui;
	
	public function new(time:Float, eventData:Dynamic, state:ChartingState)
	{
		super(time, -1, eventData, state);
		this.isEvent = true;
		events = eventData[1];
		
		loadGraphic(Paths.image('events/default'));
		setGraphicSize(ChartingState.GRID_SIZE);
		updateHitbox();
		
		eventText = new FlxText(0, 0, width, '', 12);
		eventText.setFormat(eventText.font, 12, FlxColor.WHITE, CENTER, SHADOW_XY(2, 2), FlxColor.BLACK);
		eventText.scrollFactor.x = 0;
		
		gui = new EventNoteGui(this);
		updateEventInfo();
	}
	public override function update(elapsed:Float):Void {
		super.update(elapsed);
		gui.update(elapsed);
	}
	public override function draw():Void {
		super.draw();
		
		if (!ChartingState.instance.lockedEvents) {
			gui.updateHover(EventNoteGui.closestGui == gui);
			gui.alpha = (FlxG.mouse.overlaps(gui.rect) ? 1 : alpha);
			gui.setPosition(x - gui.rect.width, y);
			gui.draw();
		}
		
		eventText.setPosition(x, y + (height - eventText.height) * .5);
		eventText.alpha = alpha;
		eventText.draw();
	}
	public override function destroy() {
		super.destroy();
		gui = FlxDestroyUtil.destroy(gui);
		eventText = FlxDestroyUtil.destroy(eventText);
	}
	
	public function updateEventInfo() {
		gui.events = events;
		gui.updateDisplay();
		gui.updateHover(gui.hovering, true);
		
		eventText.text = Std.string(events.length);
	}
	
	public override function setSustainLength(newLength:Float, zoom:Float = 1) {}
	public override function updateSustainToZoom(zoom:Float = 1) {}
}

@:access(states.editors.ChartingState)
class EventNoteGui extends FlxSpriteGroup {
	public static var maxWidth:Float = (ChartingState.GRID_SIZE * 5);
	public var selectedEventSprite:FlxSprite;
	public var events:Array<Array<String>>;
	public var eventNote:EventMetaNote;
	
	public var eventContainer:FlxSpriteGroup;
	public var hovering:Bool = false;
	public var rect:FlxSprite;
	
	public var fields:FlxText;
	public var desc:FlxText;
	
	var valuePair:FlxTextFormatMarkerPair;
	var titlePair:FlxTextFormatMarkerPair;
	
	public static var closestGui:EventNoteGui = null;
	
	public function new(event:EventMetaNote) {
		super();
		
		eventNote = event;
		
		rect = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		rect.alpha = .6;
		add(rect);
		
		fields = new FlxText(-500 - 6, 1, 500, '', 12);
		fields.setFormat(Paths.font('vcr.ttf'), 12, 0xffffff, RIGHT, FlxTextBorderStyle.OUTLINE, 0xff000000);
		add(fields);
		desc = new FlxText(-410 - 6, 1, 410, '', 12);
		desc.setFormat(Paths.font('vcr.ttf'), 12, 0xa3a3a3, RIGHT, FlxTextBorderStyle.OUTLINE, 0x80000000);
		add(desc);
		
		eventContainer = new FlxSpriteGroup();
		add(eventContainer);
		
		valuePair = new FlxTextFormatMarkerPair(new FlxTextFormat(0x80ffc0), '\u0100');
		titlePair = new FlxTextFormatMarkerPair(new FlxTextFormat(0xffffff), '\u0101');
	}
	
	public function updateDisplay():Void {
		var size:Int = ChartingState.GRID_SIZE;
		
		rect.setGraphicSize(Std.int(Math.min(Math.max(size * events.length, size), maxWidth)), size);
		rect.updateHitbox();
		
		eventContainer.group.killMembers();
		
		for (i => event in events) {
			var sprite:FlxSprite = eventContainer.recycle(FlxSprite, function() {
				var sprite:FlxSprite = new FlxSprite();
				sprite.antialiasing = ClientPrefs.data.antialiasing;
				
				return sprite;
			});
			
			eventContainer.remove(sprite, true);
			
			sprite.ID = i;
			sprite.loadGraphic(Paths.image('events/${event[0].length == 0 ? 'default' : event[0]}') ?? Paths.image('events/default'));
			sprite.setGraphicSize(size);
			sprite.updateHitbox();
			sprite.revive();
			sprite.setPosition(FlxMath.lerp(0, rect.width - sprite.width, (events.length <= 1 ? 0 : i / (events.length - 1))), 0);
			
			eventContainer.add(sprite);
		}
	}
	
	public override function update(elapsed:Float):Void {
		super.update(elapsed);
		
		if (FlxG.mouse.overlaps(rect)) {
			if (closestGui == null || Math.abs(y + height * .5 - FlxG.mouse.y) < Math.abs(closestGui.y + closestGui.height * .5 - FlxG.mouse.y))
				closestGui = this;
		}
	}
	
	public function select(bounds:flixel.math.FlxRect):Void {
		var charter:ChartingState = ChartingState.instance;
		var selected:Bool = false;
		
		for (event in eventContainer) {
			var eventBounds = event.getScreenBounds(null, charter.camUI);
			eventBounds.top -= charter.scrollY;
			eventBounds.bottom -= charter.scrollY;

			if (bounds.overlaps(eventBounds) && !Lambda.exists(charter.selectedEvents, (e) -> e.event == events[event.ID])) {
				charter.selectedEvents.push({event: events[event.ID], note: eventNote});
				selected = true;
			}
		}
		
		if (selected)
			charter.onSelectNote();
	}
	
	public function updateHover(hovering:Bool, force:Bool = false):Void {
		var charter:ChartingState = ChartingState.instance;
		
		this.hovering = hovering;
		
		if (hovering)
			closestGui = null;
		
		var near:Null<Float> = null;
		var closest:FlxSprite = null;
		
		var sine:Float = (.75 + Math.cos(Math.PI * charter.noteSelectionSine * 2) / 4);
		
		for (event in eventContainer) {
			if (!event.alive) continue;
			
			if (Lambda.exists(charter.selectedEvents, (e) -> e.event == events[event.ID])) {
				event.setColorTransform(sine, sine, sine, alpha, -32, 64, 0);
			} else {
				event.setColorTransform(1, 1, 1, alpha);
			}
			
			if (hovering && FlxG.mouse.overlaps(event)) {
				var dist:Float = Math.sqrt(Math.pow(FlxG.mouse.x - event.x - event.width * .5, 2) + Math.pow(FlxG.mouse.y - event.y - event.height * .5, 2));
				if (closest == null) {
					closest = event;
					near = dist;
				} else if (dist < near) {
					near = dist;
					closest = event;
				}
			}
		}
		
		if (closest != null) {
			fields.visible = desc.visible = true;
			
			var selection = Lambda.find(charter.selectedEvents, (e) -> e.event == events[closest.ID]);
			var redM:Int = (selection == null || FlxG.keys.pressed.SHIFT ? 0 : -153);
			var m:Int = (FlxG.mouse.pressed ? -64 : 128);
			
			if (selection != null && FlxG.keys.pressed.SHIFT) {
				closest.setColorTransform(1, 1, 1, alpha, m - 32, m + redM + 64, m + redM);
			} else {
				closest.setColorTransform(1, 1, 1, alpha, m, m + redM, m + redM);
			}
			
			if (FlxG.mouse.justReleased) {
				if (selection != null) { // snipe
					if (FlxG.keys.pressed.SHIFT) {
						charter.selectedEvents.remove(selection);
						
						return;
					}
					
					if (eventNote.events.length > 1) {
						events.remove(events[closest.ID]);
						eventNote.updateEventInfo();
						
						charter.curEventSelected = Std.int(Math.min(charter.curEventSelected, eventNote.events.length - 1));
						
						charter.selectedEvents.remove(selection);
					} else {
						charter.selectedNotes.remove(eventNote);
						charter.events.remove(eventNote);
						charter.curRenderedNotes.remove(eventNote, true);
					}
					
					charter.addUndoAction(DELETE_EVENT, {events: [selection]});
					
					charter.updateSelectedEvents();
					charter.resetSelectedNotes();
					selectedEventSprite = null;
					
					return;
				} else {
					if (!FlxG.keys.pressed.SHIFT) charter.resetSelectedNotes();
					
					// if (!charter.selectedNotes.contains(eventNote)) charter.selectedNotes.push(eventNote);
					charter.selectedEvents.push({event: events[closest.ID], note: eventNote});
					charter.updateSelectedEventText();
				}
			}
			
			var info:Array<String> = events[closest.ID];
			var fieldPadding:Int = Std.int(Math.max(Math.max( // umm yeah this is annoying actually
				(info[0].length == 0 ? 4 : info[0].length),
				(info[1].length == 0 ? 7 : info[1].length)
				), (info[2].length == 0 ? 7 : info[2].length)
			));
			var fieldSpace:String = ('').rpad(' ', fieldPadding);
			
			fields.text = 'event  $fieldSpace\nvalue 1  $fieldSpace\nvalue 2  $fieldSpace';
			desc.visible = true;
			desc.applyMarkup(
				(info[0].length == 0 ? 'None' : '\u0101' + info[0] + '\u0101') +
				'\n' + (info[1].length == 0 ? '<empty>' : '\u0100' + info[1] + '\u0100') +
				'\n' + (info[2].length == 0 ? '<empty>' : '\u0100' + info[2] + '\u0100')
			, [
				valuePair,
				titlePair
			]);
		} else if (desc.visible || force) {
			desc.visible = false;
			fields.text = ('\n' + events.length + (events.length == 1 ? ' event' : ' events')); // Lol
		}
		
		selectedEventSprite = closest;
	}
	
	public override function draw():Void {
		fields.alpha = .5;
		desc.alpha = 1;
		
		super.draw();
	}
}