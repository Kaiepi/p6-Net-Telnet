use v6.d;
unit module Net::Telnet:ver<0.0.1>:auth<github:Kaiepi>;

=begin pod

=head1 NAME

Net::Telnet - TELNET library for clients and servers

=head1 SYNOPSIS

    use Net::Telnet::Client;
    use Net::Telnet::Constants;
    use Net::Telnet::Server;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred[NAWS, TERMINAL_TYPE],
        :supported[SGA, ECHO];
    $client.text.tap({ .print });

    await $client.connect;
    await $client.send-text: 'cowsay ayy lmao';
    $client.close;

    my Net::Telnet::Server $server .= new:
        :host<localhost>,
        :preferred[SGA, ECHO],
        :supported[NAWS, TERMINAL_TYPE];

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

C<Net::Telnet> is a library for creating TELNET clients and servers.

Before you get started, read the documentation in the C<docs> directory and
read the example code in the C<examples> directory.

If you are using C<Net::Telnet::Client> and don't know what options the server
will attempt to negotiate with, run C<bin/p6telnet-grep-options> using the
server's host and port to grep the list of options it attempts to negotiate with
when you first connect to it.

The following options are currently supported:

=item TRANSMIT_BINARY
=item ECHO
=item SGA
=item TERMINAL_TYPE
=item XDISPLOC
=item NAWS

=head1 AUTHOR

Ben Davies (Kaiepi)

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
