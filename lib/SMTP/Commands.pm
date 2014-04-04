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

sub _get_params {
    my ($self, $cmd) = @_;
    my $data = $self->session->get('cmd');

    my %params;
    foreach (@$data) {
        $params{ keys %{ $_->[1] } } = values %{ $_->[1] };
    }

    \%params;
}

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
    while ($str =~ /([[:alpha:][:digit:]-]+)(?:=([^\s=]))?/gmsx) {
        $params{$1} = $2 || 1;
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
    $args =~ /^EHLO \s (\p{Alnum}+) \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    $self->session->clean;

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

# S: 250
# E: 552, 451, 452, 550, 553, 503, 455, 555

    if (!$self->session->get('helo') && !$self->session->get('ehlo')) {
        $self->_send('%d Send EHLO/HELO first', BAD_SEQUENCE_OF_COMMANDS);
        return;
    }

    # Mail-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "MAIL FROM:" Reverse-path [SP Mail-parameters] CRLF
    $args =~ /^MAIL \s FROM: (<[^>]+>) \s? (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS); # INVALID CODE
        return;
    }

    my ($from, $params) = ($1, $self->_parse_esmtp_params($2));

    if ($params->{SIZE}) {
        unless ($self->extensions->{size}->amount($params->{SIZE})) {
            $self->_send('%d Message size exceeds fixed maximium message size',
                EXCEEDED_STORAGE_ALLOCATION);
            return;
        }
    }

    $self->session->store(mail => [$from, $params]);

    $self->_send('%d OK', OK);
}

sub rcpt {
    my ($self, $args) = @_;

# S: 250, 251 (but see Section 3.4 for discussion of 251 and 551)
# E: 550, 551, 552, 553, 450, 451, 452, 503, 455, 555

    # needs MAIL
    unless ($self->session->get('mail')) {
        $self->_send('%d Need MAIL command', BAD_SEQUENCE_OF_COMMANDS);
        return;
    }

    # Rcpt-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "RCPT TO:" ( "<Postmaster@" Domain ">" / "<Postmaster>" / Forward-path ) [SP Rcpt-parameters] CRLF
    $args =~ /^RCPT \s TO: (.+) \s? (.+)? \r\n/imsx;

    unless ($1) {
        $self->_send('%d ERROR_IN_PARAMETERS', ERROR_IN_PARAMETERS);
        return;
    }

    # 550 reply, typically with a string such as "no such user"

    my ($recipients, $params) = ($1, $self->_parse_esmtp_params($2));

    $self->session->get('rcpt');
    $self->session->store(rcpt => [$recipients, $params]);

    $self->_send('%d OK', OK);
}

sub data {
    my ($self, $fh, $args) = @_;

# E: 503, 554

    # needs MAIL and RCPT
    unless ($self->session->get('rcpt')) {
        $self->_send('%d No valid recipients', TRANSACTION_FAILED);
        return;
    }

    $self->_send('%d Start mail input; end with <CRLF>.<CRLF>', START_MAIL_INPUT);
    my $data = $self->session->fh->readline("\r\n.\r\n");

    unless (defined $data) {
        $self->_send('%d Error in processing DATA', ERROR_IN_PROCESSING);
        return;
    }

    $data =~ s/\r\n.\r\n$//msx;

    {
        use bytes;
        my $max_size = $self->extensions->{size}->amount;
        if (bytes::length($data) > $max_size) {
            $self->_send('%d Size limit exceeded', EXCEEDED_STORAGE_ALLOCATION);
            return;
        }
    }

    $self->session->store(data => $data);
    $self->_send('%d OK', OK);

use DDP;
p $self->session->get;
    # call process_message?
    #$self->session->daemon->process_message();
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

sub vrfy {
    my ($self, $args) = @_;

# E: 550, 551, 553, 502, 504

    # "VRFY" SP String CRLF
    $args =~ /^VRFY \s (.+) \r\n/imsx;

    unless ($1) {
        $self->_send('%d error_in_parameters', ERROR_IN_PARAMETERS);
        return;
    }

    $self->_send('%d As you wish!', CANNOT_VRFY_USER);
}

sub quit {
    my ($self, $args) = @_;
    #$self->session->clean;
    $self->_send('%d Thank you, come again!', CLOSING_TRANSMISSION);
    close $self->session->fh;
}

1;
