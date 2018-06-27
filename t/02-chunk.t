use v6.c;
use Net::Telnet::Chunk;
use Test;

my $actions = Net::Telnet::Chunk::Actions.new;

{
    my $msg = "{IAC}{AYT}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions).made[0];
    cmp-ok $match, '~~', Net::Telnet::Chunk::Command, 'Can match bare commands';
    is $match.command, AYT, 'Can match bare command types';
    is $match.gist, 'IAC AYT', 'Can make commands human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize commands';
    is $match.Str, $msg, 'Can stringify commands';
}

{
    my $msg = "{IAC}{DO}{SGA}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions).made[0];
    cmp-ok $match, '~~', Net::Telnet::Chunk::Negotiation, 'Can match negotiations';
    is $match.command, DO, 'Can match negotiation commands';
    is $match.option, SGA, 'Can match negotiation options';
    is $match.gist, 'IAC DO SGA', 'Can make negotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize negotiations';
    is $match.Str, $msg, 'Can stringify negotiations';
}

{
    my $msg = "{IAC}{SB}{NAWS}\x[00]\x[FF]\x[FF]\x[00]\x[FF]\x[FF]{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$actions).made[0];
    cmp-ok $match, '~~', Net::Telnet::Chunk::Subnegotiation::NAWS, 'Can match subnegotiations';
    is $match.option, NAWS, 'NAWS subnegotiation has correct option';
    is $match.width,  255, 'Can match NAWS subnegotiation width';
    is $match.height, 255, 'Can match NAWS subnegotiation height';
    is $match.gist, 'IAC SB NAWS 255 255 IAC SE', 'Can make NAWS subnegotiations human-readable';
    is $match.serialize.decode('latin1'), $msg, 'Can serialize NAWS subnegotiations';
    is $match.Str, $msg, 'Can stringify NAWS subnegotiations';
}

done-testing;
