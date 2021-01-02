#!perl
# lib/Data/Hopen.pm: utility routines for hopen(1).  This file is also the
# source of the repo's README.md, which is autogenerated from this POD.

package Data::Hopen;
use strict;
use Data::Hopen::Base;

use parent 'Exporter';

# TODO move more of these to a separate utility package?
# Probably keep hnew, hlog, $VERBOSE, and $QUIET here.
use vars::i {
    '@EXPORT' => [qw(hnew hlog getparameters)],
                                #v * => can be localized
    '@EXPORT_OK' => [qw(loadfrom *VERBOSE *QUIET UNSPECIFIED NOTHING explainvar
                        hlog_level_names)],
};
use vars::i '%EXPORT_TAGS' => {
    default => [@EXPORT],
    v => [qw(*VERBOSE *QUIET)],
    all => [@EXPORT, @EXPORT_OK],
};

use Data::Hopen::Util::NameSet;
use Getargs::Mixed;
use Storable ();

our $VERSION = '0.000020';

# Docs {{{1

=head1 NAME

Data::Hopen - A dataflow library with first-class edges

=head1 SYNOPSIS

C<Data::Hopen> is a dataflow library that runs actions you specify, moves data
between those actions, and permits transforming data as the data moves.  It is
the underlying engine of the L<App::hopen> cross-platform software build
generator, but can be used for any dataflow task that can be represented as a
directed acyclic graph (DAG).

=head1 INSTALLATION

Easiest: install C<cpanminus> if you don't have it - see
L<https://metacpan.org/pod/App::cpanminus#INSTALLATION>.  Then run
C<cpanm Data::Hopen>.

Manually: clone or untar into a working directory.  Then, in that directory,

    perl Makefile.PL
    make
    make test

