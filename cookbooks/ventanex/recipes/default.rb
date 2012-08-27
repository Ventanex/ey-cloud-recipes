equire 'digest/sha1'
require 'ftools'

package "media-gfx/imagemagick"

# Need newer rubygems
rubygems_version = '1.8.17'

execute "Update RubyGems to #{rubygems_version}" do
  command %Q{ 
  sudo gem install rubygems-update -v #{rubygems_version}
  sudo sudo /usr/lib/jruby/1.6/bin/update_rubygems
  }

  not_if do
    Gem::Version.new(`gem -v`) >= Gem::Version.new(rubygems_version)
  end
end

# SetTimezones
timezone = "America/Chicago"
change_timezone = (Time.now.zone != "CDT")
service "vixie-cron"
service "sysklogd"
service "nginx"

link "/etc/localtime" do
  to "/usr/share/zoneinfo/#{timezone}"
  notifies :restart, resources(:service => ["vixie-cron", "sysklogd", "nginx"]), :delayed
  not_if "readlink /etc/localtime | grep -q '#{timezone}$'"
end

node[:applications].each do |app_name,data|
  ['trinidad.yml','env.custom'].each do |file|
    conf_file = "/data/#{app_name}/current/config/#{file}"
    ey_file = "/data/#{app_name}/shared/config/#{file}"
    copy_file = false
    if File.exists?(conf_file)
      if File.exists?(ey_file)
        copy_file = (File.symlink?(ey_file) || Digest::SHA1.file(ey_file).hexdigest != Digest::SHA1.file(conf_file).hexdigest )
        if copy_file
          Chef::Log.info "Deleting #{ey_file}"
          File.delete(ey_file)
        end
      else
        copy_file = true
      end
      if copy_file
        Chef::Log.info "Copying #{conf_file} to #{ey_file}"
        File.copy(conf_file,ey_file)
      end
    end
  end
end

trinidad_version = '1.4.0'
execute "updating trinidad gem to #{trinidad_version}" do
    command "sudo gem update trinidad; sudo monit restart trinidad_HQ; sudo gem cleanup trinidad"
     #not_if { "sudo gem list | grep -q 'trinidad (#{trinidad_version})'" }
end