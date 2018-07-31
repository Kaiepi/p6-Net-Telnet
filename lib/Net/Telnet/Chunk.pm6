use v6.c;
use Net::Telnet::Command;
use Net::Telnet::Constants;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation::NAWS;
unit module Net::Telnet::Chunk;

grammar Grammar {
    token TOP { <chunk>+ }

    token chunk {
        || <data>
        || <command>
        || <negotiation>
        || <subnegotiation>
    }

    # TELNET data is ASCII encoded. Extended ASCII is supported, but characters
    # outside the normal ASCII range are sent as XASCII subnegotiations.
    token data { <:ascii>+ }

    token command {
        \x[FF]
        <command=[\x[F1]..\x[F9]]>
    }

    token negotiation {
        \x[FF]
        <command=[\x[FB]..\x[FE]]>
        <option=[\x[00]..\x[FF]]>
    }

    token byte {
        | <[\x[00]..\x[FE]]>
        | \x[FF] <(\x[FF])>
    }

    proto token subnegotiation {*}
    token subnegotiation:sym(NAWS) {
        \x[FF] \x[FA]
        <.sym>
        <byte> ** 4
        \x[FF] \x[F0]
    }
}

class Actions {
    method TOP($/) { make $<chunk>».ast }

    method chunk($/) {
        given $/ {
            when $<data>           { make $<data>.ast           }
            when $<command>        { make $<command>.ast        }
            when $<negotiation>    { make $<negotiation>.ast    }
            when $<subnegotiation> { make $<subnegotiation>.ast }
        }
    }

    method data($/ --> Str) { make ~$/ }

    method command($/ --> Net::Telnet::Command) {
        make Net::Telnet::Command.new(command => TelnetCommand(~$<command>))
    }

    method negotiation($/ --> Net::Telnet::Negotiation) {
        make Net::Telnet::Negotiation.new(
            command => TelnetCommand(~$<command>),
            option  => TelnetOption(~$<option>)
        )
    }

    method byte($/ --> UInt8) { make $/.ord }

    method subnegotiation:sym(NAWS)($/ --> Net::Telnet::Subnegotiation::NAWS) {
        my @bytes  = $<byte>».ast;
        my $width  = @bytes[0] +< 8 +| @bytes[1];
        my $height = @bytes[2] +< 8 +| @bytes[3];
        make Net::Telnet::Subnegotiation::NAWS.new:
            width  => $width,
            height => $height;
    }
}
