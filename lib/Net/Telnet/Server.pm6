use v6.d;
use Net::Telnet::Connection;
use Net::Telnet::Constants :ALL;
unit class Net::Telnet::Server;

class Connection does Net::Telnet::Connection {
    trusts Net::Telnet::Server;

    has Int $.id;
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
    my Int $id   = $!next-connection-id⚛++;
    my Str $host = $socket.peer-host;
    my Int $port = $socket.peer-port;

    my Connection $connection .= new: :$id, :$host, :$port, :@!preferred, :@!supported;
    $connection!Connection::on-connect: $socket;

    $!connections.emit: $connection;
}

multi method close(--> Bool) {
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
