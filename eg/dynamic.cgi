#!/usr/bin/perl -w
#
# Example CGI which generates a basic three-item, single-level menu.
#
# $Id: dynamic.cgi,v 1.3 2000/10/16 17:47:30 adam Exp $

use strict;

use HTML::Navigation;
use CGI;

sub dynamic_items { [ 'item 2', 'item 3' ] }

my $nav = new HTML::Navigation(base_url => 'dynamic.cgi');
my $structure =
  [
   __param__ => 'param',
   __callbacks__ => [{
                      pre_items  => sub { "<ol>\n"  },
                      post_items => sub { "</ol>\n" },
                      pre_item   => sub { "  <li> " },
                      post_item  => sub { "\n"      },
                      unselected => sub {
                        my ($nav, %p) = @_;
                        return $nav->ahref(text => $p{item},
                                           params => [ $nav->params(%p) ]);
                      },
                      selected => sub {
                        my ($nav, %p) = @_;
                        return $p{item};
                      },
                     }],
   'item 1',
   \&dynamic_items,
  ];
$nav->structure($structure);

my $q = new CGI;
print $q->header();

my @params = $q->param();
my %params = map { $_ => $q->param($_) } @params;

print $q->start_html(-title => 'dynamic single-level menu example'),
      $nav->output(\%params),
      $q->end_html();

