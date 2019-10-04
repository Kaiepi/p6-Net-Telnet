use v6.d;
use Net::Telnet::Constants :ALL;

module Net::Telnet {
    role Subnegotiation {
        has TelnetOption $.option;

        # Overridden by implementations.
        proto method gist(--> Str) {
            "{IAC.key} {SB.key} {$!option.key} {{*}} {IAC.key} {SE.key}"
        }

        # Overridden by implementations.
        proto method serialize(--> Blob) {
            Blob.new(
                IAC.ord,
                SB.ord,
                $!option.ord,
                |[(), |{*}].reduce({ ($^b == 0xFF) ?? (|$^a, $^b, $^b) !! (|$^a, $^b) }),
                IAC.ord,
                SE.ord
            )
        }

        method Str(--> Str) {
            self.serialize.decode: 'latin1'
        }
    }

    class Subnegotiation::NAWS does Subnegotiation {
        has UInt16 $.width  is required;
        has UInt16 $.height is required;

        method new(UInt16 :$width, UInt16 :$height) {
            my TelnetOption $option = NAWS;
            self.bless: :$option, :$width, :$height;
        }

        multi method gist(--> Str) {
            "$!width $!height"
        }

        multi method serialize(--> Blob) {
            Blob.new(
                $!width  +> 8,
                $!width  +& 0xFF,
                $!height +> 8,
                $!height +& 0xFF
            )
        }
    }

    class Subnegotiation::TerminalType does Subnegotiation {
        has TerminalTypeCommand $.command;
        has Str                 $.type;

        method new(TerminalTypeCommand :$command, Str :$type) {
            my TelnetOption $option = TERMINAL_TYPE;
            self.bless: :$option, :$command, :$type;
        }

        multi method gist(--> Str) {
            given $!command {
                when TerminalTypeCommand::IS {
                    "{$!command.key} $!type"
                }
                when TerminalTypeCommand::SEND {
                    $!command.key
                }
            }
        }

        multi method serialize(--> Blob) {
            given $!command {
                when TerminalTypeCommand::IS {
                    Blob.new: $!command.value, |$!type.encode: 'latin1'
                }
                when TerminalTypeCommand::SEND {
                    Blob.new: $!command.value
                }
            }
        }
    }

    class Subnegotiation::XDispLoc does Subnegotiation {
        has XDispLocCommand $.command;
        has Str                 $.type;

        method new(TerminalTypeCommand :$command, Str :$type) {
            my TelnetOption $option = XDISPLOC;
            self.bless: :$option, :$command, :$type;
        }

        multi method gist(--> Str) {
            given $!command {
                when XDispLocCommand::IS {
                    "{$!command.key} $!type"
                }
                when XDispLocCommand::SEND {
                    $!command.key
                }
            }
        }

        multi method serialize(--> Blob) {
            given $!command {
                when XDispLocCommand::IS {
                    Blob.new: $!command.value, |$!type.encode: 'latin1'
                }
                when XDispLocCommand::SEND {
                    Blob.new: $!command.value
                }
            }
        }
    }

    class Subnegotiation::Unsupported does Subnegotiation {
        has Blob $.bytes;

        multi method gist(--> Str) {
            $!bytes.map({ sprintf '%02x', $_ }).join(' ').uc
        }

        multi method serialize(--> Blob) {
            $!bytes
        }
    }
}
