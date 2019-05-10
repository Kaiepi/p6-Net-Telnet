use v6.d;
use Net::Telnet::Constants;
unit class Net::Telnet::Command;

has TelnetCommand $.command;

method name  { $!command.key   }
method value { $!command.value }

method gist(--> Str) { "{IAC.key} {$!command.key}" }

method serialize(--> Blob) { Blob.new: IAC.ord, $!command.ord }

method Str(--> Str) { "{IAC}{$!command}" }
