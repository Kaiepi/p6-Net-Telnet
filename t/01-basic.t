use v6.c;
use Test;
use Net::Telnet::Client;

plan 3;

my $server = IO::Socket::INET.listen('127.0.0.1', 8000);
my $client;

lives-ok {
    $client = await Net::Telnet::Client.connect('127.0.0.1', 8000);
}, 'Can open new connections';
is $client.host, '127.0.0.1', 'Can get connection host';
is $client.port, 8000, 'Can get connection port';

$client.close;
$server.close;
