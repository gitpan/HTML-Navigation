#!/usr/bin/perl -w
#
# Example CGI which generates a two-level menu.
#
# $Id: two-level.cgi,v 1.2 2000/10/16 17:47:30 adam Exp $

use strict;

use HTML::Navigation;
use CGI;

my $nav = new HTML::Navigation(base_url => 'two-level.cgi');
my $structure =
  [
   __param__ => 'first',
   __callbacks__ => [
                     # level 0
                     {
                      pre_items  => sub { "<ol>\n"  },
                      post_items => sub { "</ol>\n" },
                      pre_item   => sub { "<li> "   },
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
                     },

                     # level 1
                     {
                      pre_items  => sub { "<ul>\n"  },
                      post_items => sub { "</ul>\n" },
                      pre_item   => sub { "<li> "   },
                     },
                    ],
   'item 1' => [
                __param__ => 'submenu_1',
                'one',
                'two',
                'three',
               ],
   'item 2',
   'item 3' => [
                __param__ => 'submenu_2',
                __default__ => 'five',
                __callbacks__ => [{
                                   pre_item  => sub { "<li> <b>" },
                                   post_item => sub { " </b>\n"  },
                                  }],
                'four',
                'five',
                'six',
                'seven',
               ],
  ];
$nav->structure($structure);

my $q = new CGI;
print $q->header();

my @params = $q->param();
my %params = map { $_ => $q->param($_) } @params;

print $q->start_html(-title => 'two-level menu example'),
      $nav->output(\%params),
      $q->end_html();

