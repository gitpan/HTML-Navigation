#!/usr/bin/perl -w
#
# HTML::Navigation --
# Perl module class encapsulating generic HTML navigation menus
#
# Copyright (c) 2000 Adam Spiers <adam@spiers.net>. All rights
# reserved. This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: Navigation.pm,v 1.16 2000/10/24 16:00:32 adam Exp $
#

package HTML::Navigation;

use vars qw($VERSION);
$VERSION = '0.26';

require 5.004;

=head1 NAME

HTML::Navigation - generic HTML navigation structure class

=head1 SYNOPSIS

  my $nav = new HTML::Navigation();

  # a simple, one-level menu
  $nav->structure([
                   __callbacks__ => [ $callbacks ],
                   __param__ => 'param1',
                   'foo',
                   'bar',
                  ]);

  # output a two-item navigation menu with the `bar' item selected
  print $nav->output({ param1 => 'bar' });

=head1 DESCRIPTION

HTML::Navigation makes it easy to generate an HTML navigation
structure without forcing you into any particular layout or design.
All the output is done by your own subroutines, which the module
invokes as callbacks (code refs).

You supply the navigation structure and callbacks for generating
different bits of the output, and the module takes care of the rest.
You may wonder what "the rest" refers to; what else there is to do
except generate output?  Well, HTML::Navigation really comes into its
own with nested (multi-level) navigation structures, including
dynamically generated ones.  The structures are ordered directed
acyclic graphs where each node is a menu item which can optionally
have subnodes.

See L<"EXAMPLES"> for the quickest way to learn how the module works.

Please note that parsing of the structure is currently performed when
output() is called rather than when new() is called.  This avoids
unnecessary calls to potentially expensive callbacks which may be
given to dynamically generate parts of the navigation structure.

=cut

use strict;

use Carp qw(:DEFAULT cluck);
use CGI qw(a);
use Data::Dumper;
use URI::Escape qw(uri_escape);

use vars qw(@ISA);
@ISA = qw(Exporter);

use Exporter;
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(navigation);

=head1 METHODS

=head2 new()

  my $nav = new HTML::Navigation(structure => $structure);

or

  my $nav = new HTML::Navigation();
  $nav->structure($structure);

The two forms are identical in results.  Likewise you can specify a
C<base_url> parameter instead of setting a base url via the
C<base_url()> method.

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  
  my $class = ref $pkg || $pkg;
  my $self = {};
  bless $self, $class;

  $self->structure($p{structure}) if $p{structure};
  $self->base_url($p{base_url})   if $p{base_url};

  return $self;
}

=head2 structure()

  my $structure = $nav->structure();

  $nav->structure($new_structure);

Reads/writes the navigation data structure.  See L<"EXAMPLES"> for an
extensive tutorial on how to form these data structures.

=cut

sub structure {
  my $self = shift;

  if (@_) {
    $self->{_structure} = $_[0];
  }

  return $self->{_structure};
}


=head2 output()

  my %CGI_params = map { $_ => $req->param($_) } qw/param1 param2/;
  my $out = $nav->output(\%CGI_params);

Returns the HTML for a navigation menu, as defined by the
C<_navigation> key in the frontend object.

=cut

sub output {
  my ($self, $ARGS) = @_;

  my $out = $self->recurse(
                           mode      => 'output',
                           parent    => 'top',
                           structure => $self->structure(),
                           callbacks => [],
                           ARGS      => $ARGS,
                           params    => [],
                           tree      => {},
                           level     => 0
                          );

  return $out;
}

=head2 dump_all_params()

Returns an array containing all the combinations of CGI parameters
required to select every element in the navigation structure.  Each
combination is in standard CGI QUERY_STRING format, i.e.

  param1=foo;param2=bar;param3=...

=cut

