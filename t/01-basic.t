use v6.c;
use Net::Telnet::Client;
use Net::Telnet::Constants;
use Net::Telnet::Option;
use Net::Telnet::Server;
use Test;

plan 23;

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
	my Promise $p .= new;

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

            $p.keep;
        });

        is $connection.id, 0, 'First connection received has an ID of 0';
        is $connection.host, $server.host, 'Can receive connections on 127.0.0.1';
        isnt $connection.port, $server.host, 'Connections are received on a different port from the server';
        ok $connection.preferred('SGA'), 'Can get server preferred options';
        ok $connection.supported('NAWS'), 'Can get server supported options';
        await $connection.send: 'ayy lmao';
    });

    lives-ok { await $client.connect }, 'Can open new connections with clients';
    is $client.host, '127.0.0.1', 'Can get client host';
    is $client.port, 8000, 'Can get client port';
    ok $client.preferred('NAWS'), 'Can get client preferred options';
    ok $client.supported('SGA'), 'Can get client supported options';
    await $p;
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
