use v6.c;
use Net::Telnet::Client;
use Net::Telnet::Constants;
use Net::Telnet::Option;
use Net::Telnet::Server;
use Test;

plan 25;

my Str $host = '127.0.0.1';
my Int $port = 8000;

{
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port,
        :preferred<NAWS>,
        :supported<SGA>;
    my Net::Telnet::Server $server .= new:
        :$host,
        :$port,
        :preferred<SGA>,
        :supported<NAWS>;
    my Promise             $p      .= new;

    $client.text.tap(-> $text {
        is $text, 'ayy lmao', 'Can emit text messages received by the client';
        $client.close;
    });

    $server.listen.tap(-> $connection {
        $connection.text.tap(done => {
            is $connection.closed, True, 'Connection closed state is accurate after the client closes the connection';

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
        });

        is $connection.id, 0, 'First connection received has an ID of 0';
        is $connection.host, $server.host, 'Can receive connections on 127.0.0.1';
        isnt $connection.port, $server.host, 'Connections are received on a different port from the server';
        ok $connection.preferred('SGA'), 'Can get server preferred options';
        ok $connection.supported('NAWS'), 'Can get server supported options';
        await $connection.send: 'ayy lmao';
        $p.keep;
    });

    lives-ok { await $client.connect }, 'Can open new connections with clients';
    await $p;
    is $client.host, '127.0.0.1', 'Can get client host';
    is $client.port, 8000, 'Can get client port';
    ok $client.preferred('NAWS'), 'Can get client preferred options';
    ok $client.supported('SGA'), 'Can get client supported options';
	await $client.close-promise;
    is $client.closed, True, 'Client closed state is accurate after the client closes the connection';

    {
        my $option = $client.options{NAWS};
        ok defined($option), 'Client NAWS option exists';
        is $option.us, YES, 'Client local NAWS state is enabled';
    }

    {
        my $option = $client.options{SGA};
        ok defined($option), 'Client SGA option exists';
        is $option.them, YES, 'Client remote SGA option is enabled';
    }

    $server.close;
}

{
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port;
    my Net::Telnet::Server $server .= new:
        :$host,
        :$port;
    my Promise $p1 .= new;
    my Promise $p2 .= new;

    $client.text.tap(done => {
        $p1.keep;
    });

    $server.listen.tap(-> $connection {
        $connection.close;
        await $p1;
        is $connection.closed, True, 'Connection closed state is accurate after the server closes the connection';
        $p2.keep;
    });

    await $client.connect;
    await $p2;
    is $client.closed, True, 'Client closed state is accurate after the server closes the connection';

    $server.close;
}

{
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port;
    my Net::Telnet::Server $server .= new:
        :$host,
        :$port;

    $server.listen.tap(-> $connection {
        await $connection.send: "\x[FF]\x[FA]\x[FF]\x[F0]".encode: 'latin1' for 0..^3;
    });

    await $client.connect;
    await $client.close-promise;
    ok $client.closed, 'Connection gets closed after 3 messages breaking protocol in a row';
    $server.close;
}

{
    my Net::Telnet::Client $client .= new:
        :$host,
        :$port,
        :supported<TRANSMIT_BINARY>;
    my Net::Telnet::Server $server .= new:
        :$host,
        :$port,
        :preferred<TRANSMIT_BINARY>;
    my Blob                $in     .= new: 1,2,3;
    my Promise             $p      .= new;

    $server.listen.tap(-> $connection {
        my Blob $out .= new;
        await $connection.send: 'Transmitting...';
        $connection.binary.tap(-> $data {
            $out ~= $data;
        }, done => {
            cmp-ok $out, 'eqv', $in, 'Can receive binary transmissions';
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

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
