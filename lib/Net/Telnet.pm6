use v6.d;
unit module Net::Telnet:ver<0.0.1>;

=begin pod

=head1 NAME

Net::Telnet - Telnet library for clients and servers

=head1 SYNOPSIS

    use Net::Telnet::Client;
    use Net::Telnet::Constants;
    use Net::Telnet::Server;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred[NAWS],
        :supported[SGA, ECHO];
    $client.text.tap({ .print });
    await $client.connect;
    await $client.negotiated;
    await $client.send-text: 'cowsay ayy lmao';
    $client.close;

    my Net::Telnet::Server $server .= new:
        :host<localhost>,
        :preferred[SGA, ECHO],
        :supported[NAWS];

    react {
        whenever $server.listen -> $connection {
            $connection.text.tap(-> $text {
                say "{$connection.host}:{$connection.port} sent '$text'";
                $connection.close;
            }, done => {
                # Connection was closed; clean up if necessary.
            });

            LAST {
                # Server was closed; clean up if necessary.
            }

            QUIT {
                # Handle exceptions.
            }
        }
        whenever signal(SIGINT) {
            $server.close;
        }
    }

=head1 DESCRIPTION

Net::Telnet is a library for creating Telnet clients and servers. See
C<Net::Telnet::Client> and C<Net::Telnet::Server> for more documentation.

=head1 AUTHOR

Ben Davies (Kaiepi)

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