sub dump_all_params {
  my $self = shift;

  my $dump = sub {
    my ($nav, %p) = @_;
    my @params = $nav->params(%p);
    return $nav->query_string(\@params) . "\n";
  };

  my $out = $self->recurse(
                           mode      => 'params',
                           parent    => 'top',
                           structure => $self->structure(),
                           callbacks => [{
                                          selected   => $dump,
                                          unselected => $dump,
                                         }],
                           ARGS      => {},
                           params    => [],
                           tree      => {},
                           level     => 0,
                           ignore_defaults => 1,
                          );

  # Eww!  Gak!  But it works.
  my @param_sets = grep $_, split(/[\n\r]+/, $out);
  my @all_params = ();
  foreach my $param_set (@param_sets) {
    my @params = ();
    my @key_val_pairs = split /;/, $param_set;

    foreach my $key_val (@key_val_pairs) {
      my ($k, $v) = split /=/, $key_val;
      push @params, $k => $v;
    }

    push @all_params, \@params;
  }

  return @all_params;
}

sub _inherit_callbacks {
  my $self = shift;
  my ($callbacks) = @_;

  my $local_callbacks = [];
  
  if (@$callbacks) {
    for my $level (0 .. $#$callbacks) {
      $local_callbacks->[$level] = { %{ $callbacks->[$level] } };
    }
  }

  return $local_callbacks;
}

sub _override_callbacks {
  my $self = shift;
  my ($p, $local_callbacks, $overrides) = @_;
  
  foreach my $override_level (0 .. $#$overrides) {
    my $override = $overrides->[$override_level];

    if (ref $override ne 'HASH') {
      die "parse error: the `$p->{parent}' menu contains items in the ",
        "__callbacks__ arrayref which aren't hashrefs\n";
    }
        
    while (my ($name, $coderef) = each %$override) {
      $self->_debug(6, $p, "    overriding `$name' callback at level " .
                           "$p->{level} + $override_level");
      $local_callbacks->[$p->{level} + $override_level]{$name} = $coderef;
    }
  }
}

sub _submenu_is_selected {
  my $self = shift;
  my (%p) = @_;

  return 1 if $p{level} == 0;
  
  my $parent_ARG = $p{ARGS}{$p{params}[$p{level} - 1]} || '';
  return $parent_ARG eq $p{parent};
}

sub _fill_in_defaults {
  my $self = shift;
  my ($ARGS, %p) = @_;

  my $ptr  = $p{tree};
  my $item = $p{parent};

  while (exists $ptr->{__default__}) {
    $item = $ARGS->{$ptr->{__param__}} = $ptr->{__default__};
    $ptr = $ptr->{$item};
  }
}

