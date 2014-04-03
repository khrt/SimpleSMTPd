package SMTP::Session;

use strict;
use warnings;

use Carp;

use SMTP::Commands;
use SMTP::ReplyCodes;
use IO::Socket::INET;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    if ($self->{listen}) {
        my (undef, $iaddr) = unpack_sockaddr_in($self->fh->peername)
            or $self->slog('Unable to get peername.');
        $self->{remote_address} = inet_ntoa($iaddr);
    }

    $self->{command} = SMTP::Commands->new(session => $self);
    $self;
}

sub command { shift->{command} }
sub daemon { shift->{daemon} }
sub fh { shift->{fh} }
sub remote_address { shift->{remote_address} || 'UNKNOWN' }

sub slog { shift->daemon->logger(@_) }

sub _send {
    my ($self, $code, $msg, @args) = @_;
    my $fh = $self->fh;

    if (ref($msg) eq 'ARRAY') {
        my $multi_line_msg;

        foreach my $l (@$msg) {
            my ($m, @args) = @$l;
            $multi_line_msg .= sprintf "%d-$m\r\n", $code, @args;
        }

        print $fh $multi_line_msg;
    }
    elsif ($code && $msg) {
        printf $fh "%d $msg\r\n", $code, @args;
    }
    else {
        printf $fh "%d Requested action aborted: error in processing\r\n",
            ERROR_IN_PROCESSING;
    }
}

# Session data
sub clean { shift->{data} = {} }

sub get {
    my ($self, $key) = @_;

    if ($key) {
        $key = lc $key;
        my $data = $self->{data}{$key};
        return $self->{data}{$key}[0] if ref($data) && scalar(@$data) == 1;
        return $self->{data}{$key}
    }

    $self->{data};
}

sub store {
    my ($self, $key, $value) = @_;
    push @{ $self->{data}{lc($key)} }, $value;
}

# Main loop
sub handle {
    my $self = shift;

    my $fh = $self->fh;

    $self->slog(info => '%s has connected', $self->remote_address);
    $self->_send(READY, '%s %s', $self->daemon->address, $self->daemon->name);

    while (1) {
        my $req = $fh->readline("\r\n");

        unless (defined $req) {
            close $fh; # TODO: handle my be already closed
            $self->slog(info => 'Connection closed');
            last;
        }

        my ($cmd, $args) = split /\s/, $req, 2;
        $cmd = lc($cmd);

        if ($self->{command}->can($cmd)) {
            $self->{command}->$cmd($req);
        }
        else {
            $self->{command}->not_implemented;
        }
    }
}

1;
