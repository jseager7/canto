use strict;
use warnings;
use Test::More tests => 7;
use Test::Deep;
use Clone qw(clone);

use Canto::TestUtil;
use Canto::Curs::Utils;
use Canto::Track::OrganismLookup;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();

# set pombe as a host organism in pathogen_host_mode
$config->{host_organism_taxonids} = [4932];
$config->_set_host_organisms($track_schema);
$Canto::Track::OrganismLookup::cache = {};

my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $phi_phenotype_config = clone $config->{annotation_types}->{phenotype};
$phi_phenotype_config->{name} = 'disease formation phenotype';
$phi_phenotype_config->{namespace} = 'disease formation phenotype';
$phi_phenotype_config->{feature_type} = 'metagenotype';

push @{$config->{available_annotation_type_list}}, $phi_phenotype_config;
$config->{annotation_types}->{$phi_phenotype_config->{name}} = $phi_phenotype_config;


my $existing_pombe_genotype =
  $curs_schema->find_with_type('Genotype', { identifier => 'aaaa0007-genotype-test-1' });

ok ($existing_pombe_genotype);

my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                         curs_schema => $curs_schema);
my $cerevisiae_genotype =
  $genotype_manager->make_genotype(undef, undef, [], 4932);

my $metagenotype =
  $genotype_manager->make_metagenotype(pathogen_genotype => $existing_pombe_genotype,
                                       host_genotype => $cerevisiae_genotype);


my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $curs_schema,
                                                   config => $config);

my $annotation_json = {
  'term_suggestion_definition' => undef,
  'evidence_code' => 'Other',
  'extension' => [],
  'feature_type' => 'metagenotype',
  'term_ontid' => 'PHIPO:0000006',
  'term_suggestion_name' => undef,
  'feature_id' => $metagenotype->metagenotype_id(),
  'annotation_type' => 'disease formation phenotype',
  'key' => 'aaaa0007',
  'submitter_comment' => 'Figure 5',
};

my $result = $service_utils->create_annotation($annotation_json);

my ($completed_count, $annotations_ref) =
  Canto::Curs::Utils::get_annotation_table($config, $curs_schema, 'disease formation phenotype');

is (@$annotations_ref, 1);
is ($annotations_ref->[0]->{term_name}, 'pathogenicity phenotype');
is ($annotations_ref->[0]->{term_ontid}, 'PHIPO:0000006');
is ($annotations_ref->[0]->{pathogen_genotype}->{feature_display_name}, 'SPCC63.05delta ssm4KE');
is ($annotations_ref->[0]->{host_genotype}->{organism}->{full_name},
    'Saccharomyces cerevisiae');
# host genotype has no alleles:
is (@{$annotations_ref->[0]->{host_genotype}->{alleles}}, 0);
