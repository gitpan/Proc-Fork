# Functions to make forking easier.

use strict;
package Proc::Fork;
use Exporter;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION    = 0.05;    # Also change it in the docs
@ISA        = qw(Exporter);
@EXPORT     = qw(parent child error);
@EXPORT_OK  = qw();

# For parent(), child(), and error():
#
# If wantarray is undefined, then the function is the first in line,
# and should die if there is a fork error ($fork_rc is undef), since
# there are no preceding clauses to handle it.
#
# If @_ is 0, then the function is the last in line, and should
# perform the fork.
#
# If there is a scalar parameter, and it's not a "Fork object", then
# the user has almost certainly forgotten the semicolon after the
# final clause.
#
# A "Fork object" is not really an object; it's just a football that
# gets passed around by these routines.  It simply contains the return
# value from fork().  It's blessed to detect user error.


# $fork_rc = Proc::Fork::parent {...code...};
# $fork_rc = Proc::Fork::parent {...code...} $fork_rc;
#
# If the fork() return value indicates that this is the parent
# process, then the code reference is executed (with child pid passed
# as the only parameter), and then waits for the child pid to finish.
#
sub parent (&;$)
	{
	my $parent_code = shift;
	my ($fork_rc, $rc_obj);
	if (@_)    # Fork has allegedly already been done. Check parameter.
		{
		$rc_obj = shift;
		croak "Syntax error (missing semicolon after parent clause?)" unless UNIVERSAL::isa($rc_obj, __PACKAGE__);
		$fork_rc = $$rc_obj;
		}
	else       # Fork hasn't been done yet. Do it.
		{
		$fork_rc = fork;
		$rc_obj  = bless \$fork_rc, __PACKAGE__;
		}

	die "Cannot fork: $!\n"  if !defined $fork_rc  &&  !defined wantarray;
	$parent_code->($fork_rc) if $fork_rc != 0;
	return $rc_obj;
	}


# $fork_rc = Proc::Fork::child {...code...};
# $fork_rc = Proc::Fork::child {...code...} $fork_rc;
#
# If the fork() return value indicates that this is the child process,
# then the code reference is executed.  If the fork() return value
# indicates an error (ie, it's undef), then this function dies, printing $!.
#
sub child (&;$)
	{
	my $child_code = shift;
	my ($fork_rc, $rc_obj);
	if (@_)    # Fork has allegedly already been done. Check parameter.
		{
		$rc_obj = shift;
		croak "Syntax error (missing semicolon after child clause?)" unless UNIVERSAL::isa($rc_obj, __PACKAGE__);
		$fork_rc = $$rc_obj;
		}
	else       # Fork hasn't been done yet. Do it.
		{
		$fork_rc = fork;
		$rc_obj  = bless \$fork_rc, __PACKAGE__;
		}

	die "Cannot fork: $!\n"  if !defined $fork_rc  &&  !defined wantarray;
	$child_code->()  if defined($fork_rc)  &&  $fork_rc == 0;
	return $rc_obj;
	}


# $fork_rc = Proc::Fork::error {...code...};
#
# Proc::Fork::error provides a way to have custom error handling on fork
# failure.  If there is no 'error' clause, then parent() or child()
# will die with a simple error (which will include $!).
#
# If the fork() return value indicates that fork() failed, then the
# code reference is executed.
#
sub error (&;$)
	{
	my $error_code = shift;
	my ($fork_rc, $rc_obj);
	if (@_)    # Fork has allegedly already been done. Check parameter.
		{
		$rc_obj = shift;
		croak "Syntax error (missing semicolon after error clause?)" unless UNIVERSAL::isa($rc_obj, __PACKAGE__);
		$fork_rc = $$rc_obj;
		}
	else       # Fork hasn't been done yet. Do it.
		{
		$fork_rc = fork;
		$rc_obj  = bless \$fork_rc, __PACKAGE__;
		}

	$error_code->()  if !defined $fork_rc;
	return $rc_obj;
	}


1;
__END__

=head1 NAME

Proc::Fork - Simple interface to fork() system call.

=head1 VERSION

This documentation describes version 0.05 of Fork.pm, March 15, 2002.

