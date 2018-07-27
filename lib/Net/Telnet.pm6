use v6.c;
unit module Net::Telnet:ver<0.0.1>;

=begin pod

=head1 NAME

Net::Telnet - Telnet library for clients and servers

=head1 SYNOPSIS

    use Net::Telnet::Client;

    my Net::Telnet::Client $client .= new: :host<telehack.com>, :options<ECHO SGA>;
    $client.text.tap({ .print });
    await $client.connect;
    await $client.send("cowsay ayy lmao\r\n");

    use Net::Telnet::Server;

    # TODO

=head1 DESCRIPTION

Net::Telnet is a library for creating Telnet clients and servers. See
C<Net::Telnet::Client> and C<Net::Telnet::Server> for more documentation.

=head1 AUTHOR

Ben Davies (kaiepi)

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Ben Davies

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
