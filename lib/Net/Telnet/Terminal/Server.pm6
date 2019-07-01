use v6.d;
unit module Net::Telnet::Terminal::Server;

my package Net::Telnet::Terminal {
    constant Server = do if $*DISTRO.is-win {
        require Net::Telnet::Terminal::Win32::Server
    } else {
        require Net::Telnet::Terminal::UNIX::Server
    };
}
