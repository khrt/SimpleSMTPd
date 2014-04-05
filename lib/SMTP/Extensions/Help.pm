package SMTP::Extensions::Help;

use strict;
use warnings;

use SMTP::StatusCodes;

my %HELP = (
    ehlo => '"EHLO" SP ( Domain / address-literal ) CRLF',
    helo => '"HELO" SP Domain CRLF',
    mail => '"MAIL FROM:" Reverse-path [SP Mail-parameters] CRLF',
    rcpt => '"RCPT TO:" ( "<Postmaster@" Domain ">" / "<Postmaster>" / Forward-path ) [SP Rcpt-parameters] CRLF',
    data => '"DATA" CRLF',
    rset => '"RSET" CRLF',
    vrfy => '"VRFY" SP String CRLF',
    expn => '"EXPN" SP String CRLF',
    help => '"HELP" [ SP String ] CRLF',
    noop => '"NOOP" [ SP String ] CRLF',
    quit => '"QUIT" CRLF',
);

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub help {
    my ($self, $args) = @_;

    $args =~ /^HELP \s? (.+)?\r\n/imsx;
    my $keyword = $1;

    my $response;
    if ($keyword && $HELP{$keyword}) {
        $response = sprintf '%d %s', HELP_MESSAGE, $HELP{$keyword};
    }
    else {
        $response = sprintf '%d RFC5321 http://tools.ietf.org/html/rfc5321',
            HELP_MESSAGE;
    }

    # S: 211, 214
    # E: 502, 504
    $self->_send($response);
}

1;

__END__

L<RFC5321|http://tools.ietf.org/html/rfc5321>
