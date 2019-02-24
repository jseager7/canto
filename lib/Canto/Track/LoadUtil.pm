package Canto::Track::LoadUtil;

=head1 NAME

Canto::Track::LoadUtil -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::LoadUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;
use Digest::SHA qw(sha1_base64);
use Try::Tiny;
use JSON;

use feature qw(state);

use Package::Alias PubmedUtil => 'Canto::Track::PubmedUtil';

use Canto::Curs::GeneManager;
use Canto::Curs::AlleleManager;
use Canto::Curs::GenotypeManager;

use Canto::Track;

has 'schema' => (
  is => 'ro',
  isa => 'Canto::TrackDB',
  required => 1,
);

has 'default_db_name' => (
  is => 'ro'
);

has 'preload_cache' => (
  is => 'ro',
);

has 'cache' => (
  is => 'ro', init_arg => undef,
  lazy_build => 1,
);

sub _build_cache
{
  my $self = shift;

  my $cache = {
    cv => {},
    cvterm => {},
    dbxref => {},
  };

  if ($self->preload_cache()) {
    $self->_preload_dbxref_cache($cache);
  }

  return $cache;
}

=head2 get_organism

 Usage   : my $organism = $load_util->get_organism($scientific_name, $taxonid);
       OR: my $organism = $load_util->get_organism($scientific_name, $taxonid, $common_name);
 Function: Find or create, and then return the organism matching the arguments
 Returns : The found or new organism

=cut
sub get_organism
{
  my $self = shift;

  my $scientific_name = shift;
  my $taxonid = shift;
  my $common_name = shift;

  croak "no taxon id supplied" unless $taxonid;

  croak "taxon id not a number: $taxonid" unless $taxonid =~ /^\d+$/;

  my $schema = $self->schema();

  my $new_org =
    $schema->resultset('Organism')->find_or_create(
      {
        scientific_name => $scientific_name,
        organismprops => [ { value => $taxonid,
                             type => { name => 'taxon_id' },
                             rank => 0 } ]
      });

  if ($common_name && !defined $new_org->common_name()) {
    $new_org->common_name($common_name);
    $new_org->update();
  }

  return $new_org;
}

=head2 find_organism_by_taxonid

 Usage   : my $organism = $load_util->find_organism_by_taxonid($taxonid);
 Function: Find and return the organism with the given taxonid
 Returns : the organism object or undef

