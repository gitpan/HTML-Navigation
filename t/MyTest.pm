#!/usr/bin/perl -w

package MyTest;

use strict;

use Data::Dumper;
use Exporter;

use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);

@EXPORT_OK = qw(log_test callbacks callback html_page cat uc_href
                multi_level multi_page multi_filename);

sub log_test (@) {
  print "! ", @_;
}

sub callbacks {
  my ($name) = @_;
  my @callbacks = qw/
                     pre_items
                     pre_item
                     selected
                     unselected
                     post_item
                     item_glue
                     post_items
                    /;
  return { map { $_ => callback($_, $name) } @callbacks };
}

sub callback {
  my ($type, $name) = @_;
  
  my ($pre, $post) = ('', '');

  if ($type eq 'pre_items') {
    $pre = '<ol start="0" type="@@BULLET@@">';
  }
  elsif ($type eq 'pre_item') {
    $pre = '<li>';
    $post = '{';
  }
  elsif ($type eq 'post_item') {
    $post = '}';
  }
  elsif ($type eq 'post_items') {
    $pre = '</ol>';
  }

  $pre =~ s/<(\w+)>/<$1 id="$name">/ if $name;

  return sub {
    my ($nav, %p) = @_;

    my $leaf = $p{leaf} ? '' : qq{ class="not_leaf"};
    $leaf = '' unless exists $p{leaf};

    my $mid = "<!-- $type: $p{item}$leaf -->";
    my $text = $p{item};
    $text .= " [$name]" if $name;
    $text .= " (not leaf)" if $leaf;
    if ($type eq 'unselected') {
      $mid = $nav->ahref(text => $text,
                         params => [ $nav->params(%p) ]);
    }
    elsif ($type eq 'selected') {
      $mid = qq{<span class="selected">$text</span>};
    }
    elsif ($type eq 'item_glue') {
      $post = $p{level} . '+';
    }
  
    my $out = '';

    if ($mid) {
      $out .= '    ' x $p{level};
      $out .= '  ' if $type !~ /items/ || $type =~ /selected/;

      $out .= join ' ', grep($_, $pre, $mid, $post);

      $out = "\n$out\n" if $type =~ /item_glue/;
      $out .= "\n";
    }

    my $bullet = (qw/1 a I A i/)[$p{level} % 5];
    $out =~ s/\@\@BULLET\@\@/$bullet/g;
    
    return $out;
  };
}

sub multi_level {
  [
   __param__ => 'first',
   __callbacks__ => [
                     # top level
                     callbacks(),

                     # second level
                     callbacks('level 2'),

                     # third level
                     callbacks('level 3'),
                    ],
   'item_0',

   # test simple submenu, using callbacks set earlier
   'item_1' => [
                __param__ => 'submenu_1',
                '1_a',
                sub { [ '1_b' , '1_c' ] },
               ],

   # test callback overriding/inheritance
   'item_2' => [
                __param__ => 'submenu_2',
                __callbacks__ => [
                                  callbacks('item 2 level 1'),
                                  callbacks('item 2 level 2'),
                                 ],
                '2_a',
                '2_b' => [
                          __param__ => 'submenu_2_b',
                          '2_b_I',
                          '2_b_II',
                         ],
               ],
   
   # test __default__ and __omit__
   'item_3' => [
                __param__ => 'submenu_3',
                __default__ => '3_c',
                __callbacks__ => [{
                                   omit => sub {
                                     my ($nav, %p) = @_;
                                     return $p{item} =~ /b/;
                                   }
                                  }],
                '3_a',
                '3_b',
                '3_c',
               ],

   # test __default__ and callback overriding/inheritance
   # with multiple nesting
   'item_4' => [
                __param__ => 'submenu_4',
                # test defaulting to first in list
                __default__ => '',
                '4_a' => [
                          __param__ => 'submenu_4_a',
                          __default__ => '4_a_II',
                          '4_a_I' => [
                                      __param__ => 'submenu_4_a_I',
                                      '4_a_I_A',
                                      '4_a_I_B',
                                      '4_a_I_C',
                                     ],
                          '4_a_II' => [
                                       __param__ => 'submenu_4_a_II',
                                       '4_a_II_A',
                                      ],
                         ],

                # test local __callback__ selectively overriding `global' ones
                __callbacks__ =>
                  [
                   {
                    unselected => callback('unselected', 'unsel override'),
                   },
                   {
                    unselected => callback('unselected', 'unsel override 2'),
                   },
                  ],
                '4_b',
                '4_c' => [
                          __param__ => 'submenu_4_c',
                          __callbacks__ =>
                            [{ selected =>
                                 callback('selected', 'sel override 2') }],
                          '4_c_I',
                          '4_c_II',
                          __callbacks__ =>
                            [{ unselected =>
                                 callback('unselected', 'unsel override 3') }],
                          '4_c_III',
                         ],
               ],
  ];
}

sub multi_filename {
  my ($query_string) = @_;

  (my $filename = $query_string) =~ s/.*=//; # hah!
  return "multi_html/${filename}.html";
}

sub html_page {
  my ($title, $nav) = @_;

  my $html = <<EOF;
<html>
<head>
  <title> $title </title>

  <style type="text/css">
    .selected {
      color: white;
      background: blue;
    }
  </style>
</head>

<body>
$nav
</body>
</html>
EOF

  return $html;
}

sub multi_page {
  return html_page('multi-level navigation test', @_);
}

sub cat {
  my ($filename) = @_;
  if (open(FILE, $filename)) {
    my $cat = join '', <FILE>;
    close(FILE);
    return $cat;
  }
  else {
    die "Couldn't open `$filename': $!";
    return undef;
  }
}

sub uc_href {
  my ($text) = @_;
  $text =~ s/<a HrEf=/<A HREF=/gi;
  $text =~ s!</a>!</A>!gi;
  return $text;
}
