#!/usr/bin/perl -w

package MyCompare;

# Data::Compare, eat your heart out ;-)
#
# I know, I know, reinventing the wheel is Bad.  But Data::Compare
# isn't currently good enough - it cheats with references.  And it
# kinda sucks to have to install another module just to run a test
# suite.

use strict;

use Data::Dumper;
use Exporter;

use vars qw(@ISA @EXPORT_OK);
@ISA = qw(Exporter);

@EXPORT_OK = qw(&equal_hashes &equal_arrays);

sub equal_hashes {
  my ($a, $b) = @_;

  my @a = sort keys %$a;
  my @b = sort keys %$b;
  
  while (my $p = shift @a and my $q = shift @b) {
#   print "Comparing `$p' and `$q' ...\n";
    
    if (defined($p) xor defined($q)) {
      print "first key undefined\n" unless defined($p);
      print "second key undefined\n" unless defined($q);
      return 0;
    }
    
    if ($p ne $q) {
      print "`$p' ne `$q'\n";
      return 0;
    }
    
    if (defined($a->{$p}) xor defined($b->{$q})) {
      print "first value (key `$p') undef\n" unless defined($a->{$p});
      print "second value (key `$q') undef\n" unless defined($b->{$q});
      return 0;
    }
    
    next if (! defined($a->{$p}) and ! defined($b->{$q}));

    if (ref($a->{$p}) ne ref($b->{$q})) {
      print "ref mismatch on values for `$p'\n";
      return 0;
    }

    if (! ref($a->{$p})) {
      # both scalars
      if ($a->{$p} eq $b->{$q}) {
        next;
      }
      else {
        print "key `$p': `$a->{$p}' ne `$b->{$q}'\n";
        return 0;
      }
    }

    # both refs

    # TODO - deal with blessed refs here
    my $type = ref $a->{$p};

    if ($type eq 'HASH') {
      # recursion rules
      return 0 unless equal_hashes($a->{$p}, $b->{$q});
    }
    elsif ($type eq 'ARRAY') {
      return 0 unless equal_arrays($a->{$p}, $b->{$q});
    }
    else {
      die "key `$p': cannot compare refs of type `$type'\n";
    }
  }

  return 1;
}

sub equal_arrays {
  my ($a, $b) = @_;

  local $^W = 0;  # silence spurious -w undef complaints
  if (@$a != @$b) {
    print "Arrays of different length:\n", (Dumper $a), (Dumper $b);
    return 0;
  }
  
  for (my $i = 0; $i < @$a; $i++) {
#   print "Comparing `$a->[$i]' and `$b->[$i]' ...\n";
    if (defined($a->[$i]) xor defined($b->[$i])) {
      print "first value (index $i) undef\n"  unless defined($a->[$i]);
      print "second value (index $i) undef\n" unless defined($b->[$i]);
      return 0;
    }
    elsif (! defined $a->[$i]) {
      # both defined
      if (ref($a->[$i]) ne ref($b->[$i])) {
        print "ref mismatch on values for index $i\n";
        return 0;
      }

      if (! ref($a->[$i])) {
        # both scalars
        if ($a->[$i] eq $b->[$i]) {
          next;
        }
        else {
          print "index $i: `$a->[$i]' ne `$b->[$i]'\n";
          return 0;
        }
      }

      # both refs

      # TODO - deal with blessed refs here
      my $type = ref $a->[$i];

      if ($type eq 'HASH') {
        return 0 unless equal_hashes($a->[$i], $b->[$i]);
      }
      elsif ($type eq 'ARRAY') {
        return 0 unless equal_arrays($a->[$i], $b->[$i]);
      }
      else {
        die "index $i: cannot compare refs of type `$type'\n";
      }
    }
  }
  
  return 1;
}
