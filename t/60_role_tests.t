use strict;
use warnings;
use Test::More tests => 5;
use Test::Deep;

use MooseX::Test::Role;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Cache;
use Canto::Role::TaxonIDLookup;
use Canto::Role::ChadoFeatureCache;

my $test_util = Canto::TestUtil->new();

$test_util->init_test();

my $config = $test_util->config();
my $schema = Canto::TrackDB->new(config => $config);

my @results = $schema->resultset('Organism')->search();

is(@results, 2);

my $organism = $results[0];

my $taxonidlookup = consumer_of('Canto::Role::TaxonIDLookup',
                                  config => sub {
                                    return $config;
                                  });



is($taxonidlookup->taxon_id_lookup($organism), 4896);


my $chado_schema = $test_util->chado_schema();
my $chado_feature_cache = consumer_of('Canto::Role::ChadoFeatureCache',
                                      schema => sub {
                                        return $chado_schema;
                                      },
                                      cache => sub {
                                        return Canto::Cache::get_cache($config, 'Canto::SomePackage');
                                      },
                                      config => sub {
                                        return $config;
                                      });

my $pombe_org = $chado_schema->resultset('Organism')->find({ species => 'pombe' });
my $pombe_taxon = $chado_feature_cache->get_cached_taxonid($pombe_org->organism_id());

is ($pombe_taxon, 4896);


my $allele = $chado_schema->resultset('Feature')->find({ name => 'wtf22-a1' });
my $allele_details = $chado_feature_cache->get_cached_allele_details($allele);

my $expected_wtf22_details =
  {
    'name' => 'wtf22-a1',
    'description' => 'T11C',
    'taxonid' => '4896',
    'type' => undef,
    'primary_identifier' => 'SPCC576.16c:allele-1',
    'gene_display_name' => 'wtf22'
  };

cmp_deeply($allele_details,
           $expected_wtf22_details);


my $genotype = $chado_schema->resultset('Feature')->find({ name => 'cdc11-33 wtf22-a1' });
my $genotype_details = $chado_feature_cache->get_cached_genotype_details($genotype);


cmp_deeply($genotype_details,
           {
             'alleles' => [
               {
                 'taxonid' => '4896',
                 'description' => 'unknown',
                 'type' => undef,
                 'gene_display_name' => 'cdc11',
                 'primary_identifier' => 'SPCC1739.11c:allele-1',
                 'name' => 'cdc11-33'
               },
               $expected_wtf22_details,
             ],
             'name' => 'cdc11-33 wtf22-a1',
             'identifier' => 'aaaa0007-test-genotype-2'
           }
         );
