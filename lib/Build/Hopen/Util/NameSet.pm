# Build::Hopen::Util::NameSet - set of strings and regexps
package Build::Hopen::Util::NameSet;
use Build::Hopen;
use Build::Hopen::Base;
#use parent 'Exporter';

our $VERSION = '0.000003'; # TRIAL

# Docs {{{1

=head1 NAME

Build::Hopen::Util::NameSet - set of names (strings or regexps)

=head1 SYNOPSIS

NameSet stores strings and regexps, and can quickly tell you whether
a given string matches one of the stored strings or regexps.

=cut

# }}}1

=head1 FUNCTIONS

=head2 new

Create a new instance.  Usage: C<< Build::Hopen::Util::Nameset->new(...) >>.
The parameters are as L</add>.

=cut

sub new {
    my $class = shift or croak 'Call as ' . __PACKAGE__ . '->new(...)';
    my $self = bless { _strings => [], _regexps => [], _RE => undef }, $class;
    $self->add(@_) if @_;
    return $self;
} #new()

=head2 add

Add one or more strings or regexps to the NameSet.  Usage:

    $instance->add(x1, x2, ...)

where each C<xn> can be a scalar, regexp, arrayref (processed recursively)
or hashref (the keys are added and the values are ignored).

=cut

sub add {
    my $self = shift or croak 'Need an instance';
    return unless @_;
    $self->{_RE} = undef;   # dirty the instance

    foreach my $arg (@_) {
        if(!ref $arg) {
            push @{$self->{_strings}}, "$arg";
        } elsif(ref $arg eq 'Regexp') {
            push @{$self->{_regexps}}, $arg;
        } elsif(ref $arg eq 'ARRAY') {
            $self->add(@$arg);
        } elsif(ref $arg eq 'HASH') {
            $self->add(keys %$arg);
        } else {
            use Data::Dumper;
            croak "I don't know how to handle this: " . Dumper($arg)
        }
    }
} #add()

=head2 contains

Return truthy if the NameSet contains the argument.  Usage:
C<< $set->contains('foo') >>.

=cut

sub contains {
    my $self = shift or croak 'Need an instance';
    $self->{_RE} = $self->_build unless $self->{_RE};   # Clean
    hlog { $self->{_RE} };
    return shift =~ $self->{_RE};
} #contains()

=head2 smartmatch overload

For convenience, C<< 'foo' ~~ $nameset >> invokes
C<< $nameset->contains('foo') >>.  This is inspired by the Raku behaviour,
in which C<< $x ~~ $y >> calls C<< $y.ACCEPTS($x) >>

=cut

use overload
    fallback => 1,
    '~~' => sub {
        my ($self, $other, $swap) = @_;
        hlog { 'Smartmatch' . ($swap ? ' (swapped)' : '') };
        return $self->contains($other);
    };

=head2 _build

(Internal) Build a regex from all the strings and regexps in the set.
Returns the new regexp --- does not mutate $self.

In the current implementation, strings are matched case-sensitively.
Regexps are matched with whatever flags they were compiled with.

=cut

sub _build {
    my $self = shift or croak 'Need an instance';

    my $strs = join '|', map { quotemeta } @{$self->{_strings}};
    my $str = join '|', @{$self->{_regexps}}, $strs;
        # Each regexp stringifies with surrounding parens, so we
        # don't need to add any.

    return $str ? qr/$str/ : qr/(*FAIL)/;
        # If $str is empty, the nameset is empty (`(*FAIL)`).  Otherwise,
        # qr// would match anything.
} #_build()

1;
__END__
# vi: set fdm=marker: #
