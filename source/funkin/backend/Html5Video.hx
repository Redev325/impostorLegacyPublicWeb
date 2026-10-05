package funkin.backend;

#if html5
import js.Browser;
import haxe.Timer;
#end

class Html5Video
{
	#if html5
	static var currentVideo:Null<js.html.VideoElement> = null;
	static var currentBackdrop:Null<js.html.DivElement> = null;
	static var endCallback:Null<Void->Void> = null;
	static var errorCallback:Null<Void->Void> = null;
	static var finished:Bool = false;
	static var started:Bool = false;
	static var pauseRequested:Bool = false;
	static var loadTimeout:Null<Timer> = null;
	static var endWatchdog:Null<Timer> = null;
	#end

	public static function play(path:String, onReady:Void->Void, onEnd:Void->Void, onError:Void->Void, ?muted:Bool = false, ?loop:Bool = false):Bool
	{
		#if html5
			stop();

			if (path == null || path.trim().length == 0)
			{
				if (onError != null) onError();
				return false;
			}

			final backdrop:js.html.DivElement = cast Browser.document.createElement('div');
			currentBackdrop = backdrop;
			backdrop.style.position = 'fixed';
			backdrop.style.left = '0';
			backdrop.style.top = '0';
			backdrop.style.width = '100vw';
			backdrop.style.height = '100vh';
			backdrop.style.backgroundColor = 'black';
			backdrop.style.pointerEvents = 'none';
			backdrop.style.zIndex = '99998';
			Browser.document.body.appendChild(backdrop);

			final video:js.html.VideoElement = cast Browser.document.createElement('video');
			currentVideo = video;
			endCallback = onEnd;
			errorCallback = onError;
			finished = false;
			started = false;
			pauseRequested = false;

			video.preload = 'auto';
			// Allow the browser to begin the media load without requiring an
			// additional network response before the first play() attempt.
			video.autoplay = false;
			video.controls = false;
			video.loop = loop;
			video.muted = muted;
			video.setAttribute('playsinline', 'true');
			video.setAttribute('webkit-playsinline', 'true');
			video.src = path;
			video.style.position = 'fixed';
			video.style.left = '0';
			video.style.top = '0';
			video.style.width = '100vw';
			video.style.height = '100vh';
			video.style.objectFit = 'contain';
			video.style.backgroundColor = 'black';
			video.style.visibility = 'hidden';
			video.style.zIndex = '99999';

			final revealVideo:Void->Void = function() {
				if (currentVideo != video || finished || pauseRequested) return;
				try video.style.visibility = 'visible' catch (e:Dynamic) {}
			};

			final markStarted:Void->Void = function() {
				if (currentVideo != video || finished || started || pauseRequested) return;
				started = true;

				if (loadTimeout != null)
				{
					loadTimeout.stop();
					loadTimeout = null;
				}

				if (onReady != null) onReady();
			};

			// Browsers commonly reject audible HTML5 video when it is started after
			// the Story Mode asset-loading callbacks have finished because the original
			// click no longer counts as an active user gesture. Start muted as a
			// fallback so the actual cutscene can still begin, then unmute it as soon
			// as the browser has accepted playback.
			var autoplayMuted:Bool = muted;
			var audiblePlaybackRequested:Bool = !muted;

			final requestPlay:Void->Void = function() {
				if (currentVideo != video || finished || pauseRequested) return;

				try
				{
					if (!autoplayMuted && !audiblePlaybackRequested)
					{
						video.muted = true;
						autoplayMuted = true;
					}

					final result:Dynamic = untyped video.play();
					if (result != null)
					{
						final catchFunction:Dynamic = Reflect.field(result, 'catch');
						if (catchFunction != null)
						{
							Reflect.callMethod(result, catchFunction, [function(_) {
								if (!started && !autoplayMuted)
								{
									autoplayMuted = true;
									audiblePlaybackRequested = false;
									try
									{
										video.muted = true;
										final retry:Dynamic = untyped video.play();
										if (retry != null)
										{
											final retryCatch:Dynamic = Reflect.field(retry, 'catch');
											if (retryCatch != null)
												Reflect.callMethod(retry, retryCatch, [function(_) if (!started) finish(errorCallback)]);
										}
									}
									catch (e2:Dynamic)
									{
										if (!started) finish(errorCallback);
									}
								}
								else if (!started)
								{
									finish(errorCallback);
								}
							}]);
						}
					}
				}
				catch (e:Dynamic)
				{
					if (!started && !autoplayMuted)
					{
						autoplayMuted = true;
						audiblePlaybackRequested = false;
						try
						{
							video.muted = true;
							untyped video.play();
						}
						catch (e2:Dynamic)
						{
							if (!started) finish(errorCallback);
						}
					}
					else if (!started)
					{
						finish(errorCallback);
					}
				}
			};

			// loadeddata means the browser has decoded the first video frame.
			// Reveal the video at that point so the black backdrop covers only the
			// pre-first-frame period, rather than waiting on requestVideoFrameCallback.
			video.onloadeddata = function(_) {
				revealVideo();
				requestPlay();
			};
			video.onloadedmetadata = function(_) requestPlay();
			video.oncanplay = function(_) requestPlay();
			video.onplay = function(_) {
				// Once the browser has accepted muted autoplay, make the game video
				// audible again. This keeps the original cutscene soundtrack while
				// avoiding the autoplay-policy rejection that prevented the video
				// from appearing at all.
				if (!muted && autoplayMuted)
				{
					try video.muted = false catch (e:Dynamic) {}
				}
				audiblePlaybackRequested = !muted;
				markStarted();
				revealVideo();
			};
			video.onended = function(_) finish(endCallback);
			// Some HTML5/browser combinations do not reliably dispatch `ended`.
			// Detect the final video timestamp as a second, non-invasive end path.
			video.ontimeupdate = function(_) {
				if (currentVideo != video || finished || !started) return;
				final duration:Float = video.duration;
				if (!Math.isNaN(duration) && duration > 0 && video.currentTime >= duration - 0.10)
					finish(endCallback);
			};
			video.onerror = function(_) finish(errorCallback);

			Browser.document.body.appendChild(video);
			// Explicitly start loading after insertion so browsers initialize the
			// media element consistently when the URL is served from GitHub Pages.
			try video.load() catch (e:Dynamic) {}
			// Request playback immediately as well as from loadeddata/canplay.
			// This preserves a user-gesture activation when the cutscene was started
			// directly from a Story Mode selection before the network finishes loading.
			requestPlay();

			// Poll the media clock as a final end-of-video fallback. Some browsers
			// can omit both `ended` and a final `timeupdate` for DOM video.
			endWatchdog = new Timer(100);
			endWatchdog.run = function() {
				if (currentVideo != video || finished)
					return;
				try
				{
					final duration:Float = video.duration;
					if (video.ended || (!Math.isNaN(duration) && duration > 0 && video.currentTime >= duration - 0.05))
						finish(endCallback);
				}
				catch (e:Dynamic) {}
			};

			loadTimeout = Timer.delay(function() {
				if (currentVideo == video && !finished && !started)
					finish(errorCallback);
			}, 12000);

			return true;
		#else
			return false;
		#end
	}

