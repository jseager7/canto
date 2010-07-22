#!/usr/bin/env perl
use strict;

BEGIN {
  $ENV{MYAPP_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use PomCur;

use Plack::Builder;

PomCur->setup_engine('PSGI');
my $app = sub { PomCur->run(@_) };

builder {
  enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
    "Plack::Middleware::ReverseProxy";
  $app;
};


