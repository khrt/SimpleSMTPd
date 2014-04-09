package SMTP::Extensions::EnhancedStatusCodes;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(ES_SUCCESS ES_TRANSIENT_FAILURE ES_PERMANENT_FAILURE);

# Other or Undefined Status
use constant OTHER_UNDEFINED_STATUS => '0.0';

# Address status
use constant OTHER_ADDRESS_STATUS                   => '1.0';
use constant BAD_DESTINATION_MAILBOX_ADDRESS        => '1.1';
use constant BAD_DESTINATION_SYSTEM_ADDRESS         => '1.2';
use constant BAD_DESTINATION_MAILBOX_ADDRESS_SYNTAX => '1.3';
use constant DESTINATION_MAILBOX_ADDRESS_AMBIGUOUS  => '1.4';
use constant DESTINATION_ADDRESS_VALID              => '1.5';
use constant DESTINATION_MAILBOX_HAS_MOVED          => '1.6';
use constant NO_FORWARDING_ADDRESS                  => '1.6';
use constant BAD_SENDERS_MAILBOX_ADDRESS_SYNTAX     => '1.7';
use constant BAD_SENDERS_SYSTEM_ADDRESS             => '1.8';

# Mailbox status
use constant OTHER_OR_UNDEFINED_MAILBOX_STATUS           => '2.0';
use constant MAILBOX_DISABLED                            => '2.1';
use constant NOT_ACCEPTING_MESSAGES                      => '2.1';
use constant MAILBOX_FULL                                => '2.2';
use constant MESSAGE_LENGTH_EXCEEDS_ADMINISTRATIVE_LIMIT => '2.3';
use constant MAILING_LIST_EXPANSION_PROBLEM              => '2.4';

# Mail system status
use constant OTHER_OR_UNDEFINED_MAIL_SYSTEM_STATUS   => '3.0';
use constant MAIL_SYSTEM_FULL                        => '3.1';
use constant SYSTEM_NOT_ACCEPTING_NETWORK_MESSAGES   => '3.2';
use constant SYSTEM_NOT_CAPABLE_OF_SELECTED_FEATURES => '3.3';
use constant MESSAGE_TOO_BIG_FOR_SYSTEM              => '3.4';

# Network and Routing status
use constant OTHER_OR_UNDEFINED_NETWORK_OR_ROUTING_STATUS => '4.0';
use constant NO_ANSWER_FROM_HOST                          => '4.1';
use constant BAD_CONNECTION                               => '4.2';
use constant ROUTING_SERVER_FAILURE                       => '4.3';
use constant UNABLE_TO_ROUTE                              => '4.4';
use constant NETWORK_CONGESTION                           => '4.5';
use constant ROUTING_LOOP_DETECTED                        => '4.6';
use constant DELIVERY_TIME_EXPIRED                        => '4.7';

# Mail delivery protocol status
use constant OTHER_OR_UNDEFINED_PROTOCOL_STATUS => '5.0';
use constant INVALID_COMMAND                    => '5.1';
use constant SYNTAX_ERROR                       => '5.2';
use constant TOO_MANY_RECIPIENTS                => '5.3';
use constant INVALID_COMMAND_ARGUMENTS          => '5.4';
use constant WRONG_PROTOCOL_VERSION             => '5.5';

# Messsage content or Message media status
use constant OTHER_OR_UNDEFINED_MEDIA_ERROR        => '6.0';
use constant MEDIA_NOT_SUPPORTED                   => '6.1';
use constant CONVERSION_REQUIRED_AND_PROHIBITED    => '6.2';
use constant CONVERSION_REQUIRED_BUT_NOT_SUPPORTED => '6.3';
use constant CONVERSION_WITH_LOSS_PERFORMED        => '6.4';
use constant CONVERSION_FAILED                     => '6.5';

# Security or Policy status
use constant OTHER_OR_UNDEFINED_SECURITY_STATUS            => '7.0';
use constant DELIVERY_NOT_AUTHORIZED                       => '7.1';
use constant MESSAGE_REFUSED                               => '7.1';
use constant MAILING_LIST_EXPANSION_PROHIBITED             => '7.2';
use constant SECURITY_CONVERSION_REQUIRED_BUT_NOT_POSSIBLE => '7.3';
use constant SECURITY_FEATURES_NOT_SUPPORTED               => '7.4';
use constant CRYPTOGRAPHIC_FAILURE                         => '7.5';
use constant CRYPTOGRAPHIC_ALGORITHM_NOT_SUPPORTED         => '7.6';
use constant MESSAGE_INTEGRITY_FAILURE                     => '7.7';

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self;
}

sub ehlo { 'ENHANCEDSTATUSCODES' }

sub _print {
    my ($class, $cname) = @_;
    no strict 'refs';
    sprintf '%s.%s', $class, &$cname;
}

sub ES_SUCCESS { _print(2, $_[0]) }
sub ES_TRANSIENT_FAILURE { _print(4, $_[0]) }
sub ES_PERMANENT_FAILURE { _print(5, $_[0]) }

1;

__END__

L<RFC2034|http://tools.ietf.org/html/rfc2034>
L<RFC1893|http://tools.ietf.org/html/rfc1893>
