#######################################################
###                                                 ###
###   EPrints YouTube Import Plugin                 ###
###                                                 ###
#######################################################
###                                                 ###
###            Developed by David Tarrant           ###
###                                                 ###
###          Released under the GPL Licence         ###
###           (c) University of Southampton         ###
###                                                 ###
#######################################################

# The location of the DROID JAR file
$c->{"executables"}->{"youtubedl"} = '/usr/bin/youtube-dl';

# Invocation syntax
$c->{"invocation"}->{"youtube-filename"} = '$(youtubedl) --get-filename $(VIDURL)';
$c->{"invocation"}->{"youtube-download"} = '$(youtubedl) -o $(OUTPUT) $(VIDURL)';

$c->{plugins}{"Import::Youtube"}{params}{disable} = 0;

# when a youtube-imported eprint is committed, trigger downloading the video
# (if it doesn't already have it)
$c->add_dataset_trigger(
	"eprint",
	EP_TRIGGER_AFTER_COMMIT,
	\&EPrints::Plugin::Import::Youtube::trigger_download_video
);
