package funkin;

import haxe.io.Bytes;
import haxe.Timer;

import openfl.media.Sound;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import openfl.utils.AssetType;
import openfl.display.BitmapData;
import openfl.Assets;
import lime.media.AudioBuffer;
import lime.net.HTTPRequest;

import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;

import funkin.backend.FunkinCache;
import funkin.backend.Difficulty;
import funkin.states.PlayState;

/**
 * backend for retrieving and caching assets
 */
@:nullSafety(Strict)
class FunkinAssets
{
	/**
	 * Handles the caching of assets collected through `Paths` 
	 */
	public static final cache:FunkinCache = new FunkinCache();

	static final HTML5_PRELOADED_LIBRARIES:Array<String> = ['title', 'mainmenu', 'menus'];
	// Only these libraries are valid sources for synchronous HTML5 asset access.
	// Do not resolve through deferred music/fonts/embedded libraries: Lime will
	// correctly report those assets as existing, but only asynchronously.
	static final HTML5_SYNCHRONOUS_LIBRARIES:Array<String> = ['title', 'mainmenu', 'menus', 'gameplay'];

	#if html5
	static final html5LoadedLibraries:Map<String, Bool> = [];
	static var html5CurrentSongLibrary:Null<String> = null;
	static var html5SongChartText:Map<String, String> = [];
	static var html5SongEventText:Map<String, String> = [];
	static var html5SongDialogueText:Map<String, String> = [];
	static var html5SongInfoText:Map<String, String> = [];
	static var html5SongScriptText:Map<String, String> = [];
	static var html5LoadedSounds:Map<String, Sound> = [];
	#end

	#if html5
	static final HTML5_SONG_SCRIPTS:Map<String, Array<String>> = [
		'armed' => ['armed.hx'],
		'ashes' => ['ashes.hx'],
		'blackout' => ['blackout.hx'],
		'boiling-point' => ['script.hx'],
		'chippin' => ['chippin.hx'],
		'chlorophyll' => ['cholorophyll.hx'],
		'dlow' => ["d'low.hx"],
		'danger' => ['script.hx'],
		'defeat' => ['script.hx'],
		'delusion' => ['delusion.hx'],
		'double-kill' => ['double-kill.hx'],
		'double-trouble' => ['double-trouble.hx'],
		'ejected' => ['ejected.hx'],
		'finale' => ['completion.hx', 'finaleUI.hx'],
		'greatest-plan' => ['greatest-plan.hx'],
		'heartbeat' => ['heartbeat.hx'],
		'identity-crisis' => ['completion.hx'],
		'inflorescence' => ['inflorescence.hx'],
		'insane-streamer' => ['insane-streamer.hx'],
		'lemon-lime' => ['lemon-lime.hx'],
		'lights-down' => ['script.hx'],
		'magmatic' => ['magmatic.hx'],
		'mando' => ['mando.hx'],
		'meltdown' => ['meltdown.hx'],
		'neurotic' => ['neurotic.hx'],
		'o2' => ['o2.hx'],
		'oversight' => ['oversight.hx'],
		'pinkwave' => ['pinkwave.hx'],
		'pretender' => ['pretender.hx'],
		'reactor' => ['reactor.hx'],
		'reinforcements' => ['reinforcements.hx'],
		'rivals' => ['rivals.hx'],
		'roomcode' => ['script.hx'],
		'sabotage' => ['sabotage.hx'],
		'stargazer' => ['stargazer.hx'],
		'sussus-moogus' => ['sussus-moogus.hx'],
		'sussus-toogus' => ['script.hx'],
		'tomongus-tuesday' => ['tuesday.hx'],
		'top-10' => ['sigh.hx'],
		'turbulence' => ['turbulence.hx'],
		'voting-time' => ['voting-time.hx']
	];
	#end

