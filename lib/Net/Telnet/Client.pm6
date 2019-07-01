use v6.d;
use NativeCall;
use Net::Telnet::Connection;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Option;
use Net::Telnet::Terminal;
use Net::Telnet::Terminal::Client;
unit class Net::Telnet::Client does Net::Telnet::Connection;

method connect(--> Promise) {
    IO::Socket::Async.connect($!host, $!port, :enc<latin1>).then(-> $p {
        self!on-connect: await $p;
    });
}

method !init-terminal(--> Net::Telnet::Terminal) {
    Net::Telnet::Terminal::Client.new({
        if $!options{NAWS}.enabled: :local {
            $!terminal.refresh;
            await self!send-subnegotiation(NAWS);
            await $!pending.subnegotiations.get: NAWS;
            $!pending.subnegotiations.remove: NAWS;
        }
    })
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