=cut
sub find_organism_by_taxonid
{
  my $self = shift;

  my $taxonid = shift;

  croak "no taxon id supplied" unless $taxonid;

  if ($taxonid !~ /^\d+$/) {
    die qq(taxon ID "$taxonid" isn't numeric\n);
  }

  my $schema = $self->schema();

  my $organismprop_rs = $schema->resultset('Organismprop')->search();

  while (defined (my $prop = $organismprop_rs->next())) {
    if ($prop->type()->name() eq 'taxon_id' &&
        $prop->value() == $taxonid) {
      return $prop->organism();
    }
  }

  return undef;
}

=head2 get_strain

 Usage   : my $strain = $load_util->get_strain($organism_obj, $strain);
 Function: Find or create, and then return a new strain object
 Args    : a organism object and the strain description

=cut
sub get_strain
{
  my $self = shift;
  my $organism = shift;
  my $strain = shift;

  croak "no strain supplied" unless $strain;

  my $schema = $self->schema();

  return $schema->resultset('Strain')->find_or_create(
      {
        organism_id => $organism->organism_id(),
        strain_name => $strain,
      });
}

=head2 find_cv

 Usage   : my $cv = $load_util->find_cv($cv_name);
 Function: Find and return the cv object matching the arguments
 Args    : $cv_name - the cv name
 Returns : The CV or calls die()

=cut
sub find_cv
{
  my $self = shift;
  my $cv_name = shift;

  my $schema = $self->schema();

  croak "no cv name supplied" unless defined $cv_name;

  my $cv_cache = $self->cache()->{cv};

  my $cv = $cv_cache->{$cv_name};

  if (defined $cv) {
    return $cv;
  }

  $cv = $schema->resultset('Cv')->find(
      {
        name => $cv_name
      });

  if (defined $cv) {
    $cv_cache->{$cv_name} = $cv;

    return $cv;
  } else {
    croak "no CV found for: $cv_name";
  }
}

=head2 find_or_create_cv

 Usage   : my $cv = $load_util->find_or_create_cv($cv_name);
 Function: Find or create, and then return the cv object matching the arguments.
           The Cv object is cached
 Args    : $cv_name - the cv name
 Returns : The new CV

=cut
sub find_or_create_cv
{
  my $self = shift;
  my $cv_name = shift;

  if (!defined $cv_name) {
    croak "no cv name passed to find_or_create_cv()";
  }

  if (exists $self->cache()->{cv}->{$cv_name}) {
    return $self->cache()->{cv}->{$cv_name};
  } else {
    my $cv = $self->schema()->resultset('Cv')->find_or_create(
      {
        name => $cv_name
      });
    $self->cache()->{cv}->{$cv_name} = $cv;
    return $cv;
  }
}


=head2 find_db

 Usage   : my $db = $load_util->find_db()
 Function: Find then return the db object for the db_name
 Args    : db_nam
 Returns : the Db object

=cut
sub find_db
{
  my $self = shift;
  my $db_name = shift;

  my $schema = $self->schema();

  my $db = $schema->resultset('Db')->find(
      {
        name => $db_name,
      });

  if (defined $db) {
    return $db;
  } else {
    croak "no Db found for $db_name";
  }
}

=head2 find_dbxref

 Usage   : my $dbxref = $load_util->find_dbxref()
 Function: Find then return the dbxref object matching the arguments
 Args    : termid - "db_name:accession" eg. GO:0055085
 Returns : the Dbxref object

=cut
sub find_dbxref
{
  my $self = shift;
  my $termid = shift;

  my ($db_name, $dbxref_acc) = $termid =~ /^(.*?):(.*)/;

  if (!defined $db_name) {
    croak qq(dbxref "$termid" not in the form: <DB_NAME>:<ACCESSION>);
  }

  my $schema = $self->schema();

  my @dbxrefs = $schema->resultset('Db')->search({ name => $db_name })
    ->search_related('dbxrefs', { accession => $dbxref_acc })->all();

  if (@dbxrefs > 1) {
    croak "internal error: looking up $termid returned more than one result";
  }

  if (@dbxrefs == 1) {
    return $dbxrefs[0];
  } else {
    croak "no Dbxref found for $termid";
  }
}

=head2 find_cvterm

 Usage   : my $cvterm = $load_util->find_cvterm(cv => $cv,
                                                name => $cvterm_name);
 Function: Find and return the cvterm object matching the arguments
 Args    : name - the cvterm name
           cv - the Cv object
 Returns : The Cvterm or calls die()

=cut
sub find_cvterm
{
  my $self = shift;
  my %args = @_;

  my $cv = $args{cv};

  if (defined $args{cv_name}) {
    if (defined $cv) {
      croak "don't pass cv and cv_name";
    }
    $cv = $self->find_cv($args{cv_name});
  }

  my $schema = $self->schema();

  croak "no cvterm name passed" unless defined $args{name};

  my $cvterm = $schema->resultset('Cvterm')->find(
      {
        cv_id => $cv->cv_id(),
        name => $args{name}
      });

  if (defined $cvterm) {
    return $cvterm;
  } else {
    croak "no cvterm found for: $args{name}";
  }
}

=head2 get_db

 Usage   : my $db = $load_util->get_db($db_name);
 Function: Find or create, and then return the db object matching the arguments
 Returns : The new db object

=cut
sub get_db
{
  my $self = shift;
  my $db_name = shift;

  if (exists $self->cache()->{db}->{$db_name}) {
    return $self->cache()->{db}->{$db_name};
  }

  my $schema = $self->schema();

  my $db = $schema->resultset('Db')->find_or_create(
      {
        name => $db_name
      });

  $self->cache()->{db}->{$db_name} = $db;

  return $db;
}

sub _create_dbxref
{
  my $self = shift;
  my $db = shift;
  my $dbxref_acc = shift;

  my $schema = $self->schema();

  my $dbxref = $schema->resultset('Dbxref')->create(
      {
        accession => $dbxref_acc,
        db => $db
      });

  my $termid = $db->name() . ':' .$dbxref_acc;

  $self->cache()->{dbxref}->{$termid} = $dbxref;

  return $dbxref;
}

sub _preload_dbxref_cache
{
  my $self = shift;
  my $cache = shift;

  my $dbxref_rs = $self->schema()->resultset('Dbxref')
    ->search({}, { prefetch => 'db' });

  for my $dbxref ($dbxref_rs->all()) {
    $cache->{dbxref}->{$dbxref->db_accession()} = $dbxref;
  }
}

=head2 get_dbxref_by_accession

 Usage   : my $dbxref = $load_util->get_dbxref($db, $dbxref_acc, $term_name,
                                               $create_only);
 Function: Find or create, and then return the object matching the arguments
 Args    : $dbxref_acc - the term ID eg. "GO:0055085"
           $term_name - the term name, used as the accession if the $dbxref_acc
                        is undef with "Canto" as the db name
           $create_only - if true, don't try to find() the dbxref before
                          creating, assume it's new
 Returns : The new dbxref object

=cut
sub get_dbxref_by_accession
{
  my $self = shift;
  my $termid = shift;
  my $term_name = shift;
  my $create_only = shift;

  my $db_name;
  my $accession;

  if (defined $termid) {
    if ($termid =~ /(.*):(.*)/) {
      $db_name = $1;
      $accession = $2
    } else {
      $db_name = 'Canto';
      $accession = $termid;
    }
  } else {
    if (defined $term_name) {
      $db_name = 'Canto';
      $accession = $term_name;
    } else {
      croak "no termid or term_name passed to get_dbxref_by_accession()";
    }
  }

  my $key = "$db_name:$accession";

  if (!$create_only) {
    if (exists $self->cache()->{dbxref}->{$key}) {
      return $self->cache()->{dbxref}->{$key};
    } else {
      my $dbxref = undef;

      try {
        $dbxref = $self->find_dbxref($key);
        $self->cache()->{dbxref}->{$key} = $dbxref;
      } catch {
        # fall through - dbxref not in DB
      };

      if (defined $dbxref) {
        return $dbxref;
      }
    }
  }
  my $db = $self->get_db($db_name);
  my $dbxref = $self->_create_dbxref($db, $accession);

  $self->cache()->{dbxref}->{$key} = $dbxref;

  return $dbxref;
}

=head2 get_cvterm

 Usage   : my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                               term_name => $term_name,
                                               ontologyid => $ontologyid,
                                               definition => $definition,
                                               create_only => $create_only);
 Function: Find or create, and then return the object matching the arguments.
           The result is cached using the cv_name and term_name.
 Args    : cv_name - the Cv name
           term_name - the cvterm name
           ontologyid - the id in the ontology, eg. "GO:0001234"
           definition - the term definition
           alt_ids - an array ref of alternate ontology IDs for this
                     term
           create_only - if true, don't try to find() the cvterm before
                         creating, assume it's new
 Returns : The new cvterm object

