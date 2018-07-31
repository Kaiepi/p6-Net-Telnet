use v6.c;
use Net::Telnet::Chunk;
use Net::Telnet::Option;
unit role Net::Telnet::Connection;

has Str      $.host;
has Int      $.port;
has Supplier $.text .= new;

has Map $.options;
has Str @.preferred;
has Str @.supported;

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

# Overridden by implementations.
method !parse-subnegotiation(Net::Telnet::Chunk::Subnegotiation $subnegotiation) { }

# Overridden by implementations.
multi method send(Blob $data --> Promise) { }
multi method send(Str $data --> Promise)  { }

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Chunk::Negotiation $negotiation .= new: :$command, :$option;
    say '[SEND] ', $negotiation;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    my Net::Telnet::Chunk::Subnegotiation $subnegotiation = self!try-send-subnegotiation($option);
    return Promise.start({ 0 }) unless defined $subnegotiation;

    say '[SEND] ', $subnegotiation;
    self.send: $subnegotiation.serialize
}

# Overridden by implementations.
method !try-send-subnegotiation(--> Net::Telnet::Chunk::Subnegotiation) { }
