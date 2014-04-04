package SMTP::Session;

use strict;
use warnings;

use Carp;

use SMTP::Commands;
use SMTP::ReplyCodes;
use IO::Socket::INET;

use Socket qw(getnameinfo);

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    if ($self->daemon->{listen}) {
        my ($port, $iaddr) = unpack_sockaddr_in($self->fh->peername)
            or $self->slog(warn => 'Unable to get peername.');
        $self->{remote_address} = inet_ntoa($iaddr);

        my ($err, $hostname, $servicename) = getnameinfo($self->fh->peername);
        $self->{remote_host} = $hostname || '';
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
    my ($self, $msg, @args) = @_;
    my $fh = $self->fh;

    if (!$msg) {
        $msg = ERROR_IN_PROCESSING
            . " Requested action aborted: error in processing";
    }

    printf $fh "$msg\r\n", @args;
}

# Session data
sub clean { shift->{data} = {} }

sub get {
    my ($self, $key) = @_;

    if ($key) {
        $key = lc $key;
        my $data = $self->{data}{$key};
        #return $self->{data}{$key}[0] if ref($data) && scalar(@$data) == 1;
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
    $self->_send('%d %s %s', READY, $self->daemon->address, $self->daemon->name);

    while (1) {
        #$fh->timeout($::REQ_TIMEOUT);
        my $req = $fh->readline("\r\n");
        #$fh->timeout($::RES_TIMEOUT);

        #defined $req or $self->err(408, "request timeout");

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
