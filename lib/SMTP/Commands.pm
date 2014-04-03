package SMTP::Commands;

use strict;
use warnings;

use SMTP::Extensions::Size;
#use SMTP::Extensions::8BitMIME;
#use SMTP::Extensions::EnhancedStatusCodes;
#use SMTP::Extensions::Auth::Login
use SMTP::ReplyCodes;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    $self->{extensions} = [
        SMTP::Extensions::Size->new
    ];

    $self;
}

sub extensions { shift->{extensions} }

sub session { shift->{session} }
sub _send { shift->session->_send(@_) }

sub not_implemented {
    my $self = shift;
    $self->_send(COMMAND_UNRECOGNIZED, 'Unrecognized command');
}

sub ehlo {
    my ($self, $args) = @_;

    # "EHLO" SP ( Domain / address-literal ) CRLF
    $args =~ /^EHLO \s (.+) \r\n/imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'ERROR_IN_PARAMETERS');
        return;
    }

    my $domain = $1;

#    ( "250-" Domain [ SP ehlo-greet ] CRLF
#    *( "250-" ehlo-line CRLF )
#    "250" SP ehlo-line CRLF )

    # 250-mx.google.com at your service, [212.31.107.118]
    # 250-SIZE 35882577 # in bytes in DATA
    # 250-8BITMIME
    # 250-STARTTLS
    # 250-ENHANCEDSTATUSCODES
    # 250 CHUNKING

    my @extensions;
    foreach my $ext (@{ $self->extensions }) {
        push @extensions, [$ext->ehlo];
    }

    $self->session->done('HELO');
    $self->_send(
        OK, [['Privet %s, what you wish?', $domain], @extensions]
    );
}

sub helo {
    my ($self, $args) = @_;

    # "HELO" SP Domain CRLF
    $args =~ /^HELO \s (\p{Alnum}+) \r\n/imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'ERROR_IN_PARAMETERS');
        return;
    }

    my $domain = $1;

    $self->session->done('HELO');
    $self->_send(OK, 'Privet %s, what you wish?', $domain);
}

sub mail {
    my ($self, $args) = @_;

    # ehlo/helo first
    unless (0) {
        $self->_send(BAD_SEQUENCE_OF_COMMANDS, 'send EHLO/HELO first')
    }

    $args =~ m/
        # "MAIL FROM:" Reverse-path
        ^MAIL FROM: <([^>]+)>
        # [SP Mail-parameters] CRLF
        \s? (.+)? \r\n
    /imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'ERROR_IN_PARAMETERS');
        return;
    }

    my ($from, $params) = ($1, $2);

    $self->session->data->{from} = $from;
    #$self->session->{} = $params;

    $self->session->done('MAIL');
    $self->_send(OK, 'OK');
}

sub rcpt {
    my ($self, $args) = @_;

    # needs MAIL

    # RCPT TO:<forward-path> [ SP <rcpt-parameters> ] <CRLF>
    my $recipients;

    $self->session->data->{recipients} = $recipients;

    $self->session->done('RCPT');
    $self->_send(OK, 'OK');
}

sub data {
    my ($self, $fh, $args) = @_;

    # needs RCPT
}

sub rset {
    my ($self, $fh, $args) = @_;

    # This command specifies that the current mail transaction will be aborted.
    #
    # Any stored sender, recipients, and mail data MUST be discarded,
    # and all buffers and state tables cleared.
    #
    # The receiver MUST send a "250 OK" reply to a RSET command with no arguments.

    $self->session->clean;
    $self->_send(OK, 'OK');
}

sub noop {
    my $self = shift;
    $self->_send(OK, 'OK');
}

sub quit {
    my $self = shift;
    $self->_send(CLOSING_TRANSMISSION, 'Thank you, come again!');
    close $self->session->fh;
}

sub vrfy {
    my ($self, $args) = @_;

    # "VRFY" SP String CRLF
    $args =~ /^VRFY \s (.+) \r\n/imsx;
    $self->_send(CANNOT_VRFY_USER, 'As you wish!');
}

1;
