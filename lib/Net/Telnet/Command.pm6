use v6.c;
unit class Net::Telnet::Command;

enum TelnetCommand is export (
    'TELNET_SE'   => 240, # Subnegotiation End
    'TELNET_NOP'  => 241, # No Operation
    'TELNET_DM'   => 242, # Data Mark
    'TELNET_BRK'  => 243, # Break
    'TELNET_IP'   => 244, # Interrupt Process
    'TELNET_AO'   => 245, # Abort Output
    'TELNET_AYT'  => 246, # Are You There?
    'TELNET_EC'   => 247, # Erase Character
    'TELNET_EL'   => 248, # Erase Line
    'TELNET_GA'   => 249, # Go Ahead
    'TELNET_SB'   => 250, # Subnegotiation Begin
    'TELNET_WILL' => 251,
    'TELNET_WONT' => 252,
    'TELNET_DO'   => 253,
    'TELNET_DONT' => 254,
    'TELNET_IAC'  => 255  # Interpret As Command
);

enum TelnetOption is export (
    'TELOPT_TRANSMIT_BINARY'     => 0,
    'TELOPT_ECHO'                => 1,
    'TELOPT_RCP'                 => 2,   # Reconnection
    'TELOPT_SGA'                 => 3,   # Suppress Go Ahead
    'TELOPT_NAMS'                => 4,   # Message Size Negotiation
    'TELOPT_STATUS'              => 5,
    'TELOPT_TIMING_MARK'         => 6,
    'TELOPT_RCTE'                => 7,   # Remote Controlled Trans and Echo
    'TELOPT_NAOL'                => 8,   # Output Line Width
    'TELOPT_NAOP'                => 9,   # Output Line Height
    'TELOPT_NAOCRD'              => 10,  # Output Carriage-Return Disposition
    'TELOPT_NAOHTS'              => 11,  # Output Horizontal Tab Stops
    'TELOPT_NAOHTD'              => 12,  # Output Horizontal Tab Disposition
    'TELOPT_NAOFFD'              => 13,  # Output Formfeed Disposition
    'TELOPT_NAOVTS'              => 14,  # Output Vertical Stops
    'TELOPT_NAOVTD'              => 15,  # Output Vertical Disposition
    'TELOPT_NAOLFD'              => 16,  # Output Linefeed Disposition
    'TELOPT_XASCII'              => 17,  # Extended ASCII
    'TELOPT_LOGOUT'              => 18,
    'TELOPT_BM'                  => 19,  # Byte Macro
    'TELOPT_DET'                 => 20,  # Data Entry Terminal
    'TELOPT_SUPDUP'              => 21,
    'TELOPT_SUPDUP_OUTPUT'       => 22,
    'TELOPT_SEND_LOCATION'       => 23,
    'TELOPT_TERMINAL_TYPE'       => 24,
    'TELOPT_END_OF_RECORD'       => 25,
    'TELOPT_TUID'                => 26,  # TACACS User Identification
    'TELOPT_OUTMRK'              => 27,  # Output Marking
    'TELOPT_TTYLOC'              => 28,  # Terminal Location Number
    'TELOPT_3270_REGIME'         => 29,
    'TELOPT_X_3_PAD'             => 30,
    'TELOPT_NAWS'                => 31,  # Negotiate About Window Size
    'TELOPT_TERMINAL_SPEED'      => 32,
    'TELOPT_TOGGLE_FLOW_CONTROL' => 33,
    'TELOPT_LINEMODE'            => 34,
    'TELOPT_XDISPLOC'            => 35,  # X Display Location
    'TELOPT_ENVIRON'             => 36,  # Environment
    'TELOPT_AUTHENTICATION'      => 37,
    'TELOPT_ENCRYPT'             => 38,
    'TELOPT_NEW_ENVIRON'         => 39,
    'TELOPT_TN3270E'             => 40,
    'TELOPT_XAUTH'               => 41,
    'TELOPT_CHARSET'             => 42,
    'TELOPT_RSP'                 => 43,  # Remote Serial Port
    'TELOPT_COM_PORT_OPTION'     => 44,
    'TELOPT_SLE'                 => 45,  # Suppress Local Echo
    'TELOPT_START_TLS'           => 46,
    'TELOPT_KERMIT'              => 47,
    'TELOPT_SEND_URL'            => 48,
    'TELOPT_FORWARD_X'           => 49,
    'TELOPT_PRAGMA_LOGON'        => 138,
    'TELOPT_SSPI_LOGON'          => 139,
    'TELOPT_PRAGMA_HEARTBEAT'    => 140,
    'TELOPT_EXOPL'               => 255
);

# TODO
