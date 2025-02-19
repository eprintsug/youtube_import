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
# youtube-dl in place. Change as required, then reenable plugin 
# for change to take effect
$c->{"youtube-dl"}->{"source"} = "https://github.com/yt-dlp/yt-dlp";
$c->{"youtube-dl"}->{"target"} = "/opt/yt-dlp/yt-dlp";

$c->{"executables"}->{"youtubedl"} = $c->{"youtube-dl"}->{"target"};

$ENV{LC_ALL} = $ENV{LANG} unless defined $ENV{LC_ALL};

# Invocation syntax
$c->{"invocation"}->{"youtube-filename"} = '$(youtubedl) --get-title $(VIDURL)';
$c->{"invocation"}->{"youtube-download"} = '$(youtubedl) -S res,ext:mp4:m4a --recode mp4 -f best -o $(OUTPUT) $(VIDURL)';

$c->{plugins}{"Import::Youtube"}{params}{disable} = 0;

$c->{youtube_import}->{mime_to_ext} = {
	'video/x-msvideo' => 'avi',
	'video/mp4' => 'mp4',
	'video/mpeg' => 'mpeg',
	'video/ogg' => 'ogg',
	'video/mp2t' => 'ts',
	'video/webm' => 'webm',
	'video/webp' => 'webp',
	'video/3gpp' => '3gp',
	'video/3gpp2' => '3g2',
};
