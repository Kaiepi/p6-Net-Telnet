use v6.d;
use Net::Telnet::Constants;
use Net::Telnet::Pending;
use Test;

my TelnetCommand                 $command      = DO;
my TelnetOption                  $option       = TRANSMIT_BINARY;
my Net::Telnet::Negotiation      $negotiation .= new: :$command, :$option;
my Net::Telnet::Pending          $pending     .= new;
my Net::Telnet::Pending::Request $request;

$request = $pending.negotiations.request: $option;
is $pending.negotiations{$option}, $request, 'Stores the pending request';
$pending.negotiations.resolve: $negotiation;
is $pending.negotiations.await($option), $command, 'Can resolve pending requests';
nok $pending.negotiations{$option}, 'Removes the pending request after it is awaited';

done-testing;

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