sub recurse {
  my $self = shift;
  my %p = @_;

  # Make a copy so we can change the top-level elements.
  my $structure = [ @{ $p{structure} } ];

  $self->_debug(2, \%p, ">>> level $p{level}");

  my $local_callbacks = $self->_inherit_callbacks($p{callbacks});

  # Make a local copy of an arrayref of CGI parameter names used to
  # reach this depth.
  my $local_params = [ @{ $p{params} } ];

  my ($out, $first_item) = ('', 1);

  while (my $item = shift @$structure) {
    if (ref $item eq 'CODE') {
      $self->_debug(4, \%p, "unpacking CODE");
      unshift @$structure, @{ $item->($self) };
      $item = shift @$structure;
    }

    if ($item eq '__callbacks__') {
      my $overrides = shift @$structure;
      next if $p{mode} eq 'params';
      $self->_debug(5, \%p, "doing __callbacks__");
      next unless @$overrides;
      $self->_override_callbacks(\%p, $local_callbacks, $overrides);
      next;
    }

    if ($item eq '__param__') {
      $p{tree}{__param__} = $local_params->[$p{level}] = shift @$structure;
      $self->_debug(4, \%p, "__param__ is `$p{tree}{__param__}'");
      next;
    }

    die "navigation structure was missing __param__ in $p{parent} menu"
      unless $p{tree}{__param__};

    if ($item eq '__default__') {
      $self->_debug(4, \%p, "doing __default__");
      # this menu has a default item
      my $default_item = shift @$structure;
      $p{tree}{__default__} = $default_item || '';
      $self->_debug(4, \%p, "`$p{parent}' menu defaults " .
                       "$p{tree}{__param__} to " .
                       ($default_item ? "`$default_item'" : 'first item'));
      next;
    }

    last unless $item;

    # At this point we must have a real item.
    $self->_debug(2, \%p, "* item `$item'");
    $p{item} = $item;
    delete $p{submenu};

    # Refresh %p with any changes so that callback code has up-to-date info.
    # Yuck.
    @p{qw/callbacks params/} = ($local_callbacks, $local_params);

    my $omit = $self->_callback('omit', %p);
    
    my ($submenu_out, $item_out);
    
    unless ($omit) {
      # Make unspecified defaults point to the first item in the list.
      $p{tree}{__default__} ||= $item if exists $p{tree}{__default__};
      $p{tree}{$item} = {};

      # At this point if there is a default we know about it for sure.
      # Is an item in this submenu selected?  If not, and this submenu
      # itself is selected, and there is a default, we fake up ARGS to
      # make the default item selected.
      my $default = $p{tree}{__default__};
      my $ARG = $p{ARGS}{$p{tree}{__param__}};
    
      if (! $ARG && $self->_submenu_is_selected(%p) && $default) {
        $self->_fill_in_defaults($p{ARGS}, %p);
      }

      $out .= $self->_callback('pre_items', %p)
        if $first_item && $self->_submenu_is_selected(%p);

      ($p{submenu}, $submenu_out, $item_out) =
        $self->_recurse_item($local_callbacks, $local_params, $structure, %p);
      $out .= $item_out . ($submenu_out || '');
      $first_item = 0;
    }

    if (@$structure) {
      # Add inter-item glue if there are more items and we haven't just
      # done a submenu (a submenu can use its post_items callback if it
      # really wants something outputted after it).  We also avoid the
      # inter-item glue if we've omitted the item (duh).
      if (! $omit && (! $p{submenu} || ! defined $submenu_out)) {
        $out .= $self->_callback('item_glue', %p)
          if $self->_submenu_is_selected(%p);
      }
    }
    else {
      # no more items, invoke post_items callback
      $out .= $self->_callback('post_items', %p)
        if $self->_submenu_is_selected(%p);
    }
  }

  return $out;
}

sub _recurse_item {
  my $self = shift;
  my ($local_callbacks, $local_params, $structure, %p) = @_;

  # If we're in CGI parameter dumping mode, fake it so it looks like
  # we selected the current item, so that the params() method yields
  # the right results.
  $p{ARGS}{$p{tree}{__param__}} = $p{item} if $p{mode} eq 'params';

  my $submenu_out = undef;
  
  if (ref $structure->[0] eq 'ARRAY') {
    # This item contains a submenu.
    $p{submenu} = shift @$structure;

    my %new_p = (
                 mode      => $p{mode},
                 parent    => $p{item},
                 structure => $p{submenu},
                 callbacks => $local_callbacks,
                 ARGS      => $p{ARGS},
                 params    => $local_params,
                 tree      => $p{tree}{$p{item}},
                 level     => $p{level} + 1,
                 ignore_defaults => $p{ignore_defaults},
                );
    
    $submenu_out = $self->recurse(%new_p);

    $self->_debug(2, \%p, "    <<< back to level $p{level}");
  }

  my $item_out = '';
  if ($self->_submenu_is_selected(%p)) {
    $self->_test_item_looks_selected(\%p);
    $item_out = $self->_output_item(%p);
  }

  if (! $self->_ARG_selects_item(\%p)) {
    $submenu_out = undef;
  }

  delete $p{ARGS}{$p{tree}{__param__}} if $p{mode} eq 'params';

  return ($p{submenu}, $submenu_out, $item_out);
}

