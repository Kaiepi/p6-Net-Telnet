use v6.d;
use Net::Telnet::Client;
use Net::Telnet::Server;

my Blob    $in  = "If two astronauts were on the moon and one bashed the other's head in with a rock would that be fucked up or what?".encode;
my Promise $p  .= new;

my Net::Telnet::Server $server .= new: :0port, :preferred<TRANSMIT_BINARY>;
$server.listen.tap(-> $connection {
    await $connection.negotiated;
    await $connection.send-binary: $in;
    $connection.close;
});

my Net::Telnet::Client $client .= new: :port($server.port), :supported<TRANSMIT_BINARY>;
$client.binary.tap(-> $supply {
    my Blob $out .= new;
    $supply.tap(-> $data {
        $out ~= $data;
    }, done => {
        say 'Received binary data from the server: ', $out;
        $p.keep;
    });
}, done => {
    $server.close;
    exit 0;
});

await $client.connect;
sleep;
