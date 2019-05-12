use v6.d;
use Net::Telnet::Client;
use Net::Telnet::Server;

my Net::Telnet::Server $server .= new: :0port;
$server.listen.tap(-> $connection {
    $connection.text.tap(-> $message {
        print $message;
        await $connection.send-text: 'pong';
        $connection.close;
    });
});

my Net::Telnet::Client $client .= new: port => $server.port;
$client.text.tap(-> $message {
    print $message;
}, done => {
    $server.close;
    exit 0;
});

await $client.connect;
await $client.send-text: 'ping';
sleep;
