#!/usr/bin/env perl
use 5.018;
use strict;
use warnings;

#use lib 'local/path/to/libraries';

use Plack::Handler::CGI;
use SlackInvite::App;

my $app = sub { SlackInvite::App->run_psgi(@_) };

Plack::Handler::CGI->new->run($app);

__END__