	public static function skip():Void
	{
		#if html5
			finish(endCallback);
		#end
	}

	public static function pause():Void
	{
		#if html5
			if (currentVideo == null || finished) return;
			pauseRequested = true;
			try currentVideo.pause() catch (e:Dynamic) {}
		#end
	}

	public static function resume():Void
	{
		#if html5
			if (currentVideo == null || finished) return;
			pauseRequested = false;

			try
			{
				final result:Dynamic = untyped currentVideo.play();
				if (result != null)
				{
					final catchFunction:Dynamic = Reflect.field(result, 'catch');
					if (catchFunction != null)
						Reflect.callMethod(result, catchFunction, [function(_) {}]);
				}
			}
			catch (e:Dynamic) {}
		#end
	}

	public static function stop():Void
	{
		#if html5
			final video = currentVideo;
			currentVideo = null;
			endCallback = null;
			errorCallback = null;
			finished = true;
			started = false;
			pauseRequested = false;

			if (loadTimeout != null)
			{
				loadTimeout.stop();
				loadTimeout = null;
			}
			stopEndWatchdog();

			cleanupVideo(video);
			cleanupBackdrop();
		#end
	}

	public static function seek(delta:Float):Void
	{
		#if html5
			if (currentVideo == null || finished) return;

			try
			{
				final duration:Float = currentVideo.duration;
				final target:Float = currentVideo.currentTime + delta;
				currentVideo.currentTime = Math.max(0, (Math.isNaN(duration) || duration <= 0) ? target : Math.min(target, duration));
			}
			catch (e:Dynamic) {}
		#end
	}

	#if html5
	public static function getTime():Float
	{
		return currentVideo == null ? 0 : currentVideo.currentTime;
	}

	public static function getLength():Float
	{
		if (currentVideo == null) return -1;
		final duration:Float = currentVideo.duration;
		return Math.isNaN(duration) ? -1 : duration;
	}

	public static function isPlaying():Bool
	{
		return currentVideo != null && !currentVideo.paused && !currentVideo.ended;
	}

	public static function getPercent():Float
	{
		final duration = getLength();
		return duration > 0 ? getTime() / duration : 0;
	}

	static function finish(callback:Null<Void->Void>):Void
	{
		if (finished) return;
		finished = true;
		pauseRequested = false;

		if (loadTimeout != null)
		{
			loadTimeout.stop();
			loadTimeout = null;
		}
		stopEndWatchdog();

		final video = currentVideo;
		currentVideo = null;
		final cb = callback;
		endCallback = null;
		errorCallback = null;

		// Do the full cleanup before invoking any game/script callback. The
		// callback can load dialogue assets or run HScript, and an exception there
		// must never leave the full-screen black DOM backdrop stuck over the game.
		cleanupVideo(video);
		cleanupBackdrop();

		if (cb != null)
		{
			try cb() catch (e:Dynamic) trace('HTML5 video end callback error: ' + e);
		}
	}

	static function stopEndWatchdog():Void
	{
		if (endWatchdog != null)
		{
			endWatchdog.stop();
			endWatchdog = null;
		}
	}

	static function cleanupBackdrop():Void
	{
		final backdrop = currentBackdrop;
		currentBackdrop = null;
		if (backdrop == null) return;
		try
		{
			if (backdrop.parentNode != null) backdrop.parentNode.removeChild(backdrop);
		}
		catch (e:Dynamic) {}
	}

	static function cleanupVideo(video:Null<js.html.VideoElement>):Void
	{
		if (video == null) return;

		// Hide the DOM element before detaching it so a stale compositor frame
		// can never remain over the Flixel canvas during the cutscene transition.
		try video.style.visibility = 'hidden' catch (e:Dynamic) {}
		try video.style.display = 'none' catch (e:Dynamic) {}
		try video.pause() catch (e:Dynamic) {}
		try video.removeAttribute('src') catch (e:Dynamic) {}
		try video.load() catch (e:Dynamic) {}
		try
		{
			if (video.parentNode != null) video.parentNode.removeChild(video);
		}
		catch (e:Dynamic) {}
	}
	#end
}