(you may need to install dependencies as well -
see L<https://www.cpan.org/modules/INSTALL.html> for resources).
If all the tests pass,

    make install

If some of the tests fail, please check the issues and file a new one if
no one else has reported the problem yet.

=head1 VARIABLES

Not exported by default, except as noted.

=head2 $VERBOSE

Set to a positive integer to get debug output on stderr from hopen's internals.
The higher the value, the more output you are likely to get.  See also L</hlog>.

The initial value is taken from environment variable C<HOPEN_VERBOSITY>,
and defaults to 0 if that variable is not present.

=head2 $QUIET

Set to truthy to suppress output.  Quiet overrides L</$VERBOSE>.

=head2 @hlog_level_names

Lists of hlog level human-readable verbosity names.  If you change them,
keep them to five characters or less each.

=cut

# }}}1

use vars::i {
    '$VERBOSE' => 0+ ($ENV{HOPEN_VERBOSITY} // '0'),
    '$QUIET' => false,
    '@hlog_level_names' => [qw(NONE info debug log trace peek)],
};

=head1 FUNCTIONS

All are exported by default unless indicated.

=head2 hnew

Creates a new Data::Hopen instance.  For example:

    hnew DAG => 'foo';

is the same as

    Data::Hopen::G::DAG->new( name => 'foo' );

The first parameter (C<$class>) is an abbreviated package name.  It is tried
as the following, in order.  The first one that succeeds is used.

=over

=item 1.

C<Data::Hopen::G::$class>.  This is tried only if C<$class>
does not include a double-colon.

=item 2.

C<Data::Hopen::$class>

=item 3.

C<$class>

=back

The second parameter
must be the name of the new instance.  All other parameters are passed
unchanged to the relevant constructor.

=cut

sub hnew {
    my $class = shift or croak 'Need a class';
    my @stems = ('Data::Hopen::G::', 'Data::Hopen::', '');
    shift @stems if $class =~ /::/;

    my $found_class = false;

    foreach my $stem (@stems) {
        eval "require $stem$class";
        next if $@;
        $found_class = "$stem$class";
        my $instance = "$found_class"->new('name', @_);
            # put 'name' in front of the name parameter.
        return $instance if $instance;
    }

    if($found_class) {
        croak "Could not create instance for $found_class";
    } else {
        croak "Could not find class for $class";
    }
} #hnew()

=head2 hlog

Log information if L</$VERBOSE> is set.  Usage:

    hlog { <list of things to log> } [optional min verbosity level (default 1)];

The items in the list are joined by C<' '> on output, and a C<'\n'> is added.
Each line is prefixed with C<'# '> for the benefit of test runs, and with
its verbosity level name from L</@hlog_level_names>

The list is in C<{}> so that it won't be evaluated if logging is turned off.
It is a full block, so you can run arbitrary code to decide what to log.
If the block returns an empty list, hlog will not produce any output.
However, if the block returns at least one element, hlog will produce at
least a C<'# '>.

The message will be output only if L</$VERBOSE> is at least the given minimum
verbosity level (1 by default).

If C<< $VERBOSE > 2 >>, the filename and line from which hlog was called
will also be printed.

=cut

sub hlog (&;$) {
    return if $QUIET;
    my $level = ($_[1] // 1);
    return unless $VERBOSE >= $level;

    my @log = &{$_[0]}();
    return unless @log;

    chomp $log[$#log] if $log[$#log];
    # TODO add an option to number the lines of the output
    my $levelname = sprintf("%-6s", $hlog_level_names[$level] // $level);
    my $msg = (join(' ', @log)) =~ s/^/# $levelname /gmr;
    if($VERBOSE>2) {
        my ($package, $filename, $line) = caller;
        $msg .= " (at $filename:$line)";
    }
    say STDERR $msg;
} #hlog()

=head2 getparameters

An alias of the C<parameters()> function from L<Getargs::Mixed>, but with
C<-undef_ok> set.

=cut

my $GM = Getargs::Mixed->new(-undef_ok => true);

sub getparameters {
    unshift @_, $GM;
    goto &Getargs::Mixed::parameters;
} #getparameters()

=head2 loadfrom

(Not exported by default) Load a package given a list of stems.  Usage:

    my $fullname = loadfrom($name[, @stems]);

Returns the full name of the loaded package, or falsy on failure.
If C<@stems> is omitted, no stem is used, i.e., C<$name> is tried as-is.

=cut

sub loadfrom {
    my $class = shift or croak 'Need a class';

    foreach my $stem (@_, '') {
        hlog { loadfrom => "$stem$class" } 3;
        eval "require $stem$class";
        if($@) {
            hlog { loadfrom => "$stem$class", 'load result was', $@ } 3;
        } else {
            return "$stem$class";
        }
    }

    return undef;
} #loadfrom()

=head2 explainvar

Return a human-readable string saying, at a high level, what C<$_[0]>
(or C<$_>, when no args are given) is.  Mostly for use in debugging.

=cut

sub explainvar :prototype(_) {
    my $x = shift;
    return !defined $x ? '<undef>' : (lc ref $x) || 'scalar';
}

=head1 CONSTANTS

=head2 UNSPECIFIED

A L<Data::Hopen::Util::NameSet> that matches any non-empty string.
Always returns the same reference, so that it can be tested with C<==>.

=cut

my $_UNSPECIFIED = Data::Hopen::Util::NameSet->new(qr/.(*ACCEPT)/);
sub UNSPECIFIED () { $_UNSPECIFIED };

=head2 NOTHING

A L<Data::Hopen::Util::NameSet> that never matches.  Always returns the
same reference, so that it can be tested with C<==>.

=cut

my $_NOTHING = Data::Hopen::Util::NameSet->new();
sub NOTHING () { $_NOTHING };

1; # End of Data::Hopen
__END__

# Rest of docs {{{1

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Hopen
    perldoc hopen

You can also look for information at:

=over

=item * GitHub (report bugs here)

L<https://github.com/cxw42/hopen>

=item * MetaCPAN

L<https://metacpan.org/release/Data-Hopen>

=back

=head1 INSPIRED BY

=over

=item *

L<Luke|https://github.com/gvvaughan/luke>

=item *

a bit of L<Ant|https://ant.apache.org/>

=item *

a tiny bit of L<Buck|https://buckbuild.com/concept/what_makes_buck_so_fast.html>

=item *

my own frustrations working with CMake.

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018--2019 Christopher White, C<< <cxwembedded at gmail.com> >>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program; if not, write to the Free
Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

=cut

# }}}1
# vi: set fdm=marker:
