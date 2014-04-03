#!/usr/bin/evn perl

use strict;
use warnings;

use feature ':5.18';

no utf8;
use bytes;

use DDP;

use Coro;
use Coro::Event;
use Coro::Socket;
use Coro::Semaphore;

use IO::Socket::UNIX;

my $MAX_CONNECTS = 5;
my $REQ_TIMEOUT  = 60;
my $RES_TIMEOUT  = 180;
my $MAX_POOL     = 20;
my $SERVER_HOST  = "0.0.0.0";
my $SERVER_PORT  = 2525;

my $SOCKET = '/tmp/simple-smtpd.sock';
unlink $SOCKET;

my $port =
#    Coro::Socket->new(
    Coro::Socket->new_from_fh(
        IO::Socket::UNIX->new(
            Local => $SOCKET,
            Type  => SOCK_STREAM,
            Listen => 1,
        )
#        LocalAddr => $SERVER_HOST,
#        LocalPort => $SERVER_PORT,
#        ReuseAddr => 1,
#        Listen => 1,
    ) or die 'unable to start server';

$SIG{PIPE} = 'IGNORE';

my $connections = Coro::Semaphore->new($MAX_CONNECTS);

async { loop() };

while (1) {
    $connections->down;

    if (my $fh = $port->accept) {
        async_pool {
            print $fh 'Hello, number: ' . $connections->count . ".\n";

            while ($fh) {
                #my $req = $fh->readline("\015\012.\015\012");
                my $req = $fh->readline("\n");

                defined($req) or die;
                chomp($req);
                print $fh "I was told: `$req`\n";

                if ($req eq 'QUIT') {
                    close $fh;
                }
            }

            warn 'hi';
            close $fh;

            $connections->up;
        };
    }
}
