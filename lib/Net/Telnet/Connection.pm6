use v6.d;
use NativeCall;
use Net::Telnet::Chunk;
use Net::Telnet::Command;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Exceptions;
use Net::Telnet::Negotiation;
use Net::Telnet::Option;
use Net::Telnet::Pending;
use Net::Telnet::Subnegotiation;
use Net::Telnet::Terminal;
unit role Net::Telnet::Connection;

my Int constant SO_OOBINLINE = do given $*VM.osname {
    when 'linux' { 0x000A }
    default      { 0x0100 }
};
my Int constant SOL_SOCKET   = do given $*VM.osname {
    when 'linux' { 0x0001 }
    default      { 0xFFFF }
};

sub setsockopt(int32, int32, int32, Pointer[void], uint32 --> int32) is native {*}

has IO::Socket::Async $.socket;

has Str      $.host;
has Int      $.port;
has Promise  $.close-promise .= new;
has Supplier $!text          .= new;
has Supplier $!binary        .= new;
has Supplier $!current-binary;

has Net::Telnet::Pending $.pending .= new;

has Map          $.options;
has TelnetOption @.preferred;
has TelnetOption @.supported;

has Int $.host-width  = 0;
has Int $.host-height = 0;
has Int $.peer-width  = 0;
has Int $.peer-height = 0;
has Tap $!terminal;

has Net::Telnet::Chunk::Actions $!actions   .= new;
has Blob                        $!remainder .= new;

method closed(--> Bool) {
    $!close-promise.status ~~ Kept
}

method text(--> Supply) {
    $!text.Supply
}

method binary(--> Supply) {
    $!binary.Supply
}

method supported(TelnetOption $option --> Bool) {
    @!supported ∋ $option
}

method preferred(TelnetOption $option --> Bool) {
    @!preferred ∋ $option
}

method new(
    Str :$host = 'localhost',
    Int :$port = 23,
        :$preferred = [],
        :$supported = [],
        *%args
) {
    my TelnetOption @preferred = |$preferred;
    my TelnetOption @supported = |$supported;
    my Map $options  .= new: TelnetOption.enums.kv.map(-> $k, $v {
        my TelnetOption $option    = TelnetOption($v);
        my Bool         $supported = @supported ∋ $option;
        my Bool         $preferred = @preferred ∋ $option;
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred;
    });
    self.bless: :$host, :$port, :$options, :@supported, :@preferred, |%args;
}

method !on-connect(IO::Socket::Async $!socket) {
    $!socket.Supply(:bin).tap(-> $data {
        self!parse: $data;
    }, done => {
        self!on-close;
    });

    if $*VM.version >= v2018.12 {
        my Int           $fd     = $!socket.native-descriptor;
        my Pointer[void] $optval = nativecast(Pointer[void], CArray[int32].new: 1);
        setsockopt($fd, SOL_SOCKET, SO_OOBINLINE, $optval, nativesizeof(int32));
    }

    $!host-width  = Net::Telnet::Terminal.width;
    $!host-height = Net::Telnet::Terminal.height;
    $!terminal    = signal(SIGWINCH).tap({
        $!host-width  = Net::Telnet::Terminal.width;
        $!host-height = Net::Telnet::Terminal.height;
        if $!options{NAWS}.enabled: :local {
            await self!send-subnegotiation(NAWS);
            await $!pending.subnegotiations.get: NAWS;
            $!pending.subnegotiations.remove: NAWS;
        }
    });

    self!send-initial-negotiations;

    self
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
}

method !on-close(--> Nil) {
    $!close-promise.keep;
    $!remainder .= new;
    $!text.done;
    $!binary.done;
    $!terminal.close;
}

