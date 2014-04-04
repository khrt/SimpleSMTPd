#!/usr/bin/evn perl

use strict;
use warnings;

use lib qw(../lib lib);

use SMTP;

my $smtp = SMTP->new(
    listen => '127.0.0.1:9025',
    #unix => '/tmp/simple-smtpd.sock',

    log_level => 'debug',
    #log_file => '',

#    user => '',
#    group => '',

    process_message => sub { die 'NOT IMPLEMENTED' }
);

$smtp->process_message(sub {
    my %msg = @_;

    use DDP;
    p %msg;

    # %msg:
    #   - peer
    #   - mailfrom
    #   - recipients
    #   - data

});

# EHLO
# HELO
# MAIL
# RCPT
# DATA
# RSET
# NOOP
# QUIT
# VRFY
#$smtp->on('ehlo', sub {});
#$smtp->on('helo', sub {});

$smtp->run;
