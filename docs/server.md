NAME
====

Net::Telnet::Server

DESCRIPTION
===========

`Net::Telnet::Server` is a class that creates TELNET servers.

SYNOPSIS
========

    use Net::Telnet::Constants;
    use Net::Telnet::Server;

    my Net::Telnet::Server $server .= new:
        :host<localhost>,
        :preferred[SGA, ECHO],
        :supported[NAWS];

    react {
        whenever $server.listen -> $connection {
            $connection.text.tap(-> $text {
                say "Received: $text";
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

ATTRIBUTES
==========

  * IO::Socket::Async::ListenSocket **$.socket**

The server's socket.

  * Str **$.host**

The server's hostname.

  * Int **$.port**

The server's port.

  * Net::Telnet::Constants::TelnetOption **@.preferred**

A list of option names to be enabled by the server.

  * Net::Telnet::Constants::TelnetOption **@.supported**

A list of options to be allowed to be enabled by the client.

METHODS
=======

  * **new**(Str *:$host*, Int *:$port*, Str *:@preferred*, Str *:@supported*)

Initializes a new `Net::Telnet::Server` instance.

  * **listen**(--> Supply)

Begins listening for connections given the host and port the server was initialized with. This returns a `Supply` that emits `Net::Telnet::Server::Connection` instances. See the documentation on `Net::Telnet::Connection` for more information.

  * **close**(--> Bool)

Closes the server's socket.