	#if html5
	/**
	 * Resolve an asset to the library that is actually ready for synchronous
	 * access in the HTML5 build.
	 *
	 * Lime's unqualified Assets.exists(path) can report an asset from a
	 * runtime-only library (for example gameplay:assets/images/currency/beans.png)
	 * even when the same asset also exists in a preloaded menu library. Choosing
	 * that runtime copy makes Assets.getBitmapData/getSound/getText throw the
	 * "exists, but only asynchronously" error. Prefer preloaded libraries first.
	 */
	/**
 	 * Loads HTML5 asset libraries that are intentionally kept out of the
 	 * startup preloader. This lets menus stay fast while still making
 	 * gameplay assets available synchronously once a song starts.
 	 */
	public static function loadHtml5Sound(url:String, cacheKeys:Array<String>, onComplete:Void->Void):Void
	{
		#if html5
			for (key in cacheKeys)
			{
				final loaded:Null<Sound> = html5LoadedSounds.get(key);
				if (loaded != null)
				{
					cache.cacheSound(key, loaded);
					html5LoadedSounds.set(key, loaded);
					onComplete();
					return;
				}
				if (cache.currentTrackedSounds.exists(key))
				{
					onComplete();
					return;
				}
			}

			function attemptLoad(attempt:Int):Void
			{
				final sound:Sound = new Sound();
				var handled:Bool = false;

				function finish():Void
				{
					if (handled) return;
					handled = true;
					for (key in cacheKeys)
					{
						cache.cacheSound(key, sound);
						html5LoadedSounds.set(key, sound);
					}
					onComplete();
				}

				sound.addEventListener(Event.COMPLETE, function(_) {
					finish();
				});

				sound.addEventListener(IOErrorEvent.IO_ERROR, function(error) {
					if (handled) return;
					handled = true;

					if (attempt < 3)
					{
						Timer.delay(() -> attemptLoad(attempt + 1), 500 * attempt);
					}
					else
					{
						Logger.log('HTML5 audio request failed after 3 attempts: ' + url + '\\nException: ' + error.text, ERROR);
						onComplete();
					}
				});

				try
				{
					sound.load(new URLRequest(url));
				}
				catch (e:Dynamic)
				{
					if (handled) return;
					handled = true;

					if (attempt < 3)
					{
						Timer.delay(() -> attemptLoad(attempt + 1), 500 * attempt);
					}
					else
					{
						Logger.log('HTML5 audio request failed after 3 attempts: ' + url + '\\nException: ' + e, ERROR);
						onComplete();
					}
				}
			}

			attemptLoad(1);
		#else
			onComplete();
		#end
	}

	public static function loadHtml5SoundObject(url:String, cacheKeys:Array<String>, onComplete:Null<Sound>->Void):Void
	{
		#if html5
			for (key in cacheKeys)
			{
				final loaded:Null<Sound> = html5LoadedSounds.get(key);
				if (loaded != null)
				{
					onComplete(loaded);
					return;
				}
			}
			
			function complete(sound:Null<Sound>):Void
			{
				if (sound != null)
				{
					for (key in cacheKeys)
						html5LoadedSounds.set(key, sound);
				}
				onComplete(sound);
			}
			
			function loadDirect():Void
			{
				final directUrl:String = cacheKeys.length > 0 ? cacheKeys[0] : url;
				try
				{
					Sound.loadFromFile(directUrl)
						.onComplete(function(sound:Sound) complete(sound))
						.onError(function(_) {
							Logger.log('HTML5 audio request failed: ' + directUrl, ERROR);
							complete(null);
						});
				}
				catch (e:Dynamic)
				{
					Logger.log('HTML5 audio request could not start: ' + directUrl + '\\nException: ' + e, ERROR);
					complete(null);
				}
			}
			
			// Qualified IDs use Lime's registered asset library. If that cannot
			// resolve the deferred library at runtime, fall back to the actual
			// packaged browser URL so gameplay does not depend on Lime's library
			// registration state.
			try
			{
				Assets.loadSound(url, true)
					.onComplete(function(sound:Sound) complete(sound))
					.onError(function(_) loadDirect());
			}
			catch (e:Dynamic)
			{
				loadDirect();
			}
		#else
			onComplete(null);
		#end
	}


	public static function loadHtml5Libraries(libraries:Array<String>, onComplete:Void->Void):Void
	{
		#if html5
			final queue:Array<String> = libraries.copy();
			
			function loadNext():Void
			{
				if (queue.length == 0)
				{
					onComplete();
					return;
				}
				
				final library:Null<String> = queue.shift();
				if (library == null)
				{
					loadNext();
					return;
				}
				
				if (html5LoadedLibraries.exists(library))
				{
					loadNext();
					return;
				}
				
				// Do not gate this on Assets.hasLibrary(). Deferred HTML5 libraries
				// are exactly the libraries that may not be registered until this call
				// resolves their manifest.
				Assets.loadLibrary(library).onComplete(function(loadedLibrary) {
					if (loadedLibrary == null)
					{
						Logger.log('HTML5 asset library could not be loaded: ' + library, ERROR);
						loadNext();
						return;
					}
					
					html5LoadedLibraries.set(library, true);
					loadNext();
				}).onError(function(error) {
					Logger.log('Failed to load HTML5 asset library ' + library + '\\nException: ' + error, ERROR);
					loadNext();
				});
			}
			
			loadNext();
		#else
			onComplete();
		#end
	}

