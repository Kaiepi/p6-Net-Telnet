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

has Str $!type          is rw;
has Int $!width         is rw;
has Int $!height        is rw;
has Tap $!sigwinch-tap;

submethod BUILD(Tap :$!sigwinch-tap) {
    $!type   = 'unknown';
    $!width  = 0;
    $!height = 0;
}

submethod DESTROY() {
    $!sigwinch-tap.close;
}

method new(&on-sigwinch) {
    my Tap $sigwinch-tap = signal(SIGWINCH).tap(&on-sigwinch);
    self.bless: :$sigwinch-tap;
}

# Method exclusive to clients.
method refresh(--> Nil) {
    # XXX: what would be an appropriate terminal type here? vt100 or something?
    # It could depend on whether or not PowerShell or cmd is running. I can't
    # tell without being able to test. Just set it to unknown for now.
    $!type   = 'unknown';
    $!width  = do {
        my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
        GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
        $csbi.srWindow.Right - $csbi.srWindow.Left + 1
    };
    $!height = do {
        my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
        GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
        $csbi.srWindow.Bottom - $csbi.srWindow.Top + 1
    };
}
