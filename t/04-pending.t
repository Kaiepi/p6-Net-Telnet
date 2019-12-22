use v6.d;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Context;
use Net::Telnet::Exceptions;
use Test;

plan 5;

my TelnetCommand                 $command      = DO;
my TelnetOption                  $option       = TRANSMIT_BINARY;
my Net::Telnet::Negotiation      $negotiation .= new: :$command, :$option;
my Net::Telnet::Context          $context     .= new: :preferred[], :supported[];
my Net::Telnet::Context::Request $request;

throws-like {
    $context.negotiations.get($option);
}, X::Net::Telnet::OptionRace, 'Trying to get a non-existent request throws';

$request = $context.negotiations.request($option);
is $context.negotiations.get($option), $request, 'Can make a request';
$context.negotiations.resolve($negotiation);
is await($request), $negotiation, 'Can resolve a request and await it';
$context.negotiations.remove($option);
nok $context.negotiations.has($option), 'Can remove a request';

throws-like {
    $context.negotiations.remove($option);
}, X::Net::Telnet::OptionRace, 'Trying to remove a non-existent request throws';

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
