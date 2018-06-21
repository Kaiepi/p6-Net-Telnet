use v6.c;
use Net::Telnet::Chunk;
use Test;

my $actions = Net::Telnet::Chunk::Actions.new;

{
    my $cmd = "{IAC}{AYT}";
    my $match = Net::Telnet::Chunk::Grammar.parse($cmd, :$actions).made[0];
    ok $match ~~ Net::Telnet::Chunk::Command, 'Can match bare commands';
    is $match.command, AYT, 'Can match bare command types';
}

{
    my $cmd = "{IAC}{DO}{SGA}";
    my $match = Net::Telnet::Chunk::Grammar.parse($cmd, :$actions).made[0];
    ok $match ~~ Net::Telnet::Chunk::Negotiation, 'Can match negotiations';
    is $match.command, DO, 'Can match negotiation commands';
    is $match.option, SGA, 'Can match negotiation options';
}

{
    my $cmd = "{IAC}{SB}{NAWS}\c[00]\c[80]\c[00]\c[60]{IAC}{SE}";
    my $match = Net::Telnet::Chunk::Grammar.parse($cmd, :$actions).made[0];
    ok $match ~~ Net::Telnet::Chunk::Subnegotiation::NAWS, 'Can match subnegotiations';
    is $match.begin, SB, 'Can match subnegotation begin commands';
    is $match.end, SE, 'Can match subnegotiation end commands';
    is $match.option, NAWS, 'Can match subnegotiation options';
    is $match.width, 80, 'Can match NAWS subnegotiation width';
    is $match.height, 60, 'Can match NAWS subnegotiation height';
}

done-testing;
