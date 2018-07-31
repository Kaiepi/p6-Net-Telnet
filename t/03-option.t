use v6.c;
use Net::Telnet::Constants;
use Net::Telnet::Option;
use Test;

{
    my Net::Telnet::Option $option .= new:
        option    => TRANSMIT_BINARY,
        preferred => False,
        supported => False;

    is $option.on-receive-will, DONT, 'Sends DONT in response to WILL while disabled remotely';
    nok defined($option.on-receive-wont), 'Sends nothing in response to WONT while disabled remotely';
	is $option.on-send-do, DONT, 'Sends DONT when attempting to send DO while disabled remotely';
	nok defined($option.on-send-dont), 'Sends nothing when attempting to send DONT while disabled remotely';

	is $option.on-receive-do, WONT, 'Sends WONT in response to DO while disabled locally';
	nok defined($option.on-receive-dont), 'Sends nothing in response to DONT while disabled locally';
	is $option.on-send-will, WONT, 'Sends WONT when attempting to send WILL while disabled locally';
	nok defined($option.on-send-wont), 'Sends nothing when attempting to send WONT while disabled locally';
}

{
	my Net::Telnet::Option $option .= new:
		option    => TRANSMIT_BINARY,
		preferred => True,
		supported => True;

	is $option.on-send-do, DO, 'Sends DO when attempting to send DO while disabled remotely';
	is $option.them, WANTYES, 'Sets state to WANTYES while enabling remotely';
	nok defined($option.on-receive-will), 'Sends nothing in response to WILL while enabling remotely';
	is $option.them, YES, 'Sets state to YES while enabled remotely';

	is $option.on-send-dont, DONT, 'Sends DONT when attempting to send DONT while enabled remotely';
	is $option.them, WANTNO, 'Sets state to WANTNO while disabling remotely';
	nok defined($option.on-receive-wont), 'Sends nothing in response to WILL while disabling remotely';
	is $option.them, NO, 'Sets state to NO while disabled remotely';

	$option.on-send-do;
	nok defined($option.on-send-dont), 'Sends nothing when attempting to send DONT while enabling remotely';
	$option.on-send-dont;
	is $option.themq, OPPOSITE, 'Queues DONT while enabling remotely';
	is $option.on-receive-will, DONT, 'Pops DONT from the queue while disabling remotely on the queue';
	is $option.them, WANTNO, 'Sets state to WANTNO while disabling remotely on the queue';
	is $option.themq, EMPTY, 'Queue is emptied while disabling remotely on the queue';
	$option.on-receive-wont;
	is $option.them, NO, 'Sets state to NO while disabled remotely on the queue';

	$option.on-send-do;
	$option.on-receive-will;
	$option.on-send-dont;
	nok defined($option.on-send-do), 'Sends nothing when attempting to send DO while disabling remotely';
	$option.on-send-do;
	is $option.themq, OPPOSITE, 'Queues DO while enabling remotely on the queue';
	is $option.on-receive-wont, DO, 'Pops DO from the queue while enabling remotely on the queue';
	is $option.them, WANTYES, 'Sets state to WANTYES while disabling remotely on the queue';
	is $option.themq, EMPTY, 'Queue is emptied while enabling remotely on the queue';
	$option.on-receive-will;
	is $option.them, YES, 'Sets state to YES while enabled locally on the queue';

	is $option.on-send-will, WILL, 'Sends WILL when attempting to send WILL while disabled locally';
	is $option.us, WANTYES, 'Sets state to WANTYES while enabling locally';
	nok defined($option.on-receive-do), 'Sends nothing in response to DO while enabling locally';
	is $option.us, YES, 'Sets state to YES while enabled locally';

	is $option.on-send-wont, WONT, 'Sends WONT when attempting to send WONT while enabled locally';
	is $option.us, WANTNO, 'Sets state to WANTNO while disabling locally';
	nok defined($option.on-receive-dont), 'Sends nothing in response to DONT while disabling locally';
	is $option.us, NO, 'Sets state to NO while disabled locally';

	$option.on-send-will;
	nok defined($option.on-send-wont), 'Sends nothing when attempting to send WONT while enabling locally';
	$option.on-send-wont;
	is $option.usq, OPPOSITE, 'Queues WONT while enabling locally';
	is $option.on-receive-do, WONT, 'Pops WONT from the queue while disabling locally on the queue';
	is $option.us, WANTNO, 'Sets state to WANTNO while disabling locally on the queue';
	is $option.usq, EMPTY, 'Queue is emptied while disabling locally on the queue';
	$option.on-receive-dont;
	is $option.us, NO, 'Sets state to NO while disabled locally on the queue';

	$option.on-send-will;
	$option.on-receive-do;
	$option.on-send-wont;
	nok defined($option.on-send-will), 'Sends nothing when attempting to send WILL while disabling locally';
	$option.on-send-will;
	is $option.usq, OPPOSITE, 'Queues WILL while enabling locally on the queue';
	is $option.on-receive-dont, WILL, 'Pops WILL from the queue while enabling locally on the queue';
	is $option.us, WANTYES, 'Sets state to WANTYES while disabling locally on the queue';
	is $option.usq, EMPTY, 'Queue is emptied while enabling locally on the queue';
	$option.on-receive-do;
	is $option.us, YES, 'Sets state to YES while enabled locally on the queue';
}

done-testing;
