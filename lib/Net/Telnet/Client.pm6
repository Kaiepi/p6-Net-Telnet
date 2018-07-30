use v6.c;
use Net::Telnet::Chunk;
use Net::Telnet::Option;
unit class Net::Telnet::Client;

has Str               $.host;
has Int               $.port;
has IO::Socket::Async $.socket;
has Bool              $.closed   = True;
has Supplier          $.text    .= new;
has Map               $.options;

has Int $.client-width  = 0;
has Int $.client-height = 0;
has Int $.server-width  = 0;
has Int $.server-height = 0;

has Net::Telnet::Chunk::Actions $!actions    .= new;
has Blob                        $!parser-buf .= new;

method text(--> Supply) { $!text.Supply }

method new(Str :$host, Int :$port = 23, :@preferred, :@supported --> ::?CLASS:D) {
    my Map $options .= new: TelnetOption.enums.kv.map: -> $k, $v {
        my $option    = TelnetOption($v);
        my $supported = defined @supported.index($k);
        my $preferred = defined @preferred.index($k);
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred;
    };

    self.bless: :$host, :$port, :$options;
}

multi method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port).then(-> $p {
        $!closed = False;

        my Buf $buf .= new;
        $!socket = $p.result;
        $!socket.Supply(:bin, :$buf).act(-> $data {
            self.parse($data);
        }, done => {
            $!closed = True;
        }, quit => {
            $!closed = True;
        });

        # TODO: once getting the file descriptor of IO::Socket::Async sockets is
        # possible, set SO_OOBINLINE and implement GA support.

        self
    });
}

method parse(Blob $data) {
    my Blob                        $buf    = $!parser-buf.elems ?? $!parser-buf.splice.append($data) !! $data;
    my Str                         $msg    = $buf.decode('latin1');
    my Net::Telnet::Chunk::Grammar $match .= subparse($msg, :$!actions);

    for $match.ast -> $chunk {
        given $chunk {
            when Net::Telnet::Chunk::Command {
                say '[RECV] ', $chunk;
                self!parse-command: $chunk;
            }
            when Net::Telnet::Chunk::Negotiation {
                say '[RECV] ', $chunk;
                self!parse-negotiation: $chunk;
            }
            when Net::Telnet::Chunk::Subnegotiation {
                say '[RECV] ', $chunk;
                self!parse-subnegotiation: $chunk;
            }
            when Str {
                $!text.emit($chunk);
            }
        }
    }

    $!parser-buf = $match.postmatch.encode('latin1') if $match.postmatch;
}

method !parse-command(Net::Telnet::Chunk::Command $command) {
    # ...
}

method !parse-negotiation(Net::Telnet::Chunk::Negotiation $negotiation --> Promise) {
    my Net::Telnet::Option $option = $!options{$negotiation.option};
    my TelnetCommand       $command;

    given $negotiation.command {
        when DO   { $command = $option.on-receive-do   }
        when DONT { $command = $option.on-receive-dont }
        when WILL { $command = $option.on-receive-will }
        when WONT { $command = $option.on-receive-wont }
    }

    if defined $command {
        self!send-negotiation($command, $negotiation.option).then(-> $p {
            [$p.result, await self!send-subnegotiation: $negotiation.option]
        });
    } else {
        Promise.start({ [0, 0] })
    }
}

method !parse-subnegotiation(Net::Telnet::Chunk::Subnegotiation $subnegotiation) {
    given $subnegotiation {
        when Net::Telnet::Chunk::Subnegotiation::NAWS {
            $!server-width  = $subnegotiation.width;
            $!server-height = $subnegotiation.height;
        }
    }
}

multi method send(Blob $data --> Promise) { $!socket.write($data) }
multi method send(Str $data --> Promise)  { $!socket.print($data) }

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Chunk::Negotiation $negotiation .= new: :$command, :$option;
    say '[SEND] ', $negotiation;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    my Net::Telnet::Chunk::Subnegotiation $subnegotiation;

    given $option {
        when NAWS {
            # TODO: detect width/height of terminal from Net::Telnet::Terminal.
            # Having 0 for the width and height is allowed, that just means the
            # server decides what the width and height should be on its own.
            $!client-width  = 0;
            $!client-height = 0;
            $subnegotiation = Net::Telnet::Chunk::Subnegotiation::NAWS.new:
                width  => $!client-width,
                height => $!client-height;
        }
    }

    if defined $subnegotiation {
        say '[SEND] ', $subnegotiation;
        self.send: $subnegotiation.serialize
    } else {
        Promise.start({ 0 })
    }
}

method close(--> Bool) {
    return False if $!closed;

    $!socket.close;
    $!closed      = True;
    $!parser-buf .= new;
    True
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
