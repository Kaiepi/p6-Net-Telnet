use v6.c;
use Net::Telnet::Connection;
unit class Net::Telnet::Client does Net::Telnet::Connection;

has Bool              $.closed = True;

multi method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port).then(-> $p {
        $!closed = False;

        my Buf $buf .= new;
        $!socket = $p.result;
        $!socket.Supply(:bin, :$buf).act(-> $data {
            self.parse: $data;
        }, done => {
            $buf = Nil;
            self!on-close;
        }, quit => {
            $buf = Nil;
            self!on-close;
        });

        # TODO: once getting the file descriptor of IO::Socket::Async sockets is
        # possible, set SO_OOBINLINE and implement GA support.

        self
    });
}

method close(--> Bool) {
    return False if $!closed;
    $!socket.close
}

method !on-close {
    $!closed      = True;
    $!parser-buf .= new;
    $!text.done;
}

=begin pod

=head1 NAME

Net::Telnet::Client - Telnet client library

=head1 DESCRIPTION

Net::Telnet::Client is a library for creating Telnet clients.

=head1 SYNOPSIS

    use Net::Telnet::Client;

    my Net::Telnet::Client $client .= new: :host<telehack.com>, :supported<ECHO SGA NAWS>;
    $client.text.tap(-> $text { $text.print });
    await $client.connect;
    await $client.send("cowsay ayy lmao\r\n");

=head1 ATTRIBUTES

=item Str B<host>

The host with which the client will connect.

=item Int B<port>

The port with which the client will connect.

=item IO::Socket::Async B<socket>

The connection object.

=item Bool B<closed>

Whether or not the connection is currently closed.

=item Map B<options>

A map of the state of all options the client is aware of. Its shape is
C«(Net::Telnet::Chunk::TelnetOption => Net::Telnet::Option)».

=item Int B<client-width>

The client's terminal width.

=item Int B<client-height>

The client's terminal height.

=item Int B<server-width>

The server's terminal width.

=item Int B<server-height>

The server's terminal height.

=head1 METHODS

=item B<text>(--> Supply)

Returns the supply to which text received by the client is emitted.

=item B<supported>(Str $option --> Bool)

Returns whether the option C<$option> is allowed to be enabled by the opposite
end of the connection.

=item B<preferred>(Str $option --> Bool)

Returns whether C<$option> is allowed to be enabled by this end of the
connection.

=item B<new>(Str :$host, Int :$port, :@supported?, :@preferred? --> Net::Telnet::Client)

Initializes a Telnet client. C<$host> and C<$port> are used by C<.connect> to
connect to a server. C<@supported> is an array of options of which the client
will allow the server to negotiate with, while C<@preferred> is an array of
options of which the client I<will> negotiate with the server with. Both are not
required, but should preferrably be included.

=item B<connect>(--> Promise)

Connects the client to a server given the host and port provided in C<.new>.
The promise returned is resolved once the connection has begun.

=item B<send>(Blob I<$data> --> Promise)
=item B<send>(Str I<$data> --> Promise)

Sends a message to the server.

=item B<parse>(Blob I<$data>)

Parses messages received from the server.

=item B<close>(--> Bool)

Closes the connection to the server, if any is open.

=head1 AUTHOR

Ben Davies (kaiepi)

=end pod
