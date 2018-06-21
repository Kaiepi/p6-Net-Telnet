use v6.c;
unit class Net::Telnet::Chunk;

enum TelnetCommand is export (
    'SE'   => 0xF0.chr, # Negotiation End
    'NOP'  => 0xF1.chr, # No Operation
    'DM'   => 0xF2.chr, # Data Mark
    'BRK'  => 0xF3.chr, # Break
    'IP'   => 0xF4.chr, # Interrupt Process
    'AO'   => 0xF5.chr, # Abort Output
    'AYT'  => 0xF6.chr, # Are You There?
    'EC'   => 0xF7.chr, # Erase Character
    'EL'   => 0xF8.chr, # Erase Line
    'GA'   => 0xF9.chr, # Go Ahead
    'SB'   => 0xFA.chr, # Negotiation Begin
    'WILL' => 0xFB.chr,
    'WONT' => 0xFC.chr,
    'DO'   => 0xFD.chr,
    'DONT' => 0xFE.chr,
    'IAC'  => 0xFF.chr  # Interpret As Command
);

enum TelnetOption is export (
    'TRANSMIT_BINARY'     => 0x00.chr,
    'ECHO'                => 0x01.chr,
    'RCP'                 => 0x02.chr, # Reconnection
    'SGA'                 => 0x03.chr, # Suppress Go Ahead
    'NAMS'                => 0x04.chr, # Message Size Negotiation
    'STATUS'              => 0x05.chr,
    'TIMING_MARK'         => 0x06.chr,
    'RCTE'                => 0x07.chr, # Remote Controlled Trans and Echo
    'NAOL'                => 0x08.chr, # Output Line Width
    'NAOP'                => 0x09.chr, # Output Line Height
    'NAOCRD'              => 0x0A.chr, # Output Carriage-Return Disposition
    'NAOHTS'              => 0x0B.chr, # Output Horizontal Tab Stops
    'NAOHTD'              => 0x0C.chr, # Output Horizontal Tab Disposition
    'NAOFFD'              => 0x0D.chr, # Output Formfeed Disposition
    'NAOVTS'              => 0x0E.chr, # Output Vertical Stops
    'NAOVTD'              => 0x0F.chr, # Output Vertical Disposition
    'NAOLFD'              => 0x10.chr, # Output Linefeed Disposition
    'XASCII'              => 0x11.chr, # Extended ASCII
    'LOGOUT'              => 0x12.chr,
    'BM'                  => 0x13.chr, # Byte Macro
    'DET'                 => 0x14.chr, # Data Entry Terminal
    'SUPDUP'              => 0x15.chr,
    'SUPDUP_OUTPUT'       => 0x16.chr,
    'SEND_LOCATION'       => 0x17.chr,
    'TERMINAL_TYPE'       => 0x18.chr,
    'END_OF_RECORD'       => 0x19.chr,
    'TUID'                => 0x1A.chr, # TACACS User Identification
    'OUTMRK'              => 0x1B.chr, # Output Marking
    'TTYLOC'              => 0x1C.chr, # Terminal Location Number
    '3270_REGIME'         => 0x1D.chr,
    'X_3_PAD'             => 0x1E.chr,
    'NAWS'                => 0x1F.chr, # Negotiate About Window Size
    'TERMINAL_SPEED'      => 0x20.chr,
    'TOGGLE_FLOW_CONTROL' => 0x21.chr,
    'LINEMODE'            => 0x22.chr,
    'XDISPLOC'            => 0x23.chr, # X Display Location
    'ENVIRON'             => 0x24.chr, # Environment
    'AUTHENTICATION'      => 0x25.chr,
    'ENCRYPT'             => 0x26.chr,
    'NEW_ENVIRON'         => 0x27.chr,
    'TN3270E'             => 0x28.chr,
    'XAUTH'               => 0x29.chr,
    'CHARSET'             => 0x2A.chr,
    'RSP'                 => 0x2B.chr, # Remote Serial Port
    'COM_PORT_OPTION'     => 0x2C.chr,
    'SLE'                 => 0x2D.chr, # Suppress Local Echo
    'START_TLS'           => 0x2E.chr,
    'KERMIT'              => 0x2F.chr,
    'SEND_URL'            => 0x30.chr,
    'FORWARD_X'           => 0x31.chr,
    'PRAGMA_LOGON'        => 0x8A.chr,
    'SSPI_LOGON'          => 0x8B.chr,
    'PRAGMA_HEARTBEAT'    => 0x8C.chr,
    'EXOPL'               => 0xFF.chr
);

class Command {
    has TelnetCommand $.command;

    method name  { $!command.key   }
    method value { $!command.value }

    method gist(--> Str) { "{IAC.key} $!command.key" }

    method Str(--> Str) { self.gist }
}

