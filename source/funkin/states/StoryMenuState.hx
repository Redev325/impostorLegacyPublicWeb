			if (onLoadFailed != null) onLoadFailed();
			return;
		}
		
		final playlist:Array<String> = [for (song in week.songs) song[0]];
		if (playlist.length == 0)
		{
			if (onLoadFailed != null) onLoadFailed();
			return;
		}
		
		for (songName in playlist)
		{
			if (songName == null || StringTools.trim(Std.string(songName)).length == 0)
			{
				Logger.log('Story Mode week ' + week.fileName + ' contains an empty song entry', ERROR);
				if (onLoadFailed != null) onLoadFailed();
				return;
			}
		}
		
		PlayState.storyMeta.curWeek = WeekData.weeksList.indexOf(week.fileName);
		PlayState.storyMeta.currency = week.currency;
		PlayState.storyMeta.playlist = playlist;
		PlayState.storyMeta.misses = 0;
		PlayState.storyMeta.score = 0;
		PlayState.isStoryMode = true;
		PlayState.chartingMode = false;
		// A newly entered Story Mode week must be allowed to show its
		// first-song cutscene. The static flag otherwise survives state changes
		// and makes Sussus Moogus jump straight into gameplay.
		PlayState.seenCutscene = false;
		
		WeekData.setDirectoryFromWeek(week);
		
		function startWeek():Void
		{
			try
			{
				final ret = PlayState.prepareForSong(playlist[0], PlayState.storyMeta.difficulty, true);
				if (ret != null)
				{
					Logger.log('Failed to prepare Story Mode song ' + playlist[0] + '\\nException: ' + ret, ERROR);
					if (onLoadFailed != null) onLoadFailed();
					return;
				}
				
				FlxG.switchState(PlayState.new);
			}
			catch (e)
			{
				Logger.log('Failed to start Story Mode week ' + week.fileName + '\\nException: ' + e, ERROR);
				if (onLoadFailed != null) onLoadFailed();
			}
		}
		
		#if html5
		FunkinAssets.loadHtml5SongAssets(playlist[0], startWeek, onLoadFailed);
		#else
		startWeek();
		#end
	}

	var wasPressingCruiser:Bool = false;
	