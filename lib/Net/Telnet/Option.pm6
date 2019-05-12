use v6.d;
use Net::Telnet::Constants;
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

proto method enabled(Bool :$local?, Bool :$remote? --> Bool) {*}
multi method enabled(Bool :$local! --> Bool)   { $!us   == YES }
multi method enabled(Bool :$remote! --> Bool)  { $!them == YES }

proto method disabled(Bool :$local?, Bool :$remote? --> Bool) {*}
multi method disabled(Bool :$local! --> Bool)  { $!us   != YES }
multi method disabled(Bool :$remote! --> Bool) { $!them != YES }

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
                    $!them   = WANTNO;
                    $!themq  = EMPTY;
                    $to-send = DONT;
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
            if $!preferred {
                $!us     = YES;
                $to-send = WILL;
            } else {
                $to-send = WONT;
            }
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
                    $!us = YES;
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

method on-send-will(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!us {
        when NO {
            if $!preferred {
                $!us     = WANTYES;
                $to-send = WILL;
            } else {
                $to-send = WONT;
            }
        }
        when YES {
            # Already enabled.
        }
        when WANTNO {
            given $!usq {
                when EMPTY {
                    $!usq = OPPOSITE;
                }
                when OPPOSITE {
                    # Already queued an enable request.
                }
            }
        }
        when WANTYES {
            given $!usq {
                when EMPTY {
                    # Already negotiating for enable.
                }
                when OPPOSITE {
                    $!usq = EMPTY;
                }
            }
        }
    }

    $to-send
}

method on-send-wont(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!us {
        when NO {
            # Already disabled.
        }
        when YES {
            $!us     = WANTNO;
            $to-send = WONT;
        }
        when WANTNO {
            given $!usq {
                when EMPTY {
                    # Already negotiating for disable.
                }
                when OPPOSITE {
                    $!usq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $!usq {
                when EMPTY {
                    $!usq = OPPOSITE;
                }
                when OPPOSITE {
                    # Already queued a disable request.
                }
            }
        }
    }

    $to-send
}

method on-send-do(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!them {
        when NO {
            if $!supported {
                $!them   = WANTYES;
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
                    $!themq = OPPOSITE;
                }
                when OPPOSITE {
                    # Already queued an enable request.
                }
            }
        }
        when WANTYES {
            given $!themq {
                when EMPTY {
                    # Already negotiating for enable.
                }
                when OPPOSITE {
                    $!themq = EMPTY;
                }
            }
        }
    }

    $to-send
}

method on-send-dont(--> TelnetCommand) {
    my TelnetCommand $to-send;

    given $!them {
        when NO {
            # Already disabled.
        }
        when YES {
            $!them   = WANTNO;
            $to-send = DONT;
        }
        when WANTNO {
            given $!themq {
                when EMPTY {
                    # Already negotiating for disable.
                }
                when OPPOSITE {
                    $!themq = EMPTY;
                }
            }
        }
        when WANTYES {
            given $!themq {
                when EMPTY {
                    $!themq = OPPOSITE;
                }
                when OPPOSITE {
                    # Already queued on disable request.
                }
            }
        }
    }

    $to-send
}
