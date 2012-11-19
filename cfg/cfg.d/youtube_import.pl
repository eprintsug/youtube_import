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

# when a youtube-imported eprint is committed, trigger downloading the video
# (if it doesn't already have it)
$c->add_dataset_trigger("eprint", EP_TRIGGER_AFTER_COMMIT, sub {
	my( %params ) = @_;

	my $repo = $params{repository};
	my $eprint = $params{dataobj};

	if( $eprint->exists_and_set( "official_url" )) {
		my $url = $eprint->value( "official_url" );

		if( $url =~ m{^http://www\.youtube\.com/} ) {
			my $has_copy = 0;
			foreach my $doc ($eprint->get_all_documents) {
				$has_copy = 1, last if $doc->has_relation( undef, "isYoutubeVideo" );
			}
			if( !$has_copy ) {
				EPrints::DataObj::EventQueue->create_unique( $repo, {
					pluginid => "Import::Youtube",
					action => "download_video",
					params => [$eprint->internal_uri],
				});
			}
		}
	}
});
