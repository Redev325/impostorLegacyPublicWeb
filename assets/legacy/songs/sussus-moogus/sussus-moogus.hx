function onLoad()
{
	// HTML5 launches this intro natively from PlayState so the browser video
	// is not lost between asynchronous Story Mode loading and HScript startup.
	if (!IS_HTML5)
		videoCutscene('week1/sussus-moogus', true);
}