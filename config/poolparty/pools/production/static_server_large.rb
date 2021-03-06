cloud :worker_server_v2 do
  # basic settings
  using :ec2
  keypair "~/Documents/AWS/FR2/gpoEC2.pem"
  user "ubuntu"
  image_id "ami-7d43ae14" #Basic Static Server
  availability_zones ['us-east-1d']
  instances 1
  #instance_type 'm1.small'
  instance_type 'c1.xlarge'
  
  #attach the ebs volumes
  # ebs_volumes do
  #   size 80
  #   device "/dev/sdh"
  # end
  
  chef :solo do
    repo File.join(File.dirname(__FILE__) ,"..", "..", "..", "..", "vendor", "plugins")
    
    recipe "apt"
    recipe 's3sync'
    recipe "ubuntu"
    #recipe "openssl"
    #recipe "imagemagick"
    #recipe "postfix"

    #recipe 'princexml'
    #recipe 'monit'

    #recipe "mysql::client"

    #recipe "nginx"
    
    #recipe "apache2"
    #recipe "php::php5"
    #recipe "passenger_enterprise::apache2"
    
    #recipe 'rubygems'
    
    #recipe "git"
    #recipe "capistrano"
    #recipe "rails"
    #recipe "redis"
    #recipe "resque_web"

    #recipe "iodocs"
    
    attributes chef_cloud_attributes('production').recursive_merge(
      :chef    => {
                    :roles => ['static', 'worker', 'blog', 'my_fr2', "iodocs"]
                  },
      :nginx   => {
                    :varnish_proxy => false,
                    :gzip          => 'off',
                    :listen_port   => '8080',
                    :doc_root      => '/var/www/apps/fr2/current/public'
                  },
      :aws     => {
                     :ebs => { :volume_id => "vol-784f6b11" }
                  },
      :sphinx  => {
                    :server_address => 'sphinx.fr2.ec2.internal'
                  },
      :apache => { 
                   :server_aliases => "www.#{@app_url}",
                   :listen_ports   => ['80'],
                   :vhost_port     => '80',
                   :docroot        => '/var/www/apps/fr2_blog/public',
                   :name           => 'fr2_blog',
                   :enable_mods    => ["rewrite", "deflate", "expires"]
                 },
      :resque_web => {  
                      :password => @resque_web_password
                     },
      #:god => {
          #:bin_path => '/opt/ruby-enterprise/bin/god',
          #:domain => 'federalregister.gov',
          #:email_name => 'info',
          #:email_domain => 'criticaljuncture.org',
          #:monitor => [{:name => 'resque', :options => {:queue => 'fr_index', :queue_count => 2, :interval => 1.0}}]
        #}
      
      :monit => {
            :check_interval => 30,
            :mail_from_address => "monit-#{@rails_env}@federalregister.gov",
            :alert_to_address => 'info@criticaljuncture.org',
            :monitors => [
                          {:name => 'resque_worker_fr_index',
                           :monitor_type => 'resque',
                           :options => {:queue => 'fr_index_pdf_previewer,fr_index_pdf_publisher',
                                        :queue_count => 2,
                                        :interval => 1,
                                        :app_path => "/var/www/apps/#{@app[:name]}/current",
                                        :total_mem => "500 MB",
                                        :total_mem_cycles => "10"
                                       }
                          },
                          {:name => 'redis',
                           :monitor_type => 'redis',
                           :options => {:host => '127.0.0.1',
                                        :port => 6379,
                                        :total_mem => '200 MB',
                                        :total_mem_cycles => 5,
                                        :max_children => 255,
                                        :max_children_cycles => 5,
                                        :max_cpu_percent => '95%',
                                        :max_cpu_percent_cycles => 5,
                                       }
                          }
                         ]
          }

    )
  end
  
  security_group "static" do
    authorize :from_port => "22", :to_port => "22"
    #authorize :from_port => "8080", :to_port => "8080"
  end
  security_group "worker"
end
