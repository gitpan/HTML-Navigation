#!/usr/bin/perl -w
#
# test CGI for easily messing around with the test multi-level
# navigation structure.  This test CGI isn't actually used by
# anything.
#
# $Id: test.cgi,v 1.2 2000/10/13 21:14:02 adam Exp $

use strict;

use MyTest qw(callbacks callback html_page multi_level);
use HTML::Navigation;
use CGI;

warn "HTML::Navigation version $HTML::Navigation::VERSION\n";

my $nav = new HTML::Navigation();
my $struct = multi_level();

$nav->structure($struct);

my $q = new CGI;
print $q->header();

$nav->base_url('test.cgi');
$nav->debug_level(5);

my @params = $q->param();
my %params = map { $_ => $q->param($_) } @params;

print html_page('multi-level navigation test', $nav->output(\%params));