=cut
sub get_cvterm
{
  my $self = shift;

  my %args = @_;

  my $cv_name = $args{cv_name};
  my $cv = $args{cv};

  if (!defined $cv_name && !defined $cv) {
    croak "no cv_name or cv passed to get_cvterm()";
  }

  if (defined $cv) {
    $cv_name = $cv->name();
  } else {
    $cv = $self->find_or_create_cv($cv_name);
  }
  my $term_name = $args{term_name};

  if (!defined $term_name) {
    confess "no term name passed to get_cvterm() for $cv_name";
  }

  my $ontologyid = $args{ontologyid};
  my $create_only = $args{create_only} && $ontologyid;
  my $key = "$cv_name--$term_name";
  my $cvterm_cache = $self->cache()->{cvterm};
  my $cached_cvterm = $cvterm_cache->{$key};

  if (defined $cached_cvterm) {
    return $cached_cvterm;
  }

  my $definition = $args{definition};
  my $is_relationshiptype = $args{is_relationshiptype} // 0;
  my $is_obsolete = $args{is_obsolete} // 0;

  my $dbxref = $self->get_dbxref_by_accession($ontologyid, $term_name, $create_only);

  my $schema = $self->schema();

  my %create_args = (
    name => $term_name,
    cv => $cv,
    dbxref => $dbxref,
    is_relationshiptype => $is_relationshiptype,
    is_obsolete => $is_obsolete,
  );

  if (defined $definition) {
    $create_args{definition} = $definition;
  }

  my $cvterm;

  if ($create_only) {
    $cvterm = $self->schema()->resultset('Cvterm')->create({
      %create_args
    });
  } else {
    $cvterm = $self->schema()->resultset('Cvterm')->find_or_create({
      %create_args
    });
  }

  if (defined $args{alt_ids}) {
    for my $alt_id (@{$args{alt_ids}}) {
      my $alt_dbxref = $self->get_dbxref_by_accession($alt_id);

      $self->schema()->resultset('CvtermDbxref')->create({
        dbxref_id => $alt_dbxref->dbxref_id(),
        cvterm_id => $cvterm->cvterm_id(),
      });
    }
  }

  $cvterm_cache->{$key} = $cvterm;

  return $cvterm;
}

