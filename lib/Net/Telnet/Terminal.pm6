use v6.d;
unit role Net::Telnet::Terminal;

# This library isn't concerned with terminal emulation. All we care about is
# implementing the TELNET protocol. That said, there are some TELNET options
# that require information about the system terminal. These are implemented in
# Net::Telnet::Client::Terminal and Net::Telnet::Server;:Connection::Terminal.
#
# If you wish to implement proper terminal emulation, you'll need to wrap or
# subclass Net::Telnet::Client and Net::Telnet::Client::Terminal and implement
# the logic yourself. You'll need to use a PTY for this.

# Get/set the terminal type.
method type(--> Str)   {...}
# Get/set the terminal width.
method width(--> Int)  {...}
# Get/set the terminal height.
method height(--> Int) {...}
