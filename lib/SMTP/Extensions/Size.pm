package SMTP::Extensions::Size;

use strict;
use warnings;

use constant DEFAULT_SIZE => 5 * 1024 * 1024;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub amount {
    my ($self, $size) = @_;

    if ($size) {
        return if $size > $self->{size};
        $self->{size} = $size
    }

    $self->{size} || DEFAULT_SIZE;
}

sub ehlo {
    my $self = shift;
    sprintf 'SIZE %d', $self->amount;
}

1;

__END__

L<RFC 1870|http://tools.ietf.org/html/rfc1870>

Not implemented 6.1 (1), 6.4
