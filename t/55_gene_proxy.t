use strict;
use warnings;
use Test::More tests => 6;

use Canto::TestUtil;
use Canto::Curs::Utils;
use Canto::Curs::GeneProxy;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $schema = $test_util->track_schema();

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $doa10 = $curs_schema->resultset('Gene')->find({ primary_identifier => 'SPBC14F5.07' });

ok($doa10);

my $doa10_proxy = Canto::Curs::GeneProxy->new(config => $config, cursdb_gene => $doa10);

is($doa10_proxy->primary_name(), 'doa10');
is($doa10_proxy->display_name(), 'doa10');

is($doa10_proxy->product(), 'ER-localized ubiquitin ligase Doa10 (predicted)');

is($doa10_proxy->taxonid(), '4896');

is($doa10_proxy->feature_id(), $doa10->gene_id());