sub _ARG_selects_item {
  my ($self, $p) = @_;

  # Is the item selected?  This simple test will cover most cases:
  my $ARG = $p->{ARGS}{$p->{tree}{__param__}} || '';
  return $ARG eq $p->{item} ? 1 : 0;
}

sub _test_item_looks_selected {
  my ($self, $p) = @_;

  my $selected = $self->_ARG_selects_item($p);

  # Normally this item node is a leaf.
  my $leaf = 1;

  # However, if the item has a submenu ...
  if ($p->{submenu}) {
    my $submenu_param = $p->{tree}{$p->{item}}{__param__};
    $self->_debug(3, $p, "submenu_param for $p->{item} is ",
                         $submenu_param || '__undef__');

    my $has_default = exists $p->{tree}{$p->{item}}{__default__};

    if ($p->{ARGS}{$submenu_param}) {
      # that means we're inside the submenu, so deselect it
      # i.e. make it a link so that the user can go back up to it,
      # *unless* the submenu has a default sub-item, in which case
      # we don't want the user to be able to go back up to it.
      $selected = 0 unless $has_default;
        
      # It also means this item isn't a leaf in the selection tree.
      $leaf = 0;
    }

    # If the submenu itself is selected then it can't be a leaf either.
    $leaf = 0 if $selected;
  }

  $self->_debug(3, $p, "    ? $p->{item} " . ($selected ? '' : 'un') .
                       "selected, " . ($leaf ? 'leaf' : 'not a leaf'));
  $p->{selected} = $selected;
  $p->{leaf}     = $leaf;
}

sub _output_item {
  my $self = shift;
  my (%p) = @_;

  my $out = '';
  
  # invoke the pre_item callback before every item
  $out .= $self->_callback('pre_item', %p);

  if ($p{selected}) {
    $out .= $self->_callback('selected', %p);
  } else {
    $out .= $self->_callback('unselected', %p);
  }

  # invoke the post_item callback after every item
  $out .= $self->_callback('post_item', %p);

  return $out;
}

sub _callback {
  my $self = shift;
  my $type = shift;
  my %p = @_;

  # Crawl back up the callback levels until we find a callback of the
  # type we're after.
  
  my $level = $p{level};
  my $callback;
  do {
    $callback = $p{callbacks}[$level]{$type};
    $level--;
  } until ($callback or $level < 0);

  my $out = '';

  if ($callback) {
    $self->_debug(4, \%p, "    - $type $p{item}");
    $out = $self->$callback(%p);
  }
  else {
    $self->_debug(5, \%p, "    - no $type callback available");
    $self->_debug(5, \%p, Dumper $p{callbacks}) if $type eq 'unselected';
  }

  return $out;
}

=head2 params()

  sub unselected_callback {
    my ($nav, %p) = @_;

    # make unselected menu item a hyperlink
    return $nav->ahref(text   => $p{item},
                       params => [ $nav->params(%p) ]);
  }

Helper method for figuring out what CGI parameters are needed to
point to the item described by C<%p>.

=cut

sub params {
  my $self = shift;
  my %p = @_;

  my @params = ();

  # Figure out what order we'll return the params.  We take a copy
  # to avoid altering %p, which is supposed to be read-only.
  my @params_order = @{ $p{params} };
  foreach my $param (@params_order) {
    push @params, $param => $p{ARGS}{$param};
  }

  # Innermost param needs to point to current item, not currently
  # selected item.
  pop @params;
  push @params, $p{item};

  unless ($p{ignore_defaults}) {
    # Traverse tree looking for default items, and adding parameters
    # to this link so it will take us straight to those default items.
    my $item = $p{item};
    my $ptr  = $p{tree}{$item};
    while ($ptr->{__default__}) {
      $self->_debug(6, \%p, "$p{item} has default");
      push @params, $ptr->{__param__} => $ptr->{__default__};
      $item = $ptr->{__default__};
      $ptr = $ptr->{$item};
      $self->_debug(6, \%p, "  -> default is $item");
    }
  }

  return @params;
}


