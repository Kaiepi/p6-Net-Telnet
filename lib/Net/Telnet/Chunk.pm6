use v6.c;
use Net::Telnet::Command;
use Net::Telnet::Constants;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation::NAWS;
use Net::Telnet::Subnegotiation::Unsupported;
unit module Net::Telnet::Chunk;

grammar Grammar {
    token TOP { <chunk>+ }

    token chunk {
        || <text>
        || <command>
        || <negotiation>
        || <subnegotiation>
    }

    # TELNET data is ASCII encoded. Extended ASCII is supported, but characters
    # outside the normal ASCII range are sent as XASCII subnegotiations.
    token text { <:ascii>+ }

    token command {
        \x[FF]
        <command=[\x[F1]..\x[F9]]>
    }

    token negotiation {
        \x[FF]
        <command=[\x[FB]..\x[FE]]>
        <option=[\x[00]..\x[FF]]>
    }

    token subnegotiation {
        \x[FF] \x[FA]
        <subnegotiation-data>
        \x[FF] \x[F0]
    }

    token byte {
        | <[\x[00]..\x[FE]]>
        | \x[FF] ** 2
    }

    proto token subnegotiation-data {*}
    token subnegotiation-data:sym(NAWS) {
        <option=.sym>
        <byte> ** 4
    }
    token subnegotiation-data:sym<unsupported> {
        $<option>=[.]
        <byte>+
    }
}

class Actions {
    method TOP($/) { make $<chunk>».ast }

    method chunk($/) {
        given $/ {
            when $<text>           { make $<text>.ast           }
            when $<command>        { make $<command>.ast        }
            when $<negotiation>    { make $<negotiation>.ast    }
            when $<subnegotiation> { make $<subnegotiation>.ast }
        }
    }

    method text($/ --> Str) { make ~$/ }

    method command($/ --> Net::Telnet::Command) {
        make Net::Telnet::Command.new(command => TelnetCommand(~$<command>))
    }

    method negotiation($/ --> Net::Telnet::Negotiation) {
        make Net::Telnet::Negotiation.new(
            command => TelnetCommand(~$<command>),
            option  => TelnetOption(~$<option>)
        )
    }

    method subnegotiation($/ --> Net::Telnet::Subnegotiation) {
        make $<subnegotiation-data>.ast
    }

    method byte($/ --> UInt8) { make $/.ord }

    method subnegotiation-data:sym(NAWS)($/ --> Net::Telnet::Subnegotiation::NAWS) {
        my @bytes  = $<byte>».ast;
        my $width  = @bytes[0] +< 8 +| @bytes[1];
        my $height = @bytes[2] +< 8 +| @bytes[3];
        make Net::Telnet::Subnegotiation::NAWS.new:
            :$width,
            :$height;
    }
    method subnegotiation-data:sym<unsupported>($/ --> Net::Telnet::Subnegotiation::Unsupported) {
        my      $option = TelnetOption(~$<option>);
        my Blob $bytes .= new: $<byte>».ast;
        make Net::Telnet::Subnegotiation::Unsupported.new:
            :$option,
            :$bytes;
    }
}
