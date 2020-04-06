package EPrints::Plugin::Screen::EPMC::Youtube_Import;

use EPrints::Plugin::Screen::EPMC;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub new
{
      my( $class, %params ) = @_;

      my $self = $class->SUPER::new( %params );

      $self->{actions} = [qw( enable disable configure )];
      $self->{disable} = 0; # always enabled, even in lib/plugins

      $self->{package_name} = "youtube_import";

      return $self;
}

=item $screen->action_enable( [ SKIP_RELOAD ] )

Enable the L<EPrints::DataObj::EPM> for the current repository.

If SKIP_RELOAD is true will not reload the repository configuration.

=cut


sub action_enable
{
	my( $self, $skip_reload ) = @_;

    $self->SUPER::action_enable( $skip_reload );
    my $repo =  $self->{repository};
   
    my $youtube_dl_source = $repo->get_conf("youtube-dl", "source") || "https://yt-dl.org/downloads/latest/youtube-dl";
    my $youtube_dl_target = $repo->get_conf("youtube-dl", "target") || $repo->get_conf("archiveroot")."/bin/youtube-dl";
    $repo->{config}->{enable_web_imports} = 1;

    my $r = EPrints::Utils::wget( $repo, $youtube_dl_source, $youtube_dl_target );
	
    if( !$r->is_success ){
        print STDERR "There may have been an issue downloading youtube-dl: $r->status_line. \n\nMaybe try https://ytdl-org.github.io/youtube-dl/download.html to obtain the binary.\n";    
    }

	$self->reload_config if !$skip_reload;
}

sub action_disable
{
	my( $self, $skip_reload ) = @_;

      	$self->SUPER::action_disable( $skip_reload );

	my $repo = $self->{repository};
}

sub render_messages
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $epm = $self->{processor}->{dataobj};

	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	return $frag if (!$epm->is_enabled());

	#my $youtube_dl = $repository->get_conf( 'executables', 'youtube-dl' );
	my $youtube_dl = $repo->get_conf( "executables", "youtubedl" );

	if (!defined($youtube_dl) || (!-e $youtube_dl)) {
		$frag->appendChild( $repo->render_message( 'error', $self->html_phrase( 'error:not_configured' ) ) );
		return $frag;
	}
	
	$frag->appendChild( $repo->render_message( 'message', $self->html_phrase( 'ready' ) ) );
	
	return $frag;
}

sub allow_configure { shift->can_be_viewed( @_ ) }

sub action_configure
{
	my( $self ) = @_;

	my $epm = $self->{processor}->{dataobj};
	my $epmid = $epm->id;

	foreach my $file ($epm->installed_files)
	{
		my $filename = $file->value( "filename" );
		next if $filename !~ m#^epm/$epmid/cfg/cfg\.d/(.*)#;
		my $url = $self->{repository}->current_url( host => 1 );
		$url->query_form(
			screen => "Admin::Config::View::Perl",
			configfile => "cfg.d/youtube_import.pl",
		);
		$self->{repository}->redirect( $url );
		exit( 0 );
	}

	$self->{processor}->{screenid} = "Admin::EPM";

	$self->{processor}->add_message( "error", $self->html_phrase( "missing" ) );
}



1;
