package SlackInvite::App;
use 5.018;
use strict;
use warnings;

use DateTime;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use Path::Tiny qw(path);
use Plack::Request;
use Template::Mustache;


=head1 NAME

SlackInvite::App - The slack_invite PSGI application.

=head1 SYNOPSIS

    use SlackInvite::App;

    my $app = sub { SlackInvite::App->run_psgi(@_) };

=head1 DESCRIPTION

This PSGI application is designed to be run as a CGI or FCGI script at a
single URL. It accepts a user's information as request parameters and
contacts the Slack API to have the user sent an invitation to a
preconfigured workspace. It then displays a success or error page to the
user, and it appends a line to a TSV log file recording the interaction.


=head1 REQUEST PARAMETERS

Provide the following parameters either in the query string of a GET
request or the form of a POST request:

=over

=item email

The email address of the user.

=item first_name

The first name of the user.

=item last_name

The last name of the user

=back


=head1 CONFIGURATION

This module fetches configuration via L<SlackInvite::Config>, relying on
the following parameters:

=over

=item slack_api_token

The Slack legacy token from which the invitation should be sent,
generated via
L<https://api.slack.com/custom-integrations/legacy-tokens>.

=item slack_channels

A comma-separated list of channels to which to invite the user.

=item log_file

The path to the slack_invite.log file. (See L<LOG FILE> below.)

=item success_html

A Mustache template used to generate HTML for the page displayed to the
user after the invitation request has been successfully processed. (See
L<HTML TEMPLATES> below.)

=item error_html

A Mustache template used to generate HTML for the page displayed when an
error occurs. (See L<HTML TEMPLATES> below.)

=back


=head1 LOG FILE

The app logs all requests to a file at a preconfigured file path. (See
L<CONFIGURATION> above.)

The log itself is a tab-separated sequence of fields, in the following
order:

=over

=item The UTC date and time of the request, in ISO 8601
yyyy-mm-ddThh:mm:ss format.

=item The HTTP response code returned to the user.

=item The error returned by the Slack API, or "ok" if there was no
error.

=item The request parameters, serialized as a JSON object.

=back


=head1 HTML TEMPLATES

This app uses L<Template::Mustache> to generate HTML for the success and
error pages. (See L<CONFIGURATION> above.)

The template data includes the following keys:

=over

=item email

The email address of the user.

=item first_name

The first name of the user.

=item last_name

The last name of the user

=item error

(Only in error_html.) The name of the error that occurred or a message
identifying the error that occurred.

=back

Additionally, all other request parameters are available to the
template.

=cut


my $slack_api_url = 'https://slack.com/api/users.admin.invite';


# Override in derived class to return user agent for testing.
sub _new_user_agent {
    my $class = shift;
    return LWP::UserAgent->new(@_);
}

# Override in derived class to return configuration for testing.
sub _config {
    require SlackInvite::Config;
    return SlackInvite::Config->config;
}


sub _log {
    my $class = shift;
    my ($code, $error, $params) = @_;

    my $timestamp = DateTime->now;

    my $params_json = encode_json($params);

    my $config = $class->_config;

    path($config->{log_file})->append_utf8("$timestamp\t$code\t$error\t$params_json\n");
}

sub _success {
    my $class = shift;
    my ($params) = @_;

    my $config = $class->_config;

    $class->_log(200, 'ok', $params);

    my $html = Template::Mustache->render(
        $config->{success_html},
        $params,
    );

    return [
        200,
        [ 'Content-Type' => 'text/html' ],
        [ $html ],
    ];
}

sub _error {
    my $class = shift;
    my ($params, $error, $code) = @_;

    my $config = $class->_config;

    $code //= 200;

    $class->_log($code, $error, $params);

    my $html = Template::Mustache->render(
        $config->{error_html},
        { %$params, error => $error },
    );

    return [
        $code,
        [ 'Content-Type' => 'text/html' ],
        [$html],
    ];
}


sub run_psgi {
    my $class = shift;
    my ($env) = @_;

    my $req = Plack::Request->new($env);
    my %params = %{ $req->parameters };

    my $ua = $class->_new_user_agent();
    my $config = $class->_config;

    my $api_res = $ua->post( $slack_api_url => {
        token => $config->{slack_api_token},
        channels => $config->{slack_channels},

        email => $params{email},
        first_name => $params{first_name},
        last_name => $params{last_name},

        resend => 'true',
    } );

    my $api_res_json = $api_res->content;
    my $api_res_data = eval {
        my $decoded = decode_json($api_res_json);
        die "API call did not return a JSON object" unless ref $decoded eq 'HASH';
        $decoded;
    };
    if ($@) {
        my ($error) = split("\n", $@);
        $error =~ s/ at \S+ line \d+//;
        return $class->_error(\%params, $error, 500);
    }

    return $class->_error(\%params, $api_res_data->{error})
        if not $api_res_data->{ok};

    return $class->_success(\%params);
};
