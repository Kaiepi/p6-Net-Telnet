use v6.c;
use Net::Telnet::Constants;
use Net::Telnet::Subnegotiation;
unit class Net::Telnet::Subnegotiation::NAWS does Net::Telnet::Subnegotiation;

has UInt16 $.width  is required;
has UInt16 $.height is required;

method new(UInt16 :$width, UInt16 :$height) {
    self.bless: :option(NAWS), :$width, :$height;
}

multi method gist(--> Str) {
    "$!width $!height"
}

multi method serialize(--> Blob) {
    Blob.new:
        $!width  +> 8,
        $!width  +& 0xFF,
        $!height +> 8,
        $!height +& 0xFF
}
