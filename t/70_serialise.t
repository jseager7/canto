use strict;
use warnings;
use Test::Deep;

use Test::More tests => 6;

use Clone qw(clone);
use JSON;
use utf8;
use Encode;

use Digest::SHA qw(sha1_base64);

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Track::Serialise;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);

my %extra_curs_statuses = (
        annotation_status => Canto::Controller::Curs::CURATION_IN_PROGRESS,
        annotation_status_datestamp => '2012-02-15 13:45:00',
        session_genes_count => 4,
        session_unknown_conditions_count => 1,
        session_term_suggestions_count => 1,
);

my $abstract =
 qr/In the fission yeast, Schizosaccharomyces pombe, synaptonemal complexes/;
my $full_expected_curation_session =
  {
    genes => {
      'Schizosaccharomyces pombe SPAC27D7.13c' => {
        uniquename => 'SPAC27D7.13c',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPBC14F5.07' => {
        uniquename => 'SPBC14F5.07',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPCC63.05' => {
        uniquename => 'SPCC63.05',
        organism => 'Schizosaccharomyces pombe',
      },
      'Schizosaccharomyces pombe SPBC1826.01c' => {
        uniquename => 'SPBC1826.01c',
        organism => 'Schizosaccharomyces pombe',
      }
    },
    alleles => {
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-1' => {
        primary_identifier => 'SPAC27D7.13c:aaaa0007-1',
        name => 'ssm4delta',
        description => 'deletion',
        allele_type => 'deletion',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-2' => {
        description => 'G40A,K43E',
        allele_type => 'amino_acid_mutation',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-2',
        name => 'ssm4KE'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-3' => {
        description => 'del_100-200',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        allele_type => 'partial_nucleotide_deletion',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-3',
        name => 'ssm4-D4'
      },
      'Schizosaccharomyces pombe SPCC63.05:aaaa0007-1' => {
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        allele_type => 'deletion',
        description => 'deletion',
        name => 'SPCC63.05delta',
        primary_identifier => 'SPCC63.05:aaaa0007-1'
      },
      'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-4' => {
        description => 'del_200-300',
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
        allele_type => 'partial_nucleotide_deletion',
        primary_identifier => 'SPAC27D7.13c:aaaa0007-4'
      }
    },
    genotypes => {
      'aaaa0007-genotype-test-1' => {
        'name' => 'SPCC63.05delta ssm4KE',
        'background' => 'h+',
        alleles => [
          {
            id => 'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-1',
          },
          {
            id => 'Schizosaccharomyces pombe SPCC63.05:aaaa0007-1',
          },
        ],
      },
      'aaaa0007-genotype-test-2' => {
        alleles => [
          {
            id => 'Schizosaccharomyces pombe SPAC27D7.13c:aaaa0007-3',
            expression => 'Knockdown',
         },
        ],
      },
    },
    annotations => [
      {
        evidence_code => "IMP",
        creation_date => "2010-01-02",
        term => "GO:0055085",
        status => "new",
        type => "biological_process",
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        term_suggestion => {
          name => 'miscellaneous transmembrane transport',
          definition =>
            'The process in which miscellaneous stuff is transported from one side of a membrane to the other.',
        },
        gene => 'Schizosaccharomyces pombe SPAC27D7.13c',
      },
      {
        evidence_code => "IPI",
        creation_date => "2010-01-02",
        term => "GO:0034763",
        status => "new",
        type => "biological_process",
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        with_gene => "SPBC1826.01c",
        extension => [
          {
            relation => 'exists_during',
            rangeValue => 'GO:0051329',
          },
          {
            relation => 'has_substrate',
            rangeValue => 'PomBase:SPBC1105.11c',
          },
          {
            relation => 'requires_feature',
            rangeValue => 'Pfam:PF00564',
          },
        ],
        gene => 'Schizosaccharomyces pombe SPBC14F5.07',
      },
      {
        evidence_code => "IPI",
        creation_date => "2010-01-02",
        term => "GO:0034763",
        status => "new",
        type => "biological_process",
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        with_gene => "SPBC1826.01c",
        extension => [
          {
            relation => 'exists_during',
            rangeValue => 'GO:0051329',
          },
          {
            relation => 'has_substrate',
            rangeValue => 'PomBase:SPBC1105.11c',
          }
        ],
        gene => 'Schizosaccharomyces pombe SPBC14F5.07',
      },
      {
        evidence_code => 'IDA',
        creation_date => '2010-01-02',
        status => 'new',
        type => 'molecular_function',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        term => 'GO:0022857',
        gene => 'Schizosaccharomyces pombe SPBC14F5.07',
      },
      {
        type => 'genetic_interaction',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'Synthetic Haploinsufficiency',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        interacting_genes => [
          'Schizosaccharomyces pombe SPBC14F5.07',
        ],
      },
      {
        type => 'genetic_interaction',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'Far Western',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
        interacting_genes => [
          'Schizosaccharomyces pombe SPAC27D7.13c',
        ]
      },
      {
        status => 'new',
        term => 'FYPO:0000013',
        evidence_code => 'Epitope-tagged protein immunolocalization experiment data',
        creation_date => '2010-01-02',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        type => 'phenotype',
        conditions => [
          'PECO:0000137',
          'rich medium',
        ],
        genotype => 'aaaa0007-genotype-test-1',
      },
      {
        evidence_code => 'Co-immunoprecipitation experiment',
        creation_date => '2010-01-02',
        genotype => 'aaaa0007-genotype-test-2',
        status => 'new',
        type => 'phenotype',
        publication => 'PMID:19756689',
        curator => {
          name => 'Some Testperson',
          email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::false,
        },
        term => 'FYPO:0000017'
      },
      {
        type => 'post_translational_modification',
        status => 'new',
        creation_date => "2010-01-02",
        evidence_code => 'ISS',
        publication => 'PMID:19756689',
        curator => {
          name => 'Another Testperson',
          email => 'a.n.other.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
          community_curated => JSON::XS::true,
        },
        term => 'MOD:01157',
        gene => 'Schizosaccharomyces pombe SPCC63.05',
      },
    ],
    publications => {
      'PMID:19756689' => {
        title => 'SUMOylation is required for normal development of linear elements and wild-type meiotic recombination in Schizosaccharomyces pombe.',
        abstract => re($abstract),
      },
    },
    metadata => {
      canto_session => 'aaaa0007',
      curation_pub_id => 'PMID:19756689',
      term_suggestion_count => 1,
      unknown_conditions_count => 1,
      accepted_timestamp => '2012-02-15 13:45:00',
      curation_in_progress_timestamp => '2012-02-15 13:45:00',
      session_created_timestamp => '2012-02-15 13:45:00',
      curator_email => 'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org',
      curator_name => 'Some Testperson',
      curator_role => 'community',
      curation_accepted_date => '2012-02-15 13:45:00',
      %extra_curs_statuses,
    },
    organisms => {
      4896 => {
        full_name => 'Schizosaccharomyces pombe',
      },
    },
  };

