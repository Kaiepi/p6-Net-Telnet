use v6.d;
unit module Net::Telnet::Terminal::Client;

my package Net::Telnet::Terminal {
    constant Client = do if $*DISTRO.is-win {
        require Net::Telnet::Terminal::Win32::Client
    } else {
        require Net::Telnet::Terminal::UNIX::Client
    };
}
