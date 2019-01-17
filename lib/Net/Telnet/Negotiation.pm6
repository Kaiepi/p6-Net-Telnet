use v6.c;
use Net::Telnet::Constants;
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
