# Data::Hopen::TEMPLATE - template for a hopen module
package # hide from PAUSE
    Data::Hopen::TEMPLATE;

use Data::Hopen;
use strict;
use Data::Hopen::Base;

our $VERSION = '0.000020';

# TODO if using exporter
use parent 'Exporter';
our (@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    @EXPORT = qw();
    @EXPORT_OK = qw();
    %EXPORT_TAGS = (
        default => [@EXPORT],
        all => [@EXPORT, @EXPORT_OK]
    );
}

# TODO if a class
use parent 'TODO';
use Class::Tiny qw(TODO);

# Docs {{{1

=head1 NAME

Data::Hopen::TEMPLATE - The great new Data::Hopen::TEMPLATE

=head1 SYNOPSIS

TODO

=cut

# }}}1

=head1 FUNCTIONS

=head2 todo

=cut

sub todo {
    my $self = shift or croak 'Need an instance';
    ...
} #todo()

# TODO if using a custom import()
#sub import {    # {{{1
#} #import()     # }}}1

#1;
__END__
# vi: set fdm=marker: #
