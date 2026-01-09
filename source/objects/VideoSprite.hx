package objects;

import flixel.addons.display.FlxPieDial;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#else
import openfl.events.NetStatusEvent;
import openfl.media.SoundTransform;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
#end

class VideoSprite extends FlxSpriteGroup {
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;
	public var holdingTime:Float = 0;
	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;

	private var videoName:String;

	public var waiting:Bool = false;
	#if hxvlc
	public var videoSprite:FlxVideoSprite;
	#elseif js
	public var videoSprite:FlxVideo;
	#end
	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false) {
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if(!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// initialize sprites
		#if hxvlc
		videoSprite = new FlxVideoSprite();
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;
		if(!shouldLoop) videoSprite.bitmap.onEndReached.add(finishVideo);
		videoSprite.load(videoName, shouldLoop ? ['input-repeat=65545'] : null);
		videoSprite.bitmap.onFormatSetup.add(function()
		{
			/*
			#if hxvlc
			var wd:Int = videoSprite.bitmap.formatWidth;
			var hg:Int = videoSprite.bitmap.formatHeight;
			trace('Video Resolution: ${wd}x${hg}');
			videoSprite.scale.set(FlxG.width / wd, FlxG.height / hg);
			#end
			*/
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
		});

		#elseif js
		videoSprite = new FlxVideo(videoName);
		videoSprite.finishCallback= finishVideo;
		#end
		// callbacks
		add(videoSprite);
		if(canSkip) this.canSkip = true;
	
		// start video and adjust resolution to screen size
	}

	var alreadyDestroyed:Bool = false;
	override function destroy()
	{
		if(alreadyDestroyed)
			return;

		trace('Video destroyed');
		if(cover != null)
		{
			remove(cover);
			cover.destroy();
		}
		
		finishCallback = null;
		onSkip = null;

		if(FlxG.state != null)
		{
			if(FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if(FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}
		super.destroy();
		alreadyDestroyed = true;
	}
	function finishVideo()
	{
		if (!alreadyDestroyed)
		{
			if(finishCallback != null)
				finishCallback();
			
			destroy();
		}
	}

	override function update(elapsed:Float)
	{
		if(canSkip)
		{
			if(Controls.instance.pressed('accept'))
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if(holdingTime >= _timeToSkip)
			{
				if(onSkip != null) onSkip();
				finishCallback = null;
				#if hxvlc
				videoSprite.bitmap.onEndReached.dispatch();
				#else
				videoSprite.finishVideo();
				#end
				trace('Skipped video');
				return;
			}
		}
		super.update(elapsed);
	}

	function set_canSkip(newValue:Bool)
	{
		canSkip = newValue;
		if(canSkip)
		{
			if(skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				add(skipSprite);
			}
		}
		else if(skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if(skipSprite == null) return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}
	#if hxvlc
	public function play() videoSprite?.play();
	public function resume() videoSprite?.resume();
	public function pause() videoSprite?.pause();
	#elseif js
	public function resume() videoSprite?.resumeVideo();
	public function pause() videoSprite?.pauseVideo();
	#end
	#end
}
/**
 * Plays a video via a NetStream. Only works on HTML5.
 * This does NOT replace hxvlc, nor does hxvlc replace this.
 * hxvlc only works on desktop and does not work on HTML5!
 * Ripped from Funkin'.
 *  
*/
class FlxVideo extends FlxSprite
{
	#if html5
	var video:Video;
  	var netStream:NetStream;
  	var videoPath:String;

  	/**
   	* A callback to execute when the video finishes.
   	*/
  	public var finishCallback:Void->Void;

  	public function new(videoPath:String)
  	{
    super();

    this.videoPath = videoPath;

    makeGraphic(2, 2, FlxColor.TRANSPARENT);

    video = new Video();
    video.x = 0;
    video.y = 0;
    video.alpha = 0;

    FlxG.game.addChild(video);

    var netConnection:NetConnection = new NetConnection();
    netConnection.connect(null);

    netStream = new NetStream(netConnection);
    netStream.client = {onMetaData: onClientMetaData};
    netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionNetStatus);
    netStream.play(videoPath);
  }

  /**
   * Tell the FlxVideo to pause playback.
   */
  public function pauseVideo():Void
  {
    if (netStream != null)
    {
      netStream.pause();
    }
  }

  /**
   * Tell the FlxVideo to resume if it is paused.
   */
  public function resumeVideo():Void
  {
    // Resume playing the video.
    if (netStream != null)
    {
      netStream.resume();
    }
  }

  var videoAvailable:Bool = false;
  var frameTimer:Float;

  static final FRAME_RATE:Float = 60;

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (frameTimer >= (1 / FRAME_RATE))
    {
      frameTimer = 0;
      // TODO: We just draw the video buffer to the sprite 60 times a second.
      // Can we copy the video buffer instead somehow?
      pixels.draw(video);
    }

    if (videoAvailable) frameTimer += elapsed;
  }

  /**
   * Tell the FlxVideo to seek to the beginning.
   */
  public function restartVideo():Void
  {
    // Seek to the beginning of the video.
    if (netStream != null)
    {
      netStream.seek(0);
    }
  }

  /**
   * Tell the FlxVideo to end.
   */
  public function finishVideo():Void
  {
    netStream.dispose();
    FlxG.removeChild(video);

    if (finishCallback != null) finishCallback();
  }

  public override function destroy():Void
  {
    if (netStream != null)
    {
      netStream.dispose();

      if (FlxG.game.contains(video)) FlxG.game.removeChild(video);
    }

    super.destroy();
  }

  /**
   * Callback executed when the video stream loads.
   * @param metaData The metadata of the video
   */
  public function onClientMetaData(metaData:Dynamic):Void
  {
    video.attachNetStream(netStream);

    onVideoReady();
  }

  function onVideoReady():Void
  {
    video.width = FlxG.width;
    video.height = FlxG.height;

    videoAvailable = true;

    //FunkinSound.onVolumeChanged.add(onVolumeChanged);
    onVolumeChanged(FlxG.sound.muted ? 0 : FlxG.sound.volume);

    makeGraphic(Std.int(video.width), Std.int(video.height), FlxColor.TRANSPARENT);
  }

  function onVolumeChanged(volume:Float):Void
  {
    netStream.soundTransform = new SoundTransform(volume);
  }

  function onNetConnectionNetStatus(event:NetStatusEvent):Void
  {
    if (event.info.code == 'NetStream.Play.Complete') finishVideo();
  }
  #end
}