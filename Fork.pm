#!/usr/bin/perl
use strict;
use warnings;

=head1 NAME

Proc::Fork -- Simple interface to fork() system call.

=head1 VERSION

This documentation describes version 0.1 of Proc::Fork, April 23, 2005

=head1 SYNOPSIS

 use Proc::Fork;

 child {
     # child code goes here.
 }
 parent {
     my $child_pid = shift;
     # parent code goes here.
     waitpid $child_pid, 0;
 }
 retry {
     my $attempts = shift;
     # what to do if if fork() fails:
     # return true to try again, false to abort
     return if $attempts > 5;
     sleep 1, return 1;
 }
 error {
     # Error-handling code goes here
     # (fork() failed and the retry block returned false)
 };
 # Note the semicolon at the end! Necessary in most cases

=head1 DESCRIPTION

This package provides a simple and intuitive interface to fork().

The code for the parent, child, retry handler and error handler are
grouped together in a "fork block".  The clauses may appear in any
order, but they must be consecutive (without any other statements in
between).

The semicolon after the last clause is B<mandatory>, unless the last
clause is at the end of the enclosing block or file.

All four clauses need not be specified.  If the retry clause is
omitted, only one fork will be attempted. If the error clause is
omitted the program will die with a simple message if it can't
retry. If the parent or child clause is omitted, the respective
(parent or child) process will start execution after the final clause.
So if one or the other only has to do some simple action, you need
only specify that one.  For example:

 # spawn off a child process to do some simple processing
 child {
     exec '/bin/ls', '-l';
     die "Couldn't exec ls: $!\n";
 };
 # Parent will continue execution from here
 # ...

If the code in any of the clauses does not die or exit, it will
continue execution after the fork block.

=head1 INTERFACE

=head2 child

 child { ... }

This function executes the code reference passed to it if it
discovers that it is the child process.

=head2 parent

 parent { ... }

This function executes the code reference passed to it if it
discovers that it is the parent process. It passes the child's
PID to the code.

=head2 retry

 retry { ... }

This function executes the code reference passed to it if there
was an error, ie if C<fork> returned undef. If the code returns
true, another C<fork> is attempted. The function passes the number
of fork attempts so far to the code.

This can be used to implement a wait-and-retry logic that may be
essential for some applications like daemons.

If a C<retry> clause is not used, no retries will be attempted and
a fork failure will immediately lead to the C<error> clause being
called.

=head2 error

 error { ... }

This function executes the code reference passed to it if there was
an error, ie C<fork> returned undef and the C<retry> clause returned
false. The function passes the number of forks attempted to the code.

If an C<error> clause is not used, errors will raise an exception
using C<die>.

=head1 SYNTAX NOTE

B<Imporant note:> Due to the way Perl 5 parses these functions, there
must be a semicolon after the close brace of the final clause, whether
it be a C<parent>, C<child>, C<retry> or C<error> clause, unless that
closing brace is the final token of the enclosing block or file.

Proc::Fork attempts to detect missing semicolons.  How well this works
remains to be seen.

=head1 EXAMPLES

=head2 Simple example

 # example with IPC via pipe
 use strict;
 use IO::Pipe;
 use Proc::Fork;
 my $p = new IO::Pipe;

 parent {
     my $child = shift;
     $p->reader;
     print while ( <$p> );
     waitpid $child,0;
 }
 child {
     $p->writer;
     print $p "Line 1\n";
     print $p "Line 2\n";
     exit;
 }
 retry {
     if( $_[0] < 5 ) {
		 sleep 1;
		 return 1;
     }
     return 0;
 }
 error {
     die "That's all folks\n";
 }

=head2 Multi-child example

 use strict;
 use Proc::Fork;
 use IO::Pipe;

 my $num_children = 5;    # How many children we'll create
 my @children;            # Store connections to them
 $SIG{CHLD} = 'IGNORE';   # Don't worry about reaping zombies

 # Spawn off some children
 for my $num ( 1 .. $num_children ) {
     # Create a pipe for parent-child communication
     my $pipe = new IO::Pipe;

     # Child simply echoes data it receives, until EOF
     child {
         $pipe->reader;
         my $data;
         while ( $data = <$pipe> ) {
             chomp $data;
             print STDERR "child $num: [$data]\n";
         }
         exit;
     };

     # Parent here
     $pipe->writer;
     push @children, $pipe;
 }

 # Send some data to the kids
 for ( 1 .. 20 ) {
     # pick a child at random
     my $num = int rand $num_children;
     my $child = $children[$num];
     print $child "Hey there.\n";
 }