=head2 ahref()

  my $html = ahref(url    => 'http://www.foobar.com/baz.pl',
                   text   => 'click me', # defaults to the url parameter
                   params => {
                              param1 => 'val1',
                              param2 => 'val2',
                             },
                   # any other parameters get added as attributes, e.g.
                   class  => 'myclass', # <A ... CLASS="myclass" ...>
                   ...
                  );

Convenient method for generating hyperlinks.  All parameters are optional,
but ahref() will moan if it can't figure out a sensible value for HREF.
The value for the C<params> key can be a hashref or an arrayref; in the
latter case the order of the parameters is preserved in the output.

=cut

sub ahref {
  my $self = shift;
  my %p = @_;

  my ($url, $text, $params) = delete @p{qw/url text params/};

  $url    ||= $self->base_url();
  $text   ||= $url;
  $params ||= {};

  my $query_string = $self->query_string($params);
  $p{href} = $url . ($query_string ? "?$query_string" : '');

  if (! $p{href}) {
    cluck "ahref resulted in empty url";
    delete $p{href};
  }
  
  return a(\%p, $text);
}

=head2 query_string()

  # Set $query_string to `param1=foo%20bar;param2=baz'
  my $query_string = $nav->query_string([
                                         param1 => 'foo bar',
                                         param2 => 'baz',
                                        ]);

This method provides an easy way of generating a string suitable
for appending to the end of a CGI URL in order to create GET queries.

You can pass the parameters in either a hashref or an arrayref; in the
latter case the order given is preserved.

=cut

sub query_string {
  my $self = shift;
  my ($params) = @_;

  my @params = ();

  if (ref $params eq 'HASH') {
    @params = map { [ $_ => $params->{$_} ] } keys %$params;
  }
  elsif (ref $params eq 'ARRAY') {
    if (@$params % 2 != 0) {
      confess "value of `params' key had odd number of elements in arrayref";
    }
    for (my $i = 0; $i < $#$params; $i += 2) {
      push @params, [ @$params[$i, $i + 1] ];
    }
  }
  else {
    confess "value of `params' key wasn't a hashref or arrayref";
  }

  my $query_string = join ';', map { uri_escape($_->[0]) .
                                     "=" .
                                     uri_escape($_->[1]) } @params;
  return $query_string;
}

=head2 base_url()

  my $base_url = $nav->base_url();
  $nav->base_url('foo.pl');

Read/write a base url for the links generated by C<ahref()> to default
to if no C<url> parameter is given.

=cut

sub base_url {
  my $self = shift;

  if (@_) {
    $self->{_base_url} = $_[0];
  }

  return $self->{_base_url} || '';
}

=head2 debug_level()

  my $current_level = $self->debug_level();

  $self->debug_level($new_level);

Read/write debugging verbosity level (defaults to 0).

Debugging appears on STDOUT.

=cut

sub debug_level {
  my $self = shift;

  if (@_) {
    $self->{_debug_level} = $_[0];
  }

  return $self->{_debug_level} || 0;
}

sub _debug {
  my ($self, $level, $p, @rest) = @_;
  warn '', ('    ' x $p->{level}), @rest, "\n"
    if $self->debug_level() >= $level;
}

=head1 TUTORIAL

