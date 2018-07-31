use v6.c;
use Net::Telnet::Constants;
use Net::Telnet::Subnegotiation;
unit class Net::Telnet::Subnegotiation::Unsupported does Net::Telnet::Subnegotiation;

has Blob $.bytes;

method new(TelnetOption :$option, Blob :$bytes) {
    self.bless: :$option, :$bytes;
}

multi method gist(--> Str) {
    $!bytes.map({
        my $byte = $_.base(16);
        $byte [R~]= 0 if $byte.chars == 1;
        $byte
    }).join(' ')
}

multi method serialize(--> Blob) {
    $!bytes
}
