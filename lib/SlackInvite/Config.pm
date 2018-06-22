package SlackInvite::Config;
use 5.018;
use strict;
use warnings;

use Readonly;

Readonly::Hash my %config => (

    # A legacy token: https://api.slack.com/custom-integrations/legacy-tokens
    slack_api_token => 'xxxx-xxxxxxxxx-xxxx',

    # Which channels you'd like to send an invitation to, comma-separated.
    slack_channels => '',

    # The path to the log file in which interactions will be recorded.
    log_file => '/path/to/slack_invite.log',


    success_html => <<'SUCCESS_HTML',
<html>
<head>
    <title>You've been invited!</title>
</head>
<body>
    <p>An invitation has been sent to {{email}}.</p>

    <p>It should be in your inbox any time now!</p>

</body>
</html>
SUCCESS_HTML


    error_html => <<'ERROR_HTML',
<html>
<head>
    <title>Error</title>
</head>
<body>
    <p>We had a problem sending out your invitation because of the
    following error: {{error}}.</p>
</body>
</html>
ERROR_HTML

);


sub config {
    return \%config;
}


1;