	/**
	 * Loads the deferred library for exactly one song before PlayState starts.
	 * Story Mode and Freeplay both use this path on HTML5.
	 */
	public static function loadHtml5SongAssets(songName:String, onComplete:Void->Void, ?onError:Void->Void):Void
	{
		#if html5
			// Only the chart has to be ready before entering PlayState. The
			// PlayableSong class already streams Inst.ogg/Voices.ogg after the
			// state is created, so waiting for audio here can make Story Mode
			// appear stuck on slower connections.
			final safeSongName:String = Paths.sanitize(songName);
			final effectiveDifficulty:Int = PlayState.storyMeta.difficulty;
			final chartDifficulty:String = Difficulty.getDifficultyFilePath(effectiveDifficulty);
			final chartCacheKey:String = safeSongName + ':' + effectiveDifficulty;
			final songFolder:String = safeSongName == 'dlow' ? "d'low" : safeSongName;
			final songLibrary:String = 'song_' + (safeSongName == 'dlow' ? 'd_low' : safeSongName);
			final chartId:String = songLibrary + ':assets/songs/' + songFolder + '/data/' + chartDifficulty + '.json';
			final instFile:String = (PlayState.SONG?.trackSwap ?? false) ? 'Track-main.ogg' : 'Inst.ogg';
			final voicePath:String = 'assets/songs/' + songFolder + '/Voices.ogg';
			final needsVoices:Bool = PlayState.SONG?.needsVoices ?? false;

			function fail(reason:Dynamic):Void
			{
				Logger.log('Unable to load HTML5 song assets for ' + songName + ': ' + reason, ERROR);
				final callback:Void->Void = onError ?? function() {};
				callback();
			}

			function finishWithChart(text:String, afterChart:Void->Void):Void
			{
				if (text.trim().length == 0)
				{
					fail('chart file was empty');
					return;
				}
				if (parseJson(text) == null)
				{
					fail('chart JSON could not be parsed');
					return;
				}
				html5SongChartText.set(chartCacheKey, text);
				afterChart();
			}

			function loadExternalSound(url:String, cacheKeys:Array<String>, ?afterAudio:Void->Void):Void
			{
				final callback:Void->Void = afterAudio ?? function() {};
				FunkinAssets.loadHtml5Sound(url, cacheKeys, callback);
			}

			function loadSongInfo(afterInfo:Void->Void):Void
			{
				final infoKey:String = safeSongName;
				if (html5SongInfoText.exists(infoKey))
				{
					afterInfo();
					return;
				}
				final infoUrl:String = 'assets/songs/' + songFolder + '/info.txt';
				final loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, function(_) {
					html5SongInfoText.set(infoKey, Std.string(loader.data));
					afterInfo();
				});
				loader.addEventListener(IOErrorEvent.IO_ERROR, function(_) {
					html5SongInfoText.set(infoKey, '');
					afterInfo();
				});
				try
				{
					loader.load(new URLRequest(infoUrl));
				}
				catch (e)
				{
					html5SongInfoText.set(infoKey, '');
					afterInfo();
				}
			}

