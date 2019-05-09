use v6.c;
unit module Net::Telnet::Exceptions;

class X::Net::Telnet::ProtocolViolation is Exception {
    has Str  $.host;
    has Int  $.port;
    has Blob $.remainder;

    method message(--> Str) {
        my Str $bytes = $!remainder.map({ sprintf '%2x', $_ }).uc;

        qq:to/END/;
        Data received from $!host:$!port violates TELNET protocol:
        $bytes
        END
    }
}

class X::Net::Telnet::TransmitBinary is Exception {
    has Str $.host;
    has Str $.port;

    method message(--> Str) {
        "Failed to send binary data to $!host:$!port: the TRANSMIT_BINARY negotiation was declined"
    }
}