=head1 SYNOPSIS

 use Proc::Fork;

 child
 {
     # child code goes here.
 }
 parent
 {
     my $child_pid = shift;
     # parent code goes here.
     waitpid $child, 0;
 }
 error
 {
     # Error-handling code goes here (if fork() fails).
 };
 # Note the semicolon at the end. Necessary if other statements follow.

=head1 DESCRIPTION

This package provides a simple interface to fork().

The code for the parent, child, and (optional) error handler are
grouped together in a "fork block".  The clauses may appear in any
order, but they must be consecutive (without any other statements in
between).

The semicolon after the last clause is I<mandatory>, unless the last
clause is at the end of the enclosing block or file.

All three clauses need not be specified.  If the error clause is
omiitted, the program will die with a simple message if a fork error
occurs.  If the parent or child clause is omitted, the respective
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

=head1 FUNCTIONS

=over 4

=item child

 child { ...code... }

This function forks, if the fork has not yet been done, and executes
the code reference passed to it if it discovers that it is the child
process.

If there is a fork error, and there is no error{} clause, this
function dies with a simple error message (which will include $!).

=item parent

 parent { ...code... }

This function forks, if the fork has not yet been done, and executes
the code reference passed to it if it discovers that it is the parent
process.

If there is a fork error, and there is no error{} clause, this
function dies with a simple error message (which will include $!).

=item error

 error { ...code... };

This optional function forks, if the fork has not yet been done, and
executes the code reference passed to it if there was an error (ie, if
fork returned undef).  If an C<error> clause is not used, C<parent> or
C<child> will detect the fork error and will die.

=back

=head1 SYNTAX NOTE

B<Imporant note:> Due to the way Perl 5 parses these functions, there
must be a semicolon after the close brace of the final clause, whether
it be a C<parent>, C<child>, or C<error> clause, unless that closing
brace is the final token of the enclosing block or file.

Fork.pm attempts to detect missing semicolons.  How well this works
remains to be seen.

=head1 SIMPLE EXAMPLE

 # example with IPC via pipe
 use strict;
 use IO::Pipe;
 use Proc::Fork;
 my $p = new IO::Pipe;

 parent
 {
     my $child = shift;
     $p->reader;
     print while (<$p>);
     waitpid $child,0;
 }
 child
 {
     $p->writer;
     print $p "Line 1\n";
     print $p "Line 2\n";
     exit;
 }
 error
 {
     die "That's all folks\n";
 }

=head1 MULTI-CHILD EXAMPLE

 use strict;
 use Proc::Fork;
 use IO::Pipe;

 my $num_children = 5;    # How many children we'll create
 my @children;            # Store connections to them
 $SIG{CHLD} = 'IGNORE';   # Don't worry about reaping zombies

 # Spawn off some children
 for my $num (1..$num_children)
 {
     # Create a pipe for parent-child communication
     my $pipe = new IO::Pipe;

     # Child simply echoes data it receives, until EOF
     child
     {
         $pipe->reader;
         my $data;
         while ($data = <$pipe>)
         {
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
 for (1..20)
 {
     # pick a child at random
     my $num = int rand $num_children;
     my $child = $children[$num];
     print $child "Hey there.\n";
 }

=head1 DAEMON EXAMPLE

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

=head1 INET SERVER EXAMPLE

 # Socket-based server example
 use strict;
 use IO::Socket::INET;
 use Proc::Fork;

 $SIG{CHLD} = 'IGNORE';

 my $server = IO::Socket::INET->new(LocalPort => 7111,  Type => SOCK_STREAM, Reuse => 1, Listen => 10)
     or die "Couln't start server: $!\n";

 my $client;
 while ($client = $server->accept)
 {
     child
     {
         # Service the socket
         sleep(10);
         print $client "Ooga! ", time % 1000, "\n";
         exit;    # child exits. Parent loops to accept another connection.
     }
 }

=head1 EXPORTS

This package exports the following symbols by default.

 child
 error
 parent

=head1 REQUIREMENTS

Carp.pm (included with Perl)

=head1 BUGS

None currently known.  But that doesn't mean much.

=head1 AUTHOR / COPYRIGHT

Eric J. Roode, eric@myxa.com

Copyright (c) 2002 by Eric J. Roode. All Rights Reserved.  This module
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

If you have suggestions for improvement, please drop me a line.  If
you make improvements to this software, I ask that you please send me
a copy of your changes. Thanks.

=cut
