use Irssi;
use POSIX;
use LWP::UserAgent;
use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
	authors     => "Grigoriy Dzhanelidze",
	contact     => "ohaistarlight\@gmail.com",
	name        => "IrssiPushover",
	description => "Send irssi highlights to pushover",
	license     => "Apache License, version 2.0",
	url         => "https://github.com/StrLght/irssi-pushover",
	changed     => "2014-05-01"
);

my $lastServer;
my $lastMsg;
my $lastNick;
my $lastAddress;
my $lastTarget;

sub private {
	my ($server, $msg, $nick, $address) = @_;
	$lastServer = $server;
	$lastMsg = $msg;
	$lastNick = $nick;
	$lastAddress = $address;
	$lastTarget = "!PRIVATE";
}

sub public {
	my ($server, $msg, $nick, $address, $target) = @_;
	$lastServer = $server;
	$lastMsg = $msg;
	$lastNick = $nick;
	$lastAddress = $address;
	$lastTarget = $target;
}

sub print_text {
	my ($dest, $text, $stripped) = @_;

	my $opt = MSGLEVEL_HILIGHT | MSGLEVEL_MSGS;
	if (
		($dest->{level} & ($opt)) && (($dest->{level} & MSGLEVEL_NOHILIGHT) == 0) &&
		(!Irssi::settings_get_bool("irssipushover_away_only") || $lastServer->{usermode_away})
	) {
		notify();
	}
}

sub notify {
	if (!Irssi::settings_get_str('irssipushover_api_token')) {
		Irssi::print("IrssiPushover: Set API token to send notifications: /set irssipushover_api_token [token]");
		return;
	}

	if (!Irssi::settings_get_str('irssipushover_user_token')) {
		Irssi::print("IrssiPushover: Set user token to send notifications: /set irssipushover_user_token [token]");
		return;
	}

	my $api_token = Irssi::settings_get_str('irssipushover_api_token');
	my $user_token = Irssi::settings_get_str('irssipushover_user_token');
	my $header = $lastTarget eq "!PRIVATE" ? "$lastNick: " : "$lastTarget $lastNick: ";
	my $len = 512 - length($header);
	my @msg = unpack("(A$len)*", $lastMsg);
	foreach (@msg) {
		my $result = LWP::UserAgent->new()->post(
			"https://api.pushover.net/1/messages.json", [
			"token" => $api_token,
			"user" => $user_token,
			"message" => $header . $_, 
		]);
		if (!$result->is_success) {
			my $status = $result->status_line;
			Irssi::print("IrssiPushover: Failed to send notification: $status.");
		}
	}
}

Irssi::settings_add_str('IrssiPushover', 'irssipushover_api_token', '');
Irssi::settings_add_str('IrssiPushover', 'irssipushover_user_token', '');
Irssi::settings_add_bool('IrssiPushover', 'irssipushover_away_only', false);

Irssi::signal_add('message irc action', 'public');
Irssi::signal_add('message public', 'public');
Irssi::signal_add('message private', 'private');
Irssi::signal_add('print text', 'print_text');
