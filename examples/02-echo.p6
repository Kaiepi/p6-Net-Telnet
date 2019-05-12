use v6.d;
use Net::Telnet::Client;
use Net::Telnet::Server;

my Net::Telnet::Server $server .= new: :0port, :supported<ECHO>;
$server.listen.tap(-> $connection {
    $connection.text.tap(-> $message {
        $connection.close;
    });
});

my Net::Telnet::Client $client .= new: :port($server.port), :preferred<ECHO>;
$client.text.tap(-> $message {
    print $message;
}, done => {
    $server.close;
    exit 0;
});

await $client.connect;
await $client.send-text: 'This message was echoed by the server.';
sleep;
