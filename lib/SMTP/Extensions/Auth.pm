package SMTP::Extensions::Auth;

use strict;
use warnings;

use SMTP::StatusCodes;
use SMTP::Extensions::EnhancedStatusCodes;

use SMTP::Extensions::Auth::Login;
use SMTP::Extensions::Auth::Plain;

use base 'Exporter';
our @EXPORT = qw(auth);

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub ehlo {
    my $self = shift;
    my $methods = join ' ', map { "${ \ref($self) }::$_"->name } qw(Login Plain);
    "AUTH $methods";
}

sub auth {
    my ($self, $args) = @_;

    $args =~ /^AUTH \s (\p{Alnum}+)/imsx;
    my $method = lc $1;

    if (!$method || !$self->extensions->{auth}->can($method)) {
        $self->_send(
            '%d %s Authentication method `%s\' invalid',
            AUTH_FAILED,
            ES_PERMANENT_FAILURE('AUTHENTICATION_CREDENTIALS_INVALID'),
            uc($method)
        );
        return;
    }

    my ($user, $pass) = $self->extensions->{auth}->$method($self->session, $args);
    if (!$user || !$pass) {
        $self->_send(
            '%d %s Authentication credentials invalid',
            AUTH_FAILED,
            ES_TRANSIENT_FAILURE('AUTHENTICATION_CREDENTIALS_INVALID')
        );
        return;
    }

    my $res = $self->session->daemon->on('authentication')->($user, $pass);
    unless ($res) {
        $self->_send(
            '%d %s Authentication credentials invalid',
            AUTH_FAILED,
            ES_PERMANENT_FAILURE('AUTHENTICATION_CREDENTIALS_INVALID')
        );
        return;
    }

    $self->_send(
        '%d %s Authentication succeeded',
        AUTH_SUCCESS,
        ES_SUCCESS('OTHER_OR_UNDEFINED_SECURITY_STATUS')
    );

    $self->session->store(auth => $user);

    1;
}

1;

__END__

