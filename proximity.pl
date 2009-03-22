use strict;
use warnings;
use POSIX qw( strftime );
use IO::Socket::UNIX;

my $periscope_dir   = "$ENV{HOME}/Pictures/Periscope";
my $blink           = 40;
my $poll            = 5;
my $he_is_here      = 1;  # somebody must be here, he started the script

while (1) {
    my $duration  = time - time_of_last_movement();
    if ($duration > $blink) {  # no motion in a while
        if ($he_is_here) { # he left!
            warn strftime( "You left at %T\n", localtime( time - $duration ) );
            irssi('away');
        }
        $he_is_here = 0;
    }
    else {  # motion recently
        if ( not $he_is_here ) { # he arrived!
            warn strftime( "You arrived at %T\n\n", localtime );
            irssi('available');
        }
        $he_is_here = 1;
    }
    sleep $poll;
}

sub irssi {
    my ($status) = @_;
    my $command = $status eq 'away'      ? 'away -all Away'
                : $status eq 'available' ? 'away -all'
                : die "Invalid status '$status'"
                ;

    # connect to irssi's socket (from socket-interface.pl)
    my $socket = IO::Socket::UNIX->new(
        Peer => $ENV{HOME} . '/.irssi/socket',
        Type => SOCK_STREAM,
    ) or die $@;

    # send the command
    print $socket "command $command\n" or die "Unable to print to socket: $!";
    my $response = <$socket>;  # wait for the server's response
    close $socket;
    return;
}

sub time_of_last_movement {
    my @pics = sort by_number glob("$periscope_dir/periscope*.jpg");
    return 0 if not @pics;  # hasn't moved yet
    my $motion_at = mtime($pics[-1]);

    # delete all but the most recent image
    unlink $_ for @pics[ 0 .. ( $#pics - 1 ) ];

    return $motion_at;
}

sub by_number {
    my ($a_num) = $a =~ /(\d+)/;
    my ($b_num) = $b =~ /(\d+)/;
    return $a_num <=> $b_num;
}

sub mtime {
    my ($filename) = @_;
    return ( stat $filename )[9];
}
