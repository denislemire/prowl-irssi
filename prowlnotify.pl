use strict;
use warnings;

# irssi imports
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI %config);

$VERSION = "0.1";
%IRSSI = (
	authors => "Denis Lemire",
	contact => "denis\@lemire.name",
	name => "prowl",
	description => "Sets nick away when client discconects from the "
		. "irssi-proxy sends messages to an iPhone via prowl.",
	license => "GPLv2",
	url => "http://www.denis.lemire.name",
);

$config{away_level} = 0;
$config{prowluser} = '';
$config{prowlpass} = '';
$config{awayreason} = 'Auto-away because client has disconnected from proxy.';
$config{debug} = 0;
$config{clientcount} = 0;

sub debug
{
	if ($config{debug}) {
		my $text = shift;
		my $caller = caller;
		Irssi::print('From ' . $caller . ":\n" . $text);
	}
}

sub send_prowl
{
	my ($event, $text) = @_;

	debug("Sending prowl");

	use LWP::UserAgent;

	# Grab our options.
	my %options = ();

	$options{'application'} = 'IRSSI';
	$options{'event'} = $event;
	$options{'notification'} = $text;

	# URL encode our arguments
	$options{'application'} =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	$options{'event'} =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
	$options{'notification'} =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;

	# Generate our HTTP request.
	my ($userAgent, $request, $response, $requestURL);
	$userAgent = LWP::UserAgent->new;
	$userAgent->agent("ProwlScript/1.0");

	$requestURL = sprintf("https://prowl.weks.net/api/add_notification.php?application=%s&event=%s&description=%s",
				$options{'application'},
				$options{'event'},
				$options{'notification'});

	$request = HTTP::Request->new(GET => $requestURL);
	$request->authorization_basic($config{'prowluser'}, $config{'prowlpass'});

	$response = $userAgent->request($request);

	if ($response->is_success) {

	} elsif ($response->code == 401) {
	#	print STDERR "Notification not posted: incorrect username or password.\n";
	} else {
	#	print STDERR "Notification not posted: " . $response->status_line . "\n";
	}
}

sub client_connect
{
	my (@servers) = Irssi::servers;
 
	$config{clientcount}++;
	debug("Client connected.");

	# setback
	foreach my $server (@servers) {
		# if you're away on that server send yourself back
		if ($server->{usermode_away} == 1) {
			$server->send_raw('AWAY :');
		}
	}
}

sub client_disconnect
{
	my (@servers) = Irssi::servers;
	debug('Client Disconnectted');

	$config{clientcount}-- unless $config{clientcount} == 0;

	# setaway
	if ($config{clientcount} <= $config{away_level}) {
		# ok.. we have the away_level of clients connected or less.
		foreach my $server (@servers) {
			if ($server->{usermode_away} == "0") {
				# we are not away on this server allready.. set the autoaway
				# reason
				$server->send_raw(
					'AWAY :' . $config{awayreason}
				);
			}
		}
	}
}

sub msg_pub
{
	my ($server, $data, $nick, $mask, $target) = @_;
	 
	if ($server->{usermode_away} == "1" && $data =~ /$server->{nick}/i) {
		debug("Got pub msg with my name");
		send_prowl ("Mention", $nick . ': ' . $data);
	}
}

sub msg_pri
{
	my ($server, $data, $nick, $address) = @_;
	if ($server->{usermode_away} == "1") {
		send_prowl ("Private msg", $nick . ': ' . $data);
	}
}

Irssi::signal_add_last('proxy client connected', 'client_connect');
Irssi::signal_add_last('proxy client disconnected', 'client_disconnect');
Irssi::signal_add_last('message public', 'msg_pub');
Irssi::signal_add_last('message private', 'msg_pri');
