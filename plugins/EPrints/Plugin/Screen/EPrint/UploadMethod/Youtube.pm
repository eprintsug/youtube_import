package EPrints::Plugin::Screen::EPrint::UploadMethod::Youtube;

use base qw( EPrints::Plugin::Screen::EPrint::UploadMethod );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{actions} = [qw( add_format )];
	$self->{appears} = [
			{ place => "upload_methods", position => 500 },
		];

	return $self;
}

sub allow_add_format { shift->can_be_viewed }

sub action_add_format
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $ffname = join('_', $self->{prefix}, "url");
	my $eprint = $processor->{eprint};
	my $dataset = $eprint->get_dataset;

	my $plugin = $session->plugin('Import::Youtube',
		Handler => EPrints::CLIProcessor->new(
			message => sub { $processor->add_message(@_) },
			epdata_to_dataobj => sub {
				my ($epdata, %opts) = @_;

				my $documents = delete $epdata->{documents};

				foreach my $doc (@{$documents||[]})
				{
					$eprint->create_subdataobj('documents', $doc);
				}

				foreach my $k (keys %$epdata)
				{
					delete $epdata->{$k} if !$dataset->has_field($k);
					delete $epdata->{$k} if $eprint->exists_and_set($k);
				}

				$eprint->update($epdata);

				$eprint->commit;

				return $eprint;
			},
		),
	);

	my $url = Encode::decode_utf8( $session->param( $ffname ) );
	open(my $fh, "<", \$url);
	$plugin->input_fh(
		dataset => $dataset,
		fh => $fh,
	);
}

sub render
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;

	$f->appendChild( $self->{session}->html_phrase( "Plugin/InputForm/Component/Upload:new_from_url" ) );

	my $ffname = join('_', $self->{prefix}, "url");
	my $file_button = $self->{session}->make_element( "input",
			name => $ffname,
			size => "30",
			id => $ffname,
		);
	my $add_format_button = $self->{session}->render_button(
			value => $self->{session}->phrase( "Plugin/InputForm/Component/Upload:add_format" ),
			class => "ep_form_internal_button",
			name => "_internal_".$self->{prefix}."_add_format"
		);
	$f->appendChild( $file_button );
	$f->appendChild( $self->{session}->make_text( " " ) );
	$f->appendChild( $add_format_button );

	return $f;
}

1;
