package SMTP::Extensions::8BitMIME;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub ehlo { '8BITMIME' }

1;

__END__

L<RFC6152|https://tools.ietf.org/html/rfc6152>
