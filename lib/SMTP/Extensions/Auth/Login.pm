package SMTP::Extensions::Auth::Login;

use strict;
use warnings;

use MIME::Base64 qw(encode_base64 decode_base64);
use SMTP::StatusCodes;

use base 'Exporter';
our @EXPORT = qw(login);

sub name { 'LOGIN' }

sub login {
    my ($self, $session, $args) = @_;

    my $prompt;

    $prompt = encode_base64('Username');
    chomp($prompt);

    $session->_send('%d %s', AUTH_READY, $prompt);
    my $username = $session->fh->readline("\r\n");
    return unless $username;

    $prompt = encode_base64('Password');
    chomp($prompt);

    $session->_send('%d %s', AUTH_READY, $prompt);
    my $password = $session->fh->readline("\r\n");
    return unless $password;

    decode_base64($username), decode_base64($password);
}

1;

__END__

AUTH LOGIN
334 VXNlcm5hbWU6
dXNlcm5hbWUuY29t
334 UGFzc3dvcmQ6
bXlwYXNzd29yZA==
235 Authentication succeeded

