#!/usr/bin/perl -w

use strict;
use Test;

use lib './t';
use MyCompare qw(equal_arrays);
use MyTest qw(log_test callbacks callback html_page cat uc_href
              multi_level multi_page multi_filename);

# First check that the module loads OK.
use vars qw($loaded);
BEGIN {
  $| = 1;
  plan tests => 55;
  print "! Testing module load ...\n";
}
use HTML::Navigation;
END {
  print "not ok 1\n" unless $loaded;
}
ok(++$loaded);

# We test the following navigation structures:

my @structures =
  (
   # basic single-level
   # ------------------
   [
    __callbacks__ => [ callbacks() ],
    __param__ => 'first',
    'item 1',
    'item 2',
    'item 3',
   ],
                  
   # basic single-level, `dynamically' generated
   # -------------------------------------------
   [
    __callbacks__ => [ callbacks() ],
    __param__ => 'first',
    'item 0',
    sub {
      [
       'item 1',
       'item 2',
      ]
    },
    'item 3',
   ],
   
   # empty
   # -----
   [ ],
   
   # invalid (missing __param__)
   # ---------------------------
   [
    'foo',
   ],
   
   # invalid (__callbacks__ arrayref must contain hashrefs)
   # ------------------------------------------------------
   [
    __callbacks__ => [ 'I am not a hashref' ],
    'foo',
   ],
   
   # horribly complex, multi-level
   # -----------------------------
   multi_level(),
  );


log_test "Testing new() constructor ...\n";

my @navs = (new HTML::Navigation());

log_test "  with no params\n";
ok($navs[0]);

log_test "  with 'base_url' => 'foo.cgi' ...\n";
$navs[0] = new HTML::Navigation(base_url => 'foo.cgi');
ok($navs[0]);

$navs[$_] = new HTML::Navigation(structure => $structures[$_]) for 1 .. 5;

log_test "  with 'structure' param\n";
ok($navs[1]);

log_test "  with 'structure' => []\n";
ok($navs[2]);

log_test "  with 'structure' missing __param__\n";
ok($navs[3]);

log_test "  with 'structure' containing invalid __callbacks__\n";
ok($navs[4]);

log_test "  with 'structure' => complex multi-level\n";
ok($navs[5]);

#-----------------------------------------------------------------------------
log_test "Testing base_url() method ...\n";

ok($navs[0]->base_url(), 'foo.cgi');
ok(! $navs[1]->base_url());
ok($navs[0]->base_url('bar.cgi'), 'bar.cgi');
$navs[0]->base_url('');

#-----------------------------------------------------------------------------
log_test "Testing structure() method ...\n";

ok(! defined $navs[0]->structure());
ok($structures[0], $navs[0]->structure($structures[0]));
ok(equal_arrays($structures[$_], $navs[$_]->structure())) for 0 .. 1;

#-----------------------------------------------------------------------------
log_test "Testing output() on single-level navigation ...\n";

my $none_selected_items = <<EOF;
  <li> <!-- pre_item: item 1 --> {
  <A HREF="?first=item%201">item 1</A>
  <!-- post_item: item 1 --> }

  <!-- item_glue: item 1 --> 0+

  <li> <!-- pre_item: item 2 --> {
  <A HREF="?first=item%202">item 2</A>
  <!-- post_item: item 2 --> }

  <!-- item_glue: item 2 --> 0+

  <li> <!-- pre_item: item 3 --> {
  <A HREF="?first=item%203">item 3</A>
  <!-- post_item: item 3 --> }
EOF

chomp $none_selected_items;

my @none_selected = (<<EOF, <<EOF);
<ol start="0" type="1"> <!-- pre_items: item 1 -->
$none_selected_items
</ol> <!-- post_items: item 3 -->
EOF
<ol start="0" type="1"> <!-- pre_items: item 0 -->
  <li> <!-- pre_item: item 0 --> {
  <A HREF="?first=item%200">item 0</A>
  <!-- post_item: item 0 --> }

  <!-- item_glue: item 0 --> 0+

$none_selected_items
</ol> <!-- post_items: item 3 -->
EOF

my @items = ('item 1', 'item 2', 'item 3');

#$navs[0]->debug_level(6);
test_single_level($navs[$_], $none_selected[$_], @items) for 0 .. 1;

#-----------------------------------------------------------------------------
log_test "Testing output() on empty navigation ...\n";

ok($navs[2]->output({}), '');

#-----------------------------------------------------------------------------
log_test "Testing output() on structure missing __param__ ...\n";

eval {
  my $output = $navs[3]->output({});
};
ok($@ || '', '/^navigation structure was missing __param__ in top menu/');

#-----------------------------------------------------------------------------
log_test "Testing output() on structure with bad __callbacks__ ...\n";

eval {
  my $output = $navs[4]->output({});
};
ok($@ || '',
   "/^parse error: the `top' menu contains items in the " .
   "__callbacks__ arrayref which aren't hashrefs/");

#-----------------------------------------------------------------------------
log_test "Testing on multi-level navigation ...\n";

my $multi = $navs[5];
my @param_sets = $multi->dump_all_params();
ok(@param_sets, 27);
foreach my $param_set ([], @param_sets) {
  my $query_string = $multi->query_string($param_set) || 'none';
  my $filename = multi_filename($query_string);

  ok(multi_page(uc_href($multi->output({ @$param_set }))), cat("t/$filename"));
}

exit 0;

#=============================================================================

sub test_single_level {
  my ($nav, $none, @items) = @_;

  my %sel = ();

  log_test "  with none selected\n";
  ok(uc_href($nav->output({})), $none);
   
  foreach my $item (@items) {
    log_test "  with `$item' selected\n";
    (my $enc_item = $item) =~ s/ /%20/g;
    ($sel{$item} = $none)
      =~ s!<A\ HREF="\?first=\Q$enc_item\E">\Q$item\E</A>
          !<span class="selected">$item</span>!mx;
    ok(uc_href($nav->output({ first => $item })), $sel{$item});
  }
}
