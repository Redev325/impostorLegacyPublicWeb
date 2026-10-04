import flixel.addons.text.FlxTypeText;

import funkin.FunkinAssets;

using StringTools;

typedef DialogueCharacter =
{
	var name:String;
	var asset:String;
	var sound:String;
	var icon:String;
	var boxColor:FlxColor;
	var boxShadeColor:FlxColor;
	var animations:Array<AnimData>;
}

typedef AnimData =
{
	var anim:String;
	var name:String;
	var loop:Bool;
	var offsets:Array<Int>;
}

// Dialogue softcode!
public var hasDialogue:Bool = false;
public var hasDialogueAudio = true;

/**
 * Debug cutscene testing.
**/
public var repeatedCutscenes:Bool = false;

/**
 * other thingies
**/
public var videoCheckStory:Bool = true;

public var skippableVideo:Bool = true;
public var dialogueVideo:Dynamic;
public var skipText:FlxText; // skip dialogue video text
var bgFade:FlxSprite;
var box:RGBSprite;
var bubble:FlxSprite;
var bubble_old:FlxSprite;
var icon:HealthIcon;
var icon_old:HealthIcon;
var boxGroup:FlxSpriteGroup;
var swagDialogue:FlxTypeText;
var rtlDisplayText:FlxText;
var rtlWrapMeasure:FlxText;
var dropText:FlxText;
var dropText_old:FlxText;
var text_old:FlxText;
var dialogueList:Array<Dynamic>;
var curEmote:String = 'happy';
var curCharacter:String = 'bf';
var dialogueEnded:Bool = false;
var curIcon:String = 'bf';
var curSide:Int = 0;
var charMap:Map<String, Dynamic> = new haxe.ds.StringMap();
var blackYnot:FlxSprite;
var vidPlaying:Bool = false;
var dialogueAfter:Bool = false;
var rtlMode:Bool = false;
var rtlFullText:String = "";

#if html5
function addDialogueObject(obj:Dynamic):Void
{
	addToState(obj);
}
#else
function addDialogueObject(obj:Dynamic):Void
{
	add(obj);
}
#end

// dialogue portraits
var portrait:Array<FlxSprite> = [];

