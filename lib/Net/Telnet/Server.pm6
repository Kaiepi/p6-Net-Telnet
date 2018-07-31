use v6.c;
use Net::Telnet::Connection;
unit class Net::Telnet::Server;

class Connection does Net::Telnet::Connection {
    has Int $.id;

    method on-open(IO::Socket::Async $socket) {
        self!on-connect: $socket;
        self!negotiate-on-init;
    }
}

has Tap  $.socket;
has Str  $.host;
has Int  $.port;

has Supplier  $.connections .= new;
has atomicint $!next-connection-id;

has Str @.preferred;
has Str @.supported;

method connections(--> Supply) { $!connections.Supply }

method new(
    Str :$host,
    Int :$port      = 23,
        :$preferred = [],
        :$supported = []
) {
    my Str @preferred = |$preferred;
    my Str @supported = |$supported;
    self.bless: :$host, :$port, :@preferred, :@supported;
}

method listen(--> Supply) {
    $!socket = IO::Socket::Async.listen($!host, $!port).tap(-> $socket {
        self!on-connect: $socket;
    });
    $!connections.Supply
}

method !on-connect(IO::Socket::Async $socket) {
    my Int $id = $!next-connection-id⚛++;
    my Connection $connection .= new:
        :$id,
        :host($socket.peer-host),
        :port($socket.peer-port),
        :@!preferred,
        :@!supported;
    $connection.on-open: $socket;
    $!connections.emit: $connection;
}

multi method close(--> Bool) {
    $!socket.close;
    $!connections.done;
}

=begin pod

=head1 NAME

Net::Telnet::Server - Telnet server library

=head1 DESCRIPTION

Net::Telnet::Server is a library for creating Telnet servers.

=head1 SYNOPSIS

    use Net::Telnet::Server;

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

=head1 ATTRIBUTES

=item Tap B<$.socket>

The server's socket.

=item Str B<$.host>

The server's hostname.

=item Int B<$.port>

The server's port.

=item Supplier B<$.connections>

A supplier that emits C<Net::Telnet::Server::Connection> objects when they
connect to the server. C<Net::Telnet::Server::Connection> objects are similar
to C<Net::Telnet::Client> objects, but include an additional C<Int> C<$.id>
attribute to simplify tracking the state of the connection object if needed.

=item Net::Telnet::Option B<@.preferred>

A list of option names to be enabled by the server. Valid option names can be
found in C<Net::Telnet::Constants::TelnetOption>.

=item Net::Telnet::Option B<@.supported>

A list of option names to be allowed to be enabled by the client. Valid option
names can be found in C<Net::Telnet::Constants::TelnetOption>.

=head1 METHODS

=item B<connections>(--> Supply)

This returns C<$!connections.Supply>.

=item B<new>(Str I<:$host>, Int I<:$port>, Str I<:@preferred>, Str I<:@supported>)

Initializes a new C<Net::Telnet::Server> instance.

=item B<listen>(--> Supply)

Begins listening for connections given the host and port the server was
initialized with. This returns C<$!connections.Supply>.

=item B<close>(--> Bool)

Closes the server's socket.

=end pod
