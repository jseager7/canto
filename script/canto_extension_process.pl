#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Temp qw/ tempfile /;
use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
use Canto::Meta::Util;

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

sub usage
{
  my $message = shift;

  if ($message) {
    warn "$message\n";
  }

  die "usage:
  $0 extension_conf_file <OBO file names>
";
}

if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
  usage();
}

my ($extension_conf_file, @filenames) = @ARGV;

if (!@filenames) {
  usage "missing OBO file name argument(s)";
}

sub parse_conf
{
  my $conf_fh = shift;

  my %res = ();

  while (defined (my $line = <$conf_fh>)) {
    chomp $line;

    my ($domain, $domain_name, $subset_rel, $allowed_extension, $range, $display_text) =
      split (/\t/, $line);

    if (!defined $display_text) {
      die "config line has too few fields: $line\n";
    }

    $res{$domain} = {
      domain_name => $domain_name,
      subset_rel => $subset_rel,
      allowed_extension => $allowed_extension,
      range => $range,
      display_text => $display_text,
    };
  }

  return %res;
}

open my $conf_fh, '<', $extension_conf_file
  or die "can't open $extension_conf_file: $!\n";

my %conf = parse_conf($conf_fh);

close $conf_fh or die "$!\n";

my %subsets = ();

for my $filename (@filenames) {
  my ($temp_fh, $temp_filename) = tempfile();

  system ("owltools $filename --save-closure-for-chado $temp_filename") == 0
    or die "can't open pipe from owltools: $?";

  open my $owltools_out, '<', $temp_filename
    or die "can't open owltools output from $temp_filename: $!\n";

  while (defined (my $line = <$owltools_out>)) {
    chomp $line;
    my ($subject, $rel_type, $depth, $object) =
      split (/\t/, $line);

    die $line unless $rel_type;

    $rel_type =~ s/^OBO_REL://;

    if ($conf{$object}) {
      if ($conf{$object}->{subset_rel} eq $rel_type) {
        $subsets{$subject}{$object} = 1;
      }
    }
  }
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $cvterm_rs = $schema->resultset('Cvterm');

while (defined (my $cvterm = $cvterm_rs->next())) {
  print $cvterm->name(), "\n";
}
