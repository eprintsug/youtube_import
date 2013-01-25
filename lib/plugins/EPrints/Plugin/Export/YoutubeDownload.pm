=head1 NAME

EPrints::Plugin::Export::YoutubeDownload

=cut

package EPrints::Plugin::Export::YoutubeDownload;

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Download source video";
	$self->{accept} = [ 'list/eprint' ];
	$self->{visible} = "staff";
	$self->{suffix} = ".txt";
	$self->{mimetype} = "text/plain; charset=utf-8";
	
	return $self;
}

sub output_dataobj
{
	my( $self, $eprint, %opts ) = @_;

	my $repo = $self->{session};

	EPrints::DataObj::EventQueue->create_unique( $repo, {
			pluginid => "Import::Youtube",
			action => "download_video",
			params => [$eprint->internal_uri],
		});

	return "eprint.".$eprint->id."\n";
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

