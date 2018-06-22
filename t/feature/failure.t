#!/usr/bin/env perl
use 5.018;
use strict;
use warnings;

t::feature::failure->runtests;


BEGIN {
package t::feature::failure;
use 5.018;
use strict;
use warnings;

use parent 't::feature::Test::Class';

use Test::Most;
# use Carp::Always;
use Data::Dumper;

use HTML::Entities qw(encode_entities);
use Path::Tiny ();
use Plack::Test ();
use HTTP::Request::Common qw(POST);
use Readonly;
use Test::Deep::JSON;

=head1 NAME

t::feature::failure - Test the slack_invite error paths.

=head1 SYNOPSIS

    # run all tests
    prove -lv t/feature/failure.t

    # run single test method
    TEST_METHOD=test_METHOD_NAME prove -lv t/feature/failure.t

=cut


## Private methods

# Set up the simulated Slack API call to produce the given given response.
sub _map_ua_response {
    my $test = shift;
    my ($content) = @_;

    my $ua_response = HTTP::Response->new(200);
    $ua_response->content($content);
    $test->{ua}->map_response(
        sub {
            my $request = shift;
            if (
                $request->method eq 'POST'
                && $request->uri eq 'https://slack.com/api/users.admin.invite'
            ) {
                return 1;
            }
            return undef;
        } => $ua_response,
    );
}

# Set up the fixture for a failure test. Takes the Slack API response
# content as an argument, and returns ($log_file, \%form_data, $client).
sub _setup_fixture {
    my $test = shift;
    my ($ua_response) = @_;

    my $log_file = Path::Tiny->tempfile;

    Readonly::Hash my %config => (
        log_file => "$log_file",
        error_html => 'ERROR! {{first_name}} {{last_name}} {{email}} {{error}}',
    );
    $test->{config} = \%config;

    $test->_map_ua_response($ua_response);

    Readonly::Hash my %form_data => (
        email => 'user@company.com',
        first_name => 'Joe',
        last_name => 'User',
    );

    my $client = Plack::Test->create( $test->{app} );

    return ($log_file, \%form_data, $client);
}

## Tests

=head1 TESTS

=head2 test_basic_invite

Submits a basic request for an invitation that fails, and verifies that
the script returns the expected output to the client and logs the error.

=cut

sub test_basic_invite : Test(2) {
    my $test = shift;

    my ($log_file, $form_data, $client) = $test->_setup_fixture(
        '{"ok": false, "error": "something_bad"}',
    );

    # Run the code under test.
    my $response = $client->request(
        POST('http://mysite.company.com/invite', $form_data),
    );

    cmp_deeply(
        $response,
        methods(
            code => 200,
            [ header => 'Content-Type' ] => 'text/html',
            content => 'ERROR! Joe User user@company.com something_bad',
        ),
        'response as expected'
    ) or note(Data::Dumper->Dump([$response], ['response']));

    my $log_data = $log_file->slurp();
    my $timestamp = re(qr{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}});
    cmp_deeply(
        [ map { [ split("\t", $_, 4) ] } split("\n", $log_file->slurp()) ],
        [
            [ $timestamp, 200, "something_bad", json($form_data) ],
        ],
        'invitation logged',
    ) or note(Data::Dumper->Dump([$log_data], ['log_data']));
}


=head2 test_bad_json

Submits a request for an invitation that fails because the simulated
Slack API returns malformed JSON, and verifies that the script returns
the expected output to the client and logs the error.

=cut

sub test_bad_json : Test(2) {
    my $test = shift;

    my ($log_file, $form_data, $client) = $test->_setup_fixture(
        'NOT JSON',
    );

    # Run the code under test.
    my $response = $client->request(
        POST('http://mysite.company.com/invite', $form_data),
    );

    my $expected_error = 'malformed JSON string, neither array, object,'
      . ' number, string or atom, at character offset 0 (before "NOT JSON").';

    cmp_deeply(
        $response,
        methods(
            code => 500,
            [ header => 'Content-Type' ] => 'text/html',
            content => 'ERROR! Joe User user@company.com ' . encode_entities($expected_error),
        ),
        'response as expected'
    ) or note(Data::Dumper->Dump([$response], ['response']));

    my $log_data = $log_file->slurp();
    my $timestamp = re(qr{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}});
    cmp_deeply(
        [ map { [ split("\t", $_, 4) ] } split("\n", $log_file->slurp()) ],
        [
            [ $timestamp, 500, $expected_error, json($form_data) ],
        ],
        'invitation logged',
    ) or note(Data::Dumper->Dump([$log_data], ['log_data']));
}


=head2 test_not_a_json_object

Submits a request for an invitation that fails because the simulated
Slack API returns JSON that does not represent a JSON object (i.e., a
hash), and verifies that the script returns the expected output to the
client and logs the error.

=cut

sub test_not_a_json_object : Test(2) {
    my $test = shift;

    my ($log_file, $form_data, $client) = $test->_setup_fixture(
        '[10]',
    );

    # Run the code under test.
    my $response = $client->request(
        POST('http://mysite.company.com/invite', $form_data),
    );

    my $expected_error = 'API call did not return a JSON object.';

    cmp_deeply(
        $response,
        methods(
            code => 500,
            [ header => 'Content-Type' ] => 'text/html',
            content => 'ERROR! Joe User user@company.com ' . encode_entities($expected_error),
        ),
        'response as expected'
    ) or note(Data::Dumper->Dump([$response], ['response']));

    my $log_data = $log_file->slurp();
    my $timestamp = re(qr{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}});
    cmp_deeply(
        [ map { [ split("\t", $_, 4) ] } split("\n", $log_file->slurp()) ],
        [
            [ $timestamp, 500, $expected_error, json($form_data) ],
        ],
        'invitation logged',
    ) or note(Data::Dumper->Dump([$log_data], ['log_data']));
}


1;

} # BEGIN