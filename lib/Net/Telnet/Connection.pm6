use v6.c;
use Net::Telnet::Chunk;
use Net::Telnet::Option;
unit role Net::Telnet::Connection;

has          $.socket;
has Str      $.host;
has Int      $.port;
has Supplier $.text .= new;

has Map $.options;
has Str @.preferred;
has Str @.supported;

has Int $.client-width  = 0;
has Int $.client-height = 0;
has Int $.server-width  = 0;
has Int $.server-height = 0;

has Net::Telnet::Chunk::Actions $!actions    .= new;
has Blob                        $!parser-buf .= new;

method text(--> Supply) { $!text.Supply }

method supported(Str $option --> Bool) {
    defined @!supported.first: * eq $option
}

method preferred(Str $option --> Bool) {
    defined @!preferred.first: * eq $option
}

method new(
    Str :$host,
    Int :$port = 23,
    :@preferred = [],
    :@supported = []
) {
    my Map $options .= new: TelnetOption.enums.kv.map: -> $k, $v {
        my $option    = TelnetOption($v);
        my $supported = defined @supported.index($k);
        my $preferred = defined @preferred.index($k);
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred;
    };

    self.bless: :$host, :$port, :$options, :@supported, :@preferred;
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
