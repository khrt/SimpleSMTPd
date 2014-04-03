package SMTP::Session;

use strict;
use warnings;

use Carp;

use SMTP::Commands;
use SMTP::ReplyCodes;

#use constant TERMINATOR => "\015\012";
#use constant TERMINATOR => "\r\n";
use constant TERMINATOR => "\n";

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    $self->{command} = SMTP::Commands->new(session => $self);
    $self;
}

sub command { shift->{command} }
sub daemon { shift->{daemon} }
sub fh { shift->{fh} }

sub _send {
    my ($self, $code, $msg, @args) = @_;

    $code ||= ERROR_IN_PROCESSING;
    $msg ||= 'Requested action aborted: error in processing';

    my $fh = $self->fh;
    printf $fh "%d $msg\r\n", $code, @args;
}


sub clean {
    my $self = shift;
    $self->{data} = undef;
}

sub handle {
    my $self = shift;

    my $fh = $self->fh;

    while (1) {
        $self->_send(OK, "%s %s\n", $self->{addr}, $self->daemon->name);

        my $req = $fh->readline(TERMINATOR);

        unless (defined $req) {
            # RETURN ERROR
            close $fh;
            die 'UNDEFINED REQ';
        }

        my ($cmd, $args) = split /\s/, $req, 2;

        if ($self->{command}->can($cmd)) {
            $self->{command}->$cmd($args);
        }
        else {
            $self->{command}->not_implemented;
        }
    }
}

1;