Here are some examples of navigation structures.  I will try to
introduce the concepts in increasing order of complexity.  The
structures are always suitable for passing to the C<structure()>
method, and each one can be found as part of a fully working CGI
script in the `eg' directory so that you can experiment with them more
yourself.

Note that they are always arrayrefs rather than hashrefs so that the
ordering of the items is preserved.

=head2 A basic three-item, single-level menu

This structure describes a single-level (no submenus) menu with three
items.  The value following `__param__' is the CGI parameter used to
determine which item is selected, and in this case is innovatively
called `param'.

  # Extract from eg/single.cgi
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
   'item 2',
   'item 3',
  ]

=head2 Basic callback types and ordering

The value following __callbacks__ is an arrayref containing one
hashref for each level of the navigation structure.  The example above
has only one level, so there is only one hashref inside the array ref.
The hashrefs map types of callback to the callbacks themselves, which
generate all the output.  So in this example, the callbacks get
invoked in the following order:

  pre_items
    pre_item for item 1
    selected or unselected for item 1
    post_item for item 1

    pre_item for item 2
    selected or unselected for item 2
    post_item for item 2

    pre_item for item 3
    selected or unselected for item 3
    post_item for item 3
  post_items

Output occurs when the C<output()> method is called, which takes as
its sole argument a hashref describing the current CGI parameters.
It uses this to determine whether an item is selected or not, so if
it is called as

  $nav->output({ param => 'item 2' });

then the callbacks will be invoked as follows:

  pre_items
    pre_item for item 1
    unselected for item 1
    post_item for item 1

    pre_item for item 2
    selected for item 2
    post_item for item 2

    pre_item for item 3
    unselected for item 3
    post_item for item 3
  post_items

=head2 Invocation of callbacks

As you can see from the `unselected' and `selected' callbacks in the
above code, when a callback is invoked, it gets passed the
HTML::Navigation object as the first parameter, and the remaining
parameters form a hash which contains all the information you could
possibly need to know about the current item in order to generate
suitable output for it.  The keys for the hash include:

=over 4

=item * item

The name of the current item, e.g. `item 2'.

=item * level

The depth of the current item in the navigation graph.  This will
always be 0 until we progress to the multi-level examples below.

=item * selected

True iff the current item is selected.  Normally you won't need this
because you know whether it's selected depending on whether the
`selected' or `unselected' callback has been invoked, but you could
use this to change the behaviour of the pre_item callback depending on
whether the item is selected, for example.

=item * leaf

True iff the current item is a leaf in the navigation tree.  It will
always be a leaf unless it's a submenu which is currently selected.

=item * parent

The name of the current item's parent.  This is `top' if we're at
level 0 (which, as noted above, has always been the case in the
examples so far).

=back

B<You should not attempt to change any of the values in this hash.  If
you do so, you invalidate the module's warranty and no guarantees
about its behaviour can be made.>

=head2 More callback types

There are two more callback types to know about.  The first is
`item_glue', which is invoked in between each item:

  pre_items
    pre_item for item 1
    selected or unselected for item 1
    post_item for item 1

    item_glue

    pre_item for item 2
    selected or unselected for item 2
    post_item for item 2

    item_glue

    pre_item for item 3
    selected or unselected for item 3
    post_item for item 3
  post_items

The second is `omit', which doesn't generate any output, but decides
whether a particular item should be included in or omitted from the
output.  Say that we used the following omit callback:

  sub {
    my ($nav, %p) = @_;
    return $p{item} eq 'item 2';
  }

Then the callback order would be:

  pre_items
    pre_item for item 1
    selected or unselected for item 1
    post_item for item 1

    item_glue

    pre_item for item 3
    selected or unselected for item 3
    post_item for item 3
  post_items

=head2 __default__

If we generate output for our single-level menu with no item selected
like so:

  $nav->output({});

then the callback invocation order will be

  pre_items
    pre_item for item 1
    unselected for item 1
    post_item for item 1

    pre_item for item 2
    unselected for item 2
    post_item for item 2

    pre_item for item 3
    unselected for item 3
    post_item for item 3
  post_items

so that no item appears selected.  But what if we always want an item
selected, even when the CGI parameter to select one is missing?  The
answer is to include C<__default__> in the structure:

  [
   __param__ => 'param',
   __callbacks__ => [ $level_0_callbacks ],
   __default__ => 'item 2',
   'item 1',
   'item 2',
   'item 3',
  ]

Now if the CGI parameter `param' is missing, `item 2' will be
selected.  If you want the default selected item to be the first item
in the list, but you don't necessarily know what the first item is
called (see L<"Dynamically generating items"> below) then set
C<__default__> to the empty string.

=head2 Dynamically generating items

