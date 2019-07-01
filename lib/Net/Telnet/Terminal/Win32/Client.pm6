use v6.d;
use NativeCall;
use Net::Telnet::Terminal;
unit class Net::Telnet::Terminal::Win32::Client does Net::Telnet::Terminal;

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

has Str $!type;
has Int $!width;
has Int $!height;
has Tap $!sigwinch-tap;

submethod DESTROY() {
    $!sigwinch-tap.close;
}

method new(&on-sigwinch) {
    my Tap $sigwinch-tap = signal(SIGWINCH).tap(&on-sigwinch);
    self.bless: :$sigwinch-tap;
}

method type(--> Str) is raw {
    Proxy.new(
        FETCH => -> $ { $!type },
        STORE => -> $, Str $type {
            $!type = $type // 'unknown';
        }
    )
}

method width(--> Int) is raw {
    Proxy.new(
        FETCH => -> $ { $!width },
        STORE => -> $, Int $width {
            $!width = $width // do {
                my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
                GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
                $csbi.srWindow.Right - $csbi.srWindow.Left + 1
            };
        }
    )
}

method height(--> Int) is raw {
    Proxy.new(
        FETCH => -> $ { $!height },
        STORE => -> $, Int $height {
            $!height = $height // do {
                my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
                GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
                $csbi.srWindow.Bottom - $csbi.srWindow.Top + 1
            };
        }
    )
}
