use v6.c;
use Net::Telnet::Chunk;
use Net::Telnet::Command;
use Net::Telnet::Constants;
use Net::Telnet::Negotiation;
use Net::Telnet::Option;
use Net::Telnet::Subnegotiation;
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

# TODO: when options support becomes thread-safe, map over options with .hyper.
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
}

method parse(Blob $data) {
    my Blob                        $buf    = $!parser-buf.elems ?? $!parser-buf.splice.append($data) !! $data;
    my Str                         $msg    = $buf.decode('latin1');
    my Net::Telnet::Chunk::Grammar $match .= subparse($msg, :$!actions);

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
                $!text.emit($chunk);
            }
        }
    }

    $!parser-buf = $match.postmatch.encode('latin1') if $match.postmatch;
}

method !parse-command(Net::Telnet::Command $command) {
    # ...
}

method !parse-negotiation(Net::Telnet::Negotiation $negotiation --> Promise) {
    my Net::Telnet::Option $option = $!options{$negotiation.option};
    my TelnetCommand       $command;

    given $negotiation.command {
        when DO   { $command = $option.on-receive-do   }
        when DONT { $command = $option.on-receive-dont }
        when WILL { $command = $option.on-receive-will }
        when WONT { $command = $option.on-receive-wont }
    }

    if defined $command {
        self!send-negotiation($command, $negotiation.option).then({
            given $negotiation.command {
                when WILL { await self!send-subnegotiation: $negotiation.option if $option.them == YES }
                when DO   { await self!send-subnegotiation: $negotiation.option if $option.us   == YES }
                default   { 0 }
            }
        });
    } else {
        Promise.start({ 0 })
    }
}

# Overridden by implementations.
method !parse-subnegotiation(Net::Telnet::Subnegotiation $subnegotiation) { }

# Overridden by implementations.
multi method send(Blob $data --> Promise) { }
multi method send(Str $data --> Promise)  { }

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Negotiation $negotiation .= new: :$command, :$option;
    say '[SEND] ', $negotiation;
    self.send: $negotiation.serialize
}

method !send-subnegotiation(TelnetOption $option --> Promise) {
    my Net::Telnet::Subnegotiation $subnegotiation = self!try-send-subnegotiation($option);
    return Promise.start({ 0 }) unless defined $subnegotiation;

    say '[SEND] ', $subnegotiation;
    self.send: $subnegotiation.serialize
}

# Overridden by implementations.
method !try-send-subnegotiation(--> Net::Telnet::Subnegotiation) { }
