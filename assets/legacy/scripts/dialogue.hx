	skipText.y = FlxG.height - skipText.height - (PADDING * (3 / 4));
	skipText.zIndex = 12;
}

function onVidEnd()
{
	hideCaption();
	vidPlaying = false;
	if (IS_HTML5)
	{
		// The DOM video has already been cleaned up by Html5Video.finish().
		// Keep the game cameras explicitly visible and defer the gameplay/dialogue
		// handoff to the next Flixel tick instead of mutating game state directly
		// from the browser's media-ended event.
		Html5Video.stop();
		dialogueVideo = null;
		camGame.visible = true;
		camHUD.visible = true;
		camOther.visible = true;
		skipText.visible = false;

		new FlxTimer().start(0, function(_) {
			try
			{
				if (dialogueAfter && (PlayState.isStoryMode || !videoCheckStory))
					readDialogue();
				else
					startCountdown();
			}
			catch (e:Dynamic)
			{
				trace('HTML5 post-cutscene handoff error: ' + e);
				try startCountdown() catch (fallback:Dynamic) trace('HTML5 countdown fallback error: ' + fallback);
			}
		});
		return;
	}
	dialogueVideo.destroy();
	camGame.visible = true;
	skipText.visible = false;
	if (dialogueAfter && (PlayState.isStoryMode || !videoCheckStory))
		readDialogue();
	else
		startCountdown();
	if (blackYnot != null) FlxTween.tween(blackYnot, {alpha: 0}, 0.5, {onComplete: function() blackYnot.kill()});
}

public function videoCutscene(?vid:String = 'sussus-moogus', ?dAfter:Bool, ?canSkip:Bool, ?onEnd:Void->Void, ?onFormat:Void->Void)
{
	if (IS_HTML5)
	{
		// The HTML5 PlayState can start Sussus Moogus before the song script's
		// onLoad runs. Ignore a second request from that song script while the
		// first DOM video is already active.
		if (dialogueVideo != null || vidPlaying) return;
		if ((videoCheckStory && !isStoryMode) || PlayState.seenCutscene)
		{
			startCountdown();
			return;
		}

		skippableVideo = (canSkip ?? true);
		dialogueAfter = (dAfter ?? true);
		if (!dialogueAfter) PlayState.seenCutscene = true;
		inCutscene = true;
		songStartCallback = () -> return Function_Stop;
		vidPlaying = false;
		// HTML5 uses a real DOM video layer with its own guaranteed-black backdrop.
		// Keep the Flixel game camera visible underneath it so the game is restored
		// automatically as soon as the DOM video is removed.
		final videoPath:String = resolveHtml5VideoPath(vid);
		dialogueVideo = videoPath;
		final ready:Void->Void = function() {
			vidPlaying = true;
			textFade();
			if (onFormat != null) onFormat();
		};
		final ended:Void->Void = function() {
			if (onEnd != null) onEnd();
			onVidEnd();
		};
		if (!Html5Video.play(videoPath, ready, ended, ended))
			onVidEnd();
		return;
	}

	if ((videoCheckStory && !isStoryMode) || PlayState.seenCutscene) return;
	songStartCallback = () -> return Function_Stop;
	skippableVideo = (canSkip ?? true);
	dialogueAfter = (dAfter ?? true);
	if (!dialogueAfter) PlayState.seenCutscene = true;
	blackYnot = new FlxSprite().makeScaledGraphic(FlxG.width + 3, FlxG.height, FlxColor.BLACK);
	blackYnot.camera = camOther;
	addDialogueObject(blackYnot);
	dialogueVideo = new FunkinVideoSprite();
	dialogueVideo.onFormat(() -> {
		vidPlaying = true;
		dialogueVideo.camera = camOther;
		dialogueVideo.setGraphicSize(0, FlxG.height);
		dialogueVideo.antialiasing = ClientPrefs.globalAntialiasing;
		dialogueVideo.updateHitbox();
		dialogueVideo.screenCenter();
		camGame.visible = false;
		textFade();
	});
	addDialogueObject(dialogueVideo);
	if (onEnd != null) dialogueVideo.onEnd(onEnd);
	if (onFormat != null) dialogueVideo.onFormat(onFormat);
	dialogueVideo.onEnd(onVidEnd);
	if (dialogueVideo.load(Paths.video(Paths.sanitize(vid)))) dialogueVideo.delayAndStart();
	else
	{
		if (onEnd != null) onEnd();
		onVidEnd();
	}
}

public function textFade()
{
	if (!skippableVideo || skipText == null) return;
	
	skipText.visible = true;
	skipText.alpha = 0;
	FlxTween.tween(skipText, {alpha: .5}, 2, {ease: FlxEase.sineInOut});
	FlxTween.tween(skipText, {alpha: 0}, 3, {startDelay: 4, ease: FlxEase.sineInOut});
	
	skipText.camera = camOther;
	addDialogueObject(skipText);
}

/**
 * The most disgusting code of all time. Okay so like. Imagine this: We grab the character from data/dialogue/ and load it but ONLY if it already exists.
 * This code is really bad but nothing in this mod uses more than 3 characters for dialogue total so I don't care.
 * I have not tested if more than 3 work. Please don't do that.
**/