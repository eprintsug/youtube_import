=head1 NAME

EPrints::Plugin::Import::Youtube

=cut

package EPrints::Plugin::Import::Youtube;

use EPrints;

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
	$self->{produce} = [qw( list/eprint )];
	$self->{accept} = [qw( )];
	$self->{advertise} = 1;
	$self->{import_documents} = 1; # 3.2 compat.

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $repo = $self->{session};

	my @ids;

	my $dataset = $opts{dataset};

	my $fh = $opts{"fh"};
 
	while(defined(my $url = <$fh>))
	{
		chomp($url);
		next if $url !~ m{^https?:};

		my $epdata = $self->url_to_epdata($url);

		my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );

		push @ids, $dataobj->id if defined $dataobj;
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

	if( $content =~ /<span[^>]* id="eow-date"[^>]*>\s*([^<]+)</ ) {
		my $time = eval { Time::Piece->strptime($1, "%d %b %Y") };
		if( $@ ) {
			print STDERR "Error parsing time for $url: $@";
		}
		else {
			$epdata->{date} = $time->strftime("%Y-%m-%d");
			$epdata->{date_type} = "published";
		}
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

	# <meta or <link
	if( !$meta{thumbnail_url} && $content =~ /<([^>]+\bitemprop="thumbnailUrl"[^>]*)>/i ) {
		if( $1 =~ /(?:content|href)="([^"]+)"/i ) {
			$meta{thumbnail_url} = $1;
		}
	}

	# HTML 5 scary regexp parsing
	pos($content) = 0;
	while( $content =~ m{<(\w+)([^>]+\bitemscope[^>]+)>(.*?)</\1>}sg ) {
		my( $tag, $contents ) = ($2, $3);
		my $prefix;
		if ($tag =~ /\bitemprop="([^"]+)"/ ) {
			$prefix = $1;
			if( $tag =~ /\bitemtype="([^"]+)/ ) {
				$prefix .= "{$1}";
			}
			while( $contents =~ m{<([^>]+\bitemprop="([^"]+)"[^>]*)>}g ) {
				my $prop = $2;
				if( $1 =~ /(?:content|href)="([^"]+)"/ ) {
					$meta{"$prefix.$prop"} = $1;
				}
			}
		}
	}

	for(values(%meta)) {
		$_ = HTML::Entities::decode_entities($_);
	}

	$meta{thumbnail_url} ||= $meta{'video{http://schema.org/VideoObject}.thumbnailUrl'};

	$epdata->{title} = $meta{"og:title"} || $meta{title};
	$epdata->{abstract} = $meta{"og:description"} || $meta{description};
	$epdata->{keywords} = $meta{keywords};
	$epdata->{official_url} = $meta{"og:url"};
	$epdata->{source} = $meta{"og:url"};

	if( $meta{thumbnail_url} ) {
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

	if( my $name = $meta{"author{http://schema.org/Person}.name"} ) {
		my $family = $name;
		$family =~ s/^(.+)\s+//;
		my $given = $1;
		$epdata->{creators} = [{
			name => { family => $family, given => $given },
			id => $meta{"author{http://schema.org/Person}.url"},
		}];
	}

	if( $url =~ /www.youtube.com/ ) {
		$self->meta_youtube( $epdata );
	}
}

sub meta_youtube
{
	my( $self, $epdata ) = @_;

	my $repo = $self->{repository};

	# fetch the XML descriptive data for the entry
	my $uri = URI->new('http://www.youtube.com/oembed');
	$uri->query_form(
		url => $epdata->{official_url},
		format => 'xml',
	);

	my $doc = eval { $repo->xml->parse_url( $uri ) };
	return if !defined $doc;

	my $root = $doc->documentElement;

	my %meta;

	for($root->childNodes) {
		$meta{$_->nodeName} = $_->firstChild->toString;
	}

	$epdata->{creators} = [{
		name => { family => $meta{author_name} },
		id => $meta{author_url},
	}];

	$epdata->{publisher} = $meta{provider_name};
}

sub trigger_download_video
{
	my %params = @_;

	my $repo = $params{repository};
	my $eprint = $params{dataobj};

	if( $eprint->exists_and_set( "source" )) {
		my $url = $eprint->value( "source" );

		if( $url =~ m{^http://(www\.youtube\.com|vimeo.com)/} ) {
			my $has_copy = 0;
			DOC: foreach my $doc ($eprint->get_all_documents) {
				foreach my $rel (@{$eprint->value( "relation_type" )}) {
					$has_copy = 1, last if $rel eq EPrints::Utils::make_relation( "isYoutubeVideo" );
				}
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
}

sub download_video
{
	my( $self, $eprint ) = @_;

	my $repo = $eprint->{session};

	my $repoid = $repo->{id};
	my $eprintid = $eprint->id;

	my $script = <<"EOP";
use EPrints;

my \$repo = EPrints->new->repository('$repoid');
\$repo->plugin('Import::Youtube')->download_video_daemon('$eprintid');
EOP

	my $otmp = File::Temp->new;
	$repo->system->read_perl_script($repo, $otmp, -e => $script);

	return;
}

sub download_video_daemon
{
	my ($self, $eprintid) = @_;

	my $repo = $self->{session};
	$repo->get_database->{dbh}->{InactiveDestroy} = 1;

	use POSIX;
	POSIX::setsid() or die "setsid: $!";

	my $pid = fork();
	die "fork: $!" if !defined $pid;

	if ($pid) {
		return;
	}

	$repo->get_database->{dbh}->{InactiveDestroy} = 0;
	chdir('/');
	umask 0;
	close(STDIN);

	my $eprint = $repo->dataset('eprint')->dataobj($eprintid);
	return if !defined $eprint; # eprint has gone away

	my $official_url = $eprint->value( "official_url" );

	my $tmp = File::Temp->new;

	EPrints::Platform::read_exec($repo, $tmp, 'youtube-filename',
		VIDURL => $official_url,
		);

	my $filename = <$tmp>;
	chomp($filename);

	$tmp = File::Temp->new;
	$tmp = "$tmp";

	EPrints::Platform::exec($repo, 'youtube-download',
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

	my $repo = $eprint->{session};

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
		elsif( $url =~ m{^https?://vimeo.com/(\d+)} ) {
			$frag->appendChild( $repo->xml->create_element( "iframe",
						width => 500,
						height => 281,
						src => sprintf("http://player.vimeo.com/video/%s", $1),
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

