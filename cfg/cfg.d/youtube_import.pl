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

# The location of the youtube-dl. This will default to the values 
# below which are also used in the enable process to put the most recent 
# youtube-dl in place. Uncomment and change as required.
#$c->{"youtube-dl"}->{"source"} = "https://yt-dl.org/downloads/latest/youtube-dl";
#$c->{"youtube-dl"}->{"target"} = $c->{archiveroot}."/bin/youtube-dl';

$c->{"executables"}->{"youtubedl"} = $c->{"youtube-dl"}->{"target"};

$ENV{LC_ALL} = $ENV{LANG} unless defined $ENV{LC_ALL};

# Invocation syntax
$c->{"invocation"}->{"youtube-filename"} = '$(youtubedl) --get-filename $(VIDURL)';
$c->{"invocation"}->{"youtube-download"} = '$(youtubedl) -f best -o $(OUTPUT) $(VIDURL)';

$c->{plugins}{"Import::Youtube"}{params}{disable} = 0;

# when a youtube-imported eprint is committed, trigger downloading the video
# (if it doesn't already have it)
$c->add_dataset_trigger(
	"eprint",
	EP_TRIGGER_AFTER_COMMIT,
	\&EPrints::Plugin::Import::Youtube::trigger_download_video
);
