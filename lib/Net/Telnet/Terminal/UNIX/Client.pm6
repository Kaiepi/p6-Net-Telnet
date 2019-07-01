use v6.d;
use NativeCall;
use Net::Telnet::Terminal;
unit class Net::Telnet::Terminal::UNIX::Client does Net::Telnet::Terminal;

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

has Str $!type;
has Int $!width;
has Int $!height;
has Tap $!sigwinch-tap;

submethod BUILD(Tap :$!sigwinch-tap) {
    $!type   = %*ENV<TERM> // 'unknown';
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
            $!width = $width // do {
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
            $!height = $height // do {
                my winsize $ws .= new;
                ioctl($*OUT.native-descriptor, TIOCGWINSZ, $ws);
                $ws.ws_row
            };
        }
    )
}
