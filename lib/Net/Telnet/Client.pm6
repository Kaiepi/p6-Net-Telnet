use v6.c;
use Net::Telnet::Connection;
use Net::Telnet::Option;
unit class Net::Telnet::Client does Net::Telnet::Connection;

has Bool $!negotiated = False;

method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port).then(-> $p {
        self!on-connect: $p.result;
    })
}

# We don't want to send any subnegotiations for our supported options until
# after the server has requested which options should be enabled. Only then
# should we send our negotiations, and only if the server *didn't* tell us to
# already.
method !negotiate-on-init {
    $!options-mux.protect: {
        for $!options.values -> $option {
            if $option.preferred && ($option.us == NO) && ($option.usq == EMPTY) {
                my $command = $option.on-send-will;
                await self!send-negotiation: $command, $option.option if defined $command;
            }
            if $option.supported && ($option.them == NO) && ($option.themq == EMPTY) {
                my $command = $option.on-send-do;
                await self!send-negotiation: $command, $option.option if defined $command;
            }
        }
    }
}

method !parse-text(Str $text) {
    if !$!negotiated {
        $!negotiated = True;
        self!negotiate-on-init;
    }

    $!text.emit: $text;
}

=begin pod

=head1 NAME

Net::Telnet::Client - Telnet client library

=head1 DESCRIPTION

Net::Telnet::Client is a library for creating Telnet clients.

=head1 SYNOPSIS

    use Net::Telnet::Client;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred<NAWS>,
        :supported<ECHO SGA>;
    $client.text.tap({ .print });
    await $client.connect;
    await $client.send("cowsay ayy lmao\r\n");

=head1 ATTRIBUTES

=item IO::Socket::Async B<$.socket>

The client's socket.

=item Str B<$.host>

The host with which the client will connect.

=item Int B<$.port>

The port with which the client will connect.

=item Promise B<$.close-promise>

A promise that is kept once the connection is closed.

=item Map B<$.options>

A map of the state of all options the client is aware of. Its shape is
C«(Net::Telnet::Chunk::TelnetOption => Net::Telnet::Option)».

=item Int B<$.peer-width>

The server's terminal width.

=item Int B<$.peer-height>

The server's terminal height.

=item Int B<$.host-width>

The client's terminal width.

=item Int B<$.host-height>

The client's terminal height.

=head1 METHODS

=item B<closed>(--> Bool)

Whether or not the connection is currently closed.

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