method !parse(Blob $incoming --> Nil) {
    my Blob                        $data     = $!remainder ~ $incoming;
    my Str                         $message  = $data.decode: 'latin1';
    my Net::Telnet::Chunk::Grammar $match   .= subparse: $message, :$!actions;

    if $match.ast === Nil {
        X::Net::Telnet::ProtocolViolation.new(:$!host, :$!port, :$data).throw;
    }

    for $match.ast -> $chunk {
        given $chunk {
            when Net::Telnet::Command {
                self!parse-command: $chunk;
            }
            when Net::Telnet::Negotiation {
                self!parse-negotiation: $chunk;
            }
            when Net::Telnet::Subnegotiation {
                self!parse-subnegotiation: $chunk;
            }
            when Str {
                self!parse-text: $chunk;
            }
            when Blob {
                self!parse-blob: $chunk;
            }
        }
    }

    if $match.postmatch {
        $!remainder ~= $match.postmatch.encode: 'latin1';
    } elsif $!remainder {
        $!remainder .= new;
    }
}

method !parse-command(Net::Telnet::Command $command --> Nil) {
    # ...
}

method !parse-negotiation(Net::Telnet::Negotiation $negotiation --> Nil) {
    # Resolve the pending negotiation, if any.
    $!pending.negotiations.resolve: $negotiation;

    # Update our option state.
    my Net::Telnet::Option $option  = $!options{$negotiation.option};
    my TelnetCommand       $command = do given $negotiation.command {
        when DO   { $option.on-receive-do   }
        when DONT { $option.on-receive-dont }
        when WILL { $option.on-receive-will }
        when WONT { $option.on-receive-wont }
    }

    # Handle binary transmissions.
    if $negotiation.option eq TRANSMIT_BINARY {
        given $negotiation.command {
            when WILL {
                if $option.enabled: :remote {
                    $!current-binary .= new;
                    $!binary.emit: $!current-binary.Supply;
                }
            }
            when WONT {
                if $option.disabled: :remote {
                    $!current-binary.done;
                }
            }
        }
    }

    # We must have a response from here on out.
    return unless $command.defined;

    # Send our response(s).
    await self!send-negotiation($command, $negotiation.option);
    given $negotiation.command {
        when WILL {
            await self!send-subnegotiation: $negotiation.option if $option.enabled: :remote;
        }
        when DO {
            await self!send-subnegotiation: $negotiation.option if $option.enabled: :local;
        }
    }
}

method !parse-subnegotiation(Net::Telnet::Subnegotiation $subnegotiation --> Nil) {
    # Resolve the pending subnegotiation, if any.
    $!pending.subnegotiations.resolve: $subnegotiation;

    # Update our state depending on the option.
    given $subnegotiation.option {
        when NAWS {
            $!peer-width  = $subnegotiation.width;
            $!peer-height = $subnegotiation.height;
        }
    }
}

method !parse-text(Str $data --> Nil) {
    await self.send: $data if $!options{ECHO}.enabled: :remote;
    $!text.emit: $data;
}

method !parse-blob(Blob $data --> Nil) {
    $!current-binary.emit: $data;
}

proto method send($ --> Promise) {*}
multi method send(Blob $data --> Promise) {
    $!socket.write: $data
}
multi method send(Str  $data --> Promise) {
    $!socket.print: $data
}

method send-text(Str $data --> Promise) {
    # TELNET doesn't consider text data to have finished being received until
    # it encounters CRLF.
    $!socket.print: "$data\r\n"
}

method send-binary(Blob $data --> Promise) {
    start {
        if $!options{TRANSMIT_BINARY}.disabled: :local {
            my Net::Telnet::Negotiation $negotiation;

            await self!send-negotiation: WILL, TRANSMIT_BINARY;
            $negotiation = await $!pending.negotiations.get: TRANSMIT_BINARY;
            $!pending.negotiations.remove: TRANSMIT_BINARY;

            if $negotiation.command ne DO {
                X::Net::Telnet::TransmitBinary.new(:$!host, :$!port).throw;
            }
        }

        my Blob $escaped-data .= new: $data.contents.reduce({
            $^b == 0xFF ?? (|$^a, $^b, $^b) !! (|$^a, $^b)
        });

        await self.send: $escaped-data;
        await self!send-negotiation: WONT, TRANSMIT_BINARY;
    }
}

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    $!pending.negotiations.request: $option;

    my Net::Telnet::Negotiation $negotiation .= new: :$command, :$option;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    $!pending.subnegotiations.request: $option;

    my Net::Telnet::Subnegotiation $subnegotiation = do given $option {
        when NAWS {
            Net::Telnet::Subnegotiation::NAWS.new:
                width  => $!host-width,
                height => $!host-height
        }
        default {
            Nil
        }
    };
    return Promise.start({ 0 }) unless $subnegotiation.defined;

    self.send: $subnegotiation.serialize
}