class Negotiation {
    has TelnetCommand $.command;
    has TelnetOption  $.option;

    method gist(--> Str) { "$!command {$!option.key}" }

    method Str(--> Str) { self.gist }
}

role Subnegotiation {
    has TelnetCommand $.begin;
    has TelnetOption  $.option;
    has TelnetCommand $.end;

    proto method gist(--> Str) { "$!begin {$!option.key} {{*}} $!end" }
    multi method gist(--> Str) { '' } # Overridden by classes implementing this.

    method Str(--> Str) { self.gist }
}

class Subnegotiation::NAWS does Subnegotiation {
    has Int $.width;
    has Int $.height;

    method new(:$option, :$begin, :$end, :@bytes) {
        my Int ($width-upper, $width-lower, $height-upper, $height-lower) = @bytes;
        my $width  = $width-upper  +< 8 +| $width-lower;
        my $height = $height-upper +< 8 +| $height-lower;
        self.bless: :$option, :$begin, :$end, :$width, :$height;
    }

    multi method gist(--> Str) { "$!width $!height" }
}

grammar Grammar {
    token TOP { <chunk>+ }

    token chunk {
        || <data>
        || <subnegotiation>
        || <negotiation>
        || <command>
    }

    # All bytes passed are encoded as latin1.
    token byte { . }
    # TELNET data is ASCII encoded. xtended ASCII is supported, but characters
    # outside the normal ASCII range are sent as XASCII subnegotiations.
    token data { <:ascii>+ }

    proto token command {*}
    token command:sym(SE)   { <{IAC}> <( <sym> )> }
    token command:sym(NOP)  { <{IAC}> <( <sym> )> }
    token command:sym(DM)   { <{IAC}> <( <sym> )> }
    token command:sym(BRK)  { <{IAC}> <( <sym> )> }
    token command:sym(IP)   { <{IAC}> <( <sym> )> }
    token command:sym(AO)   { <{IAC}> <( <sym> )> }
    token command:sym(AYT)  { <{IAC}> <( <sym> )> }
    token command:sym(EC)   { <{IAC}> <( <sym> )> }
    token command:sym(EL)   { <{IAC}> <( <sym> )> }
    token command:sym(GA)   { <{IAC}> <( <sym> )> }
    token command:sym(SB)   { <{IAC}> <( <sym> )> }
    token command:sym(WILL) { <{IAC}> <( <sym> )> }
    token command:sym(WONT) { <{IAC}> <( <sym> )> }
    token command:sym(DO)   { <{IAC}> <( <sym> )> }
    token command:sym(DONT) { <{IAC}> <( <sym> )> }

    token negotiation {
        [
        | <command:sym(WILL)>
        | <command:sym(WONT)>
        | <command:sym(DO)>
        | <command:sym(DONT)>
        ]
        <option=byte>
    }

    proto token subnegotiation {*}
    token subnegotiation:sym(NAWS) {
        <begin=command:sym(SB)>
        <option=sym>
        <byte> ** 4
        <end=command:sym(SE)>
    }
}

class Actions {
    method TOP($/) { make $<chunk>».ast }

    method chunk($/) { make $<data>.ast // $<subnegotiation>.ast // $<negotiation>.ast // $<command>.ast }

    method data($/ --> Str) { make ~$/ }

    method byte($/ --> Int) { make $/.ord }

    method !make-command($/ --> Command) {
        make Command.new(command => TelnetCommand(~$<sym>))
    }
    method command:sym(SE)($/ --> Command)  { self!make-command($/) }
    method command:sym(NOP)($/ --> Command) { self!make-command($/) }
    method command:sym(DM)($/ --> Command)  { self!make-command($/) }
    method command:sym(BRK)($/ --> Command) { self!make-command($/) }
    method command:sym(IP)($/ --> Command)  { self!make-command($/) }
    method command:sym(AO)($/ --> Command)  { self!make-command($/) }
    method command:sym(AYT)($/ --> Command) { self!make-command($/) }
    method command:sym(EC)($/ --> Command)  { self!make-command($/) }
    method command:sym(EL)($/ --> Command)  { self!make-command($/) }
    method command:sym(GA)($/ --> Command)  { self!make-command($/) }
    method command:sym(SB)($/ --> Command)  { self!make-command($/) }

    method negotiation($/ --> Negotiation) {
        make Negotiation.new(
            command => TelnetCommand(~$<command>),
            option => TelnetOption(~$<option>)
        );
    }

    method subnegotiation:sym(NAWS)($/ --> Subnegotiation::NAWS) {
        make Subnegotiation::NAWS.new(
            option => TelnetOption(~$<option>),
            begin => TelnetCommand(~$<begin>),
            end => TelnetCommand(~$<end>),
            bytes => make $<byte>».ast
        )
    }
}