my $small_expected_curation_session = clone $full_expected_curation_session;
$small_expected_curation_session->{publications}->{'PMID:19756689'} = {};

my %expected_people = (
  'dom@40f92df84557e35aa67918b1912c3beeb02112ab.med.harvard.edu' => {
    'password' => sha1_base64('dom@40f92df84557e35aa67918b1912c3beeb02112ab.med.harvard.edu'),
    'lab' => 'Winston Lab',
    'name' => 'Dom Helmlinger',
    'orcid' => undef,
    'role' => 'user'
  },
  'Pascale.Beauregard@5b066279c6c138f5b3b17bfa37986c8cfad042c4.ca' => {
    'password' => sha1_base64('Pascale.Beauregard@5b066279c6c138f5b3b17bfa37986c8cfad042c4.ca'),
    'lab' => 'Rokeach Lab',
    'name' => 'Pascale Beauregard',
    'orcid' => undef,
    'role' => 'user'
  },
  'peter.espenshade@38f4cb0f29557aca4b0422facb7de6f798ad031a.edu' => {
    'password' => sha1_base64('peter.espenshade@38f4cb0f29557aca4b0422facb7de6f798ad031a.edu'),
    'lab' => 'Espenshade Lab',
    'name' => 'Peter Espenshade',
    'orcid' => undef,
    'role' => 'user'
  },
  'kevin.hardwick@0b7c25eb5467e87b3655607c1aaf61d1f4d491b6.ac.uk' => {
    'password' => sha1_base64('kevin.hardwick@0b7c25eb5467e87b3655607c1aaf61d1f4d491b6.ac.uk'),
    'lab' => 'Hardwick Lab',
    'name' => 'Kevin Hardwick',
    'orcid' => undef,
    'role' => 'user'
  },
  'hoffmacs@4a222e72ead35220fce2a43b70b158fc2fbb035a.edu' => {
    'password' => sha1_base64('hoffmacs@4a222e72ead35220fce2a43b70b158fc2fbb035a.edu'),
    'lab' => 'Hoffman Lab',
    'name' => 'Charles Hoffman',
    'orcid' => undef,
    'role' => 'user'
  },
  'fred.winston@40f92df84557e35aa67918b1912c3beeb02112ab.med.harvard.edu' => {
    'password' => sha1_base64('fred.winston@40f92df84557e35aa67918b1912c3beeb02112ab.med.harvard.edu'),
    'lab' => 'Winston Lab',
    'name' => 'Fred Winston',
    'orcid' => undef,
    'role' => 'user'
  },
  'h.yamano@0e028b17263bde65a25de03c75f849251ade2fab.ac.uk' => {
    'password' => sha1_base64('h.yamano@0e028b17263bde65a25de03c75f849251ade2fab.ac.uk'),
    'lab' => 'Yamano Lab',
    'name' => 'Hiro Yamano',
    'orcid' => undef,
    'role' => 'user'
  },
  'test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org' => {
    'password' => sha1_base64('test.user@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org'),
    'lab' => 'User Lab',
    'name' => 'Test User',
    'orcid' => undef,
    'role' => 'user'
  },
  'Mary.Porter-Goff@2c0e6282230890808f2298475c741b2d2f44de03.edu' => {
    'password' => sha1_base64('Mary.Porter-Goff@2c0e6282230890808f2298475c741b2d2f44de03.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Mary Porter-Goff',
    'orcid' => undef,
    'role' => 'user'
  },
  'some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org' => {
    'password' => sha1_base64('some.testperson@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org'),
    'lab' => 'Testperson Lab',
    'name' => 'Some Testperson',
    'orcid' => undef,
    'role' => 'user'
  },
  'val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk' => {
    'password' => sha1_base64('val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk'),
    'lab' => undef,
    'name' => 'Val Wood',
    'orcid' => undef,
    'role' => 'admin'
  },
  'mah79@2b996589fd60a6e63d154d6d33fe9da221aa88e9.ac.uk' => {
    'password' => sha1_base64('mah79@2b996589fd60a6e63d154d6d33fe9da221aa88e9.ac.uk'),
    'lab' => undef,
    'name' => 'Midori Harris',
    'orcid' => undef,
    'role' => 'admin'
  },
  'other.tester@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org' => {
    'password' => sha1_base64('other.tester@3926fef56bb23eb871ee91dc2e3fdd7c46ef1385.org'),
    'lab' => 'Tester Lab',
    'name' => 'Other Tester',
    'orcid' => undef,
    'role' => 'user'
  },
  'iwasaki@5dc5820a3f5d0bc801f1b5cb0a918486b43aa25a.yokohama-cu.ac.jp' => {
    'password' => sha1_base64('iwasaki@5dc5820a3f5d0bc801f1b5cb0a918486b43aa25a.yokohama-cu.ac.jp'),
    'lab' => '岩崎ひろし Lab',
    'name' => '岩崎ひろし',
    'orcid' => undef,
    'role' => 'user'
  },
  'Nicholas.Willis@2c0e6282230890808f2298475c741b2d2f44de03.edu' => {
    'password' => sha1_base64('Nicholas.Willis@2c0e6282230890808f2298475c741b2d2f44de03.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Nicholas Willis',
    'orcid' => undef,
    'role' => 'user'
  },
  'stuart.macneill@5d99f83194201e89dc3a1241ff1fb7381be5a4be.ac.uk' => {
    'password' => sha1_base64('stuart.macneill@5d99f83194201e89dc3a1241ff1fb7381be5a4be.ac.uk'),
    'lab' => 'Macneill Lab',
    'name' => 'Stuart Macneill',
    'orcid' => undef,
    'role' => 'user'
  },
  'nick.rhind@2c0e6282230890808f2298475c741b2d2f44de03.edu' => {
    'password' => sha1_base64('nick.rhind@2c0e6282230890808f2298475c741b2d2f44de03.edu'),
    'lab' => 'Rhind Lab',
    'name' => 'Nick Rhind',
    'orcid' => undef,
    'role' => 'user'
  },
  'Luis.Rokeach@5b066279c6c138f5b3b17bfa37986c8cfad042c4.ca' => {
    'password' => sha1_base64('Luis.Rokeach@5b066279c6c138f5b3b17bfa37986c8cfad042c4.ca'),
    'lab' => 'Rokeach Lab',
    'name' => 'Luis Rokeach',
    'orcid' => undef,
    'role' => 'user'
  },
  'wahlswaynep@2c2aecc4ae15f550b3602b69113f1dedb9337ab1.edu' => {
    'password' => sha1_base64('wahlswaynep@2c2aecc4ae15f550b3602b69113f1dedb9337ab1.edu'),
    'lab' => 'Wahls Lab',
    'name' => 'Wayne Wahls',
    'orcid' => undef,
    'role' => 'user'
  },
  'John.Burg@38f4cb0f29557aca4b0422facb7de6f798ad031a.edu' => {
    'password' => sha1_base64('John.Burg@38f4cb0f29557aca4b0422facb7de6f798ad031a.edu'),
    'lab' => 'Espenshade Lab',
    'name' => 'John Burg',
    'orcid' => undef,
    'role' => 'user'
  },
  'a.nilsson@3416497253c29354cb08ec29abe683fc296c35b3.ac.uk' => {
    'password' => sha1_base64('a.nilsson@3416497253c29354cb08ec29abe683fc296c35b3.ac.uk'),
    'lab' => undef,
    'name' => 'Antonia Nilsson',
    'orcid' => undef,
    'role' => 'admin',
  },
);

my %expected_labs = (

  'Wahls Lab' => {
    'head' => 'Wayne Wahls'
  },
  'Testperson Lab' => {
    'head' => 'Some Testperson'
  },
  'Macneill Lab' => {
    'head' => 'Stuart Macneill'
  },
  'Rokeach Lab' => {
    'head' => 'Luis Rokeach'
  },
  'Rhind Lab' => {
    'head' => 'Nick Rhind'
  },
  'Hoffman Lab' => {
    'head' => 'Charles Hoffman'
  },
  'Espenshade Lab' => {
    'head' => 'Peter Espenshade'
  },
  'User Lab' => {
    'head' => 'Test User'
  },
  'Tester Lab' => {
    'head' => 'Other Tester'
  },
  'Yamano Lab' => {
    'head' => 'Hiro Yamano'
  },
  'Hardwick Lab' => {
    'head' => 'Kevin Hardwick'
  },
  '岩崎ひろし Lab', => {
    'head' => '岩崎ひろし',
  },
  'Winston Lab' => {
    'head' => 'Fred Winston'
  },
);

my @expected_pubs =
  qw"PMID:16641370 PMID:17304215 PMID:18426916 PMID:18430926 PMID:18556659
     PMID:19037101 PMID:19041767 PMID:19056896 PMID:19160458 PMID:19211838
     PMID:19351719 PMID:19436749 PMID:19627505 PMID:19664060 PMID:19686603
     PMID:19756689 PMID:20622008 PMID:20870879 PMID:20976105 PMID:7518718
     PMID:7958849 PMID:10467002 PMID:21801748";
my %expected_pubs = ();
@expected_pubs{@expected_pubs} = (ignore()) x @expected_pubs;

my $full_expected_track_data =
  {
    publications => \%expected_pubs,
    curation_sessions => {
      aaaa0007 => {
        %$full_expected_curation_session,
      },
      aaaa0006 => ignore(),
    },
    people => \%expected_people,
    labs => \%expected_labs,
  };

my $small_expected_track_data =
  {
    publications => \%expected_pubs,
    curation_sessions => {
      aaaa0007 => {
        %$small_expected_curation_session,
      },
      aaaa0006 => ignore(),
    },
    people => \%expected_people,
    labs => \%expected_labs,
  };


{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007', { all_data => 1 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $full_expected_curation_session);
}

{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007', { all_data => 0 });
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

{
  my $curs_json = Canto::Curs::Serialise::json($config, $track_schema,
                                                'aaaa0007');
  my $curs_ref = decode_json($curs_json);

  cmp_deeply($curs_ref, $small_expected_curation_session);
}

sub check_track {
  my $options = shift;
  my ($count, $track_json) = Canto::Track::Serialise::json($config, $track_schema, $options);

  my $track_ref = decode_json(encode("utf8", $track_json));

  cmp_deeply($track_ref, $full_expected_track_data);

  my %curation_sessions = %{$track_ref->{curation_sessions}};
  is (keys %curation_sessions, 2);

  my $curation_session = $curation_sessions{aaaa0007};

  cmp_deeply($curation_session, { %$full_expected_curation_session });
}

check_track({ all_data => 1 });
