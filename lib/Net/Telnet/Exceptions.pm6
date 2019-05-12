use v6.d;
use Net::Telnet::Constants;
unit module Net::Telnet::Exceptions;

class X::Net::Telnet is Exception { }

class X::Net::Telnet::ProtocolViolation is X::Net::Telnet {
    has Str  $.host;
    has Int  $.port;
    has Blob $.data;

    method message(--> Str) {
        my Str $bytes = $!data.map({ sprintf '%02x', $_ }).join(' ').uc;

        qq:to/END/;
        Data received from $!host:$!port violates TELNET protocol:
        $bytes
        END
    }
}

class X::Net::Telnet::TransmitBinary is X::Net::Telnet {
    has Str $.host;
    has Int $.port;

    method message(--> Str) {
        "Failed to send binary data to $!host:$!port: the TRANSMIT_BINARY negotiation was declined"
    }
}

class X::Net::Telnet::OptionRace is X::Net::Telnet {
    has TelnetOption $.option;
    has Str          $.type;
    has Str          $.action;

    method message(--> Str) {
        my Str $option = $!option.key;
        "Failed to $!action a negotiation for option $option. " 
            ~ "This either means that the peer is misbehaving or there is a race condition in Net::Telnet."
    }
}