			function loadSongDialogue(afterDialogue:Void->Void):Void
			{
				final dialogueKey:String = safeSongName;
				if (html5SongDialogueText.exists(dialogueKey))
				{
					afterDialogue();
					return;
				}

				final dialogueUrl:String = 'assets/songs/' + songFolder + '/dialogue.txt';
				final loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, function(_) {
					html5SongDialogueText.set(dialogueKey, Std.string(loader.data));
					afterDialogue();
				});
				loader.addEventListener(IOErrorEvent.IO_ERROR, function(_) {
					html5SongDialogueText.set(dialogueKey, '');
					afterDialogue();
				});
				try
				{
					loader.load(new URLRequest(dialogueUrl));
				}
				catch (e:Dynamic)
				{
					html5SongDialogueText.set(dialogueKey, '');
					afterDialogue();
				}
			}

			function loadDialogueMusic(afterMusic:Void->Void):Void
			{
				final dialogueText:Null<String> = html5SongDialogueText.get(safeSongName);
				if (dialogueText == null || dialogueText.trim().length == 0)
				{
					afterMusic();
					return;
				}
				final relativePath:String = 'assets/music/dialogue/' + safeSongName + '.ogg';
				loadExternalSound(relativePath, ['music:' + relativePath, relativePath], afterMusic);
			}

			function loadSongEvents(afterEvents:Void->Void):Void
			{
				final eventCacheKey:String = safeSongName;
				if (html5SongEventText.exists(eventCacheKey))
				{
					afterEvents();
					return;
				}

				final eventId:String = songLibrary + ':assets/songs/' + songFolder + '/data/events.json';
				try
				{
					if (Assets.exists(eventId, AssetType.TEXT))
					{
						final text:String = Assets.getText(eventId);
						if (text.trim().length > 0 && parseJson(text) != null)
						{
							html5SongEventText.set(eventCacheKey, text);
							afterEvents();
							return;
						}
					}
				}
				catch (e:Dynamic) {}

				final eventUrl:String = 'assets/songs/' + songFolder + '/data/events.json';
				final loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, function(_) {
					final text:String = Std.string(loader.data);
					if (text.trim().length > 0 && parseJson(text) != null)
						html5SongEventText.set(eventCacheKey, text);
					afterEvents();
				});
				loader.addEventListener(IOErrorEvent.IO_ERROR, function(_) afterEvents());
				try
				{
					loader.load(new URLRequest(eventUrl));
				}
				catch (e:Dynamic) afterEvents();
			}

			function loadSongScripts(afterScripts:Void->Void):Void
			{
				final scriptFiles:Null<Array<String>> = HTML5_SONG_SCRIPTS.get(safeSongName);
				final files:Array<String> = scriptFiles == null ? [] : scriptFiles.copy();
				var index:Int = 0;

				function loadNext():Void
				{
					if (index >= files.length)
					{
						afterScripts();
						return;
					}

					final relativePath:String = 'assets/songs/' + songFolder + '/' + files[index++];
					if (html5SongScriptText.exists(relativePath))
					{
						loadNext();
						return;
					}

					final loader:URLLoader = new URLLoader();
					loader.addEventListener(Event.COMPLETE, function(_) {
						final text:String = Std.string(loader.data);
						html5SongScriptText.set(relativePath, text);
						html5SongScriptText.set(songLibrary + ':' + relativePath, text);
						loadNext();
					});
					loader.addEventListener(IOErrorEvent.IO_ERROR, function(error) {
						Logger.log('HTML5 song script unavailable: ' + relativePath + '\\nException: ' + error.text, ERROR);
						loadNext();
					});

					try
					{
						loader.load(new URLRequest(relativePath));
					}
					catch (e:Dynamic)
					{
						Logger.log('HTML5 song script request failed: ' + relativePath + '\\nException: ' + e, ERROR);
						loadNext();
					}
				}

				loadNext();
			}

			function loadSongAssets():Void
			{
				// Preload only synchronous non-audio dependencies here. Gameplay
				// audio is created by PlayableSong using HTML5 streaming.
				loadSongEvents(function() {
					loadSongDialogue(function() {
						loadSongInfo(function() {
							loadSongScripts(function() {
								onComplete();
							});
						});
					});
				});
			}
			
			function loadChartFromNetwork(attempt:Int = 1):Void
			{
				final chartUrl:String = 'assets/songs/' + songFolder + '/data/' + chartDifficulty + '.json';
				final loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, function(_) {
					finishWithChart(Std.string(loader.data), loadSongAssets);
				});
				loader.addEventListener(IOErrorEvent.IO_ERROR, function(event) {
					if (attempt < 3)
					{
						Logger.log('Failed to load HTML5 chart ' + chartUrl + ', retrying (' + (attempt + 1) + '/3)\\nException: ' + event.text, WARN);
						Timer.delay(() -> loadChartFromNetwork(attempt + 1), 500 * attempt);
					}
					else
					{
						fail('chart request failed after 3 attempts');
					}
				});
				try
				{
					loader.load(new URLRequest(chartUrl));
				}
				catch (e)
				{
					if (attempt < 3)
						Timer.delay(() -> loadChartFromNetwork(attempt + 1), 500 * attempt);
					else
						fail(e);
				}
			}

			// HTML5 gameplay dependencies are already in the preloaded gameplay
			// library. Song-specific chart/script/dialogue/info data and audio are
			// fetched through the explicit HTML5 network/cache paths above.
			// Avoid Assets.loadLibrary(songLibrary) here: runtime library registration
			// can collide with Lime/OpenFL's existing library objects and leave the
			// library's assets marked as async-only on HTML5.

			function beginSongLoad():Void
			{
				if (html5SongChartText.exists(chartCacheKey))
				{
					loadSongAssets();
					return;
				}
				
				loadChartFromNetwork();
			}

			beginSongLoad();
		#else
			onComplete();
		#end
	}

	#if html5
	public static function getHtml5SongEvents(songName:String):Null<String>
	{
		final songPath:String = Paths.sanitize(songName);
		return html5SongEventText.get(songPath);
	}

	public static function getHtml5SongScripts(songName:String):Array<String>
	{
		final safeSong:String = Paths.sanitize(songName);
		final files:Null<Array<String>> = HTML5_SONG_SCRIPTS.get(safeSong);
		final result:Array<String> = files == null ? [] : files.copy();
		result.sort(Reflect.compare);
		return result;
	}


	public static function getHtml5SongScript(file:String):Null<String>
	{
		if (file == null || file.length == 0) return null;
		final colon:Int = file.indexOf(':');
		final normalized:String = colon > 0 ? file.substr(colon + 1) : file;
		final cached:Null<String> = html5SongScriptText.get(file) ?? html5SongScriptText.get(normalized);
		if (cached != null) return cached;
		return null;
	}


	#if html5
	public static function resolveHtml5VideoPath(videoKey:String):String
	{
		final raw:String = Std.string(videoKey ?? '').trim();
		final sanitized:String = raw.length > 0 ? Paths.sanitize(raw) : '';
		final candidates:Array<String> = [];

		function addCandidates(root:String, key:String):Void
		{
			if (key.length == 0) return;
			candidates.push(root + key + '.mp4');
			candidates.push(root + key + '.mov');
		}

		addCandidates('assets/videos/', raw);
		addCandidates('assets/videos/', sanitized);
		addCandidates('content/securitydlc/videos/', raw);
		addCandidates('content/securitydlc/videos/', sanitized);

		final listed:Array<String> = Assets.list();
		for (candidate in candidates)
		{
			for (asset in listed)
			{
				var listedPath:String = Std.string(asset);
				final colon:Int = listedPath.indexOf(':');
				if (colon > 0) listedPath = listedPath.substr(colon + 1);

				if (listedPath == candidate) return candidate;
				if (listedPath.toLowerCase() == candidate.toLowerCase()) return listedPath;
			}
		}

		final fallback:String = sanitized.length > 0 ? sanitized : raw;
		return 'assets/videos/' + fallback + '.mp4';
	}
	#end

	#if html5
	/**
	 * Dialogue character JSON is part of the synchronously loaded gameplay
	 * library. Read it directly instead of routing through the generic content
	 * loader, which also checks the song-script cache.
	 */
	public static function getHtml5DialogueCharacter(char:String):Null<String>
	{
		final raw:String = Std.string(char ?? '').trim().toLowerCase();
		if (raw.length == 0) return null;
		final assetId:String = 'gameplay:assets/data/dialogue/' + raw + '.json';
		try
		{
			if (Assets.exists(assetId, AssetType.TEXT))
				return Assets.getText(assetId);
		}
		catch (e:Dynamic)
		{
			Logger.log('Failed to read HTML5 dialogue character ' + raw + ': ' + e, WARN);
		}
		return null;
	}
	#end

	public static function getHtml5SongInfo(songName:String):Null<String>
	{
		final songPath:String = Paths.sanitize(songName);
		return html5SongInfoText.get(songPath);
	}

	public static function getHtml5SongDialogue(songName:String):Null<String>
	{
		final songPath:String = Paths.sanitize(songName);
		if (songPath.length == 0) return null;

		final cached:Null<String> = html5SongDialogueText.get(songPath);
		if (cached != null && cached.trim().length > 0)
			return cached;

		#if html5
			// Prefer the tiny preloaded dialogue library. This is available
			// synchronously even if the song-specific network cache was missed.
			final folder:String = songPath == 'dlow' ? "d'low" : songPath;
			final embeddedId:String = 'dialogue:assets/songs/' + folder + '/dialogue.txt';
			try
			{
				if (Assets.exists(embeddedId, AssetType.TEXT))
				{
					final text:String = Assets.getText(embeddedId);
					if (text.trim().length > 0)
					{
						html5SongDialogueText.set(songPath, text);
						return text;
					}
				}
			}
			catch (e:Dynamic)
			{
				Logger.log('Failed to read embedded HTML5 dialogue ' + songPath + ': ' + e, WARN);
			}
		#end

		return cached;
	}

	public static function getHtml5SongChart(songName:String, difficulty:Int):Null<String>
	{
		final songPath:String = Paths.sanitize(songName);
		return html5SongChartText.get(songPath + ':' + difficulty);
	}
	#end

	static function resolveHtml5AssetId(path:String, ?type:AssetType):Null<String>
	{
		// Respect an already-qualified Lime asset ID.
		if (path.indexOf(':') > 0)
		{
			return Assets.exists(path, type) ? path : null;
		}

		// Prefer the currently loaded song library for chart/audio/script paths.
		if (html5CurrentSongLibrary != null && Assets.hasLibrary(html5CurrentSongLibrary))
		{
			final id = html5CurrentSongLibrary + ':' + path;
			if (Assets.exists(id, type)) return id;
		}

		// Prefer libraries registered with the preloader.
		for (library in HTML5_PRELOADED_LIBRARIES)
		{
			if (!Assets.hasLibrary(library)) continue;
			final id = library + ':' + path;
			if (Assets.exists(id, type)) return id;
		}

		// Synchronous sound access must never select a preload=false library.
		// Those assets are intentionally available only through an asynchronous
		// load path and Assets.getSound() will throw the async-only error.
		if (type != SOUND)
		{
			for (library in HTML5_SYNCHRONOUS_LIBRARIES)
			{
				if (!Assets.hasLibrary(library)) continue;
				final id = library + ':' + path;
				if (Assets.exists(id, type)) return id;
			}
		}

		// For synchronous sound access, never fall back to an unqualified asset
		// lookup because Assets.exists() may find a preload=false library and
		// Assets.getSound() will then throw the async-only error.
		if (type == SOUND) return null;
		
		// Finally accept a genuinely default/unqualified non-sound asset.
		return Assets.exists(path, type) ? path : null;
	}
	#end
	
	/**
	 * Safer alternative to directly using `haxe.Json.parse`
	 */
	public static function parseJson(content:String, ?pos:haxe.PosInfos):Null<Any>
	{
		try
		{
			return haxe.Json.parse(content);
		}
		catch (e)
		{
			Logger.log('failed to parse content\nException: ${e.message}', WARN, false, pos);
			return null;
		}
	}
	
	/**
	 * Parses a json using the json5 format.
	 */
	public static function parseJson5(content:String, ?pos:haxe.PosInfos):Null<Any>
	{
		try
		{
			#if json5hx
			return haxe.Json5.parse(content);
			#else
			return haxe.Json.parse(content);
			#end
		}
		catch (e)
		{
			Logger.log('failed to parse content\nException: ${e.message}', WARN, false, pos);
			return null;
		}
	}
	
	/**
	 * Retrieves the Bytes of a given file from its path
	 */
	public static function getBytes(path:String):Bytes
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		if (FileSystem.exists(path)) return File.getBytes(path);
		#end
		#if html5
		final resolved = resolveHtml5AssetId(path);
		if (resolved != null) return Assets.getBytes(resolved);
		#else
		if (Assets.exists(path)) return Assets.getBytes(path);
		#end
		throw 'Couldnt find file at path [$path]';
	}
	
	/**
	 * Retrieves the content of a given file from its path
	 */
	public static function getContent(path:String):String
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		if (FileSystem.exists(path)) return File.getContent(path);
		#end
		#if html5
		final cachedText:Null<String> = getHtml5SongScript(path);
		if (cachedText != null) return cachedText;
		final resolved = resolveHtml5AssetId(path, TEXT);
		if (resolved != null) return Assets.getText(resolved);
		#else
		if (Assets.exists(path)) return Assets.getText(path);
		#end
		throw 'Couldnt find file at path [$path]';
	}
	
	/**
	 * Retrives a bitmap instance from path.
	 * 
	 * Will return null in the case it cannot be found.
	 */
	public static function getBitmapData(path:String, useCache:Bool = true):Null<BitmapData>
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		if (FileSystem.exists(path)) return BitmapData.fromFile(path);
		#end
		#if html5
		final resolved = resolveHtml5AssetId(path, IMAGE);
		if (resolved != null) return Assets.getBitmapData(resolved, useCache);
		return null;
		#else
		return Assets.exists(path, IMAGE) ? Assets.getBitmapData(path, useCache) : null;
		#end
	}
	
	/**
	 *	Returns whether a given path exists.
	 */
	public static function exists(path:String, ?type:AssetType):Bool
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		if (FileSystem.exists(path)) return true;
		#end
		#if html5
		return (type == null ? resolveHtml5AssetId(path) != null : resolveHtml5AssetId(path, type) != null);
		#else
		return Assets.exists(path, type);
		#end
	}
	
	/**
	 * Reads a given directory and returns all file names inside.
	 * 
	 * if it could not be found, an empty array will be returned.
	 */
	public static function readDirectory(directory:String):Array<String>
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		return FileSystem.exists(directory) ? FileSystem.readDirectory(directory) : []; // doing a check because i want this to maintain parity with ther assets variation
		#else
		if (directory.trim().length == 0) return [];
		
		final result:Array<String> = [];
		for (asset in Assets.list())
		{
			// Assets.list() returns library-qualified IDs such as
			// "menus:assets/data/weeks/week1.json". Strip the library prefix
			// before treating the remaining part as a virtual directory path.
			var virtualPath:String = asset;
			final colon:Int = virtualPath.indexOf(':');
			if (colon > 0) virtualPath = virtualPath.substr(colon + 1);
			
			final prefix:String = directory.endsWith('/') ? directory : '$directory/';
			if (!virtualPath.startsWith(prefix)) continue;
			
			final relative:String = virtualPath.substr(prefix.length);
			if (relative.length == 0) continue;
			
			final slash:Int = relative.indexOf('/');
			final child:String = slash == -1 ? relative : relative.substr(0, slash);
			if (child.length > 0 && !result.contains(child)) result.push(child);
		}
		return result;
		#end
	}
	
	public static function isDirectory(directory:String):Bool
	{
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		return FileSystem.isDirectory(directory);
		#else
		if (directory.trim().length == 0) return false;
		final prefix:String = directory.endsWith('/') ? directory : '$directory/';
		for (asset in Assets.list())
		{
			var virtualPath:String = asset;
			final colon:Int = virtualPath.indexOf(':');
			if (colon > 0) virtualPath = virtualPath.substr(colon + 1);
			if (virtualPath.startsWith(prefix) && virtualPath.length > prefix.length) return true;
		}
		return false;
		#end
	}
	
	/**
	 * retrieves a flxgraphic instance from key.
	 * 
	 * @param useCache Retrieves from the cache if possible. Otherwise, it will be cached
	 * @param allowGPU If true and is enabled in settings, the graphic will be cached on in video memory
	 */
	public static function getGraphicUnsafe(key:String, useCache:Bool = true, allowGPU:Bool = true):Null<FlxGraphic>
	{
		if (useCache && cache.currentTrackedGraphics.exists(key))
		{
			cache.localTrackedAssets.push(key);
			return cache.currentTrackedGraphics.get(key);
		}
		
		var bitmap:Null<BitmapData> = getBitmapData(key);
		
		if (bitmap != null)
		{
			return cache.cacheBitmap(key, bitmap, allowGPU);
		}
		
		return null;
	}
	
	/**
	 * retrieves a flxgraphic instance from key.
	 * 
	 * @param useCache Retrieves from the cache if possible. Otherwise, it will be cached
	 * @param allowGPU If true and is enabled in settings, the graphic will be cached on in video memory
	 */
	public static function getGraphic(key:String, useCache:Bool = true, allowGPU:Bool = true):FlxGraphic
	{
		final graphic:Null<FlxGraphic> = getGraphicUnsafe(key, useCache, allowGPU);
		
		if (graphic != null)
		{
			return graphic;
		}
		
		Logger.log('graphic ($key) was not found. Returning flixel-logo instead');
		
		return FlxG.bitmap.add('flixel/images/logo/default.png');
	}
	
	/**
	 * Retrives a Sound instance from key.
	 * 
	 * If the sound could not be found, a beep sound will be given in place.
	 * 
	 * @param useCache Retrieves from the cache if possible. Otherwise, it will be cached
	 */
	public static function getSound(key:String, useCache:Bool = true):Sound
	{
		final sound:Null<Sound> = getSoundUnsafe(key, useCache);
		
		if (sound != null)
		{
			return sound;
		}
		
		Logger.log('sound ($key) was not found. Returning beep instead');
		
		return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
	}
	
	/**
	 * Retrives a Sound instance from key.
	 * 
	 * If the sound could not be found, null will be returned.
	 * 
	 * @param useCache Retrieves from the cache if possible. Otherwise, it will be cached
	 */
	public static function getSoundUnsafe(key:String, useCache:Bool = true):Null<Sound>
	{
		#if html5
		final preloadedSound:Null<Sound> = html5LoadedSounds.get(key);
		if (preloadedSound != null)
		{
			cache.cacheSound(key, preloadedSound);
			return preloadedSound;
		}
		final normalizedPreloaded:String = key.toLowerCase();
		for (loadedKey in html5LoadedSounds.keys())
		{
			if (loadedKey.toLowerCase() == normalizedPreloaded)
			{
				final reused:Null<Sound> = html5LoadedSounds.get(loadedKey);
				if (reused != null) cache.cacheSound(key, reused);
				return reused;
			}
		}
		#end
		if (useCache)
		{
			if (cache.currentTrackedSounds.exists(key))
			{
				cache.localTrackedAssets.push(key);
				return cache.currentTrackedSounds.get(key);
			}
			#if html5
			// HTML5/Lime can normalize asset filenames differently between
			// manifest lookup and runtime requests (for example Voices.ogg ->
			// voices.ogg). Reuse the already-decoded sound regardless of case
			// instead of falling through to Assets.getSound(), which throws
			// when an asset exists only through an asynchronous library.
			final normalizedKey:String = key.toLowerCase();
			for (cachedKey in cache.currentTrackedSounds.keys())
			{
				if (cachedKey.toLowerCase() == normalizedKey)
				{
					cache.localTrackedAssets.push(cachedKey);
					return cache.currentTrackedSounds.get(cachedKey);
				}
			}
			#end
		}
		
		var sound:Null<Sound> = null;
		
		#if (MODS_ALLOWED || ASSET_REDIRECT)
		if (FileSystem.exists(key)) sound = Sound.fromFile(key);
		#end
		#if html5
		if (sound == null)
		{
			final resolved = resolveHtml5AssetId(key, SOUND);
			if (resolved != null)
			{
				// A loaded HTML5 library can expose an asset through its manifest
				// before Assets.getSound() considers it synchronously accessible.
				// Reuse Lime's decoded AssetCache first; this is the cache populated
				// by Assets.loadSound(..., true).
				try
				{
					sound = Assets.cache.getSound(resolved);
				}
				catch (e:Dynamic)
				{
					Logger.log('Could not read cached HTML5 sound ' + resolved + ': ' + e, WARN);
				}
				if (sound == null)
				{
					try
					{
						sound = Assets.getSound(resolved, true);
					}
					catch (e:Dynamic)
					{
						// Do not let Lime's async-only asset guard crash gameplay.
						// The selected song loader is responsible for loading missing
						// HTML5 audio asynchronously before PlayState starts.
						Logger.log('HTML5 sound is currently async-only: ' + resolved + '\\nException: ' + e, WARN);
					}
				}
			}
		}
		#else
		if (sound == null && Assets.exists(key, SOUND)) sound = Assets.getSound(key, true);
		#end
		
		if (sound != null)
		{
			cache.cacheSound(key, sound);
		}
		
		return sound;
	}
	
	/**
	 * Returns the platform font name for a font asset.
	 *
	 * On HTML5, resolve through the preloaded library set first so a duplicate
	 * runtime-only font cannot trigger Lime's synchronous-access error.
	 */
	public static function getFontName(path:String):String
	{
		#if html5
		final resolved = resolveHtml5AssetId(path, FONT);
		if (resolved != null) return Assets.getFont(resolved).fontName;
		return path;
		#else
		return Assets.exists(path, FONT) ? Assets.getFont(path).fontName : path;
		#end
	}

	/**
	 * Constructs a Sound instance out of a `OGG Vorbis` file providing dramatically faster load times on larger files.
	 * 
	 * These do not support `.wav` and should be using sparingly
	 */
	public static function getVorbisSound(key:String):Null<Sound>
	{
		if (key.extension() != 'ogg') return null;
		
		#if !lime_vorbis
		// trace('gulp');
		return null;
		#else
		final vorbisFile = lime.media.vorbis.VorbisFile.fromFile(key);
		
		if (vorbisFile == null) return null;
		
		final buffer = lime.media.AudioBuffer.fromVorbisFile(vorbisFile);
		
		return Sound.fromAudioBuffer(buffer);
		#end
	}
}
