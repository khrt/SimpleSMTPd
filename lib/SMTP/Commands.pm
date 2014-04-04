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

    $self->{extensions} = {
        size => SMTP::Extensions::Size->new,
    };

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
    $self->_send('%d Unrecognized command', COMMAND_UNRECOGNIZED);
}

sub ehlo {
    my ($self, $args) = @_;

    # "EHLO" SP ( Domain / address-literal ) CRLF
    $args =~ /^EHLO \s (.+) \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    my $domain = $1;

    # ( "220-" (Domain / address-literal) [ SP textstring ] CRLF
    # *( "220-" [ textstring ] CRLF )
    # "220" [ SP textstring ] CRLF )
    my @response = ("${ \READY }-Privet $domain, what you wish?");

    foreach my $ext (keys %{ $self->extensions }) {
        push @response, READY . '-' . $self->extensions->{$ext}->ehlo;
    }

    $response[-1] =~ s/-/ /;
    my $response = join "\r\n", @response;

    $self->session->store(ehlo => $domain);
    $self->_send($response);
}

sub helo {
    my ($self, $args) = @_;

    # "HELO" SP Domain CRLF
    $args =~ /^HELO \s (\p{Alnum}+) \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    my $domain = $1;

    $self->session->store(helo => $domain);
    $self->_send('%d Privet %s, what you wish?', OK, $domain);
}

sub mail {
    my ($self, $args) = @_;

    if (!$self->session->get('helo') || $self->session->get('ehlo')) {
        $self->_send('%d send EHLO/HELO first', BAD_SEQUENCE_OF_COMMANDS);
    }

    # Mail-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "MAIL FROM:" Reverse-path [SP Mail-parameters] CRLF
    $args =~ m/^MAIL FROM: <([^>]+)> \s? (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    my ($from, $params) = ($1, $self->_parse_esmtp_params($2));

    $self->session->store(mail => $from);
    $self->session->store(mail_parameters => $params);

    $self->session->data('MAIL');
    $self->_send(OK, '%d OK');
}

sub rcpt {
    my ($self, $args) = @_;

    # needs MAIL
    unless ($self->session->get('mail')) {
        $self->_send('%d send MAIL first', BAD_SEQUENCE_OF_COMMANDS)
    }

    # Rcpt-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "RCPT TO:" ( "<Postmaster@" Domain ">" / "<Postmaster>" / Forward-path ) [SP Rcpt-parameters] CRLF
    $args =~ /^RCPT TO: (.+) \s (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    my ($recipients, $params) = ($1, $self->_parse_esmtp_params($2));

    $self->session->store(rcpt => $recipients);
    $self->session->store(rcpt_parameters => $params);

    $self->session->done('RCPT');
    $self->_send('%d OK', OK);
}

sub data {
    my ($self, $fh, $args) = @_;

    # needs RCPT
}

sub rset {
    my ($self, $args) = @_;
    # "RSET" CRLF
    $self->session->clean;
    $self->_send('%d OK', OK);
}

sub noop {
    my ($self, $args) = @_;
    # "NOOP" [ SP String ] CRLF
    $self->_send('%d OK', OK);
}

sub quit {
    my ($self, $args) = @_;
    # "QUIT" CRLF
    $self->_send('%d Thank you, come again!', CLOSING_TRANSMISSION);
    close $self->session->fh;
}

sub vrfy {
    my ($self, $args) = @_;
    # "VRFY" SP String CRLF
    $args =~ /^VRFY \s (.+) \r\n/imsx;

    unless ($1) {
        $self->_send('%d error_in_parameters', ERROR_IN_PARAMETERS);
        return;
    }

    $self->_send('%d As you wish!', CANNOT_VRFY_USER);
}

1;
