
use strict;
use warnings;

use MIME::Lite;

my $msg = MIME::Lite->new(
    From    => 'me@myhost.com',
    To      => 'you@yourhost.com',
    Cc      => 'some@other.com, some@more.com',
    Subject => 'A message with 2 parts...',
    Type    => 'multipart/mixed',
);

$msg->attach(
    Type => 'TEXT',
    Data => 'Here\'s the JPEG file you wanted'
);

$msg->attach(
    Type     => 'image/jpeg',
    Path     => '/Users/ak/Pictures/pics/homer-simpson2.jpg',
    Filename => 'homer.jpeg'
);

$msg->send('smtp', '127.0.0.1:9025', Debug => 1);

