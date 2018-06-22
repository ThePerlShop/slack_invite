requires 'DateTime';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'Path::Tiny';
requires 'Plack::Handler::CGI';
requires 'Readonly';
requires 'Template::Mustache';

on 'test' => sub {
    requires 'Carp::Always';
    requires 'HTTP::Request::Common';
    requires 'Plack::Test';
    requires 'Readonly';
    requires 'Test::Class';
    requires 'Test::Deep::JSON';
    requires 'Test::LWP::UserAgent';
    requires 'Test::MockObject::Extends';
    requires 'Test::Most';
};

