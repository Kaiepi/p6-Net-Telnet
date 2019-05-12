use v6.d;
use Net::Telnet::Constants;

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
            self.bless: :option(NAWS), :$width, :$height;
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

    class Subnegotiation::Unsupported does Subnegotiation {
        has Blob $.bytes;

        method new(TelnetOption :$option, Blob :$bytes) {
            self.bless: :$option, :$bytes;
        }

        multi method gist(--> Str) {
            $!bytes.map({ sprintf '%02x', $_ }).join(' ').uc
        }

        multi method serialize(--> Blob) {
            $!bytes
        }
    }
}
