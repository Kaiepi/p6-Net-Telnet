use v6.c;
use Net::Telnet::Constants;
unit role Net::Telnet::Subnegotiation;

has TelnetOption $.option;

# Overridden by implementations.
proto method gist(--> Str) {
    "{IAC.key} {SB.key} {$!option.key} {{*}} {IAC.key} {SE.key}"
}

# Overridden by implementations.
proto method serialize(--> Blob) {
    Blob.new(
        IAC.ord,
        SB.ord,
        $!option.ord,
        |{*}.contents.reduce({ ($^b == 0xFF) ?? [|$^a, $^b, $^b] !! [|$^a, $^b] }),
        IAC.ord,
        SE.ord
    )
}

method Str(--> Str) { self.serialize.decode('latin1') }
