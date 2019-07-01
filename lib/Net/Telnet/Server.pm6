use v6.d;
use Net::Telnet::Connection;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Terminal::Server;
unit class Net::Telnet::Server;

class Connection does Net::Telnet::Connection {
    trusts Net::Telnet::Server;

    # A unique identifier for this connection.
    #
    # It's not up to the library to keep track of connections after they've
    # been emitted to the Supply returned by Net::Telnet::Server.listen. This
    # allows you to do so yourself.
    has Int $.id;

    method !init-terminal(--> Net::Telnet::Terminal) {
        Net::Telnet::Terminal::Server.new
    }

    method !send-initial-negotiations(--> Nil) {
        for $!options.values -> $option {
            if $option.preferred {
                my TelnetCommand $command = $option.on-send-will;
                if $command.defined {
                    await self!send-negotiation: $command, $option.option;
                    await $!pending.negotiations.get: $option.option;
                    $!pending.negotiations.remove: $option.option;
                }
            }
            if $option.supported {
                my TelnetCommand $command = $option.on-send-do;
                if $command.defined {
                    await self!send-negotiation: $command, $option.option;
                    await $!pending.negotiations.get: $option.option;
                    $!pending.negotiations.remove: $option.option;
                }
            }
        }

        # Send "IAC SB TERMINAL_TYPE SEND IAC SE" and await a response from the
        # client to set its terminal type.
        if $!options{TERMINAL_TYPE}.enabled: :remote {
            await self!send-subnegotiation: TERMINAL_TYPE;

            my Net::Telnet::Subnegotiation::TerminalType $subnegotiation =
                await $!pending.subnegotiations.get: TERMINAL_TYPE;
            $!terminal.type = $subnegotiation.type;

            $!pending.subnegotiations.remove: TERMINAL_TYPE;
        }
    }

    method !update-host-state(Net::Telnet::Subnegotiation $subnegotiation --> Nil) {
        given $subnegotiation.option {
            when NAWS {
                $!terminal.width  = $subnegotiation.width;
                $!terminal.height = $subnegotiation.height;
            }
            when TERMINAL_TYPE {
                if $subnegotiation.command != TerminalTypeCommand::IS {
                    my Blob $data = $subnegotiation.serialize;
                    X::Net::Telnet::ProtocolViolation.new(:$!host, :$!port, :$data).throw;
                }
                $!terminal.type = $subnegotiation.type;
            }
        }
    }

    method !update-peer-state(TelnetOption $option --> Net::Telnet::Subnegotiation) {
        given $option {
            when TERMINAL_TYPE {
                Net::Telnet::Subnegotiation::TerminalType.new(
                    command => TerminalTypeCommand::SEND
                )
            }
            default {
                Nil
            }
        }
    }
}

has IO::Socket::Async::ListenSocket $.socket;

has Str $.host;
has Int $.port;

has TelnetOption @.preferred;
has TelnetOption @.supported;

has Supplier  $!connections         .= new;
has atomicint $!next-connection-id;

method new(
    Str :$host      = 'localhost',
    Int :$port      = 23,
        :$preferred = [],
        :$supported = []
) {
    my TelnetOption @preferred = |$preferred;
    my TelnetOption @supported = |$supported;
    self.bless: :$host, :$port, :@preferred, :@supported;
}

method listen(--> Supply) {
    $!socket = IO::Socket::Async.listen($!host, $!port, :enc<latin1>).tap(-> $connection {
        self!on-connect: $connection;
    });

    $!port = await $!socket.socket-port if $!port == 0;

    $!connections.Supply
}

method !on-connect(IO::Socket::Async $socket --> Nil) {
    my Int        $id          = $!next-connection-id⚛++;
    my Str        $host        = $socket.peer-host;
    my Int        $port        = $socket.peer-port;
    my Connection $connection .= new:
        :$id, :$host, :$port, :@!preferred, :@!supported;
    $connection!Connection::on-connect: $socket;
    $!connections.emit: $connection;
}

method close(--> Bool) {
    $!connections.done;
    $!socket.close;
}

=begin pod

=head1 NAME

Net::Telnet::Server

=head1 DESCRIPTION

C<Net::Telnet::Server> is a class that creates TELNET servers.

=head1 SYNOPSIS

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

=head1 ATTRIBUTES

=item IO::Socket::Async::ListenSocket B<$.socket>

The server's socket.

=item Str B<$.host>

The server's hostname.

=item Int B<$.port>

The server's port.

=item Net::Telnet::Constants::TelnetOption B<@.preferred>

A list of option names to be enabled by the server.

=item Net::Telnet::Constants::TelnetOption B<@.supported>

A list of options to be allowed to be enabled by the client.

=head1 METHODS

=item B<new>(Str I<:$host>, Int I<:$port>, Str I<:@preferred>, Str I<:@supported>)

Initializes a new C<Net::Telnet::Server> instance.

=item B<listen>(--> Supply)

Begins listening for connections given the host and port the server was
initialized with. This returns a C<Supply> that emits
C<Net::Telnet::Server::Connection> instances. See the documentation on
C<Net::Telnet::Connection> for more information.

=item B<close>(--> Bool)

Closes the server's socket.

=end pod