=head2 get_pub

 Usage   : my $pub = $load_util->get_pub($uniquename);
 Function: Find or create, and then return the object matching the arguments
 Args    : $uniquename - the PubMed ID
           $load_type - a cvterm from the "Publication load types" CV that
                        records who is loading this publication
 Returns : The new pub object

=cut
sub get_pub
{
  my $self = shift;
  my $uniquename = shift;
  my $load_type = shift;

  if (!defined $load_type) {
    croak("no load_type passed to get_pub()");
  }

  my $schema = $self->schema();

  state $load_type_cv = $self->find_cv('Canto publication load types');
  state $load_type_term = $self->find_cvterm(cv => $load_type_cv,
                                             name => $load_type);

  state $pub_type_cv = $self->find_cv('Canto publication type');
  state $pub_type = $self->find_cvterm(cv => $pub_type_cv,
                                       name => 'unknown');

  state $pub_status_cv = $self->find_cv('Canto publication triage status');
  state $pub_new_status = $self->find_cvterm(cv => $pub_status_cv,
                                             name => 'New');

  return $schema->resultset('Pub')->find_or_create(
      {
        uniquename => $uniquename,
        type => $pub_type,
        triage_status => $pub_new_status,
        load_type => $load_type_term,
      });
}

=head2 get_lab

 Usage   : my $lab = $load_util->get_lab($lab_head_obj);
 Function: Find or create, and then return the object matching the arguments
 Args    : $lab_head_obj - the Person object for the lab head
 Returns : The new lab object

=cut
sub get_lab
{
  my $self = shift;
  my $lab_head = shift;

  my $schema = $self->schema();

  my $lab_head_name = $lab_head->name();

  (my $lab_head_surname = $lab_head_name) =~ s/.* //;

  return $schema->resultset('Lab')->find_or_create(
      {
        lab_head => $lab_head,
        name => "$lab_head_surname Lab"
      });
}

