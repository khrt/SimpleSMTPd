package SMTP::Extensions::Help;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(help);

use SMTP::StatusCodes;
use SMTP::Extensions::EnhancedStatusCodes;

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

sub ehlo { 'HELP' }

sub help {
    my ($self, $args) = @_;

    $args =~ /^HELP \s? (.+)?\r\n/imsx;
    my $keyword = $1;

    my $response;
    my @statuses = (HELP_MESSAGE, ES_SUCCESS('OTHER_UNDEFINED_STATUS'));
    if ($keyword && $HELP{$keyword}) {
        my $help = <<HELP_END;
%d-%s "%s" ABNF Syntax:
%d-%s %s
HELP_END
        $response = sprintf $help,
            @statuses, uc($keyword), @statuses, $HELP{$keyword};
    }
    elsif ($keyword && !$HELP{$keyword}) {
        $response =
            sprintf "%d %s Keyword \"%s\" is not implemented!\r\n",
                HELP_MESSAGE,
                ES_PERMANENT_FAILURE('INVALID_COMMAND_ARGUMENTS'),
                uc($keyword);
    }
    else {
        my $help = <<HELP_END;
%d-%s This server implementation matches RFC5321.
%d-%s Learn more at http://tools.ietf.org/html/rfc5321
%d-%s --
%d-%s Extended HELLO (EHLO)
%d-%s HELLO          (HELO)
%d-%s MAIL           (MAIL)
%d-%s RECIPIENT      (RCPT)
%d-%s DATA           (DATA)
%d-%s RESET          (RSET)
%d-%s VERIFY         (VRFY)
%d-%s EXPAND         (EXPN)
%d-%s HELP           (HELP)
%d-%s NOOP           (NOOP)
%d %s QUIT           (QUIT)
HELP_END
        my $lines = $help =~ tr/\r\n//;
        $response = sprintf $help, (@statuses) x ($lines + 1);
    }

    # S: 211, 214
    # E: 502, 504
    $self->_send($response);
}

1;

__END__

L<RFC5321|http://tools.ietf.org/html/rfc5321>
