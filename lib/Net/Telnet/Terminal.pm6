use v6.c;
use NativeCall;
unit class Net::Telnet::Terminal;

# Windows
class COORD is repr('CStruct') {
    has int16 $.X;
    has int16 $.Y;
}

class SMALL_RECT is repr('CStruct') {
    has int16 $.Left;
    has int16 $.Top;
    has int16 $.Right;
    has int16 $.Bottom;
}

class CONSOLE_SCREEN_BUFFER_INFO is repr('CStruct') {
    HAS COORD      $.dwSize;
    HAS COORD      $.dwCursorPosition;
    has uint16     $.wAttributes;
    HAS SMALL_RECT $.srWindow;
    HAS COORD      $.dwMaximumWindowSize;
}

sub GetStdHandle(int32 --> Pointer[void]) is native {*}
sub GetConsoleScreenBufferInfo(Pointer[void], CONSOLE_SCREEN_BUFFER_INFO is rw --> int32) is native {*}

# POSIX
class winsize is repr('CStruct') {
    has uint16 $.ws_row;
    has uint16 $.ws_col;
    has uint16 $.ws_xpixel;
    has uint16 $.ws_ypixel;
}

constant TIOCGWINSZ = {
    constant IOCPARM_MASK = 0x1FFF;
    constant IOC_OUT      = 0x40000000;
    my $group = 't'.ord;
    my $num   = 104;
    my $len   = nativesizeof(winsize);
    IOC_OUT +| (($len +& IOCPARM_MASK) +< 16) +| ($group +< 8) +| $num
}();

sub ioctl(int32, uint32, winsize is rw --> int32) is native {*}

method width(--> Int) {
    if $*VM.osname eq 'MSWin32' {
        my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
        GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
        $csbi.srWindow.Right - $csbi.srWindow.Left + 1
    } else {
        my winsize $ws .= new;
        ioctl($*OUT.native-descriptor, TIOCGWINSZ, $ws);
        $ws.ws_col
    }
}

method height(--> Int) {
    if $*VM.osname eq 'MSWin32' {
        my CONSOLE_SCREEN_BUFFER_INFO $csbi .= new;
        GetConsoleScreenBufferInfo(GetStdHandle($*OUT.native-descriptor), $csbi);
        $csbi.srWindow.Bottom - $csbi.srWindow.Top + 1
    } else {
        my winsize $ws .= new;
        ioctl($*OUT.native-descriptor, TIOCGWINSZ, $ws);
        $ws.ws_row
    }
}