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

# You can install youtube-dl from the following link
# https://github.com/rg3/youtube-dl/
# you might need to change the location of the script
$c->{"executables"}->{"youtubedl"} = '/usr/bin/youtube-dl';

# Change from zero to one in order to disable the plugin
$c->{plugins}{"Import::Youtube"}{params}{disable} = 0;

# To add a Videos (external) tab to Kultur modify kultur.pl to the following:
#        my @tabs = (
#                # render youtube player
#                &kultur_render_youtube( $session, $dataset, $eprint, \@docs ),
#                # render document tab(s)
#                &kultur_render_documents( $session, $dataset, $eprint, \@docs ),
#                # render metadata tab(s)
#                $metadata_tab
#        );
