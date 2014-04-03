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

sub _parse_esmtp_params {
    my ($self, $str) = @_;
    return if not $str;

    # esmtp-keyword  = (ALPHA / DIGIT) *(ALPHA / DIGIT / "-")
    # esmtp-value    = 1*(%d33-60 / %d62-126)
    #               ; any CHAR excluding "=", SP, and control
    #               ; characters.  If this string is an email address,
    #               ; i.e., a Mailbox, then the "xtext" syntax [32]
    #               ; SHOULD be used.

    my %params;
    while ($str =~ /([[:alpha:][:digit:]-]+)=([^\s=])/gmsx) {
        $params{$1} = $2;
    }

    \%params;
}

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

    # ( "220-" (Domain / address-literal)
    # [ SP textstring ] CRLF
    # *( "220-" [ textstring ] CRLF )
    # "220" [ SP textstring ] CRLF )

    my @extensions;
    foreach my $ext (@{ $self->extensions }) {
        push @extensions, [$ext->ehlo];
    }

    $self->session->store(ehlo => $domain);
    $self->_send(OK, [['Privet %s, what you wish?', $domain], @extensions]);
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

    $self->session->store(helo => $domain);
    $self->_send(OK, 'Privet %s, what you wish?', $domain);
}

sub mail {
    my ($self, $args) = @_;

    if (!$self->session->get('helo') || $self->session->get('ehlo')) {
        $self->_send(BAD_SEQUENCE_OF_COMMANDS, 'send EHLO/HELO first');
    }

    # Mail-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "MAIL FROM:" Reverse-path [SP Mail-parameters] CRLF
    $args =~ m/^MAIL FROM: <([^>]+)> \s? (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'ERROR_IN_PARAMETERS');
        return;
    }

    my ($from, $params) = ($1, $self->_parse_esmtp_params($2));

    $self->session->store(mail => $from);
    $self->session->store(mail_parameters => $params);

    $self->session->data('MAIL');
    $self->_send(OK, 'OK');
}

sub rcpt {
    my ($self, $args) = @_;

    # needs MAIL
    unless ($self->session->get('mail')) {
        $self->_send(BAD_SEQUENCE_OF_COMMANDS, 'send MAIL first')
    }

    # Rcpt-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "RCPT TO:" ( "<Postmaster@" Domain ">" / "<Postmaster>" / Forward-path ) [SP Rcpt-parameters] CRLF
    $args =~ /^RCPT TO: (.+) \s (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'error_in_parameters');
        return;
    }

    my ($recipients, $params) = ($1, $self->_parse_esmtp_params($2));

    $self->session->store(rcpt => $recipients);
    $self->session->store(rcpt_parameters => $params);

    $self->session->done('RCPT');
    $self->_send(OK, 'OK');
}

sub data {
    my ($self, $fh, $args) = @_;

    # needs RCPT
}

sub rset {
    my ($self, $args) = @_;
    # "RSET" CRLF
    $self->session->clean;
    $self->_send(OK, 'OK');
}

sub noop {
    my ($self, $args) = @_;
    # "NOOP" [ SP String ] CRLF
    $self->_send(OK, 'OK');
}

sub quit {
    my ($self, $args) = @_;
    # "QUIT" CRLF
    $self->_send(CLOSING_TRANSMISSION, 'Thank you, come again!');
    close $self->session->fh;
}

sub vrfy {
    my ($self, $args) = @_;
    # "VRFY" SP String CRLF
    $args =~ /^VRFY \s (.+) \r\n/imsx;

    unless ($1) {
        $self->_send(ERROR_IN_PARAMETERS, 'error_in_parameters');
        return;
    }

    $self->_send(CANNOT_VRFY_USER, 'As you wish!');
}

1;
