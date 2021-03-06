use v6.d;
use Net::Telnet::Chunk;
use Net::Telnet::Command;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation;
use Test;

plan 39;

my Net::Telnet::Chunk::Actions $actions .= new;

{
    my $msg = "{IAC}{AYT}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Command, 'Can match bare commands';
    is $match.command, AYT, 'Can match bare command types';
    is $match.gist, 'IAC AYT', 'Can make commands human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize commands';
    is $match.Str, $msg, 'Can stringify commands';
}

{
    my $msg = "{IAC}{DO}{SGA}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Negotiation, 'Can match negotiations';
    is $match.command, DO, 'Can match negotiation commands';
    is $match.option, SGA, 'Can match negotiation options';
    is $match.gist, 'IAC DO SGA', 'Can make negotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize negotiations';
    is $match.Str, $msg, 'Can stringify negotiations';
}

{
    my $msg = "{IAC}{DO}{TRANSMIT_BINARY}\x[01]\x[02]\x[03]{IAC}{DONT}{TRANSMIT_BINARY}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions).ast;
    cmp-ok $match, '!~~', Nil, 'Can handle binary transmissions';
    cmp-ok $match[1], 'eqv', Blob.new(1, 2, 3), 'Can match binary data';
}

{
    my $msg = "{IAC}{SB}{NAWS}\x[00]\x[FF]\x[FF]\x[00]\x[FF]\x[FF]{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Subnegotiation::NAWS, 'Can match NAWS subnegotiations';
    is $match.option, NAWS, 'NAWS subnegotiation has correct option';
    is $match.width,  255, 'Can match NAWS subnegotiation width';
    is $match.height, 255, 'Can match NAWS subnegotiation height';
    is $match.gist, 'IAC SB NAWS 255 255 IAC SE', 'Can make NAWS subnegotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize NAWS subnegotiations';
    is $match.Str, $msg, 'Can stringify NAWS subnegotiations';
}

{
    my $msg = "{IAC}{SB}{TERMINAL_TYPE}\x[00]{'xterm'}{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Subnegotiation::TerminalType, 'Can match TERMINAL_TYPE IS subnegotiations';
    is $match.option, TERMINAL_TYPE, 'TERMINAL_TYPE IS subnegotiation has correct option';
    is $match.command, TerminalTypeCommand::IS, 'TERMINAL_TYPE IS subnegotiation has correct command';
    is $match.type, 'xterm', 'TERMINAL_TYPE IS subnegotiation has correct type';
    is $match.gist, 'IAC SB TERMINAL_TYPE IS xterm IAC SE', 'Can make TERMINAL_TYPE IS subnegotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize TERMINAL_TYPE IS subnegotiations';
    is $match.Str, $msg, 'Can stringify TERMINAL_TYPE IS subnegotiations';
}

{
    my $msg = "{IAC}{SB}{TERMINAL_TYPE}\x[01]{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Subnegotiation::TerminalType, 'Can match TERMINAL_TYPE SEND subnegotiations';
    is $match.option, TERMINAL_TYPE, 'TERMINAL_TYPE SEND subnegotiation has correct option';
    is $match.command, TerminalTypeCommand::SEND, 'TERMINAL_TYPE SEND subnegotiation has correct option';
    is $match.type, Str, 'TERMINAL_TYPE SEND subnegotiation has correct type';
    is $match.gist, 'IAC SB TERMINAL_TYPE SEND IAC SE', 'Can make TERMINAL_TYPE SEND subnegotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize TERMINAL_TYPE SEND subnegotiations';
    is $match.Str, $msg, 'Can stringify TERMINAL_TYPE SEND subnegotiations';
}

{
    my $msg = "{IAC}{SB}{EXOPL}\x[FF]\x[FF]{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions, :rule<chunk>).ast;
    cmp-ok $match, '~~', Net::Telnet::Subnegotiation::Unsupported, 'Can match unsupported subnegotiations';
    is $match.option, EXOPL, 'Unsupported subnegotiation has correct option';
    is $match.gist, 'IAC SB EXOPL FF IAC SE', 'Can make unsupported subnegotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize unsupported subnegotiations';
    is $match.Str, $msg, 'Can stringify unsupported subnegotiations';
}

# vim: ft=perl6 sw=4 ts=4 sts=4 expandtab
