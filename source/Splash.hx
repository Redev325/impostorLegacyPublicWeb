package;

import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

import funkin.FunkinAssets;
import funkin.states.TitleState;
import openfl.utils.AssetType;
import openfl.utils.Assets;
#if !html5
import funkin.video.FunkinVideoSprite;
#else
import funkin.backend.Html5Video;
#end

using StringTools;

@:access(flixel.FlxGame)
class Splash extends FlxState
{
	var _cachedAutoPause:Bool;
	
	var logo:FlxSprite;
	
	var willSkip:Bool = false;
	var canSkip:Bool = true;
	
	var initialTimer:Null<FlxTimer> = null;
	var finishing:Bool = false;
#if html5
	var titleLibraryReady:Bool = false;
	var splashComplete:Bool = false;
#end
	
	override function create()
	{
		_cachedAutoPause = FlxG.autoPause;
		FlxG.autoPause = false;

#if html5
		// Show the Nightmare Vision splash immediately after the browser preloader.
		// Load the title library in parallel so a slow title-asset request cannot
		// prevent the splash from appearing first.
		openfl.Assets.loadLibrary('title')
			.onComplete(function(_) {
				titleLibraryReady = true;
				if (splashComplete) complete();
			})
			.onError(function(error) {
				trace('Failed to load HTML5 title asset library before title state: ' + Std.string(error));
				titleLibraryReady = true;
				if (splashComplete) complete();
			});
#end
		
		#if VIDEOS_ALLOWED
		var canPlayVid:Bool = false;
		var video = new FunkinVideoSprite();
		video.onFormat(() -> {
			video.setGraphicSize(0, FlxG.height);
			video.updateHitbox();
			video.screenCenter();
			add(video);
		});
		canPlayVid = video.load(Paths.video('intro'));
		#end
		
		initialTimer = FlxTimer.wait(1, () ->
			{
				#if html5
				final introPath:String = 'assets/videos/intro.mp4';
				if (Assets.exists('embedded:' + introPath, AssetType.BINARY))
					Html5Video.play(introPath, function() {}, logoFunc, logoFunc);
				else
					logoFunc();
				#elseif VIDEOS_ALLOWED
				video.onEnd(logoFunc);
				if (canPlayVid) video.play() else logoFunc();
				#else
				logoFunc();
				#end
			});
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (logo != null)
		{
			logo.updateHitbox();
			logo.screenCenter();
		}
		
		if (canSkip && (FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.ENTER || FlxG.mouse.justPressed)) finish();
	}
	
	function logoFunc()
	{
		#if html5
		var nmvText:FlxText = new FlxText(0, 0, FlxG.width, 'NIGHTMARE VISION', 54);
		nmvText.setFormat(Paths.font('vcr.ttf', false), 54, FlxColor.WHITE, FlxTextAlign.CENTER);
		nmvText.screenCenter();
		nmvText.alpha = 0;
		nmvText.scale.set(0.2, 1.25);
		add(nmvText);
		logo = nmvText;
		new FlxTimer().start(0.15, (t:FlxTimer) -> {
			FlxG.sound.volume = 1;
			try FlxG.sound.play(Paths.sound('intro')) catch (_) {}
			nmvText.alpha = 1;
			nmvText.scale.set(0.2, 1.25);
			t.reset(0.06125);
		});
		new FlxTimer().start(0.21125, (t:FlxTimer) -> {
			nmvText.scale.set(1.25, 0.5);
			t.reset(0.06125);
		});
		new FlxTimer().start(0.2725, (t:FlxTimer) -> {
			nmvText.scale.set(1.125, 1.125);
			FlxTween.tween(nmvText.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.elasticOut});
		});
		FlxTimer.wait(1.5225, () -> {
			FlxTween.tween(nmvText.scale, {x: 0.2, y: 0.2}, 1.5, {ease: FlxEase.quadIn});
			FlxTween.tween(nmvText, {alpha: 0}, 1.5, {ease: FlxEase.quadIn});
			FlxTimer.wait(2.3, finish);
		});
		#else
		var folder:Array<String> = [];
		if (!FileSystem.isDirectory('assets/images/branding') || (folder = FileSystem.readDirectory('assets/images/branding')).length == 0) return finish();
		folder = folder.filter(str -> !FileSystem.isDirectory('assets/images/branding/$str'));
		var img = FlxG.random.getObject(folder);
		logo = new FlxSprite().loadGraphic(Paths.image('branding/' + Path.withoutExtension(img)));
		logo.screenCenter();
		logo.visible = false;
		add(logo);
		var step = 0;
		new FlxTimer().start(0.25, (t:FlxTimer) -> {
			switch (step++)
			{
				case 0:
					FlxG.sound.volume = 1;
					FlxG.sound.play(Paths.sound('intro'));
					logo.visible = true;
					logo.scale.set(0.2, 1.25);
					t.reset(0.06125);
				case 1:
					logo.scale.set(1.25, 0.5);
					t.reset(0.06125);
				case 2:
					logo.scale.set(1.125, 1.125);
					FlxTween.tween(logo.scale, {x: 1, y: 1}, 0.25, {ease: FlxEase.elasticOut});
					t.reset(1.25);
				case 3:
					FlxTween.tween(logo.scale, {x: 0.2, y: 0.2}, 1.5, {ease: FlxEase.quadIn});
					FlxTween.tween(logo, {alpha: 0}, 1.5, {ease: FlxEase.quadIn, onComplete: (t:FlxTween) -> FlxTimer.wait(0.8, finish)});
			}
		});
		#end
	}

	function finish()
	{
		initialTimer?.cancel();
		if (finishing) return;
#if html5
		splashComplete = true;
		if (!titleLibraryReady) return;
#end
		complete();
	}
	
	function complete()
	{
		if (finishing) return;
		finishing = true;
		FlxG.autoPause = _cachedAutoPause;
		FlxG.switchState(() -> Type.createInstance(Main.startMeta.initialState, []));
	}
}
