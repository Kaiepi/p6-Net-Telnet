use v6.c;
use Test;
use Net::Telnet::Client;

plan 6;

my $server = IO::Socket::INET.listen('127.0.0.1', 8000);
my $client;

lives-ok {
    $client = await Net::Telnet::Client.connect('127.0.0.1', 8000);
}, 'Can open new connections';
is $client.peer-host, '127.0.0.1', 'Can get connection host';
is $client.peer-port, 8000, 'Can get connection port';
is $client.closed, False, 'Can get connection closed state';

$client.close;
is $client.closed, True, 'Connection closed state is accurate after the client closes the connection';

$client = await Net::Telnet::Client.connect('127.0.0.1', 8000);
$server.close;
sleep 0.000001;
is $client.closed, True, 'Connection closed state is accurate after the server closes the connection';
