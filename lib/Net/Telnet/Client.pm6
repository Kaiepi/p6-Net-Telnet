use v6.d;
use NativeCall;
use Net::Telnet::Connection;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Option;
use Net::Telnet::Terminal;
unit class Net::Telnet::Client does Net::Telnet::Connection;

class Terminal does Net::Telnet::Terminal {
    # Windows
    my class COORD is repr('CStruct') {
        has int16 $.X;
        has int16 $.Y;
    }

    my class SMALL_RECT is repr('CStruct') {
        has int16 $.Left;
        has int16 $.Top;
        has int16 $.Right;
        has int16 $.Bottom;
    }

    my class CONSOLE_SCREEN_BUFFER_INFO is repr('CStruct') {
        HAS COORD      $.dwSize;
        HAS COORD      $.dwCursorPosition;
        has uint16     $.wAttributes;
        HAS SMALL_RECT $.srWindow;
        HAS COORD      $.dwMaximumWindowSize;
    }

    sub GetStdHandle(int32 --> Pointer[void]) is native {*}
    sub GetConsoleScreenBufferInfo(Pointer[void], CONSOLE_SCREEN_BUFFER_INFO is rw --> int32) is native {*}

    # POSIX
    my class winsize is repr('CStruct') {
        has uint16 $.ws_row;
        has uint16 $.ws_col;
        has uint16 $.ws_xpixel;
        has uint16 $.ws_ypixel;
    }

    constant TIOCGWINSZ = do {
        my Int constant IOCPARM_MASK = 0x1FFF;
        my Int constant IOC_OUT      = 0x40000000;
        my Int $group = 't'.ord;
        my Int $num   = 104;
        my Int $len   = nativesizeof(winsize);
        IOC_OUT +| (($len +& IOCPARM_MASK) +< 16) +| ($group +< 8) +| $num
    };

    sub ioctl(int32, uint32, winsize is rw --> int32) is native {*}

    has Str  $!type;
    has Int  $!width;
    has Int  $!height;
    has Tap  $!sigwinch-tap;

    submethod BUILD(Tap :$!sigwinch-tap) {
        self.type   = Str;
        self.width  = Int;
        self.height = Int;
    }

    submethod DESTROY() {
        $!sigwinch-tap.close;
    }

    method new(&on-sigwinch) {
        my Tap $sigwinch-tap = signal(SIGWINCH).tap(&on-sigwinch);
        self.bless: :$sigwinch-tap;
    }

    # Provide proxies for the terminal type, width, and height so we can lie
    # about them if we choose to do so.

    method type(--> Str) is raw {
        Proxy.new(
            FETCH => -> $ { $!type },
            STORE => -> $, Str $type {
                $!type = $type // %*ENV<TERM> // 'unknown';
            }
        )
    }

    method width(--> Int) is raw {
        Proxy.new(
            FETCH => -> $ { $!width },
            STORE => -> $, Int $width {
                $!width = $width // do if $*VM.osname eq 'MSWin32' {
                    my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
                    GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
                    $csbi.srWindow.Right - $csbi.srWindow.Left + 1
                } else {
                    my winsize $ws .= new;
                    ioctl($*OUT.native-descriptor, TIOCGWINSZ, $ws);
                    $ws.ws_col
                };
            }
        )
    }

    method height(--> Int) is raw {
        Proxy.new(
            FETCH => -> $ { $!height },
            STORE => -> $, Int $height {
                $!height = $height // do if $*VM.osname eq 'MSWin32' {
                    my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
                    GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
                    $csbi.srWindow.Bottom - $csbi.srWindow.Top + 1
                } else {
                    my winsize $ws .= new;
                    ioctl($*OUT.native-descriptor, TIOCGWINSZ, $ws);
                    $ws.ws_row
                };
            }
        )
    }
}

method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port, :enc<latin1>).then(-> $p {
        self!setup-terminal;
        self!on-connect: await $p;
    });
}

method !setup-terminal(--> Nil) {
    $!terminal = Terminal.new: {
        if $!options{NAWS}.enabled: :local {
            await self!send-subnegotiation(NAWS);
            await $!pending.subnegotiations.get: NAWS;
            $!pending.subnegotiations.remove: NAWS;
        }
    };
}

method !send-initial-negotiations(--> Nil) {
    # Wait for the server to send its initial negotiations before sending our
    # own. This is to avoid race conditions.
    sleep 3;

    # We don't care about the results of the initial negotiations.
    for $!pending.negotiations.keys -> $option {
        $!pending.negotiations.remove: $option;
    }

    # Check if we received "IAC SB TERMINAL_TYPE SEND IAC SE" from the server.
    # Reply with "IAC SB TERMINAL_TYPE IS <ttype> IAC SE" if so.
    if $!pending.subnegotiations.has: TERMINAL_TYPE {
        my Net::Telnet::Subnegotiation::TerminalType $subnegotiation =
            await $!pending.subnegotiations.remove: TERMINAL_TYPE;

        if $subnegotiation.command != TerminalTypeCommand::SEND {
            my Blob $data = $subnegotiation.serialize;
            X::Net::Telnet::ProtocolViolation.new(:$!host, :$!port, :$data).throw;
        }

        await self!send-subnegotiation: TERMINAL_TYPE;
        $!pending.subnegotiations.remove: TERMINAL_TYPE;
    }

    # We don't care about the rest of the subnegotiations; they either don't
    # take a response or aren't supported.
    for $!pending.subnegotiations.kv -> $option, $request {
        $!pending.subnegotiations.remove: $option;
    }

    # Negotiate any remaining options.
    for $!options.values -> $option {
        if $option.preferred && $option.disabled: :local {
            my TelnetCommand $command = $option.on-send-will;
            if $command.defined {
                await self!send-negotiation: $command, $option.option;
                await $!pending.negotiations.get: $option.option;
                $!pending.negotiations.remove: $option.option;
            }
        }
        if $option.supported && $option.disabled: :remote {
            my TelnetCommand $command = $option.on-send-do;
            if $command.defined {
                await self!send-negotiation: $command, $option.option;
                await $!pending.negotiations.get: $option.option;
                $!pending.negotiations.remove: $option.option;
            }
        }
    }
}

method !update-host-state(Net::Telnet::Subnegotiation $subnegotiation --> Nil) {
    # ...
}

method !update-peer-state(TelnetOption $option --> Net::Telnet::Subnegotiation) {
    given $option {
        when NAWS {
            Net::Telnet::Subnegotiation::NAWS.new(
                width  => $!terminal.width,
                height => $!terminal.height
            )
        }
        when TERMINAL_TYPE {
            Net::Telnet::Subnegotiation::TerminalType.new(
                command => TerminalTypeCommand::IS,
                type    => $!terminal.type
            )
        }
        default {
            Nil
        }
    }
}

=begin pod

=head1 NAME

Net::Telnet::Client

=head1 DESCRIPTION

C<Net::Telnet::Client> is a class that creates TELNET clients. For documentation
on the majority of its attributes and methods, see the documentation on
C<Net::Telnet::Connection>.

=head1 SYNOPSIS

    use Net::Telnet::Client;
    use Net::Telnet::Constants;

    my Net::Telnet::Client $client .= new:
        :host<telehack.com>,
        :preferred[NAWS],
        :supported[ECHO, SGA];
    $client.text.tap({ .print });

    await $client.connect;
    await $client.send-text: 'cowsay ayy lmao';
    $client.close;

=head1 METHODS

=item B<connect>(--> Promise)

Connects to the server. The promise returned is resolved once the initial
negotiations with the server have been completed.

=end pod
