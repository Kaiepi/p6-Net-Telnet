use v6.c;
use Net::Telnet::Chunk;
unit class Net::Telnet::Option;

# See RFC 1143
enum OptionState is export <NO YES WANTNO WANTYES>;
enum OptionQueue is export <EMPTY OPPOSITE>;

has TelnetOption $.option;
has Bool         $.supported;
has Bool         $.preferred is rw;
has OptionState  $.us        is rw = NO;
has OptionQueue  $.usq       is rw = EMPTY;
has OptionState  $.them      is rw = NO;
has OptionQueue  $.themq     is rw = EMPTY;
