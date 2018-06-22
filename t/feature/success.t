#!/usr/bin/env perl
use 5.018;
use strict;
use warnings;

t::feature::success->runtests;


BEGIN {
package t::feature::success;
use 5.018;
use strict;
use warnings;

use utf8;
use open qw(:std :utf8);

use parent 't::feature::Test::Class';

use Test::Most;
use Carp::Always;
use Data::Dumper;

use Test::Deep::JSON;
use Path::Tiny ();
use Plack::Test ();
use HTTP::Request::Common qw(POST);
use Readonly;
use URI::Escape qw(uri_escape);


=head1 NAME

t::feature::success - Test the slack_invite happy path.

=head1 SYNOPSIS

    # run all tests
    prove -lv t/feature/success.t

    # run single test method
    TEST_METHOD=test_METHOD_NAME prove -lv t/feature/success.t

=cut


## Tests

=head1 TESTS

=head2 test_basic_invite

Submits a basic request for an invitation that succeeds, and verifies
that all parameters are passed correctly and that the script returns the
expected output to the client and logs the operation.

=cut

sub test_basic_invite : Test(6) {
    my $test = shift;

    my $log_file = Path::Tiny->tempfile;

    Readonly::Hash my %config => (
        slack_api_token => 'API-TOKEN',
        slack_channels => 'FOO,BAR,BAZ',
        log_file => "$log_file",
        success_html => 'SUCCESS! {{first_name}} {{last_name}} {{email}}',
    );
    $test->{config} = \%config;

    my $received_request = undef;

    my $ua_response = HTTP::Response->new(200);
    $ua_response->content('{"ok": true}');
    $test->{ua}->map_response(
        sub {
            my $request = shift;
            if (
                $request->method eq 'POST'
                && $request->uri eq 'https://slack.com/api/users.admin.invite'
            ) {
                $received_request = $request;
                return 1;
            }
            return undef;
        } => $ua_response,
    );

    # In the following form data, we include some HTML special
    # characters (like < and >) to make sure they're properly escaped at
    # the appropriate times. We also include non-ASCII character to make
    # sure UTF-8 is passed through cleanly.
    Readonly::Hash my %form_data => (
        email => 'user@company.com',
        first_name => 'Joë', # Check for UTF-8 cleanliness.
        last_name => '<User>', # Check HTML escaping.
    );

    my $client = Plack::Test->create( $test->{app} );


    # We have to manually encode the form data and construct the
    # request, because URI::query_form() (used by POST() to
    # automatically encode the form) doesn't handle UTF-8 correctly.
    my $req = POST('http://mysite.company.com/invite');
    $req->content_type('application/x-www-form-urlencoded');
    my $form_encoded = join '&',
        map { uri_escape($_) . '=' . uri_escape($form_data{$_}) } keys %form_data;
    $req->content($form_encoded);
    $req->content_length(length($form_encoded));


    # Run the code under test.
    my $response = $client->request($req);


    cmp_deeply(
        $test->{ua_new_options},
        [{
            # Called new with no options requested.
        }],
        'called new as expected',
    );

    SKIP: {
        ok($received_request, 'received request')
            or skip "no received request", 2;

        cmp_deeply(
            $received_request,
            methods(
                method => 'POST',
                uri => str('https://slack.com/api/users.admin.invite'),
                [ header => 'Content-Type' ] => 'application/x-www-form-urlencoded',
            ),
            'received request as expected',
        );

        my %received_form = map { split('=', $_, 2) } split('&', $received_request->content);
        cmp_deeply(
            \%received_form,
            {
                token => uri_escape( $config{slack_api_token} ),
                channels => uri_escape( $config{slack_channels} ),

                email => uri_escape( $form_data{email} ),
                first_name => uri_escape( $form_data{first_name} ),
                last_name => uri_escape( $form_data{last_name} ),

                resend => 'true',
            },
            'received form data as expected',
        );
    }

    cmp_deeply(
        $response,
        methods(
            code => 200,
            [ header => 'Content-Type' ] => 'text/html',
            content => 'SUCCESS! Joë &lt;User&gt; user@company.com',
        ),
        'response as expected'
    ) or note(Data::Dumper->Dump([$response], ['response']));

    my $log_data = $log_file->slurp_utf8();
    my $timestamp = re(qr{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}});
    cmp_deeply(
        [ map { [ split("\t", $_, 4) ] } split("\n", $log_data) ],
        [
            [ $timestamp, 200, "ok", json(\%form_data) ],
        ],
        'invitation logged',
    ) or note(Data::Dumper->Dump([$log_data], ['log_data']));
}


1;

} # BEGIN