=head2 Daemon example

 # daemon example
 use strict;
 use Proc::Fork ();
 use Posix;

 # One-stop shopping: fork, die on error, parent process exits.
 Proc::Fork::parent {exit};

 # Other daemon initialization activities.
 close STDOUT; close STDERR; close STDIN;
 Posix::set_sid() or die "Cannot start a new session: $!\n";
 $SIG{INT} = $SIG{TERM} = $SIG{HUP} = $SIG{PIPE} = \&some_signal_handler;

 # rest of daemon program follows

=head2 Inet server example

 # Socket-based server example
 use strict;
 use IO::Socket::INET;
 use Proc::Fork;

 $SIG{CHLD} = 'IGNORE';

 my $server = IO::Socket::INET->new(
	LocalPort => 7111,
	Type => SOCK_STREAM,
	Reuse => 1,
	Listen => 10,
 ) or die "Couln't start server: $!\n";

 my $client;
 while ($client = $server->accept) {
     child {
         # Service the socket
         sleep(10);
         print $client "Ooga! ", time % 1000, "\n";
         exit; # child exits. Parent loops to accept another connection.
     }
 }

=head1 EXPORTS

This package exports the following symbols by default.

=over 4

=item C<child>

=item C<parent>

=item C<retry>

=item C<error>

=back

=head1 DEPENDENCIES

L<Carp> and L<Exporter>, which are part of the Perl distribution.

=head1 BUGS AND LIMITATIONS

None currently known, for what that's worth.

Please report any bugs or feature requests to
C<bug-proc-fork@rt.cpan.org>, or through the web interface at
L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Proc-Fork>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 AUTHOR

Aristotle Pagaltzis, L<mailto:pagaltzis@gmx.de>

Originally written by Eric J. Roode.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005 by Aristotle Pagaltzis. All Rights Reserved. This
module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

package Proc::Fork;

use Exporter;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION   = 0.1; # Also change it in the docs
@ISA       = qw(Exporter);
@EXPORT    = qw(parent child error retry);
@EXPORT_OK = qw();

# Default behaviour:
# - no code for the parent
# - nor for the child
# - no retry if the first fork attempt fails
# - die with error message on failure
sub _setup {
	my $class = shift;
	bless {
		parent => sub {},
		child  => sub {},
		retry  => sub { 0 },
		error  => sub { die "Cannot fork: $!\n" },
	}, __PACKAGE__;
}

# If there are too many parameters, or what is supposed to be a Proc::Fork
# object is not, then the user has almost certainly forgotten the semicolon
# after the final clause.
sub _configure {
	my ( $key, $val, $obj ) = @_;

	croak "Syntax error (missing semicolon after " . __PACKAGE__ . " clause?)"
		if @_ > 3
		or defined $obj and not UNIVERSAL::isa( $obj, __PACKAGE__ );

	$obj ||= __PACKAGE__->_setup;
	$obj->{ $key } = $val;

	return $obj;
}

# The Proc::Fork object went out of scope, most probably because the
# function that returned it was the last in line.
sub DESTROY {
	my $self = shift;

	my ( $pid, $retry );
	do {
		$pid = fork;
	} while not defined( $pid ) and $self->{ retry }->( ++$retry );

	my ( $dispatch, $param ) =
		  ( not defined $pid ) ? ( "error", $retry )
		: $pid == 0 ? ( "child", )
		: ( "parent", $pid );

	$self->{ $dispatch }->( $param );
}

sub parent (&;$) { unshift @_, "parent"; goto &_configure; }
sub child  (&;$) { unshift @_, "child";  goto &_configure; }
sub error  (&;$) { unshift @_, "error";  goto &_configure; }
sub retry  (&;$) { unshift @_, "retry";  goto &_configure; }

"In simplicity lies beauty.";
