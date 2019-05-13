use v6.d;
use Net::Telnet::Connection;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Option;
use Net::Telnet::Terminal;
unit class Net::Telnet::Client does Net::Telnet::Connection;

method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port, :enc<latin1>).then(-> $p {
        self!on-connect: $p.result;
    })
}

method !set-terminal-dimensions(--> Nil) {
    $!host-width  = get-terminal-width;
    $!host-height = get-terminal-height;
    $!terminal    = signal(SIGWINCH).tap({
        $!host-width  = get-terminal-width;
        $!host-height = get-terminal-height;
        if $!options{NAWS}.enabled: :local {
            await self!send-subnegotiation(NAWS);
            await $!pending.subnegotiations.get: NAWS;
            $!pending.subnegotiations.remove: NAWS;
        }
    });
}

method !send-initial-negotiations(--> Nil) {
    # Wait for the server to send its initial negotiations before sending our
    # own. This is to avoid race conditions.
    sleep 3;
    for $!pending.negotiations.kv -> $option, $request {
        await $request;
        $!pending.negotiations.remove: $option;
    }
    # TODO: handle subnegotiations properly. This doesn't matter for now since
    # NAWS doesn't expect a response and it's the only option we support with
    # subnegotiations.
    for $!pending.subnegotiations.kv -> $option, $request {
        # await $request;
        $!pending.subnegotiations.remove: $option;
    }

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
