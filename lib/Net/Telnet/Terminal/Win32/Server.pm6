use v6.d;
use Net::Telnet::Terminal;
unit class Net::Telnet::Terminal::Win32::Server does Net::Telnet::Terminal;

has Str $.type   is rw;
has Str $.width  is rw;
has Str $.height is rw;

submethod BUILD() {
    $!type   = 'unknown';
    $!width  = 0;
    $!height = 0;
}

submethod DESTROY() {}

# "Where are the type/width/height methods that were stubbed in
# Net::Telnet::Terminal?"
# Don't forget, adding public attributes implicitly adds getter methods.

# TODO: use whatever equivalent Windows has to PTYs here.
