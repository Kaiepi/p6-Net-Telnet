use v6.c;
use Net::Telnet::Chunk;
use Net::Telnet::Option;
unit class Net::Telnet::Client;

constant SUPPORTED = <ECHO SGA>;

has Str               $.host;
has Int               $.port;
has IO::Socket::Async $.socket;
has Bool              $.closed   = True;
has Supplier          $.text    .= new;
has Map               $.options;

has Net::Telnet::Chunk::Actions $!actions    .= new;
has Blob                        $!parser-buf .= new;

method text(--> Supply) { $!text.Supply }

method new(Str :$host, Int :$port = 23, :@options? --> ::?CLASS:D) {
    my Map $options .= new: TelnetOption.enums.kv.map: -> $k, $v {
        my $option    = TelnetOption($v);
        my $supported = defined SUPPORTED.index($k);
        my $preferred = defined @options.index($k);
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

        self;
    });
}

method parse(Blob $data) {
    my $buf = $!parser-buf.elems ?? $!parser-buf.splice.append($data) !! $data;
    my $msg = $buf.decode('latin1');
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$!actions);

    for $match.ast -> $chunk {
        given $chunk {
            when Net::Telnet::Chunk::Command {
                say '[RECV] ', $chunk;
            }
            when (Net::Telnet::Chunk::Negotiation) {
                say '[RECV] ', $chunk;
                given $chunk.command {
                    when DO   { self!receive-do: $chunk.option   }
                    when DONT { self!receive-dont: $chunk.option }
                    when WILL { self!receive-will: $chunk.option }
                    when WONT { self!receive-wont: $chunk.option }
                }
            }
            when (Net::Telnet::Chunk::Subnegotiation) {
                say '[RECV] ', $chunk;
            }
            when Str {
                $!text.emit($chunk);
            }
        }
    }

    $!parser-buf = $match.postmatch.encode('latin1') if $match.postmatch;
}

multi method send(Blob $data --> Promise) { $!socket.write($data) }
multi method send(Str $data --> Promise)  { $!socket.print($data) }

method !send-negotiation(TelnetCommand $command, TelnetOption $option --> Promise) {
    my Net::Telnet::Chunk::Negotiation $negotiation .= new: :$command, :$option;
    say '[SEND] ', $negotiation;
    self.send($negotiation.serialize);;
}

method !send-subnegotiation(TelnetOption $option) {
    # ...
}

method !receive-will(TelnetOption $option) {
    my Net::Telnet::Option $opt = $!options{$option};
    given $opt.them {
        when NO {
            if $opt.supported && $opt.preferred {
                $opt.them = YES;
                self!send-negotiation(DO, $option);
            } else {
                self!send-negotiation(DONT, $option);
            }
        }
        when YES {
            # Already enabled.
        }
        when WANTNO {
            given $opt.themq {
                when EMPTY {
                    $opt.them = NO;
                }
                when OPPOSITE {
                    $opt.them  = YES;
                    $opt.themq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $opt.themq {
                when EMPTY {
                    $opt.them = YES;
                }
                when OPPOSITE {
                    $opt.them  = WANTNO;
                    $opt.themq = EMPTY;
                    self!send-negotiation(DONT, $option);
                }
            }
        }
    }
}

method !receive-wont(TelnetOption $option) {
    my Net::Telnet::Option $opt = $!options{$option};
    given $opt.them {
        when NO {
            # Already disabled.
        }
        when YES {
            $opt.them = NO;
            self!send-negotiation(DONT, $option);
        }
        when WANTNO {
            given $opt.themq {
                when EMPTY {
                    $opt.them = NO;
                }
                when OPPOSITE {
                    $opt.them = WANTYES;
                    $opt.themq = EMPTY;
                    self!send-negotiation(DO, $option);
                }
            }
        }
        when WANTYES {
            given $opt.themq {
                when EMPTY {
                    $opt.them = NO;
                }
                when (OPPOSITE) {
                    $opt.them = NO;
                    $opt.themq = EMPTY;
                }
            }
        }
    }
}

method !receive-do(TelnetOption $option) {
    my Net::Telnet::Option $opt = $!options{$option};
    given $opt.us {
        when NO {
            $opt.us = YES;
            if $opt.supported && $opt.preferred {
                self!send-negotiation(WILL, $option);
                self!send-subnegotiation($option);
            } else {
                self!send-negotiation(WONT, $option);
            }
        }
        when YES {
            # Already enabled.
        }
        when WANTNO {
            given $opt.usq {
                when EMPTY {
                    $opt.us = NO;
                }
                when (OPPOSITE) {
                    $opt.us  = YES;
                    $opt.usq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $opt.usq {
                when EMPTY {
                    $opt.us = YES;
                    self!send-subnegotiation($option) if $opt.supported && $opt.preferred;
                }
                when OPPOSITE {
                    $opt.us = WANTNO;
                    $opt.usq = EMPTY;
                    self!send-negotiation(WONT, $option);
                }
            }
        }
    }
}

method !receive-dont(TelnetOption $option) {
    my Net::Telnet::Option $opt = $!options{$option};
    given $opt.us {
        when NO {
            # Already disabled.
        }
        when YES {
            $opt.us = NO;
            self!send-negotiation(WONT, $option);
        }
        when WANTNO {
            given $opt.usq {
                when EMPTY {
                    $opt.us = NO;
                }
                when OPPOSITE {
                    $opt.us = WANTYES;
                    $opt.usq = EMPTY;
                    self!send-negotiation(WILL, $option);
                }
            }
        }
        when WANTYES {
            given $opt.usq {
                when EMPTY {
                    $opt.us = NO;
                }
                when (OPPOSITE) {
                    $opt.us = NO;
                    $opt.usq = EMPTY;
                }
            }
        }
    }
}

method close(--> Bool) {
    return False if $!closed;

    $!socket.close;
    $!closed      = True;
    $!parser-buf .= new;
    True
}
