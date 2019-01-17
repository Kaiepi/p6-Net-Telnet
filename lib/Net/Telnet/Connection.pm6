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
has Promise           $.close-promise .= new;
has Supplier          $.text          .= new;

has Lock::Async $!negotiations-mux         .= new;
has Promise     %!pending-negotiations;
has Promise     %!pending-subnegotiations;

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
has atomicint                   $!failed-matches  = 0;
has buf8                        $!remainder      .= new;

method closed(--> Bool) {
    $!close-promise.status ~~ Kept
}

method text(--> Supply) {
    $!text.Supply
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
        self!send-subnegotiation(NAWS) if $!options{NAWS}.enabled: :local;
    });

    self
}

method !on-close {
    $!close-promise.keep;
    $!remainder .= new;
    $!text.done;
    $!terminal.close;
}

# This is left up to the implementation to decide when to call.
method !negotiate-on-init {
    $!options-mux.protect({
        for $!options.values -> $option {
            if $option.preferred {
                my TelnetCommand $command = $option.on-send-will;
                self!send-negotiation: $command, $option.option if defined $command;
            }
            if $option.supported {
                my TelnetCommand $command = $option.on-send-do;
                self!send-negotiation: $command, $option.option if defined $command;
            }
        }
    })
}

method parse(Blob $incoming) {
    my Blob                        $data     = $!remainder ~ $incoming;
    my Str                         $message  = $data.decode: 'latin1';
    my Net::Telnet::Chunk::Grammar $match   .= subparse($message, :$!actions);

    if $match.ast ~~ Nil {
        return self.close if ++⚛$!failed-matches >= 3;
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
        }
    }

    if $match.ast ~~ Nil {
        $!remainder ~= $data;
    } elsif $match.postmatch {
        $!remainder ~= $match.postmatch.encode: 'latin1';
    } else {
        $!remainder .= new;
    }
}

method !parse-command(Net::Telnet::Command $command) {
    # ...
}

method !parse-negotiation(Net::Telnet::Negotiation $negotiation) {
    $!negotiations-mux.protect({
        if %!pending-negotiations ∋ $negotiation.option {
            return self.close if %!pending-negotiations{$negotiation.option}.status ~~ Kept;
            %!pending-negotiations{$negotiation.option}.keep: $negotiation.command;
        }
    });

    $!options-mux.protect({
        my Net::Telnet::Option $option  = $!options{$negotiation.option};
        my TelnetCommand       $command = do given $negotiation.command {
            when DO   { $option.on-receive-do   }
            when DONT { $option.on-receive-dont }
            when WILL { $option.on-receive-will }
            when WONT { $option.on-receive-wont }
        }

        if defined $command {
            self!send-negotiation($command, $negotiation.option);
            given $negotiation.command {
                when WILL { self!send-subnegotiation: $negotiation.option if $option.them == YES }
                when DO   { self!send-subnegotiation: $negotiation.option if $option.us   == YES }
            }
        }
    })
}

method !parse-subnegotiation(Net::Telnet::Subnegotiation $subnegotiation) {
    $!negotiations-mux.protect({
        if %!pending-subnegotiations ∋ $subnegotiation.option {
            return self.close if %!pending-subnegotiations{$subnegotiation.option}.status ~~ Kept;
            %!pending-subnegotiations{$subnegotiation.option}.keep: $subnegotiation.command;
        }

        given $subnegotiation.option {
            when NAWS {
                $!peer-width  = $subnegotiation.width;
                $!peer-height = $subnegotiation.height;
            }
        }
    })
}

method !parse-text(Str $text) {
    $!text.emit: $text;
}

multi method send(Blob $data --> Promise) { $!socket.write: $data }
multi method send(Str  $data --> Promise) { $!socket.print: $data }

method !send-negotiation(TelnetCommand $command, TelnetOption $option) {
    $!negotiations-mux.protect({
        my Net::Telnet::Negotiation $negotiation .= new: :$command, :$option;
        %!pending-negotiations{$option} .= new;
        say '[SEND] ', $negotiation;
        await self.send: $negotiation.serialize
    })
}

method !send-subnegotiation(TelnetOption $option) {
    $!negotiations-mux.protect({
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
        await self.send: $subnegotiation.serialize
    })
}

method close(--> Bool) {
    $!socket.close
}
