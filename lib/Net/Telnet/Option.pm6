use v6.c;
use Net::Telnet::Chunk;
unit class Net::Telnet::Option;

# See RFC 1143
enum OptionState is export <NO YES WANTNO WANTYES>;
enum OptionQueue is export <EMPTY OPPOSITE>;

has TelnetOption $.option is required; # The TELNET option this object keeps track of state for.
has Bool         $.supported = False;  # Whether the option can be enabled for the opposite end of the connection.
has Bool         $.preferred = False;  # Whether the option can be enabled by this end of the connection.
has OptionState  $.us        = NO;     # The state of the option for this end of the connection.
has OptionQueue  $.usq       = EMPTY;  # The queue bit of the option for this end of the connection.
has OptionState  $.them      = NO;     # The state of the option for the opposite end of the connection.
has OptionQueue  $.themq     = EMPTY;  # The queue bit of the option for the opposite end of the connection.

method on-receive-will(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!them {
        when NO {
            if $!supported {
                $!them   = YES;
                $to-send = DO;
            } else {
                $to-send = DONT;
            }
        }
        when YES {
            # Already enabled.
        }
        when WANTNO {
            given $!themq {
                when EMPTY {
                    $!them = NO;
                }
                when OPPOSITE {
                    $!them  = YES;
                    $!themq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $!themq {
                when EMPTY {
                    $!them = YES;
                }
                when OPPOSITE {
                    $!them  = WANTNO;
                    $!themq = EMPTY;
                }
            }
        }
    }

    $to-send
}

method on-receive-wont(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!them {
        when NO {
            # Already disabled.
        }
        when YES {
            $!them   = NO;
            $to-send = DONT;
        }
        when WANTNO {
            given $!themq {
                when EMPTY {
                    $!them = NO;
                }
                when OPPOSITE {
                    $!them   = WANTYES;
                    $!themq  = EMPTY;
                    $to-send = DO;
                }
            }
        }
        when WANTYES {
            given $!themq {
                when EMPTY {
                    $!them = NO;
                }
                when OPPOSITE {
                    $!them  = NO;
                    $!themq = EMPTY;
                }
            }
        }
    }

    $to-send
}

method on-receive-do(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!us {
        when NO {
            $!us     = YES;
            $to-send = $!supported ?? WILL !! WONT;
        }
        when YES {
            # Already enabled.
        }
        when WANTNO {
            given $!usq {
                when EMPTY {
                    $!us = NO;
                }
                when OPPOSITE {
                    $!us  = YES;
                    $!usq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $!usq {
                when EMPTY {
                    $!us     = YES;
                    $to-send = WILL if $!supported;
                }
                when OPPOSITE {
                    $!us     = WANTNO;
                    $!usq    = EMPTY;
                    $to-send = WONT;
                }
            }
        }
    }

    $to-send
}

method on-receive-dont(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!us {
        when NO {
            # Already disabled.
        }
        when YES {
            $!us     = NO;
            $to-send = WONT;
        }
        when WANTNO {
            given $!usq {
                when EMPTY {
                    $!us = NO;
                }
                when OPPOSITE {
                    $!us     = WANTYES;
                    $!usq    = EMPTY;
                    $to-send = WILL;
                }
            }
        }
        when WANTYES {
            given $!usq {
                when EMPTY {
                    $!us = NO;
                }
                when OPPOSITE {
                    $!us  = NO;
                    $!usq = EMPTY;
                }
            }
        }
    }

    $to-send
}
