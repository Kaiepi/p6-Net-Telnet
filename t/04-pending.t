use v6.d;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Exceptions;
use Net::Telnet::Pending;
use Test;

plan 5;

my TelnetCommand                 $command      = DO;
my TelnetOption                  $option       = TRANSMIT_BINARY;
my Net::Telnet::Negotiation      $negotiation .= new: :$command, :$option;
my Net::Telnet::Pending          $pending     .= new;
my Net::Telnet::Pending::Request $request;

throws-like {
    $pending.negotiations.get($option);
}, X::Net::Telnet::OptionRace, 'Trying to get a non-existent request throws';

$request = $pending.negotiations.request($option);
is $pending.negotiations.get($option), $request, 'Can make a request';
$pending.negotiations.resolve($negotiation);
is await($request), $negotiation, 'Can resolve a pending request and await it';
$pending.negotiations.remove($option);
nok $pending.negotiations.has($option), 'Can remove a pending request';

throws-like {
    $pending.negotiations.remove($option);
}, X::Net::Telnet::OptionRace, 'Trying to remove a non-existent request throws';

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