function onCreatePost()
{
	final PADDING = 15;
	skipText = new FlxText(PADDING, 0, FlxG.width - PADDING * 2, Lang.str('video_skip'));
	skipText.setFormat(Paths.font("liberbold.ttf"), 25, FlxColor.WHITE, Lang.hasSpecial('rightToLeft') ? 'right' : 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	skipText.borderSize = 2;
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
	if (!skippableVideo) return;
	
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
function speakerAnims(char:String = 'bf')
{
	// oh my fucking god dude
	var loadUp:Bool = false;
	
	var dialogueChar:DialogueCharacter;
	if (charMap.exists(char))
	{
		dialogueChar = charMap.get(char);
	}
	else
	{
		#if html5
		var rawDialogueChar:Null<String> = getHtml5DialogueCharacter(char);
		if (rawDialogueChar == null)
		{
			return portrait[curSide];
		}
		dialogueChar = FunkinAssets.parseJson5(rawDialogueChar);
		#else
		var path:String = Paths.getPath('data/dialogue/' + char + '.json', null, PathsTestMode.NORMAL);
		dialogueChar = FunkinAssets.parseJson5(FunkinAssets.getContent(path));
		#end
		if (dialogueChar == null)
		{
			return portrait[curSide];
		}
		charMap[char] = dialogueChar;
		loadUp = true;
	}
	
	curSide = dialogueChar.side;
	curSound = dialogueChar.sound;
	curIcon = dialogueChar.icon;
	box.rgbGraphics.setColors([FlxColor.fromString(dialogueChar.boxColor), 0xFF666666, FlxColor.fromString(dialogueChar.boxShadeColor)]);
	
	var who:FunkinSprite = portrait[curSide];
	if (loadUp)
	{
		who.loadAtlas('ui/dialogue/characters/${dialogueChar.asset}');
		
		for (b in dialogueChar.animations)
		{
			if (b.loop)
			{
				who.addOffset('${b.anim}-loop', b.offsets[0], b.offsets[1]);
				who.addAnimByPrefix('${b.anim}-loop', b.name, b.fps ?? 24, true);
			}
			
			who.addAnimByPrefix(b.anim, b.name, b.fps ?? 24, b.reset ?? true);
			who.addOffset(b.anim, b.offsets[0], b.offsets[1]);
		}
		
		who.animation.onFinish.add(function(anim:String) {
			if (who.hasAnim('$anim-loop')) who.playAnim('$anim-loop', true);
		});
	}
	
	boxChar = Lang.str(dialogueChar.name, dialogueChar.name);
	return who;
}

/**
	* Hm.
	`oldToo` > Refresh old?
**/
function refreshDialogue(?oldToo = false)
{
	if (dialogueList == null || dialogueList.length == 0)
	{
		dialogueEnded = true;
		goodBialogue();
		return;
	}
	
	if (oldToo)
	{
		if (bubble_old.alpha != 1)
		{
			for (i in [dropText_old, text_old, icon_old, bubble_old])
			{
				i.alpha = 1;
			}
		}
		dropText_old.text = dropText.text;
		text_old.text = rtlMode ? formatArabicDialogueText(rtlFullText) : swagDialogue.text;
		if (rtlMode) Lang.arabicTextFix(text_old);
		icon_old.changeIcon(curIcon);
		text_old.scale.y = getSquish(text_old);
		text_old.updateHitbox();
		FlxG.sound.play(Paths.sound('clickText'), 0.8);
	}
	
	dialogueEnded = false;
	
	// HScript values coming from URLLoader/cached text are Dynamic. Normalize
	// the entry to a real String before any StringTools/indexOf operation so a
	// malformed or missing line can never become an undefined JavaScript value.
	var rawEntry:Dynamic = dialogueList[0];
	var entry:String = rawEntry == null ? '' : Std.string(rawEntry).trim();
	
	while (entry.length == 0 && dialogueList.length > 1)
	{
		dialogueList.remove(dialogueList[0]);
		rawEntry = dialogueList[0];
		entry = rawEntry == null ? '' : Std.string(rawEntry).trim();
	}
	
	if (entry.length == 0)
	{
		dialogueList.resize(0);
		goodBialogue();
		return;
	}
	
	var splitName:Array<String> = entry.split(":");
	if (splitName.length < 3)
	{
		// Ignore malformed dialogue entries instead of indexing missing speaker,
		// emote, or text fields.
		dialogueList.remove(dialogueList[0]);
		refreshDialogue(oldToo);
		return;
	}
	
	curCharacter = Std.string(splitName[1]).trim();
	if (curCharacter.length == 0) curCharacter = 'bf';
	
	curEmote = Std.string(splitName[2]).trim();
	if (curEmote.length == 0) curEmote = 'neutral';
	
	// Never let a missing HTML5 portrait/audio asset prevent the dialogue
	// box and text from appearing. The original desktop script assumes all
	// dialogue assets are synchronous; the web build cannot make that assumption.
	try
	{
		v4SpeakerShit();
	}
	catch (e:Dynamic)
	{
		trace('HTML5 dialogue speaker setup failed: ' + e);
		curSide = 0;
		curSound = 'red';
		curIcon = 'red';
		boxChar = Lang.str('red', 'Red');
		dropText.text = boxChar;
		try icon.changeIcon(curIcon) catch (_) {}
	}
	
	var textStart:Int = curCharacter.length + 3 + curEmote.length;
	var dialogueText:String = textStart < entry.length ? entry.substr(textStart).trim() : '';
	
	// Preserve localized dialogue keys, but never pass null into StringTools.
	var localizedLine:Null<String> = StringTools.contains(dialogueText, 'dialogue_')
		? Lang.str(dialogueText)
		: dialogueText;
	var line:String = localizedLine ?? dialogueText;
	
	if (rtlMode)
	{
		rtlFullText = line;
		rtlDisplayText.text = line;
	}
	swagDialogue.text = line;
	swagDialogue.scale.y = getSquish(swagDialogue);
	if (rtlMode)
	{
		rtlDisplayText.scale.y = swagDialogue.scale.y;
		rtlDisplayText.text = '';
	}
	swagDialogue.resetText(line);
	swagDialogue.start(0.05, true);
	
	var who = portrait[curSide];
	
	try
	{
		who.animation.onLoop.removeAll();
		who.playAnim(curEmote);
	}
	catch (e:Dynamic)
	{
		trace('HTML5 dialogue portrait animation setup failed: ' + e);
	}
	
	swagDialogue.completeCallback = function() {
		dialogueEnded = true;
		if (rtlMode)
		{
			rtlDisplayText.text = formatArabicDialogueText(rtlFullText);
			Lang.arabicTextFix(rtlDisplayText);
		}
		
		who.animation.onLoop.addOnce(function(anim:String) {
			if (who.animation.exists(anim + '-loop'))
			{
				who.animation.play(anim + '-loop', true);
			}
			else
			{
				who.animation.pause();
			}
		});
	};
	
	dialogueList.remove(dialogueList[0]);
}

/**
 * Let us grab this shit at once!
**/
function v4SpeakerShit()
{
	var speaker:FlxSprite = speakerAnims(curCharacter);
	swagDialogue.sounds = [FlxG.sound.load(Paths.sound('dialogue/' + curSound), 0.6)];
	dropText.text = boxChar;
	icon.changeIcon(curIcon);
	
	if (!speaker.visible)
	{
		speaker.visible = true;
		switch (speaker)
		{
			case portrait[2]:
				FlxTween.tween(speaker, {alpha: 1, x: 865}, 0.5, {ease: FlxEase.quadInOut});
			case portrait[0]:
				FlxTween.tween(speaker, {alpha: 1, x: 247}, 0.5, {ease: FlxEase.quadInOut});
			case portrait[1]:
				FlxTween.tween(speaker, {alpha: 1, y: 148}, 0.5, {ease: FlxEase.quadInOut});
		}
	}
}

/** 
 * Run this function to read the songs/SONG_NAME/dialogue.txt file
**/
/**
 * Compatibility helper used by older V5 song scripts.
 * Returns the HTML5-cached dialogue for the active song when available.
 */
public function getHudV5SongDialogue(?song:String):Null<String>
{
	final activeSong:String = song ?? PlayState.SONG?.song ?? '';
	final safeSong:String = Paths.sanitize(activeSong);
	#if html5
	return getHtml5SongDialogue(safeSong);
	#else
	final txtPath:String = Paths.getPath('songs/' + safeSong + '/dialogue.txt', null, PathsTestMode.NORMAL);
	return FunkinAssets.exists(txtPath, TEXT) ? FunkinAssets.getContent(txtPath) : null;
	#end
}

public function readDialogue()
{
	if ((videoCheckStory && !isStoryMode) || PlayState.seenCutscene)
	{
		startCountdown();
		return;
	}
	var activeSong:String = PlayState.SONG?.song ?? '';
	var safeSong:String = Paths.sanitize(activeSong);
	#if html5
	var cachedDialogue:Null<String> = getHtml5SongDialogue(safeSong);
	// Sussus Moogus must still have its real dialogue even when an older
	// browser cache/build is missing the tiny dialogue.txt asset. Keep the
	// source file authoritative when available, with this exact source-text
	// fallback as a last-resort HTML5 safety net.
	if ((cachedDialogue == null || cachedDialogue.trim().length == 0) && safeSong == 'sussus-moogus')
	{
		cachedDialogue = ':red:sad:dialogue_moogus0\n'
			+ ':bf:neutral:dialogue_moogus1\n'
			+ ':gf:suspect:dialogue_moogus2\n'
			+ ':gf:suspect:dialogue_moogus3\n'
			+ ':gf:q:dialogue_moogus4\n'
			+ ':bf:neutral:dialogue_moogus5\n'
			+ ':bf:q:dialogue_moogus6\n'
			+ ':red:sad:dialogue_moogus7\n'
			+ ':gf:happy:dialogue_moogus8\n'
			+ ':gf:mad:dialogue_moogus9\n'
			+ ':red:neutral:dialogue_moogus10\n'
			+ ':bf:happy:dialogue_moogus11\n'
			+ ':red:happy:dialogue_moogus12\n'
			+ ':red:happy:dialogue_moogus13\n'
			+ ':bf:neutral:dialogue_moogus14';
		trace('HTML5 Sussus Moogus dialogue.txt fallback activated');
	}
	if (cachedDialogue != null)
		dialogueList = cachedDialogue.length > 0 ? cachedDialogue.split("\n") : [];
	else
		dialogueList = [];
	#else
	var txt = Paths.getPath('songs/' + safeSong + '/dialogue.txt', null, PathsTestMode.NORMAL);
	dialogueList = CoolUtil.coolTextFile(txt);
	#end
	if (dialogueList.length == 0)
	{
		// A cutscene without dialogue must still release the song into gameplay.
		startCountdown();
		return;
	}
	
	inCutscene = true;
	
	songStartCallback = () -> {
		return Function_Stop;
	}
	if (!repeatedCutscenes) PlayState.seenCutscene = true;
	var naughty:Bool = true;
	hasDialogue = true;
	
	// For some stuff like Arabic
	var rightLeft = Lang.hasSpecial('rightToLeft');
	var gLtR:FlxTextAlign = (rightLeft ? FlxTextAlign.RIGHT : FlxTextAlign.LEFT);
	rtlMode = rightLeft;
	
	var textX:Float = rightLeft ? 300 : 350; // 325.85
	
	// trace('Loading dialogue at ' + txt);
	if (hasDialogueAudio)
	{
		var dialogueMusic:Null<Dynamic> = null;
		#if html5
		final dialogueMusicPath:String = 'assets/music/dialogue/' + safeSong + '.ogg';
		dialogueMusic = FunkinAssets.getSoundUnsafe(dialogueMusicPath);
		#else
		dialogueMusic = Paths.music('dialogue/' + safeSong);
		#end
		#if html5
		if (dialogueMusic != null)
		{
			// Use the audio frontend's volume argument instead of HScript property
			// reflection on FlxSound.volume, which is unreliable on JavaScript.
			funkin.audio.FunkinSound.playMusic(dialogueMusic, 0.8);
		}
		#else
		if (dialogueMusic != null) FlxG.sound.playMusic(dialogueMusic);
		FlxG.sound.music.volume = 0;
		FlxTween.tween(FlxG.sound.music, {volume: 0.8}, 1);
		#end
	}
	
	bgFade = new FlxSprite(-200, -200).makeScaledGraphic(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), 0xFFFFFFFF);
	bgFade.camera = camHUD;
	bgFade.alpha = 0;
	addDialogueObject(bgFade);
	
	FlxTween.tween(bgFade, {alpha: 0.35}, 0.8, {ease: FlxEase.circIn});
	
	// Create the box group.
	boxGroup = new FlxSpriteGroup();
	boxGroup.camera = camHUD;
	addDialogueObject(boxGroup);
	
	// Dialgoue box
	box = new funkin.objects.RGBSprite(0, 431).loadGraphic(Paths.image('ui/dialogue/dialogueBox'));
	box.screenCenter(FlxAxes.X);
	box.x = Math.round(box.x);
	box.rgbGraphics.setColors([0xFFFF1515, 0xFF666666, 0xFF7D0058]);
	
	var port0:FunkinSprite = new FunkinSprite(196.85, 251);
	port0.updateHitbox();
	port0.visible = false;
	port0.alpha = 0;
	
	var port1:FunkinSprite = new FunkinSprite(206.85, 198);
	port1.frames = Paths.getSparrowAtlas('ui/dialogue/characters/gf');
	port1.updateHitbox();
	port1.screenCenter(FlxAxes.X);
	port1.visible = false;
	port1.alpha = 0;
	
	// portrait right
	var port2:FunkinSprite = new FunkinSprite(864.75 + 50, 216);
	port2.updateHitbox();
	port2.visible = false;
	port2.alpha = 0;
	
	portrait.push(boxGroup.add(port0));
	portrait.push(boxGroup.add(port1));
	portrait.push(boxGroup.add(port2));
	
	boxGroup.add(box);
	
	bubble = new FlxSprite(355.85, 496).loadGraphic(Paths.image('ui/dialogue/bubble'));
	bubble_old = new FlxSprite(355.85, 616 /* thats just, evil. oh my god ... */).loadGraphic(Paths.image('ui/dialogue/bubble'));
	for (i in [bubble, bubble_old])
	{
		i.screenCenter(FlxAxes.X);
		i.x = Math.round(i.x + 18.5); // fuck it
		boxGroup.add(i);
	}
	
	icon = new HealthIcon('red', false);
	icon.setPosition(rightLeft ? 920 : 220, (bubble.getMidpoint().y - 75));
	icon.setGraphicSize(Std.int(icon.width * 0.7));
	icon.updateHitbox();
	boxGroup.add(icon);
	
	swagDialogue = new FlxTypeText(textX, 0, Std.int(FlxG.width * 0.5), "", 28);
	swagDialogue.setFormat(Paths.font("liber.ttf"), 26, FlxColor.BLACK, gLtR);
	swagDialogue.visible = !rightLeft;
	
	dropText = new FlxText(textX, 495, Std.int(FlxG.width * 0.5), "", 28);
	dropText.setFormat(Paths.font("liberbold.ttf"), Lang.hasSpecial('smallerDialogue') ? 20 : 30, FlxColor.WHITE, gLtR, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	dropText.borderSize = 2;
	boxGroup.add(dropText);
	swagDialogue.y = dropText.y + 30;
	
	boxGroup.add(swagDialogue);
	rtlDisplayText = new FlxText(textX, swagDialogue.y, Std.int(FlxG.width * 0.5), "", 28);
	rtlDisplayText.setFormat(Paths.font("liber.ttf"), 26, FlxColor.BLACK, gLtR);
	rtlDisplayText.textField.wordWrap = true;
	rtlDisplayText.textField.multiline = true;
	rtlDisplayText.visible = rightLeft;
	boxGroup.add(rtlDisplayText);
	rtlWrapMeasure = new FlxText(textX, swagDialogue.y, Std.int(FlxG.width * 0.5), "", 28);
	rtlWrapMeasure.setFormat(Paths.font("liber.ttf"), 26, FlxColor.BLACK, gLtR);
	rtlWrapMeasure.textField.wordWrap = true;
	rtlWrapMeasure.textField.multiline = true;
	
	// old version of everything
	icon_old = new HealthIcon('red', false);
	icon_old.setPosition(icon.x, (bubble.getMidpoint().y - 75) + 120.8);
	icon_old.setGraphicSize(icon.width);
	icon_old.updateHitbox();
	icon_old.flipX = icon.flipX = rightLeft;
	boxGroup.add(icon_old);
	
	dropText_old = new FlxText(textX, 623 - 9, Std.int(FlxG.width * 0.5), "", 28);
	dropText_old.setFormat(Paths.font("liberbold.ttf"), dropText.size, FlxColor.WHITE, gLtR, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	dropText_old.borderSize = 2;
	boxGroup.add(dropText_old);
	
	text_old = new FlxText(textX, 671 - 21, Std.int(FlxG.width * 0.5), "", 28);
	text_old.setFormat(Paths.font("liber.ttf"), 26, FlxColor.BLACK, gLtR);
	boxGroup.add(text_old);
	
	for (i in [dropText_old, text_old, icon_old, bubble_old, box, icon, bubble])
	{
		i.alpha = 0.001;
	}
	// boxGroup.visible = false;
	
	for (obj in [swagDialogue, rtlDisplayText, rtlWrapMeasure, text_old])
	{
		obj._defaultFormat.leading = (Lang.getFlag('dialogueLeading') ?? 0);
		obj.updateDefaultFormat();
	}
	
	FlxTimer.wait(0.5, function() {
		box.alpha = 1;
		bubble.alpha = 1;
		icon.alpha = 1;
		refreshDialogue();
	});
}

function getAtt(ac:String)
{
	final special:Null<Array<String>> = Lang.current?.special;
	return special != null && ac != null && special.contains(ac);
}

function formatArabicDialogueText(source:String):String
{
	if (!rtlMode || source == null || source.length < 1 || rtlWrapMeasure == null) return source;
	
	var wrappedLines:Array<String> = [];
	for (paragraph in source.split("\n"))
	{
		if (paragraph.trim().length < 1)
		{
			wrappedLines.push("");
			continue;
		}
		
		var words = paragraph.split(" ");
		var currentLine:String = "";
		for (i in 0...words.length)
		{
			var word = words[words.length - 1 - i];
			var candidate = (currentLine.length > 0) ? (word + " " + currentLine) : word;
			rtlWrapMeasure.text = candidate;
			if (currentLine.length > 0 && rtlWrapMeasure.textField.numLines > 1)
			{
				wrappedLines.unshift(currentLine);
				currentLine = word;
			}
			else currentLine = candidate;
		}
		wrappedLines.unshift(currentLine);
	}
	rtlWrapMeasure.text = "";
	return wrappedLines.join("\n");
}

/** 
 * Get dialogue squish to fit with text box.
**/
function getSquish(text)
{
	return Math.min(67 / text.textField.textHeight, 1);
}

/** 
 * Ran only when the song has dialogue and in the dialogue cutscene.
**/
function dialogueUpdate(elapsed:Float)
{
	if (controls.BACK)
	{
		swagDialogue.skip();
		goodBialogue();
	}
	if (controls.ACCEPT)
	{
		if (dialogueEnded)
		{
			if (dialogueList.length > 0) refreshDialogue(true);
			else
			{
				goodBialogue();
			}
		}
		else
		{
			swagDialogue.skip();
		}
	}
}

function goodBialogue()
{
	hasDialogue = false;
	FlxG.sound.music.stop(); // fadeOut(1.5, 0);
	FlxG.sound.play(Paths.sound('panelDisappear'), 0.5);
	FlxTween.tween(bgFade, {alpha: 0}, 0.25,
		{
			ease: FlxEase.circIn
		});
	FlxTween.tween(boxGroup, {y: boxGroup.y + 700}, 0.25,
		{
			ease: FlxEase.circIn,
			onComplete: function() {
				boxGroup.kill();
				charMap.clear();
				bgFade.kill();
			}
		});
		
	startCountdown();
}

function onUpdate(elapsed)
{
	if (hasDialogue) dialogueUpdate(elapsed);
	if (vidPlaying)
	{
		if (IS_HTML5)
		{
			if (ClientPrefs.inDevMode)
			{
				if (controls.UI_RIGHT_P) Html5Video.seek(5);
				if (controls.UI_LEFT_P) Html5Video.seek(-5);
			}
			if (controls.BACK && skippableVideo) Html5Video.skip();
			return;
		}

		if (ClientPrefs.inDevMode)
		{
			if (controls.UI_RIGHT_P) dialogueVideo.time = Math.min(dialogueVideo.time + 5, dialogueVideo.length);
			if (controls.UI_LEFT_P) dialogueVideo.time = Math.min(dialogueVideo.time - 5, 0);
		}
		if (controls.BACK && skippableVideo)
		{
			dialogueVideo.kill();
			dialogueVideo.bitmap.onEndReached.dispatch();
		}
	}
}

function onUpdatePost()
{
	if (swagDialogue != null)
	{
		if (rtlMode && rtlFullText.length > 0)
		{
			var ftLen = swagDialogue.text.length;
			if (ftLen > 0)
			{
				if (ftLen > rtlFullText.length) ftLen = rtlFullText.length;
				var startIndex = rtlFullText.length - ftLen;
				if (startIndex < 0) startIndex = 0;
				rtlDisplayText.text = formatArabicDialogueText(rtlFullText.substring(startIndex));
				Lang.arabicTextFix(rtlDisplayText);
			}
			else rtlDisplayText.text = '';
			rtlDisplayText.updateHitbox();
		}
		else swagDialogue.updateHitbox();
	}
}