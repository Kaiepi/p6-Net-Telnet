[![Build Status](https://travis-ci.org/Kaiepi/p6-Net-Telnet.svg?branch=master)](https://travis-ci.org/Kaiepi/p6-Net-Telnet)

NAME
====

Net::Telnet - TELNET library for clients and servers

SYNOPSIS
========

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

DESCRIPTION
===========

`Net::Telnet` is a library for creating TELNET clients and servers.

Before you get started, read the documentation in the `docs` directory and read the example code in the `examples` directory.

If you are using `Net::Telnet::Client` and don't know what options the server will attempt to negotiate with, run `bin/p6telnet-grep-options` using the server's host and port to grep the list of options it attempts to negotiate with when you first connect to it.

The following options are currently supported:

  * TRANSMIT_BINARY

  * ECHO

  * SGA

  * TERMINAL_TYPE

  * NAWS

AUTHOR
======

Ben Davies (Kaiepi)

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

