package SMTP::Commands;

use strict;
use warnings;

use SMTP::Extensions::Size;
#use SMTP::Extensions::8BitMIME;
#use SMTP::Extensions::EnhancedStatusCodes
#use SMTP::Extensions::Auth::Login
use SMTP::ReplyCodes;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub session { shift->{session} }
sub _send { shift->session->_send(@_) }

sub not_implemented {
    my $self = shift;
    $self->_send(COMMAND_UNRECOGNIZED, 'Unrecognized command');
}

sub ehlo {
    my $self = shift;
    $self->_send(COMMAND_NOT_IMPLEMENTED, 'BYE-BYE');

#    ( "250-" Domain [ SP ehlo-greet ] CRLF
#    *( "250-" ehlo-line CRLF )
#    "250" SP ehlo-line CRLF )

    # 250-mx.google.com at your service, [212.31.107.118]
    # 250-SIZE 35882577 # in bytes in DATA
    # 250-8BITMIME
    # 250-STARTTLS
    # 250-ENHANCEDSTATUSCODES
    # 250 CHUNKING
}

sub helo {
    my $self = shift;
    # TODO: name, address
    $self->_send(OK, '%s %s is ready', 'ADDRESS', 'NAME');
}

sub mail {
    my ($self, $args) = @_;

    # ehlo/helo first

    unless ($args) {
        $self->_send(ERROR_IN_PARAMETERS, 'TODO:');
        return;
    }

    $args =~ m/
        # "MAIL FROM:" Reverse-path
        ^FROM: <([^>]+)>
        # [SP Mail-parameters] CRLF
        (.+)?
    /msx;

    my ($from, $params) = ($1, $2);

    unless ($from) {
        return;
    }

    $self->session->store(from => $from);
    #$self->session->{} = $params;

    $self->_send('%d OK', OK);
}

sub rcpt {
    my ($self, $args) = @_;

    # ehlo/helo
    # MAIL

    # RCPT TO:<forward-path> [ SP <rcpt-parameters> ] <CRLF>
    my $recipients;

    $self->session->store(recipients => $recipients);
    $self->_send('%d OK', OK);
}

sub data {
    my ($self, $fh, $args) = @_;

    # ehlo/helo
    # MAIL
    # RCPT
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
   printf $fh "%d OK\n", OK;
}

sub noop {
    my $self = shift;
    $self->_send('%d OK', OK);
}

sub quit {
    my $self = shift;
    $self->_send('%d OK', CLOSING_TRANSMISSION);
    close $self->session->fh;
}

sub vrfy {
    my ($self, $fh, $args) = @_;
    # vrfy = "VRFY" SP String CRLF
    $self->_send('%d Don\'t give up!', CANNOT_VRFY_USER);
}

1;
