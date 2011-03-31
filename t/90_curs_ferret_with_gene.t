use strict;
use warnings;
use Test::More tests => 17;

use Data::Compare;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use HTTP::Cookies;

use PomCur::TestUtil;
use PomCur::Controller::Curs;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('curs_annotations_1');

my $config = $test_util->config();
my $track_schema = $test_util->track_schema();
my @curs_objects = $track_schema->resultset('Curs')->all();
is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();
my $curs_schema = PomCur::Curs::get_schema_for_key($config, $curs_key);

my $app = $test_util->plack_app()->{app};

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $term_id = 'GO:0080170';
  my $new_annotation_re =
    qr/<td>\s*SPCC1739.10\s*<\/td>.*$term_id.*IPI.*cdc11/s;

  my $annotation_evidence_url = "$root_url/annotation/evidence/3";
  my $annotation_with_gene_url = "$root_url/annotation/with_gene/3";

  {
    my $uri = new URI("$root_url");
    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    # make sure we actually change the list of annotations later
    unlike ($res->content(), $new_annotation_re);

    # and make sure we have the right test data set
    like ($res->content(),
          qr/SPAC3A11.14c.*pkl1.*GO:0030133/s);
  }

  # test proceeding after choosing a term
  {
    my $term_id = 'GO:0080170';
    my $uri = new URI("$root_url/annotation/edit/2/biological_process");
    $uri->query_form('ferret-term-id' => $term_id,
                     'ferret-submit' => 'Proceed',
                     'ferret-term-entry' => 'transport');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_evidence_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Choose evidence for $term_id/);
  }

  # test adding evidence to an annotation
  {
    my $uri = new URI($annotation_evidence_url);
    $uri->query_form('evidence-select' => 'IPI',
                     'evidence-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, $annotation_with_gene_url);

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);
  }

  # test setting "with gene"
  {
    my $uri = new URI($annotation_with_gene_url);
    $uri->query_form('with-gene-select' => 'SPCC1739.11c',
                     'with-gene-proceed' => 'Proceed');

    my $req = HTTP::Request->new(GET => $uri);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url/annotation/transfer/3");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(),
          qr/Select the genes to transfer the annotation to/);
  }

  # test transferring annotation
  {
    my $cdc11 = $curs_schema->find_with_type('Gene',
                                              { primary_name => 'cdc11' });
    my $gene_2 =
      $curs_schema->find_with_type('Gene',
                                   { primary_identifier => 'SPAC3A11.14c' });

    my $an_rs = $curs_schema->resultset('Annotation');
    is ($an_rs->count(), 3);

    my $uri = new URI("$root_url/annotation/transfer/3");
    $uri->query_form('transfer' => 'transfer-submit',
                     dest => [$cdc11->gene_id(), $gene_2->gene_id()]);

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    is ($redirect_url, "$root_url");

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), $new_annotation_re);

    is ($an_rs->count(), 5);

    like ($redirect_res->content(), $new_annotation_re);
  }
};

done_testing;
