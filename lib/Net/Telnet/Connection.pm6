use v6.c;
use NativeCall;
use Net::Telnet::Chunk;
use Net::Telnet::Command;
use Net::Telnet::Constants;
use Net::Telnet::Negotiation;
use Net::Telnet::Option;
use Net::Telnet::Subnegotiation;
use Net::Telnet::Terminal;
unit role Net::Telnet::Connection;

my constant SO_OOBINLINE = do given $*VM.osname {
    when 'linux' { 0x000A }
    default      { 0x0100 }
};
my constant SOL_SOCKET   = do given $*VM.osname {
    when 'linux' { 0x0001 }
    default      { 0xFFFF }
};

sub setsockopt(int32, int32, int32, Pointer[void], uint32 --> int32) is native {*}

has IO::Socket::Async $.socket;
has Str               $.host;
has Int               $.port;
has Promise           $.close-promise .= new;
has Supplier          $.text          .= new;

has Lock::Async $!options-mux .= new;
has Map         $.options;
has Str         @.preferred;
has Str         @.supported;

has Int $.host-width  = 0;
has Int $.host-height = 0;
has Int $.peer-width  = 0;
has Int $.peer-height = 0;
has Tap $!terminal;

has Net::Telnet::Chunk::Actions $!actions        .= new;
has Int                         $!failed-matches  = 0;
has Blob                        $!parser-buf     .= new;

method closed(--> Bool) {
    $!close-promise.status ~~ Kept
}

method text(--> Supply) {
    $!text.Supply
}

method supported(Str $option --> Bool) {
    @!supported.contains: $option
}

method preferred(Str $option --> Bool) {
    @!preferred.contains: $option
}

method new(
    Str :$host,
    Int :$port = 23,
        :$preferred = [],
        :$supported = [],
        *%args
) {
    my Str @preferred = |$preferred;
    my Str @supported = |$supported;
    my Map $options  .= new: TelnetOption.enums.kv.map: -> $k, $v {
        my TelnetOption $option    = TelnetOption($v);
        my Bool         $supported = @supported.contains: $k;
        my Bool         $preferred = @preferred.contains: $k;
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred;
    };

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

    if $*VM.name eq 'moar' && $*VM.version >= v2018.12 {
        my Int           $fd     = $!socket.native-descriptor;
        my Pointer[void] $optval = nativecast(Pointer[void], CArray[int32].new: 1);
        setsockopt($fd, SOL_SOCKET, SO_OOBINLINE, $optval, nativesizeof(int32));
    }

    $!host-width  = Net::Telnet::Terminal.width;
    $!host-height = Net::Telnet::Terminal.height;
    $!terminal    = signal(SIGWINCH).tap({
        $!host-width  = Net::Telnet::Terminal.width;
        $!host-height = Net::Telnet::Terminal.height;
        self!send-subnegotiation(NAWS) if $!options{NAWS} && $!options{NAWS}.us == YES;
    });

    self
}

method !on-close {
    $!close-promise.keep;
    $!parser-buf .= new;
    $!text.done;
    $!terminal.close;
}

# This is left up to the implementation to decide when to call.
method !negotiate-on-init {
    $!options-mux.protect: {
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
    }
}

method parse(Blob $data) {
    my Blob                        $buf    = $!parser-buf.elems ?? $!parser-buf.splice.append($data) !! $data;
    my Str                         $msg    = $buf.decode('latin1');
    my Net::Telnet::Chunk::Grammar $match .= subparse($msg, :$!actions);

    if $match.ast ~~ Nil {
        self.close if ++$!failed-matches >= 3;
        return;
    } else {
        $!failed-matches = 0 if $!failed-matches;
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
        }
    }

    $!parser-buf = $match.postmatch.encode('latin1') if $match.postmatch;
}

method !parse-command(Net::Telnet::Command $command) {
    # ...
}

method !parse-negotiation(Net::Telnet::Negotiation $negotiation) {
    $!options-mux.protect: {
        my Net::Telnet::Option $option = $!options{$negotiation.option};
        my TelnetCommand       $command;

        given $negotiation.command {
            when DO   { $command = $option.on-receive-do   }
            when DONT { $command = $option.on-receive-dont }
            when WILL { $command = $option.on-receive-will }
            when WONT { $command = $option.on-receive-wont }
        }

        if defined $command {
            await self!send-negotiation($command, $negotiation.option);
            given $negotiation.command {
                when WILL { await self!send-subnegotiation: $negotiation.option if $option.them == YES }
                when DO   { await self!send-subnegotiation: $negotiation.option if $option.us   == YES }
            }
        }
    }
}

method !parse-subnegotiation(Net::Telnet::Subnegotiation $subnegotiation) {
    given $subnegotiation.option {
        when NAWS {
            $!peer-width  = $subnegotiation.width;
            $!peer-height = $subnegotiation.height;
        }
    }
}

method !parse-text(Str $text) {
    $!text.emit: $text;
}

multi method send(Blob $data --> Promise) { $!socket.write: $data }
multi method send(Str  $data --> Promise) { $!socket.print: $data }

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Negotiation $negotiation .= new: :$command, :$option;
    say '[SEND] ', $negotiation;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    my Net::Telnet::Subnegotiation $subnegotiation;

    given $option {
        when NAWS {
            $subnegotiation = Net::Telnet::Subnegotiation::NAWS.new:
                width  => $!host-width,
                height => $!host-height
        }
    }

    return Promise.start({ 0 }) unless defined $subnegotiation;
    say '[SEND] ', $subnegotiation;
    self.send: $subnegotiation.serialize
}

method close(--> Bool) {
    $!socket.close
}
