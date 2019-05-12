use v6.d;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Pending;
use Test;

plan 2;

my TelnetCommand                 $command      = DO;
my TelnetOption                  $option       = TRANSMIT_BINARY;
my Net::Telnet::Negotiation      $negotiation .= new: :$command, :$option;
my Net::Telnet::Pending          $pending     .= new;
my Net::Telnet::Pending::Request $request;

$request = $pending.negotiations.request: $option;
is $pending.negotiations{$option}, $request, 'Stores the pending request';
$pending.negotiations.resolve($negotiation);
$pending.negotiations.remove($option);
nok $pending.negotiations{$option}, 'Removes the pending request after it is resolved';

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
