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
    await $client.send("cowsay ayy lmao\r\n");
    $client.close;

    my Net::Telnet::Server $server .= new:
        :host<localhost>,
        :preferred<SGA ECHO>,
        :supported<NAWS>;
    $server.listen;

    react {
        whenever $server.connections -> $conn {
            $conn.text.tap(-> $text {
                say "$conn.host:$conn.port sent '$text'";
                $conn.close;
            }, done => {
                # Connection was closed; clean up if necessary.
            });

            LAST {
                # Server was closed; clean up if necessary.
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

Ben Davies (kaiepi)

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

