#!/usr/bin/perl -w
#
# Example CGI which generates a basic three-item, single-level menu.
#
# $Id: simple.cgi,v 1.2 2000/10/16 17:47:30 adam Exp $

use strict;

use HTML::Navigation;
use CGI;

my $nav = new HTML::Navigation(base_url => 'simple.cgi');
my $structure =
  [
   # uncomment to make `item 1' the default selected item
   # __default__ => ''

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

                      # uncomment this one to omit the second item
                      # omit => sub {
                      #   my ($nav, %p) = @_;
                      #   return $p{item} eq 'item 2';
                      # },
                     }],
   'item 1',
   'item 2',
   'item 3',
  ];
$nav->structure($structure);

my $q = new CGI;
print $q->header();

my @params = $q->param();
my %params = map { $_ => $q->param($_) } @params;

print $q->start_html(-title => 'single-level menu example'),
      $nav->output(\%params),
      $q->end_html();