=head2 get_person

 Usage   : my $person = $load_util->get_person($name, $email_address,
                                               $role_cvterm);
 Function: Find or create, and then return the object matching the arguments
 Args    : $name - the Person full name
           $email_address - the email address
           $role_cvterm - a cvterm from the user types cv
 Returns : The new person object

=cut
sub get_person
{
  my $self = shift;
  my $name = shift;
  my $email_address = shift;
  my $role_cvterm = shift;
  my $password = shift;
  my $orcid = shift;

  my $schema = $self->schema();

  if (!defined $email_address || length $email_address == 0) {
    die "email not set for $name\n";
  }
  if (!defined $name || length $name == 0) {
    die "name not set for $email_address\n";
  }
  if (!defined $password) {
    die "no password passed to get_person()\n";
  }
  if (!$password) {
    die "empty password passed to get_person()\n";
  }

  my $hashed_password = sha1_base64($password);

  my %args = (
    name => $name,
    email_address => $email_address,
    password => $hashed_password,
    role => $role_cvterm,
  );

  if ($orcid) {
    $args{orcid} = $orcid;
  }

  return $schema->resultset('Person')->find_or_create(\%args);
}

=head2 create_user_session

 Usage   : my ($curs, $cursdb, $curator) =
             $load_util->create_user_session($config, $pubmedid, $email_address);
 Function: Create a session for a publication and set the curator.  If the
           publication has no corresponding_author, set it to the curator.
 Args    : $config - the Config object
           $pub_uniquename - a PubMed ID with optional "PMID:" prefix
           $email_address - the email address of the user to curate the session
 Return  : The Curs object from the Track database, the CursDB object and the
           Person object for the email_address.

=cut
sub create_user_session
{
  my $self = shift;
  my $config = shift;
  my $pub_uniquename = shift;
  my $email_address = shift;

  if ($pub_uniquename =~ /^\d+$/) {
    $pub_uniquename = "PMID:$pub_uniquename";
  }

  my ($curs, $cursdb) =
    Canto::Track::create_curs($config, $self->schema(), $pub_uniquename);

  my $person = $self->schema()->resultset('Person')->find_or_create({
    email_address => $email_address,
  });

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

  $curator_manager->set_curator($curs->curs_key(), $email_address);

  return ($curs, $cursdb, $person);
}

=head2 load_pub_from_pubmed

 Usage   : my ($pub, $err_message) = $load_util->load_pub_from_pubmed($config, $pubmed_id);
 Function: Query PubMed for the details of the given publication and store
           the results in the TrackDB
 Args    : $config - a Config file
           $pubmed_id - the ID
 Returns : ($pub_object, undef) on success
           (undef, "some error message") on failure

=cut

sub load_pub_from_pubmed
{
  my $self = shift;
  my $config = shift;
  my $pubmedid = shift;

  my $raw_pubmedid;

  $pubmedid =~ s/[^_\d\w:]+//g;

  if ($pubmedid =~ /^\s*(?:pmid:|pubmed:)?(\d+)\s*$/i) {
    $raw_pubmedid = $1;
    $pubmedid = "PMID:$1";
  } else {
    my $message = 'You need to give the raw numeric ID, or the ID ' .
      'prefixed by "PMID:" or "PubMed:"';
    return (undef, $message);
  }

  my $pub = $self->schema()->resultset('Pub')->find({ uniquename => $pubmedid });

  if (defined $pub) {
    return ($pub, undef);
  } else {
    my $xml = PubmedUtil::get_pubmed_xml_by_ids($config, $raw_pubmedid);

    my $count = PubmedUtil::load_pubmed_xml($self->schema(), $xml, 'user_load');

    if ($count) {
      $pub = $self->schema()->resultset('Pub')->find({ uniquename => $pubmedid });
      return ($pub, undef);
    } else {
      (my $numericid = $pubmedid) =~ s/.*://;
      my $message = "No publication found in PubMed with ID: $numericid";
      return (undef, $message);
    }
  }
}