method close(--> Bool) {
    $!socket.close
}

=begin pod

=head1 NAME

Net::Telnet::Connection

=head1 DESCRIPTION

Net::Telnet::Connection is a role done by Net::Telnet::Client and
Net::Telnet::Server::Connection. It manages all connection state.

=head1 ATTRIBUTES

=item IO::Socket::Async B<$.socket>

The connection's socket.

=item Str B<$.host>

The host with which the connection will connect.

=item Int B<$.port>

The port with which the connection will connect.

=item Promise B<$.close-promise>

This promise is kept once the connection is closed.

=item Map B<$.options>

A map of the state of all options the connection is aware of. Its shape is
C«(Net::Telnet::Constants::TelnetOption => Net::Telnet::Option)».

=item Int B<$.peer-width>

The peer's terminal width. This is meaningless for Net::Telnet::Client since
C<NAWS> is only supported by clients.

=item Int B<$.peer-height>

The peer's terminal height. This is meaningless for Net::Telnet::Client since
C<NAWS> is only supported by clients.

=item Int B<$.host-width>

The host's terminal width. This is meaningless for
Net::Telnet::Server::Connection since C<NAWS> is only supported by clients.

=item Int B<$.host-height>

The host's terminal height. This is meaningless for
Net::Telnet::Server::Connection since C<NAWS> is only supported by clients.

=head1 METHODS

=item B<closed>(--> Bool)

Whether or not the connection is currently closed.

=item B<text>(--> Supply)

Returns the supply to which text received by the connection is emitted.

=item B<binary>(--> Supply)

Returns the supply to which supplies that emit binary data received by the
connection is emitted.

=item B<supported>(Str $option --> Bool)

Returns whether or not C<$option> is allowed to be enabled by the peer.

=item B<preferred>(Str $option --> Bool)

Returns whether or not C<$option> is allowed to be enabled by us.

=item B<new>(Str I<:$host>, Int I<:$port>, I<:@supported?>, I<:@preferred?> --> Net::Telnet::Client)

Initializes a TELNET connection. C<$host> and C<$port> are used by C<.connect> to
connect to a peer.

C<@supported> is a list of options that the connection will allow the peer to
negotiate with. On connect, C«DO» negotiations will be sent for each option in
this list as part of the connection's initial negotiations, unless this is a
Net::Telnet::Client instance and the peer has already sent a C«WILL»
negotiation.

C<@preferred> is a list of options that the connection will attempt to
negotiate with. On connect, C«IAC WILL» commands will be sent for each option
in this list as part of the connection's initial negotiations, unless this is a
Net::Telnet::Client instance and the peer has already sent a C«DO» negotiation.

=item B<connect>(--> Promise)

Connects to the peer given the host and port provided in C<new>. The promise
returned is resolved once the connection has been opened.

C<X::Net::Telnet::ProtocolViolation> may be thrown at any time if the peer is
either buggy, malicious, or not a TELNET server to begin with and doesn't
follow TELNET protocol.

C<X::Net::Telnet::OptionRace> may be thrown at any time if the peer is buggy
or malicious and attempts to start a negotiation before another negotiation for
the same option has finished. It may also be thrown if there is a race
condition somewhere in negotiation handling.

=item B<send>(Blob I<$data> --> Promise)
=item B<send>(Str I<$data> --> Promise)

Sends raw data to the server.

=item B<send-text>(Str I<$data> --> Promise)

Sends a message appended with C<CRLF> to the server.

=item B<send-binary>(Blob I<$data> --> Promise)

Sends binary data to the server. If the server isn't already expecting binary
data, this will send the necessary C<TRANSMIT_BINARY> negotiations to attempt to
convince the server to parse incoming data as binary data. This will throw
C<X::Net::Telnet::TransmitBinary> if the server declines to begin binary data
transmission.

=item B<close>(--> Bool)

Closes the connection to the server, if any is open.

=end pod
