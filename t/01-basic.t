use v6.d;
use Net::Telnet::Client;
use Net::Telnet::Constants;
use Net::Telnet::Exceptions;
use Net::Telnet::Option;
use Net::Telnet::Server;
use Test;

plan 23;

my Str $host = '127.0.0.1';
my Int $port = 8080;

{
    my Promise $p .= new;

    my Net::Telnet::Server $server .= new:
        :$host,
        :$port,
        :preferred<SGA>,
        :supported<NAWS>;
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port,
        :preferred<NAWS>,
        :supported<SGA>;

    $server.listen.tap(-> $connection {
        $connection.text.tap(done => {
            {
                my $option = $connection.options{NAWS};
                ok defined($option), 'Connection NAWS option exists';
                is $option.them, YES, 'Connection remote NAWS state is enabled';
            }

            {
                my $option = $connection.options{SGA};
                ok defined($option), 'Connection SGA option exists';
                is $option.us, YES, 'Connection SGA local option is enabled';
            }

            $p.keep;
        });

        await $connection.negotiated;
        is $connection.id, 0, 'First connection received has an ID of 0';
        is $connection.host, $server.host, 'Can receive connections on 127.0.0.1';
        isnt $connection.port, $server.host, 'Connections are received on a different port from the server';
        ok $connection.preferred('SGA'), 'Can get server preferred options';
        ok $connection.supported('NAWS'), 'Can get server supported options';
        await $connection.send-text: 'ayy lmao';
    });

    $client.text.tap(-> $text {
        is $text, "ayy lmao\r\n", 'Can emit text messages received by the client';
        $client.close;
    });

    await $client.connect;
    await $client.negotiated;
    await $p;

    is $client.host, '127.0.0.1', 'Can get client host';
    is $client.port, $port, 'Can get client port';
    ok $client.preferred('NAWS'), 'Can get client preferred options';
    ok $client.supported('SGA'), 'Can get client supported options';

    {
        my $option = $client.options{NAWS};
        ok $option.defined, 'Client NAWS option exists';
        is $option.us, YES, 'Client local NAWS state is enabled';
    }

    {
        my $option = $client.options{SGA};
        ok $option.defined, 'Client SGA option exists';
        is $option.them, YES, 'Client remote SGA option is enabled';
    }

    await $client.close-promise;
    is $client.closed, True, 'Client closed state is accurate after the client closes the connection';

    $server.close;
}

{
    my Promise $p1 .= new;
    my Promise $p2 .= new;

    my Net::Telnet::Server $server .= new: :$host, :$port;
    my Net::Telnet::Client $client .= new: :$host, :$port;

    $server.listen.tap(-> $connection {
        $connection.close;
        await $p1;
        is $connection.closed, True, 'Connection closed state is accurate after the server closes the connection';
        $p2.keep;
    });

    $client.text.tap(done => { $p1.keep });

    await $client.connect;
    await $p2;
    is $client.closed, True, 'Client closed state is accurate after the server closes the connection';

    $server.close;
}

{
    my Blob    $in .= new: 1,2,3;
    my Promise $p  .= new;

    my Net::Telnet::Server $server .= new:
        :$host,
        :$port,
        :preferred<TRANSMIT_BINARY>;
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port,
        :supported<TRANSMIT_BINARY>;

    $server.listen.tap(-> $connection {
        my Blob $out .= new;
        $connection.binary.tap(-> $data {
            $out ~= $data;
        }, done => {
            cmp-ok $out, 'eqv', $in, 'Can receive binary transmissions when TRANSMIT_BINARY is set as a preferred option';
            $p.keep;
        });
    });

    await $client.connect;
    await $client.negotiated;
    await $client.send-binary: $in;
    $client.close;
    await $p;
    $server.close;
}

{
    my Promise $p .= new;

    my Net::Telnet::Server $server .= new:
        :$host,
        :$port,
        :supported<ECHO>;
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port,
        :preferred<ECHO>;

    $client.text.tap({
        pass 'Can receive text sent when ECHO is set as a preferred option';
        $p.keep
    });

    $server.listen;
    await $client.connect;
    await $client.negotiated;
    await $client.send: "If two astronauts were on the moon and one bashed the other's head in with a rock would that be fucked up or what?";

    await Promise.anyof(
        Promise.in(5).then({ flunk 'Can receive text sent when ECHO is set as a preferred option' }),
        $p
    );

    $client.close;
    $server.close;
}
# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
