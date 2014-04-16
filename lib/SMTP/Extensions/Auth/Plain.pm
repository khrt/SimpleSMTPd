package SMTP::Extensions::Auth::Plain;

use strict;
use warnings;

use MIME::Base64 qw(encode_base64 decode_base64);

use base 'Exporter';
our @EXPORT = qw(plain);

sub name { 'PLAIN' }

sub plain {
    my ($self, $session, $args) = @_;

    $args =~ /^AUTH \s PLAIN \s (\S+)\r\n$/imsx;
    my $credentials = $1;
    return unless $credentials;

    $credentials = decode_base64($credentials);
    my (undef, $user, $pass) = split "\0", $credentials;

    $user, $pass;
}

1;

__END__
