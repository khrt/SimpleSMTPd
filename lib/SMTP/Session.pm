package SMTP::Session;

use strict;
use warnings;

use Carp;
use IO::Socket::INET;
use Socket qw(getnameinfo);

use SMTP::Commands;
use SMTP::StatusCodes;

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    if ($self->daemon->{listen}) {
        my (undef, $iaddr) = unpack_sockaddr_in($self->fh->peername)
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
sub remote_address { shift->{remote_address} || '--' }
sub remote_host { shift->{remote_host} || '--' }

sub slog { shift->daemon->logger(@_) }

sub _send {
    my ($self, $msg, @args) = @_;
    my $fh = $self->fh;

    if (!$msg) {
        $msg = "%d Requested action aborted: error in processing";
        @args = (ERROR_IN_PROCESSING);
    }

    chomp($msg);
    printf $fh "$msg\r\n", @args;
}

# Session data
sub clean { shift->{data} = {} }

sub get {
    my ($self, $key) = @_;
    return $self->{data}{$key} if $key;
    $self->{data};
}

sub store {
    my ($self, $key, $value) = @_;
    $self->{data}{$key} = $value;
}

# Main loop
sub handle {
    my $self = shift;
    my $fh = $self->fh;

    $self->slog(info => '%s has connected', $self->remote_address);
    $self->_send('%d %s %s', READY, $self->daemon->address, $self->daemon->name);

    while (1) {
#        $fh->timeout($::REQ_TIMEOUT);
        my $req = $fh->readline("\r\n");
#        $fh->timeout($::RES_TIMEOUT);

        unless (defined $req) {
            close $fh; # TODO: handle my be already closed
            $self->slog(info => '%s disconnected', $self->remote_address);
            last;
        }

        my ($cmd, $args) = split /\s/, $req, 2;
        $cmd = lc($cmd);

        $self->slog(debug => $req);

        if ($self->{command}->can($cmd)) {
            $self->{command}->$cmd($req);
        }
        else {
            $self->{command}->not_implemented;
        }
    }
}

1;
