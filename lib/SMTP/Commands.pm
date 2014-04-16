package SMTP::Commands;

use strict;
use warnings;

use SMTP::Extensions::8BitMIME;
use SMTP::Extensions::Auth;
use SMTP::Extensions::EnhancedStatusCodes;
use SMTP::Extensions::Help;
use SMTP::Extensions::Size;
use SMTP::StatusCodes;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    $self->{extensions} = {
        '8bitmime' => SMTP::Extensions::8BitMIME->new,
        auth => SMTP::Extensions::Auth->new,
        enhancedstatuscodes => SMTP::Extensions::EnhancedStatusCodes->new,
        help => SMTP::Extensions::Help->new,
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
    while ($str =~ /([[:alpha:][:digit:]-]+) (?:=([^\cK\s=]))?/gmsx) {
        $params{lc($1)} = $2 || 1;
    }

    \%params;
}

sub not_implemented {
    my $self = shift;
    $self->_send(
        '%d %s Unrecognized command',
        COMMAND_UNRECOGNIZED,
        ES_PERMANENT_FAILURE('INVALID_COMMAND')
    );
}

sub ehlo {
    my ($self, $args) = @_;

    # "EHLO" SP ( Domain / address-literal ) CRLF
    $args =~ /^EHLO \s ( \p{Alnum}+ (?: .\p{Alnum} )* ) \r\n/imsx;

    unless ($1) {
        $self->_send(
            '%d %s Invalid arguments',
            ERROR_IN_PARAMETERS,
            ES_PERMANENT_FAILURE('INVALID_COMMAND_ARGUMENTS')
        );
        return;
    }

    $self->session->clean;

    my $domain = $1;

    # ( "220-" (Domain / address-literal) [ SP textstring ] CRLF
    # *( "220-" [ textstring ] CRLF )
    # "220" [ SP textstring ] CRLF )
    my @response = ("${ \READY }-Privet $domain");

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
    $args =~ /^HELO \s ( \p{Alnum}+ (?: .\p{Alnum} )* ) \r\n/imsx;

    unless ($1) {
        $self->_send(
            '%d %s Invalid arguments',
            ERROR_IN_PARAMETERS,
            ES_PERMANENT_FAILURE('INVALID_COMMAND_ARGUMENTS')
        );
        return;
    }

    my $domain = $1;

    $self->session->store(helo => $domain);
    $self->_send('%d Privet %s', OK, $domain);
}

sub mail {
    my ($self, $args) = @_;

    if (!$self->session->get('helo') && !$self->session->get('ehlo')) {
        $self->_send(
            '%d %s Send EHLO/HELO first',
            BAD_SEQUENCE_OF_COMMANDS,
            ES_PERMANENT_FAILURE('INVALID_COMMAND')
        );
        return;
    }

    # Mail-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "MAIL FROM:" Reverse-path [SP Mail-parameters] CRLF
    $args =~ /^MAIL \s FROM: (<[^>]+>) \s? (.+)? \r\n/imsx;

    my $from = $1 || '';
    unless ($from) {
        $self->_send(
            '%d %s Invalid reverse-path - %s',
            MAILBOX_NAME_NOT_ALLOWED,
            ES_PERMANENT_FAILURE('BAD_DESTINATION_MAILBOX_ADDRESS_SYNTAX'),
            $from
        );
        return;
    }

    $self->session->clean;

    my $params = $self->_parse_esmtp_params($2);

    # Set mail-parameters
    # Set SIZE
    if ($params->{size}) {
        unless ($self->extensions->{size}->amount($params->{size})) {
            $self->_send(
                '%d %s Message size exceeds fixed maximium message size',
                EXCEEDED_STORAGE_ALLOCATION,
                ES_PERMANENT_FAILURE('MESSAGE_LENGTH_EXCEEDS_ADMINISTRATIVE_LIMIT')
            );
            return;
        }
    }

    # set reverse-path buffer
    $self->session->store(mail => [$from, $params]);
    $self->_send('%d %s OK', OK, ES_SUCCESS('OTHER_ADDRESS_STATUS'));
}

