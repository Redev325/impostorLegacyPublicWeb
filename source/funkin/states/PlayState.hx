		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);
		
		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		
		camHUD.bgColor = 0x0;
		camOther.bgColor = 0x0;
		
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		
		grpNoteSplashes = new FlxTypedContainer<NoteSplash>();
		
		persistentUpdate = true;
		persistentDraw = true;
		
		SONG ??= Chart.fromPath(Paths.json('test/test'));
		
		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;
		
		arrowSkins = SONG.arrowSkins;
		
		// set up rpc stuff
		rpcDescription = isStoryMode == true ? 'Story Mode' : 'Freeplay';
		rpcPausedDescription = 'Paused - ' + rpcDescription;
		rpcSongName = SONG.song;
		
		scripts.set('isStoryMode', isStoryMode);
		scripts.set('attackCharacter', attackCharacter);
		
		if (SONG.stage == null || SONG.stage.length == 0) SONG.stage = 'stage';
		
		// Check for bf/gf skins
		// SOMEONE GOT THE CODE WRONG IM GONNA FUCKING KILL YOUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU YOU'RE GOING TO DIE
		// i think it was me... im so sorry.
		allowBFSkin = (!isStoryMode && (SONG.allowBFskin ?? true));
		allowGFSkin = (!isStoryMode && (SONG.allowGFskin ?? true));
		allowPet = (!isStoryMode && (SONG.allowPet ?? true));
		
		// Load all global legacy scripts from their actual HTML5 asset location.
		// The project renames assets/legacy/scripts -> assets/scripts, so the generic
		// Paths.getPath() data resolver cannot find these by itself.
		#if html5
		// The browser build can retain an older asset manifest in cache. Only load
		// the global scripts that actually exist in the current Legacy source tree;
		// phantom entries such as lacking.hx must never become runtime scripts.
		final legacyGlobalScripts:Array<String> = [
			'camTweenEvent.hx',
			'cheatMenu.hx',
			'dialogue.hx',
			'mom.hx',
			'rgbPetColors.hx',
			'tasksong.hx',
			'utils.hx'
		];
		for (file in FunkinAssets.readDirectory('assets/scripts'))
		{
			if (!FunkinScript.isHxFile(file) || !legacyGlobalScripts.contains(file)) continue;
			initFunkinScript('gameplay:assets/scripts/' + file);
		}
		#else
		for (file in Paths.listAllFilesInDirectory('scripts', LOOSE).filter(path -> FunkinScript.isHxFile(path)))
		{
			initFunkinScript(file);
		}
		#end
		
		#if html5
		// Sussus Moogus's cutscene is part of the story intro. Start it from the
		// PlayState setup itself so the web build does not depend on the deferred
		// song-script onLoad callback to fire before gameplay begins.
		if (Paths.sanitize(SONG.song) == 'sussus-moogus' && isStoryMode)
		{
			final dialogueScript:Null<FunkinScript> = scripts.getScript('gameplay:assets/scripts/dialogue.hx');
			if (dialogueScript != null && dialogueScript.exists('videoCutscene'))
			{
				try
				{
					dialogueScript.call('videoCutscene', ['week1/sussus-moogus', true]);
				}
				catch (e:Dynamic)
				{
					Logger.log('Failed to start Sussus Moogus HTML5 cutscene: ' + e, ERROR, false);
				}
			}
		}
		#end
		
		stage = new Stage(SONG.stage);
		applyStageData(stage.stageData);
		
		stage.buildStage();
		
		if (stage.runScript(scripts))
		{
			scripts.addScript(stage.script);
			
			Logger.log('script: ' + stage.script.name + ' intialized');
		}
		
		if (isPixelStage) introSoundsSuffix = '-pixel';
		
		if (!ScriptConstants.stopping(scripts.call("onAddSpriteGroups")))
		{
			add(stage);
			stage.add(gfGroup);
			stage.add(dadGroup);
			stage.add(boyfriendGroup);
			stage.add(pet);
		}
		

		
		var gfVersion:String = SONG.gfVersion;
		if (gfVersion == null || gfVersion.length < 1) SONG.gfVersion = gfVersion = 'gf';
		
		if (allowPet)
		{
			pet.loadPet(ClientPrefs.equipment.get('pet'));
			checkStageFlag(pet);
			startPetScript(pet);
		}
		
		if (!stage.stageData.hide_girlfriend)
		{
			gf = new Character((allowGFSkin ? ClientPrefs.equipment.get('speakerSkin') : null) ?? gfVersion);
			checkStageFlag(gf);
			gfGroup.addChar(gf);
			gfGroup.parent = gf;
			startCharacterScript(gf.curCharacter, gf);
		}
		
		dad = new Character(SONG.player2);
		checkStageFlag(dad);
		dadGroup.addChar(dad);
		dadGroup.parent = dad;
		startCharacterScript(dad.curCharacter, dad);
		
		boyfriend = new Character((allowBFSkin ? ClientPrefs.equipment.get('playerSkin') : null) ?? SONG.player1, true);
		checkStageFlag(boyfriend);
		boyfriendGroup.addChar(boyfriend);
		boyfriendGroup.parent = boyfriend;
		startCharacterScript(boyfriend.curCharacter, boyfriend);
		
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}
		else
		{
			camPos.set(opponentCameraOffset[0], opponentCameraOffset[1]);
			camPos.x += dad.getGraphicMidpoint().x + dad.cameraPosition[0];
			camPos.y += dad.getGraphicMidpoint().y + dad.cameraPosition[1];
		}
		
		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null) gf.visible = false;
		}
		
		Conductor.songPosition = -5000;
		
		underlays = new FlxTypedGroup<LaneUnderlay>();
		
		playFields = new FlxTypedGroup<PlayField>();
		add(playFields);
		
		notes = new FlxTypedGroup<Note>();
		add(notes);
		
		playHUD = new funkin.game.huds.PsychHUD(this);
		insert(members.indexOf(playFields), playHUD); // Data told me to do this
		playHUD.cameras = [camHUD];
		
		playHUD.insert(playHUD.underlayOrder, underlays);
		
		meta = Metadata.getSong();
		
		modManager = new ModManager(this);
		
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();
		
		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		
		add(camFollow);
		
		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();
		
		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		
		botplayTxt = new FlxText(400, 55, FlxG.width - 800, "BOTPLAY", 32);
		botplayTxt.setFormat(Paths.DEFAULT_FONT, 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		if (ClientPrefs.downScroll) botplayTxt.y = FlxG.height - botplayTxt.height - 55;
		add(botplayTxt);
		
		notes.cameras = [camHUD];
		playFields.cameras = [camHUD];
		botplayTxt.cameras = [camHUD];
		
		#if html5
		// Song scripts are downloaded into FunkinAssets' HTML5 script cache.
		// Always preserve the song directory when initializing them; passing only
		// the filename (for example "ashes.hx") bypasses that cache and makes
		// FunkinAssets try to resolve a root-level file that does not exist.
		final html5SongName:String = Paths.sanitize(SONG.song);
		final html5SongFolder:String = html5SongName == 'dlow' ? "d'low" : html5SongName;
		for (scriptFile in FunkinAssets.getHtml5SongScripts(SONG.song))