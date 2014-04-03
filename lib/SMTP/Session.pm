package SMTP::Session;

use strict;
use warnings;

use Carp;

use SMTP::Commands;
use SMTP::ReplyCodes;

use IO::Socket::INET;

#use constant TERMINATOR => "\015\012";
#use constant TERMINATOR => "\r\n";
use constant TERMINATOR => "\n";

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;

    if ($self->{listen}) {
        my (undef, $iaddr) = unpack_sockaddr_in $self->fh->peername
            or $self->slog('Unable to get peername.');
        $self->{remote_address} = inet_ntoa $iaddr;
    }

    $self->{command} = SMTP::Commands->new(session => $self);
    $self;
}

sub command { shift->{command} }
sub daemon { shift->{daemon} }
sub fh { shift->{fh} }
sub remote_address { shift->{remote_address} }

sub slog { shift->daemon->logger(@_) }

sub _send {
    my ($self, $code, $msg, @args) = @_;

#    unless (scalar @res) {
#        @res = (ERROR_IN_PROCESSING,
#            'Requested action aborted: error in processing');
#    }

    # TODO:
    #   multiline: <CODE>-<MSG>
    #   online: <CODE> <MSG>

    my $fh = $self->fh;
    printf $fh "%d $msg\r\n", $code, @args;
}

sub clean {
    shift->{data} = undef;
}
sub data { shift->{data} }

sub done { shift->{done}{shift} = 1 }

sub handle {
    my $self = shift;

    my $fh = $self->fh;

    while (1) {
        #$self->slog();
        $self->_send(READY, '%s %s', $self->daemon->address, $self->daemon->name);

        my $req = $fh->readline(TERMINATOR);

        unless (defined $req) {
            # RETURN ERROR
            close $fh;
            die 'UNDEFINED REQ';
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
