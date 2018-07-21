use v6.c;
use Net::Telnet::Chunk;
unit class Net::Telnet::Client;

has Bool $.closed = False;

has IO::Socket::Async           $!socket;
has Net::Telnet::Chunk::Actions $!actions    .= new;
has Buf                         $!parser-buf .= new;

method host(--> Str) { $!socket.peer-host }
method port(--> Int) { $!socket.peer-port }

multi method connect(::?CLASS:U: Str $host, Int $port = 23 --> Promise) {
    my $client = self.new;
    $client.connect($host, $port);
}
multi method connect(::?CLASS:D: Str $host, Int $port = 23 --> Promise) {
    IO::Socket::Async.connect($host, $port).then(-> $p {
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
    my $match = Net::Telnet::Chunk::Grammar.subparse(
        $buf.decode('latin1'),
        :$!actions
    );
    .say for $match.made;
    $!parser-buf = $data.subbuf($match.to) if $match.to < $data.elems;
}

multi method send(Blob $data) { $!socket.write($data) }
multi method send(Str $data)  { $!socket.print($data) }

method close(--> Bool) {
    $!socket.close;
    $!closed = True;
}
