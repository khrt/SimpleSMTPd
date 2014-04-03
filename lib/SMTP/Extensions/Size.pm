package SMTP::Extensions::Size;

use strict;
use warnings;

use constant DEFAULT_SIZE => 5 * 1024 * 1024;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub size {
    my ($self, $size) = @_;
    $self->{size} = $size if $size;
    $self->{size} || DEFAULT_SIZE;
}

sub ehlo {
    my $self = shift;
    sprintf 'SIZE %d', $self->size;
}

1;

__END__

L<RFC 1870|http://tools.ietf.org/html/rfc1870>
