use v6.c;
use Net::Telnet::Client;
use Net::Telnet::Constants;
use Net::Telnet::Option;
use Test;

plan 15;

my IO::Socket::INET    $server .= listen: '127.0.0.1', 8000;
my Net::Telnet::Client $client .= new: :host<127.0.0.1>, :8000port, :supported<SGA ECHO NAWS>;

lives-ok { await $client.connect }, 'Can open new connections';
is $client.host, '127.0.0.1', 'Can get connection host';
is $client.port, 8000, 'Can get connection port';
ok $client.supported('SGA'), 'Can get supported options';
nok $client.preferred('NAWS'), 'Can get preferred options';
is $client.closed, False, 'Can get connection closed state';
cmp-ok $client.options{SGA}, '~~', Net::Telnet::Option, 'Can get connection options';
is $client.options{SGA}.supported, True, 'Can support options by passing them through .new';

$client.parse(Blob.new: IAC.ord, DO.ord, SGA.ord);
is $client.options{SGA}.us, YES, 'Can negotiate DO with supported options';
$client.parse(Blob.new: IAC.ord, DONT.ord, SGA.ord);
is $client.options{SGA}.us, NO, 'Can negotiate DONT with supported options';
$client.parse(Blob.new: IAC.ord, WILL.ord, SGA.ord);
is $client.options{SGA}.them, YES, 'Can negotiate WILL with supported options';
$client.parse(Blob.new: IAC.ord, WONT.ord, SGA.ord);
is $client.options{SGA}.them, NO, 'Can negotiate WONT with supported options';

$client.text.act(-> $text {
    is $text, 'ayy lmao', 'Can emit text messages received';
});
$client.parse('ayy lmao'.encode('latin1'));
sleep 1;

$client.close;
sleep 1;
is $client.closed, True, 'Connection closed state is accurate after the client closes the connection';

await $client.connect;
$server.close;
sleep 1;
is $client.closed, True, 'Connection closed state is accurate after the server closes the connection';
