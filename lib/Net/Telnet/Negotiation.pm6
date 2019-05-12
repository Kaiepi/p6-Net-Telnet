use v6.d;
use Net::Telnet::Constants :ALL;
unit class Net::Telnet::Negotiation;

has TelnetCommand $.command;
has TelnetOption  $.option;

method gist(--> Str) {
    "{IAC.key} {$!command.key} {$!option.key}"
}

method serialize(--> Blob) {
    Blob.new: IAC.ord, $!command.ord, $!option.ord
}

method Str(--> Str) {
    "{IAC}{$!command}{$!option}"
}
