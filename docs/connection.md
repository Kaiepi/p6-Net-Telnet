NAME
====

Net::Telnet::Connection

DESCRIPTION
===========

Net::Telnet::Connection is a role done by Net::Telnet::Client and Net::Telnet::Server::Connection. It manages all connection state.

ATTRIBUTES
==========

  * IO::Socket::Async **$.socket**

The connection's socket.

  * Str **$.host**

The host with which the connection will connect.

  * Int **$.port**

The port with which the connection will connect.

  * Promise **$.close-promise**

This promise is kept once the connection is closed.

  * Map **$.options**

A map of the state of all options the connection is aware of. Its shape is `(Net::Telnet::Constants::TelnetOption => Net::Telnet::Option)`.

  * Int **$.peer-width**

The peer's terminal width. This is meaningless for Net::Telnet::Client since `NAWS` is only supported by clients.

  * Int **$.peer-height**

The peer's terminal height. This is meaningless for Net::Telnet::Client since `NAWS` is only supported by clients.

  * Int **$.host-width**

The host's terminal width. This is meaningless for Net::Telnet::Server::Connection since `NAWS` is only supported by clients.

  * Int **$.host-height**

The host's terminal height. This is meaningless for Net::Telnet::Server::Connection since `NAWS` is only supported by clients.

METHODS
=======

  * **closed**(--> Bool)

Whether or not the connection is currently closed.

  * **text**(--> Supply)

Returns the supply to which text received by the connection is emitted.

  * **binary**(--> Supply)

Returns the supply to which supplies that emit binary data received by the connection is emitted.

  * **supported**(Str $option --> Bool)

Returns whether or not `$option` is allowed to be enabled by the peer.

  * **preferred**(Str $option --> Bool)

Returns whether or not `$option` is allowed to be enabled by us.

  * **new**(Str *:$host*, Int *:$port*, *:@supported?*, *:@preferred?* --> Net::Telnet::Client)

Initializes a TELNET connection. `$host` and `$port` are used by `.connect` to connect to a peer.

`@supported` is a list of options that the connection will allow the peer to negotiate with. On connect, `DO` negotiations will be sent for each option in this list as part of the connection's initial negotiations, unless this is a Net::Telnet::Client instance and the peer has already sent a `WILL` negotiation.

`@preferred` is a list of options that the connection will attempt to negotiate with. On connect, `IAC WILL` commands will be sent for each option in this list as part of the connection's initial negotiations, unless this is a Net::Telnet::Client instance and the peer has already sent a `DO` negotiation.

  * **connect**(--> Promise)

Connects to the peer given the host and port provided in `new`. The promise returned is resolved once the connection has been opened.

`X::Net::Telnet::ProtocolViolation` may be thrown at any time if the peer is either buggy, malicious, or not a TELNET server to begin with and doesn't follow TELNET protocol.

`X::Net::Telnet::OptionRace` may be thrown at any time if the peer is buggy or malicious and attempts to start a negotiation before another negotiation for the same option has finished. It may also be thrown if there is a race condition somewhere in negotiation handling.

  * **send**(Blob *$data* --> Promise)

  * **send**(Str *$data* --> Promise)

Sends raw data to the server.

  * **send-text**(Str *$data* --> Promise)

Sends a message appended with `CRLF` to the server.

  * **send-binary**(Blob *$data* --> Promise)

Sends binary data to the server. If the server isn't already expecting binary data, this will send the necessary `TRANSMIT_BINARY` negotiations to attempt to convince the server to parse incoming data as binary data. This will throw `X::Net::Telnet::TransmitBinary` if the server declines to begin binary data transmission.

  * **close**(--> Bool)

Closes the connection to the server, if any is open.

