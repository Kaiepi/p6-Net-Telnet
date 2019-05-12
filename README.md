[![Build Status](https://travis-ci.org/Kaiepi/p6-Net-Telnet.svg?branch=master)](https://travis-ci.org/Kaiepi/p6-Net-Telnet)

NAME
====

Net::Telnet - Telnet library for clients and servers

SYNOPSIS
========

    use Net::Telnet::Client;
    use Net::Telnet::Server;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred<NAWS>,
        :supported<SGA ECHO>;
    $client.text.tap({ .print });
    await $client.connect;
    await $client.negotiated;
    await $client.send-text: 'cowsay ayy lmao';
    $client.close;

    my Net::Telnet::Server $server .= new:
        :host<localhost>,
        :preferred<SGA ECHO>,
        :supported<NAWS>;

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

Net::Telnet is a library for creating Telnet clients and servers. See `Net::Telnet::Client` and `Net::Telnet::Server` for more documentation.

AUTHOR
======

Ben Davies (Kaiepi)

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

