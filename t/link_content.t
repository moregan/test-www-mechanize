#!perl

use strict;
use warnings;
use Test::More tests => 12;
use Test::Builder::Tester;
use URI::file;

use constant PORT => 13432;

delete $ENV{http_proxy}; # All our tests are running on localhost

BEGIN {
    use_ok( 'Test::WWW::Mechanize' );
}

my $server = TWMServer->new(PORT);
my $pid = $server->background;
ok( $pid, 'HTTP Server started' ) or die "Can't start the server";
# HTTP::Server::Simple->background() may return prematurely.
sleep 1;

sub cleanup { kill(9,$pid) if !$^S };
$SIG{__DIE__}=\&cleanup;

my $mech=Test::WWW::Mechanize->new();
isa_ok($mech,'Test::WWW::Mechanize');

$mech->get('http://localhost:'.PORT.'/goodlinks.html');
my @urls=$mech->links();
ok(@urls, 'Got links from the HTTP server');

# test regex
test_out('not ok 1 - link_content_like');
test_fail(+2);
test_diag(q{     "blah" doesn't look much like a regex to me.});
$mech->link_content_like(\@urls,'blah','Testing the regex');
test_test('Handles bad regexs');

# like
test_out('ok 1 - Checking all page links contain: Test');
$mech->link_content_like(\@urls,qr/Test/,'Checking all page links contain: Test');
test_test('Handles All page links contents successful');

# like - default desc
test_out('ok 1 - ' . scalar(@urls) . ' links are like \'(?-xism:Test)\'');
$mech->link_content_like(\@urls,qr/Test/);
test_test('Handles All page links contents successful - default desc');

test_out('not ok 1 - Checking all page link content failures');
test_fail(+4);
test_diag('goodlinks.html');
test_diag('badlinks.html');
test_diag('goodlinks.html');
$mech->link_content_like(\@urls,qr/BadTest/,'Checking all page link content failures');
test_test('Handles link content not found');

# unlike
# test regex
test_out('not ok 1 - link_content_unlike');
test_fail(+2);
test_diag(q{     "blah" doesn't look much like a regex to me.});
$mech->link_content_unlike(\@urls,'blah','Testing the regex');
test_test('Handles bad regexs');

test_out('ok 1 - Checking all page links do not contain: BadTest');
$mech->link_content_unlike(\@urls,qr/BadTest/,'Checking all page links do not contain: BadTest');
test_test('Handles All page links unlike contents successful');

# unlike - default desc
test_out('ok 1 - ' . scalar(@urls) . ' links are not like "(?-xism:BadTest)"');
$mech->link_content_unlike(\@urls,qr/BadTest/);
test_test('Handles All page links unlike contents successful - default desc');

test_out('not ok 1 - Checking all page link unlike content failures');
test_fail(+4);
test_diag('goodlinks.html');
test_diag('badlinks.html');
test_diag('goodlinks.html');
$mech->link_content_unlike(\@urls,qr/Test/,'Checking all page link unlike content failures');
test_test('Handles link unlike content found');


cleanup();


package TWMServer;
use base 'HTTP::Server::Simple::CGI';

sub handle_request {
    my $self=shift;
    my $cgi=shift;

    my $file=(split('/',$cgi->path_info))[-1]||'index.html';
    $file=~s/\s+//g;

    if(-r "t/html/$file") {
        if(my $response=do { local (@ARGV, $/) = "t/html/$file"; <> }) {
            print "HTTP/1.0 200 OK\r\n";
            print "Content-Type: text/html\r\nContent-Length: ",
                    length($response), "\r\n\r\n", $response;
            return;
        }
    }

    print "HTTP/1.0 404 Not Found\r\n\r\n";
}
