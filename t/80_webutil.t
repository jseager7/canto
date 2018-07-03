use strict;
use warnings;
use Test::More tests => 10;
use Test::MockObject;

use Canto::TestUtil;
use Canto::WebUtil;
use Canto::TrackDB;
use Canto::Controller::View;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $lc_app_name = lc Canto::Config::get_application_name();
my $uc_app_name = uc $lc_app_name;

my $config = $test_util->config();
$config->merge_config($test_util->root_dir() . '/t/data/50_config_1.yaml');

my $schema = Canto::TrackDB->new(config => $config);


my $mock_request = Test::MockObject->new();
$mock_request->mock('param', sub { return 'track' });

my $mock_c = Test::MockObject->new();

$mock_c->mock('schema', sub { return $schema; });
$mock_c->mock('config', sub { return $config; });
$mock_c->mock('request', sub { return $mock_request; });

package main;

my $person_email = 'Nicholas.Willis@2c0e6282230890808f2298475c741b2d2f44de03.edu';

my $person = $schema->find_with_type('Person',
                                     {
                                       email_address => $person_email
                                     });

my $person_class_info = $config->{class_info}->{track}->{person};

my ($field_value, $field_type) =
  Canto::WebUtil::get_field_value($mock_c, $person, $person_class_info,
                                   'name');

is($field_value, 'Nicholas Willis');
is($field_type, 'key_field');


($field_value, $field_type) =
  Canto::WebUtil::get_field_value($mock_c, $person, $person_class_info,
                                   'Email address');

is($field_value, $person_email);
is($field_type, 'attribute');


my $lab = $schema->find_with_type('Lab',
                                  {
                                    name => 'Rhind Lab',
                                  });

my $lab_class_info = $config->{class_info}->{track}->{lab};

($field_value, $field_type) =
  Canto::WebUtil::get_field_value($mock_c, $lab, $lab_class_info, 'people');

ok(!defined $field_value);
is($field_type, 'collection');


my $paths_string =
  'test string @@name@@ -- @@lab->name@@ more text @@lab->lab_head->name@@';
my $substituted_1 = Canto::WebUtil::substitute_paths($paths_string, $person);

is ($substituted_1, 'test string Nicholas Willis -- Rhind Lab more text Nick Rhind');

my $person_hash = {
  name => 'Nicholas Willis',
  lab => {
    name => 'Rhind Lab',
    lab_head => {
      name => 'Nick Rhind',
    },
  },
};

my $post_process_path =
  'upper case lab name: @@lab->name:uc@@ - @@lab->lab_head->name:s/Nick/N/r@@';
my $substituted_ppp = Canto::WebUtil::substitute_paths($post_process_path, $person);

is ($substituted_ppp, 'upper case lab name: RHIND LAB - N Rhind');

# substitute in using a hash instead
my $substituted_2 = Canto::WebUtil::substitute_paths($paths_string, $person_hash);
is ($substituted_2, 'test string Nicholas Willis -- Rhind Lab more text Nick Rhind');

my $js_test_string = qq~!@#$%^&*()_{}:"|<>?\
foo~;

$js_test_string .= "\tbar'zzz";

my $js_result = Canto::WebUtil::escape_inline_js($js_test_string);

is ($js_result, '!@#0^&amp;*()_{}:&quot;|&lt;&gt;?\\nfoo\\tbar\\\'zzz');
