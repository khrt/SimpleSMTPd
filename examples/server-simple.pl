#!/usr/bin/evn perl

use strict;
use warnings;

use lib qw(../lib lib);

use SMTP;

my $smtp = SMPT->new(
    listen => '0.0.0.0:9025',

    log_level => 'debug',
    #log_file => '',

#    user => '',
#    group => '',

    process_message => sub { die 'NOT IMPLEMENTED' }
);

$smtp->process_message(sub {
    my ($self, %msg) = @_;

    # %msg:
    #   - peer
    #   - mailfrom
    #   - recipeints
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
