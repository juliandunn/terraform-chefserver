#!/bin/sh

curl -s https://packagecloud.io/install/repositories/chef/current/script.rpm.sh | sh
yum -y install chef-server-core

cat <<EOF > /etc/opscode/chef-server.rb
topology "aws"

aws_access_key_id "${aws_access_key}"
aws_secret_access_key "${aws_secret_access_key}"
s3_bucket "${s3_bucket}"
rds_endpoint "${rds_endpoint}"
rds_username "${rds_username}"
rds_password "${rds_password}"

# TODO move into topology definition
opscode_erchef['search_provider'] = 'elasticsearch'
opscode_erchef['search_queue_mode'] = 'batch'
opscode_expander['enable'] = false
opscode_solr4['external'] = true
opscode_solr4['external_url] = "${elasticsearch_url}"
rabbitmq['enable'] = false

EOF

mkdir /var/opt/opscode/chef-ha-aws

cat <<EOF > /var/opt/opscode/chef-ha-aws/chef-ha-aws-extension.rb
configure = lambda do
  postgresql['external'] = true
  postgresql['vip'] = PrivateChef['rds_endpoint']
  postgresql['db_superuser'] = PrivateChef['rds_username']
  postgresql['db_superuser_password'] = PrivateChef['rds_password']

  # Required for Bookshelf
  bookshelf['enable'] = false
  nginx['x_forwarded_proto'] = "https"
  bookshelf['vip'] = "s3-external-1.amazonaws.com"
  bookshelf['external_url'] = "https://s3-external-1.amazonaws.com"
  bookshelf['access_key_id'] = PrivateChef['aws_access_key_id']
  bookshelf['secret_access_key'] = PrivateChef['aws_secret_access_key']
  opscode_erchef['s3_bucket'] = PrivateChef['s3_bucket']

  #
  # A lot of cookbook logic doesn't yet understand non-standard
  # topologies. Resetting this to standalone ensures bootstrapping
  # happens correctly until all the helpers are fixed.
  #
  PrivateChef['topology'] = 'standalone'
  default_gen_api_fqdn
end

PrivateChef.register_extension("aws", {
                                 :server_config_required => false,
                                 :gen_api_fqdn => configure,
                                 :config_values => {
                                   :aws_access_key_id => nil,
                                   :aws_secret_access_key => nil,
                                   :s3_bucket => nil,
                                   :rds_endpoint => nil,
                                   :rds_username => nil,
                                   :rds_password => nil
                                 }
                               })
EOF

cat <<EOF > /var/opt/opscode/plugins/chef-ha-aws.rb
plugin 'chef-ha-aws' do
  enabled_by_default false
  cookbook_path '/opt/opscode/embedded/cookbooks'
  config_extension_path '/var/opt/opscode/chef-ha-aws/chef-ha-aws-extension.rb'
end
EOF

# Not sure what this is yet
mkdir -p /opt/opscode/embedded/cookbooks/chef-ha-aws/recipes
touch /opt/opscode/embedded/cookbooks/chef-ha-aws/recipes/{enable,disable}.rb

# Start 'er up
chef-server-ctl reconfigure
