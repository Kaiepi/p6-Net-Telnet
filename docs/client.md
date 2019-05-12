NAME
====

Net::Telnet::Client

DESCRIPTION
===========

`Net::Telnet::Client` is a class that creates TELNET clients. For documentation on the majority of its attributes and methods, see the documentation on `Net::Telnet::Connection`.

SYNOPSIS
========

    use Net::Telnet::Client;
    use Net::Telnet::Constants;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred[NAWS],
        :supported[ECHO, SGA];
    $client.text.tap({ .print });

    await $client.connect;
    await $client.send-text: 'cowsay ayy lmao';
    $client.close;

METHODS
=======

  * **connect**(--> Promise)

Connects to the server. The promise returned is resolved once the initial negotiations with the server have been completed.