sub rcpt {
    my ($self, $args) = @_;

    # needs MAIL
    unless ($self->session->get('mail')) {
        $self->_send(
            '%d %s Need MAIL command',
            BAD_SEQUENCE_OF_COMMANDS,
            ES_PERMANENT_FAILURE('INVALID_COMMAND')
        );
        return;
    }

    # Rcpt-parameters  = esmtp-param *(SP esmtp-param)
    # esmtp-param      = esmtp-keyword ["=" esmtp-value]
    # "RCPT TO:" ( "<Postmaster@" Domain ">" / "<Postmaster>" / Forward-path ) [SP Rcpt-parameters] CRLF
    $args =~ /^RCPT \s TO: (.+) \s? (.+)? \r\n/imsx;

    my $recipient = $1;
    unless ($recipient) {
        $self->_send(
            '%d %s Invalid forward-path - %s',
            MAILBOX_NAME_NOT_ALLOWED,
            ES_PERMANENT_FAILURE('BAD_DESTINATION_MAILBOX_ADDRESS_SYNTAX'),
            $recipient
        );
        return;
    }

    my $params = $self->_parse_esmtp_params($2);

    my $rcpt = $self->session->get('rcpt') || [];
    push @$rcpt, [$recipient, $params];
    # set forward-path buffer
    $self->session->store(rcpt => $rcpt);

    $self->_send('%d %s OK', OK, ES_SUCCESS('DESTINATION_ADDRESS_VALID'));
}

# NOTE: FH
sub data {
    my ($self, $fh, $args) = @_;

    # needs MAIL and RCPT
    unless ($self->session->get('rcpt')) {
        $self->_send(
            '%d %s No valid recipients',
            BAD_SEQUENCE_OF_COMMANDS,
            ES_PERMANENT_FAILURE('INVALID_COMMAND')
        );
        return;
    }

    $self->_send('%d Start mail input; end with <CRLF>.<CRLF>', START_MAIL_INPUT);
    my $data = $self->session->fh->readline("\r\n.\r\n");

    unless (defined $data) {
        $self->_send(
            '%d %s Error in processing DATA',
            TRANSACTION_FAILED,
            ES_PERMANENT_FAILURE('CONVERSION_FAILED')
        );
        return;
    }

    $data =~ s/\r\n.\r\n$//msx;

    {
        use bytes;
        my $max_size = $self->extensions->{size}->amount;
        if (bytes::length($data) > $max_size) {
            $self->_send(
                '%d %s Size limit exceeded',
                EXCEEDED_STORAGE_ALLOCATION,
                ES_PERMANENT_FAILURE('MESSAGE_LENGTH_EXCEEDS_ADMINISTRATIVE_LIMIT')
            );
            return;
        }
    }

    # set mail data buffer
    $self->session->store(data => $data);
    $self->_send(
        '%d %s Message accepted',
        OK,
        ES_SUCCESS('OTHER_OR_UNDEFINED_MEDIA_ERROR')
    );

    my $session_data = $self->session->get;
    $self->session->clean;

    $self->session->daemon->process_message->(
        peer       => ($self->session->remote_host || $self->session->remote_address),
        mailfrom   => $session_data->{mail}[0],
        recipients => [map { $_->[0] } @{ $session_data->{rcpt} }],
        data       => $data,
    );
}

sub rset {
    my ($self, $args) = @_;
    # "RSET" CRLF
    $self->session->clean;
    $self->_send('%d %s OK', OK, ES_SUCCESS('OTHER_UNDEFINED_STATUS'));
}

sub noop {
    my ($self, $args) = @_;
    # "NOOP" [ SP String ] CRLF
    $self->_send('%d %s OK', OK, ES_SUCCESS('OTHER_UNDEFINED_STATUS'));
}

sub expn {
    my ($self, $args) = @_;
    # "EXPN" SP String CRLF
    $args =~ /^EXPN \s (.+)? \r\n/imsx;
    $self->_send(
        '%d %s Access denied to you',
        MAILBOX_UNAVAILABLE,
        ES_PERMANENT_FAILURE('OTHER_UNDEFINED_STATUS')
    );
}

sub vrfy {
    my ($self, $args) = @_;
    # "VRFY" SP String CRLF
    $args =~ /^VRFY \s (.+)? \r\n/imsx;
    $self->_send(
        '%d %s Access denied to you',
        MAILBOX_UNAVAILABLE,
        ES_PERMANENT_FAILURE('MAILING_LIST_EXPANSION_PROHIBITED')
    );
}

# NOTE: FH
sub quit {
    my ($self, $args) = @_;
    $self->session->clean;
    $self->_send(
        '%d %s Thank you, come again!',
        CLOSING_TRANSMISSION,
        ES_SUCCESS('OTHER_UNDEFINED_STATUS')
    );
    close $self->session->fh;
}

1;
