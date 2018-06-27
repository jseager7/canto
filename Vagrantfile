require 'yaml'
settings = YAML.load_file './vagrant_config.yaml'

$canto_setup_script = <<-SCRIPT
  # Go to the Canto source directory.
  cd /home/canto/canto-master

  # Initialise the Canto data directory.
  ./script/canto_start --initialise /var/canto-data
  
  # Canto won't start unless the user running the script has permissions on
  # the database.
  chown -R canto:canto /var/canto-data
SCRIPT

$ontology_loading_script = <<-SCRIPT
  # Load ontologies from Gene Ontology, FYPO, and PSI-MOD.
  cd /home/canto/canto-master
  ./script/canto_load.pl \
    --ontology http://snapshot.geneontology.org/ontology/go-basic.obo \
    --ontology http://curation.pombase.org/ontologies/fypo/latest/fypo-simple.obo \
    --ontology http://curation.pombase.org/ontologies/PSI-MOD-2016-01-19.obo
SCRIPT

Vagrant.configure("2") do |config|

  config.vm.box = "canto"
  config.vm.box_url = settings['box_url']

  config.vm.network "forwarded_port", guest: 5000, host: 5000

  config.vm.synced_folder ".", "/home/canto/canto-master",
    owner: "root"

  # Disable the default synced folder, since the working directory is already
  # synced somewhere else.
  config.vm.synced_folder ".", "/vagrant",
    disabled: true

  config.vm.provision "canto",
    type: "shell",
    inline: $canto_setup_script

  config.vm.provision "ontologies",
    type: "shell",
    inline: $ontology_loading_script,
    # If ontology loading is disabled, it can still be run manually with:
    # $ vagrant provision --provision-with ontologies
    run: settings['load_ontologies'] ? "once" : "never"

  config.ssh.username = "canto"
  config.ssh.password = "canto"
end