If you want, you can dynamically build up the navigation structure at
output time by using coderefs:

  # Extract from eg/dynamic.cgi
  sub dynamic_items { [ 'item 2', 'item 3' ] }

  my $nav = new HTML::Navigation(base_url => 'simple.cgi');
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
     'item 1',
     \&dynamic_items,
    ];

C<dynamic_items()> will be invoked during the call to C<output()>, not
before.  This is mostly of use with multi-level navigation, for which
see below.

You can use this "unpacking coderefs" technique to dynamically
generate as much of the contents of the containing arrayref as you
want, i.e. even the C<__param__>, C<__callbacks__>, and C<__default__>
bits.

You now know everything about single-level navigation!

=head2 Multi-level navigation

Again, this is best illustrated with an example of a two-level menu
(F<eg/two-level.cgi>).

  # Extract from eg/two-level.cgi
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
  ]

This has a top-level menu as before, but now clicking on the first and
third items reveal further submenus containing `one' to `three', and
`four' to `seven' respectively.  Note the difference that
C<__default__> creates between the two submenus: when you click on
`item 1' it reveals the first submenu but none of the sub-items are
selected, whereas when you click on `item 3' then `five' immediately
gets selected.

Also note how the callbacks are defined for the submenus (level 1).
Firstly the `pre_items', `post_items', `pre_item', `post_item',
`unselected', and `selected' callbacks are inherited from level 0.
Then the `pre_items', `post_items', and `pre_item' callbacks are
overriden by the callbacks in the hashref following the `# level 1'
comment.  Finally, in the `item 3' submenu only, the `pre_item' and
`post_item' callbacks are overriden.  The net effect of all this is
that both submenus are unordered lists, and the items of the second
submenu (`four' to `seven') are in bold.

Finally, note that although in this example each submenu has a
different CGI parameter name determining selection within it
(`submenu_1' and `submenu_2'), everything would still work if they had
the same CGI parameter name (e.g. `submenu').

Dynamic item generation works as before, except it is now potentially
much more useful, because if you have a submenu whose contains are
generated by a coderef which is an expensive operation (e.g. doing a
complex query on a database), then that expensive operation will only
be performed if the contents of that submenu are visible (i.e. iff the
submenu has been selected).

=head2 More complex navigation structures

All aspects of the navigation structure syntax have now been covered.
If you really want to, you could take a look at the multi-level
structure in F<t/MyTest.pm>, which contains some pathological features
designed to test the code to its limits.

=head1 BUGS / WISHLIST

Here are a few things aren't nice, and a few things which might be.
Suggestions and comments welcome.

=over 4

=item * 

The recursion code is convoluted and should be abstracted out.

=item * 

The dump_all_params() stuff is a nasty hack, which I only included to
make testing easier.

=item *

Some of the subroutines are way too long.  I tried breaking them up
several times but always ended up with something even messier :-(

=item *

Maybe it would be cleaner to do output in two passes - one for parsing
the navigation structure, and one for doing the output.  I'm guessing
that most (all?) navigation structures won't be big enough to worry
about the cost of doing two passes, but I could be wrong.

=item *

Recursion is currently depth-first only.

=item *

There needs to be a sanity check for duplicate C<__param__> values at
different levels.

=item * 

Creation/manipulation/retrieval of specific bits of the navigation
structure via methods, e.g.

  $nav->top->submenu('foo')->add_item('item under foo submenu');

Maybe use Tree::DAG_Node?  This would mean some major changes though,
as the structure is currently described as an arrayref, not a hashref,
so as to preserve ordering.  If the structure parsing phase was
separated out, that would make this a lot easier.

=item *

Optional tree-parsing during new() phase rather than during output()
phase.  This has to be optional, because it would mean that any
coderefs given to dynamically generate menu items would have to be run
here, which is bad if your coderefs point to expensive code.

=item * 

Debugging isn't tested.  But then that's kind of the point.

=back

=head1 AUTHOR

Adam Spiers <adam@spiers.net>

=cut

1;
