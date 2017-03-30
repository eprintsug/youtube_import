#$c->{plugins}{"Import::Youtube"}{params}{disable} = 0;
$c->{plugins}{"Export::YoutubeDownload"}{params}{disable} = 0;
$c->{plugins}{"Screen::EPrint::UploadMethod::Youtube"}{params}{disable} = 0;

# Invocation syntax
$c->{"invocation"}->{"youtube-filename"} = '$(youtubedl) --get-filename $(VIDURL)';
$c->{"invocation"}->{"youtube-download"} = '$(youtubedl) -o $(OUTPUT) $(VIDURL)';

$c->add_dataset_trigger(
        "eprint",
        EP_TRIGGER_AFTER_COMMIT,
        \&EPrints::Plugin::Import::Youtube::trigger_download_video
);


# To add a Videos (external) tab to Kultur modify kultur.pl to the following:
#        my @tabs = (
#                # render youtube player
#                &kultur_render_youtube( $session, $dataset, $eprint, \@docs ),
#                # render document tab(s)
#                &kultur_render_documents( $session, $dataset, $eprint, \@docs ),
#                # render metadata tab(s)
#                $metadata_tab
#        );

{
no warnings;

sub kultur_render_youtube
{
	my( $session, $dataset, $eprint, $docs ) = @_;

	my $frag = EPrints::Script::Compiled::run_youtube_player(
			undef, # $self
			{ session => $session },
			[ $eprint ],
		)->[0];

	if ($frag->hasChildNodes) {
		my $title = $session->html_phrase( "document_group_name_youtube" );

		return {
			id => "youtube",
			   title => $title,
			   content => $frag,
		};
	}

	return ();
}

}
