use v6.c;
use NativeCall;
use Net::Telnet::Chunk;
use Net::Telnet::Command;
use Net::Telnet::Constants;
use Net::Telnet::Exceptions;
use Net::Telnet::Negotiation;
use Net::Telnet::Option;
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
has Str               $.host;
has Int               $.port;
has Promise           $.negotiated    .= new;
has Promise           $.close-promise .= new;
has Supplier          $!text          .= new;
has Supplier          $!binary        .= new;

has Promise     %!pending-negotiations;
has Promise     %!pending-subnegotiations;

has Map         $.options;
has Str         @.preferred;
has Str         @.supported;

has Int $.host-width  = 0;
has Int $.host-height = 0;
has Int $.peer-width  = 0;
has Int $.peer-height = 0;
has Tap $!terminal;

has Net::Telnet::Chunk::Actions $!actions        .= new;
has atomicint                   $!failed-matches  = 0;
has Blob                        $!remainder      .= new;

method closed(--> Bool) {
    $!close-promise.status ~~ Kept
}

method text(--> Supply) {
    $!text.Supply
}

method binary(--> Supply) {
    $!binary.Supply
}

method supported(Str $option --> Bool) {
    @!supported ∋ $option
}

method preferred(Str $option --> Bool) {
    @!preferred ∋ $option
}

method new(
    Str :$host = 'localhost',
    Int :$port = 23,
        :$preferred = [],
        :$supported = [],
        *%args
) {
    my Str @preferred = |$preferred;
    my Str @supported = |$supported;
    my Map $options  .= new: TelnetOption.enums.kv.map(-> $k, $v {
        my TelnetOption $option    = TelnetOption($v);
        my Bool         $supported = @supported ∋ $k;
        my Bool         $preferred = @preferred ∋ $k;
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred;
    });
    self.bless: :$host, :$port, :$options, :@supported, :@preferred, |%args;
}

method !on-connect(IO::Socket::Async $!socket) {
    $!socket.Supply(:bin).tap(-> $data {
        self.parse: $data;
    }, done => {
        self!on-close;
    }, quit => {
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
        await self!send-subnegotiation(NAWS) if $!options{NAWS}.enabled: :local;
    });

    self
}

method !on-close {
    $!close-promise.keep;
    $!remainder .= new;
    $!text.done;
    $!binary.done;
    $!terminal.close;
}

# This is left up to the implementation to decide when to call.
method !negotiate-on-init {
    for $!options.values -> $option {
        if $option.preferred {
            my TelnetCommand $command = $option.on-send-will;
            await self!send-negotiation: $command, $option.option if defined $command;
        }
        if $option.supported {
            my TelnetCommand $command = $option.on-send-do;
            await self!send-negotiation: $command, $option.option if defined $command;
        }
    }

    $!negotiated.keep;
}

method parse(Blob $incoming) {
    my Blob                        $data     = $!remainder ~ $incoming;
    my Str                         $message  = $data.decode: 'latin1';
    my Net::Telnet::Chunk::Grammar $match   .= subparse: $message, :$!actions;

    if $match.ast ~~ Nil && ++⚛$!failed-matches >= 3 {
        X::Net::Telnet::ProtocolViolation.new(:$!host, :$!port, :$!remainder).throw;
    } elsif ⚛$!failed-matches {
        $!failed-matches ⚛= 0;
    }

    for $match.ast -> $chunk {
        given $chunk {
            when Net::Telnet::Command {
                say '[RECV] ', $chunk;
                self!parse-command: $chunk;
            }
            when Net::Telnet::Negotiation {
                say '[RECV] ', $chunk;
                self!parse-negotiation: $chunk;
            }
            when Net::Telnet::Subnegotiation {
                say '[RECV] ', $chunk;
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

    if $match.ast ~~ Nil {
        $!remainder ~= $data;
    } elsif $match.postmatch {
        $!remainder ~= $match.postmatch.encode: 'latin1';
    } elsif $!remainder {
        $!remainder .= new;
    }
}

method !parse-command(Net::Telnet::Command $command) {
    # ...
}

method !parse-negotiation(Net::Telnet::Negotiation $negotiation) {
    if %!pending-negotiations{$negotiation.option}:exists {
        return self.close if %!pending-negotiations{$negotiation.option}.status ~~ Kept;
        %!pending-negotiations{$negotiation.option}.keep: $negotiation.command;
    } else {
        %!pending-negotiations{$negotiation.option} .= start: { $negotiation.command };
    }

    my Net::Telnet::Option $option  = $!options{$negotiation.option};
    my TelnetCommand       $command = do given $negotiation.command {
        when DO   { $option.on-receive-do   }
        when DONT { $option.on-receive-dont }
        when WILL { $option.on-receive-will }
        when WONT { $option.on-receive-wont }
    }

    if defined $command {
        await self!send-negotiation($command, $negotiation.option);
        given $negotiation.command {
            when WILL { await self!send-subnegotiation: $negotiation.option if $option.them == YES }
            when DO   { await self!send-subnegotiation: $negotiation.option if $option.us   == YES }
        }
    }
}

method !parse-subnegotiation(Net::Telnet::Subnegotiation $subnegotiation) {
    if %!pending-subnegotiations{$subnegotiation.option}:exists {
        return self.close if %!pending-subnegotiations{$subnegotiation.option}.status ~~ Kept;
        %!pending-subnegotiations{$subnegotiation.option}.keep: $subnegotiation.command;
    } else {
        %!pending-subnegotiations{$subnegotiation.option} .= start: { $subnegotiation.command };
    }

    given $subnegotiation.option {
        when NAWS {
            $!peer-width  = $subnegotiation.width;
            $!peer-height = $subnegotiation.height;
        }
    }
}

method !parse-text(Str $data) {
    $!text.emit: $data;
}

method !parse-blob(Blob $data) {
    $!binary.emit: $data;
}

proto method send($ --> Promise) {*}
multi method send(Blob $data --> Promise) { $!socket.write: $data }
multi method send(Str  $data --> Promise) { $!socket.print: $data }

method send-text(Str $data --> Promise) {
    $!socket.print: "$data\r\n"
}

method send-binary(Blob $data --> Promise) {
    start {
        unless $!options{TRANSMIT_BINARY}.enabled: :remote {
            my TelnetCommand $res = await %!pending-negotiations{TRANSMIT_BINARY} if %!pending-negotiations{TRANSMIT_BINARY}:exists;
            unless $res.defined && $res eq DO {
                await self!send-negotiation: WILL, TRANSMIT_BINARY;
                $res = await %!pending-negotiations{TRANSMIT_BINARY};
                X::Net::Telnet::TransmitBinary.new(:$!host, :$!port).throw unless $res eq DO;
            }
        }

        await self.send: Blob.new: $data.reduce({ $^b == 0xFF ?? (|$^a, $^b, $^b) !! (|$^a, $^b) });
        await self!send-negotiation: WONT, TRANSMIT_BINARY;
    }
}

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Negotiation $negotiation .= new: :$command, :$option;
    %!pending-negotiations{$option} .= new;
    say '[SEND] ', $negotiation;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    my Net::Telnet::Subnegotiation $subnegotiation = do given $option {
        when NAWS {
            Net::Telnet::Subnegotiation::NAWS.new:
                width  => $!host-width,
                height => $!host-height
        }
        default { Nil }
    };
    return Promise.start({ 0 }) unless defined $subnegotiation;

    %!pending-subnegotiations{$option} .= new;
    say '[SEND] ', $subnegotiation;
    self.send: $subnegotiation.serialize
}

method close(--> Bool) {
    $!socket.close
}
