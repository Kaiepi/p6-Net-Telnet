use v6.d;
use Net::Telnet::Command;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation;
unit module Net::Telnet::Chunk;

# Whether or not the data the peer's sending should be parsed as binary data or
# as text. IAC DO TRANSMIT_BINARY enables this, while any other command
# combined with TRANSMIT_BINARY disables it.
my Bool $GLOBAL-BINARY = False;

grammar Grammar {
    token TOP { <chunk>+ }

    token chunk {
        :my Bool $*BINARY = $GLOBAL-BINARY;
        [
        || <command>
        || <negotiation>
        || <subnegotiation>
        || <blob>
        || <text>
        || <!>
        ]
        { $GLOBAL-BINARY = $*BINARY }
    }

    token byte {
        [
        | <[\x[00]..\x[FE]]>
        | \x[FF] ** 2
        ]
    }

    token blob {
        <?{ $*BINARY }> <byte>+
    }

    # TELNET data is ASCII encoded. Extended ASCII is supported, but characters
    # outside the normal ASCII range are sent as XASCII subnegotiations.
    token text {
        <!{ $*BINARY }> <:ascii>+
    }

    token command {
        \x[FF]
        <command=[\x[F1]..\x[F9]]>
    }

    token negotiation {
        \x[FF]
        <command=[\x[FB]..\x[FE]]>
        <option=[\x[00]..\x[FF]]>
        { $*BINARY = ~$<command> eq DO if ~$<option> eq TRANSMIT_BINARY }
    }

    token subnegotiation {
        \x[FF] \x[FA]
        <subnegotiation-data>
        \x[FF] \x[F0]
    }

    proto token subnegotiation-data {*}
    token subnegotiation-data:sym(NAWS) {
        <option=.sym>
        <byte> ** 4
    }
    token subnegotiation-data:sym(TERMINAL_TYPE) {
        <option=.sym>
        [
        | <command=[\x[00]]> <byte>+
        | <command=[\x[01]]>
        ]
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
            when $<blob>           { make $<blob>.ast           }
            when $<text>           { make $<text>.ast           }
            when $<command>        { make $<command>.ast        }
            when $<negotiation>    { make $<negotiation>.ast    }
            when $<subnegotiation> { make $<subnegotiation>.ast }
        }
    }

    method byte($/ --> UInt8) {
        make $/.ord
    }

    method blob($/ --> Blob) {
        make Blob.new: $<byte>».ast
    }

    method text($/ --> Str) {
        make ~$/
    }

    method command($/ --> Net::Telnet::Command) {
        my TelnetCommand $command = TelnetCommand(~$<command>);
        make Net::Telnet::Command.new: :$command
    }

    method negotiation($/ --> Net::Telnet::Negotiation) {
        my TelnetCommand $command = TelnetCommand(~$<command>);
        my TelnetOption  $option = TelnetOption(~$<option>);
        make Net::Telnet::Negotiation.new: :$command, :$option
    }

    method subnegotiation($/ --> Net::Telnet::Subnegotiation) {
        make $<subnegotiation-data>.ast
    }

    method subnegotiation-data:sym(NAWS)($/ --> Net::Telnet::Subnegotiation::NAWS) {
        my @bytes  = $<byte>».ast;
        my $width  = @bytes[0] +< 8 +| @bytes[1];
        my $height = @bytes[2] +< 8 +| @bytes[3];
        make Net::Telnet::Subnegotiation::NAWS.new: :$width, :$height
    }
    method subnegotiation-data:sym(TERMINAL_TYPE)($/ --> Net::Telnet::Subnegotiation::TerminalType) {
        my TerminalTypeCommand $command = TerminalTypeCommand(~$<command>.ord);
        my Str                 $type    = $<byte>».ast ?? Blob.new($<byte>».ast).decode('latin1') !! Nil;
        make Net::Telnet::Subnegotiation::TerminalType.new: :$command, :$type
    }
    method subnegotiation-data:sym<unsupported>($/ --> Net::Telnet::Subnegotiation::Unsupported) {
        my      $option = TelnetOption(~$<option>);
        my Blob $bytes .= new: $<byte>».ast;
        make Net::Telnet::Subnegotiation::Unsupported.new: :$option, :$bytes
    }
}
