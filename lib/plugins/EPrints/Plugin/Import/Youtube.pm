=head1 NAME

EPrints::Plugin::Import::Youtube

=cut

package EPrints::Plugin::Import::Youtube;

use Time::Piece;
use HTML::Entities;

use EPrints::Plugin::Import;
@ISA = qw( EPrints::Plugin::Import );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Youtube";
	$self->{produce} = [qw( dataobj/eprint dataobj/document )];
	$self->{accept} = [qw( )];
	$self->{advertise} = 1;

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $repo = $self->repository;

	my @ids;

	my $fh = $opts{"fh"};
 
	my $url = <$fh>;
	chomp($url);

	my $dataset = $opts{dataset};

	my $epdata = $self->url_to_epdata($url);

	my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );

	if( defined $dataobj )
	{
		# queue archiving the youtube source video
		EPrints::DataObj::EventQueue->create_unique(
			$repo,
			{
				pluginid => $self->get_id,
				action => "download_video",
				params => [$dataobj->internal_uri],
			}
		);
		push @ids, $dataobj->id;
	}

	return EPrints::List->new(
		session => $self->{session},
		dataset => $opts{dataset},
		ids => \@ids
	);
}

sub url_to_epdata 
{
	my ( $self, $url) = @_;

	my $repo = $self->{repository};

	my $epdata = {
			type => "video",
			output_media => "Video",
			ispublished => "pub",
		};

	$self->meta_info( $epdata, $url );

	return $epdata;
}

sub meta_info
{
	my( $self, $epdata, $url ) = @_;

	my $repo = $self->{repository};

	my $ua = LWP::UserAgent->new;

	my $r;
	
	# fetch the Web page and extract its <meta> fields
	$r = $ua->get( $url );

	my $content = $r->content;

	if( $content =~ /<span[^>]* id="eow-date"[^>]*>([^<]+)</ ) {
		$epdata->{date} = Time::Piece
			->strptime($1, "%d %b %Y")
			->strftime("%Y-%m-%d");
		$epdata->{date_type} = "published";
	}

	my %meta;

	pos($content) = 0;
	while( $content =~ /<meta([^>]+)>/g ) {
		my $attr = $1;
		my( $property, $content );
		if( $attr =~ /\b(?:property|name)="([^"]+)"/ ) {
			$property = $1;
		}
		if( $attr =~ /\bcontent="([^"]+)"/ ) {
			$content = $1;
		}
		next if !$property || !$content;
		$meta{$property} = $content;
	}

	for(values(%meta)) {
		$_ = HTML::Entities::decode_entities($_);
	}

	$epdata->{title} = $meta{title};
	$epdata->{abstract} = $meta{description};
	$epdata->{keywords} = $meta{keywords};
	$epdata->{official_url} = $meta{"og:url"};


	# fetch the XML descriptive data for the entry
	my $uri = URI->new('http://www.youtube.com/oembed');
	$uri->query_form(
		url => $epdata->{official_url},
		format => 'xml',
	);

	my $doc = $repo->xml->parse_url( $uri );
	my $root = $doc->documentElement;

	for($root->childNodes) {
		$meta{$_->nodeName} = $_->firstChild->toString;
	}

	$epdata->{creators} = [{
		name => { family => $meta{author_name} },
		id => $meta{author_url},
	}];

	$epdata->{publisher} = $meta{provider_name};


	# fetch the thumbnail
	$r = $ua->get( $meta{thumbnail_url} );

	$meta{thumbnail_url} =~ m{/([^/]+)$};
	my $thumbnail_filename = $1;

	push @{$epdata->{documents}}, {
		main => $thumbnail_filename,
		format => "image",
		mime_type => "image/jpeg",
		files => [{
			filename => $thumbnail_filename,
			filesize => length($r->content),
			mime_type => "image/jpeg",
			_content => $r->content_ref
		}],
	};
}

sub download_video
{
	my( $self, $eprint ) = @_;

	my $repo = $eprint->{session};

	my $official_url = $eprint->value( "official_url" );

	my $tmp = File::Temp->new;

	EPrints->system->read_exec($repo, $tmp, 'youtube-filename',
		VIDURL => $official_url,
		);

	my $filename = <$tmp>;
	chomp($filename);

	$tmp = File::Temp->new;
	$tmp = "$tmp";

	EPrints->system->exec($repo, 'youtube-download',
		VIDURL => $official_url,
		OUTPUT => $tmp,
	);
	open(my $fh, "<", $tmp);

	$eprint->create_subdataobj( "documents", {
		main => $filename,
		format => "video",
		files => [{
			filename => $filename,
			filesize => (-s $fh),
			_content => $fh,
		}],
		relation => [
			{
				type => EPrints::Utils::make_relation( "isYoutubeVideo" ),
				uri => $official_url,
			},
		],
	});

	close($fh);
	unlink($tmp);

	return;
}

package EPrints::Script::Compiled;

=item run_youtube_player EPRINT

If EPRINT's official_url is set and is youtube returns an embedded youtube player for the video.

=cut

sub run_youtube_player
{
	my( $self, $state, $eprint ) = @_;

	$eprint = $eprint->[0];

	my $repo = $eprint->repository;

	my $frag = $repo->xml->create_document_fragment;

	if( $eprint->exists_and_set( "official_url" ) )
	{
		my $url = $eprint->value( "official_url" );
		if( $url =~ m{^https?://www\.youtube\.com/.*\bv=([^;&]+)} )
		{
			$frag->appendChild( $repo->xml->create_element( "iframe",
						width => 420,
						height => 315,
						src => sprintf("http://www.youtube.com/embed/%s", $1),
						frameborder => 0,
						allowfullscreen => "yes"
					) );
		}
	}

	return [ $frag, "XHTML" ];
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

