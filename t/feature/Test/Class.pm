package t::feature::Test::Class;
use strict;
use warnings;

use parent 'Test::Class';

use Test::LWP::UserAgent;
use Test::MockObject::Extends;


=head1 NAME

t::feature::Test::Class - Superclass for slack_invite app tests.

=head1 SYNOPSIS

    use parent 't::feature::Test::Class';

    use Plack::Test ();
    use HTTP::Request::Common qw(POST);

    sub test_something : Tests() {
        my $test = shift;

        $test->{ua}->map_response(
            sub {
                my $request = shift;
                return 1 if $request->method eq 'POST'
                    && $request->uri eq 'https://slack.com/api/users.admin.invite';
                return undef;
            } => HTTP::Response->new(200, '{"ok": true}'),
        );

        $test->{config} = {
            slack_api_token => 'xxxx-xxxxxxxxx-xxxx',
            slack_channels => 'FOO,BAR,BAZ',
            # etc.
        };

        my $client = Plack::Test->create( $test->{app} );

        my $response = $client->request(
            POST 'https://slack.com/api/users.admin.invite',
            \%form_data,
        );

        is($response->code, 200);
        # etc.

        cmp_deeply(
            $test->{ua_new_options},
            [{
                # expected options passed to new()
            }],
        );
    }

=cut


=head1 FIXTURES

=head2 $test->{app}

The Plack app sub for testing.

This sub invokes C<< SlackInvite::App->run_psgi(@_) >> and can be called
directly by C<Plack::Test>. It's augmented not to actually make network
calls but instead to use an instance of C<Test::LWP::UserAgent>, stored
in L<< $test->{ua} >> below.

It also uses the configuration contained in the hashref in
C<< $test->{config} >> rather than looking for an external configuration
file. Place configured options in this hashref before calling the code
under test.

=head2 $test->{ua}

An instance of C<Test::LWP::UserAgent> that all outgoing calls are made
through for testing.

In the test code, call the C<map_response()> method to stub code for
specific URLs. See L<Test::LWP::UserAgent>.

Requests by the code under test to instantiate a user agent merely
return this object, but the requested options are appended as a hashref
to C<< @{ $test->{ua_new_options} } >>. This field can be checked after
running the code under test in order to verify that calls to C<new()>
were as expected.

=cut

sub _setup_app : Test(setup) {
    my $test = shift;

    $test->{config} = {};
    $test->{ua_new_options} = [];

    my $ua = $test->{ua} = Test::LWP::UserAgent->new();

    my $app_obj = Test::MockObject::Extends->new('SlackInvite::App');
    $app_obj->mock(_new_user_agent => sub {
        my $class = shift;
        push @{ $test->{ua_new_options} }, { @_ };
        return $ua;
    });
    $app_obj->mock(_config => sub {
        return $test->{config};
    });

    $test->{app} = sub { $app_obj->run_psgi(@_) };
}


sub _teardown_app : Test(teardown) {
    my $test = shift;
    delete $test->{app};
    delete $test->{ua};
    delete $test->{ua_new_options};
    delete $test->{config};
}


1;