=head2 create_sessions_from_json

 Usage   : my ($curs, $cursdb, $curator) =
             $load_util->create_sessions_from_json($config, $file_name, $curator_email_address);
 Function: Create sessions for the JSON data in the given file and set the curator.
 Args    : $config - the Config object
           $file_name - the JSON file,
                        see: https://github.com/pombase/canto/wiki/JSON-Import-Format
           $curator_email_address - the email address of the user to curate the session,
                                    the user must exist in the database
 Return  : The Curs object from the Track database, the CursDB object and the
           Person object for the curator_email_address.

=cut
sub create_sessions_from_json
{
  my $self = shift;
  my $config = shift;
  my $file_name = shift;
  my $curator_email_address = shift;

  my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $file_name)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
 };

  my $gene_lookup = Canto::Track::get_adaptor($config, 'gene');
  my $sessions_data = decode_json($json_text);

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

  my $curator = $self->schema()->resultset('Person')->find({
    email_address => $curator_email_address,
  });

  if (!$curator) {
    die qq|can't find user with email address "$curator_email_address" in the database\n|;
  }

  # disable connection caching so we don't run out of file descriptors
  my $connect_options = { cache_connection => 0 };

  my @results = ();

  # load the publication in batches in advance
  PubmedUtil::load_by_ids($config, $self->schema(), [keys %$sessions_data], 'admin_load');

  while (my ($pub_uniquename, $session_data) = each %$sessions_data) {
    my ($pub, $error_message) = $self->load_pub_from_pubmed($config, $pub_uniquename);

    if (!$pub) {
      die "can't get publication details for $pub_uniquename from PubMed:\n$error_message";
    }

    my ($curs, $cursdb) =
      Canto::Track::create_curs($config, $self->schema(), $pub, $connect_options);

    push @results, [$curs, $cursdb];

    my $allele_manager =
      Canto::Curs::AlleleManager->new(config => $config, curs_schema => $cursdb);
    my $genotype_manager =
      Canto::Curs::GenotypeManager->new(config => $config, curs_schema => $cursdb);
    my $gene_manager =
      Canto::Curs::GeneManager->new(config => $config, curs_schema => $cursdb);

    $curator_manager->set_curator($curs->curs_key(), $curator_email_address);

    if (!$pub->corresponding_author()) {
      $pub->corresponding_author($curator);
      $pub->update();
    }

    print "created session: ", $curs->curs_key(), " pub: ", $pub->uniquename(),
      " for: $curator_email_address\n";

    my %db_genes = ();

    for my $gene_uniquename (@{$session_data->{genes}}) {
      my $lookup_result = $gene_lookup->lookup([$gene_uniquename]);
      my %result = $gene_manager->create_genes_from_lookup($lookup_result);
      while (my ($result_uniquename, $result_gene) = each %result) {
        $db_genes{$result_uniquename} = $result_gene;
      }
    }

    my $alleles = $session_data->{alleles};

    if ($alleles) {
      while (my ($allele_uniquename, $allele_details) = each %$alleles) {
        my $allele_gene_uniquename = $allele_details->{gene};
        if (!defined $allele_gene_uniquename) {
          die qq|no "gene" field in details for $allele_uniquename in $pub_uniquename|;
        }
        my $gene = $db_genes{$allele_gene_uniquename};
        if (!defined $gene) {
          die qq|no gene the session for $allele_uniquename in $pub_uniquename|;
        }

        my $type = $allele_details->{allele_type} || 'other';
        my $name = $allele_details->{allele_name} || undef;
        my $description = $allele_details->{allele_description} || undef;
        my @args = ($allele_uniquename, $type, $name, $description, $gene);

        my @alleles_for_make_genotype =
          $allele_manager->create_simple_allele(@args);

        $genotype_manager->make_genotype(undef, undef, \@alleles_for_make_genotype,
                                         $gene->organism()->taxonid(),
                                         "genotype-$allele_uniquename");
      }
    }
  }

  return @results;
}

1;
