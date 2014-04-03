#!/usr/bin/evn perl

use strict;
use warnings;

use feature ':5.18';

no utf8;
use bytes;

use DDP;

use IO::Socket::UNIX;
use IO::Socket::INET;

my $socket =
    IO::Socket::INET->new(
        PeerAddr => 'debugmail.io:9025',
    ) or die 'unable to connect server';

#my $socket =
#    IO::Socket::UNIX->new(
#        Peer => '/tmp/socket_minsmptd',
#        Type  => SOCK_STREAM,
#    ) or die 'unable to connect server';


#while (my $result = <$socket>) {
#    print $result;
#    print $socket "Hello!\nNew line!\015\012.\015\012";
#}

while (my $result = <$socket>) {
    print <$socket>;
    print $socket "EHLO debugmail.io\015\012";
}

    print $socket "QUIT\015\012";
