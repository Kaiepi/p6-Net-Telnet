use v6.c;
use Net::Telnet::Chunk;
unit class Net::Telnet::Client;

has Bool $.closed = False;

has IO::Socket::Async           $!socket;
has Net::Telnet::Chunk::Actions $!actions    .= new;
has Buf                         $!parser-buf .= new;

method peer-host(--> Str)   { $!socket.peer-host   }
method peer-port(--> Int)   { $!socket.peer-port   }
method socket-host(--> Str) { $!socket.socket-host }
method socket-port(--> Int) { $!socket.socket-port }

multi method connect(::?CLASS:U: Str $host, Int $port = 23 --> Promise) {
    my $client = self.new;
    $client.connect($host, $port);
}
multi method connect(::?CLASS:D: Str $host, Int $port = 23 --> Promise) {
    IO::Socket::Async.connect($host, $port).then(-> $p {
        $!closed = False;

        my Buf $buf .= new;
        $!socket = $p.result;
        $!socket.Supply(:bin, :$buf).act(-> $data {
            self.parse($data);
        }, done => {
            $!closed = True;
        }, quit => {
            $!closed = True;
        });

        self;
    });
}

method parse(Blob $data) {
    my $buf = $!parser-buf.elems ?? $!parser-buf.splice.append($data) !! $data;
    my $msg = $buf.decode('latin1');
    my $match = Net::Telnet::Chunk::Grammar.subparse($msg, :$!actions);
    .say for $match.ast;
    $!parser-buf = $match.postmatch.encode('latin1') if $match.postmatch;
}

multi method send(Blob $data --> Promise) { $!socket.write($data) }
multi method send(Str $data --> Promise)  { $!socket.print($data) }

method close(--> Bool) {
    $!socket.close;
    $!closed = True;
}
