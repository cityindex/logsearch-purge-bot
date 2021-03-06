#!/usr/bin/env ruby

require 'json'
require 'base64'
require 'tempfile'
require 'pty'

def get_service_credentials(service_name)
	vcap_services = JSON.parse(ENV['VCAP_SERVICES'])
	named_services = vcap_services['user-provided'].select { |item| item['name']==service_name }
	named_services[0]['credentials'] 
end

def write_to_tmp_file(contents)
	file = Tempfile.new('start_ssh_tunnel')
  	file.write(contents)
  	file.close
  	File.chmod(0600, file.path)
  	file.path
end

puts "----> Extracting SSH credentials from ENV['VCAP_SERVICES']"

credentials = get_service_credentials('logsearch-ppe-ssh_tunnel')
uri = credentials["uri"]
ssh_private_key_path = write_to_tmp_file(Base64.decode64(credentials["ssh_private_key_base64"]))
ssh_known_hosts_path = write_to_tmp_file(Base64.decode64(credentials["ssh_known_hosts_base64"]))

puts "----> Starting tunnel..."
tunnel = ARGV[0]
cmd = "ssh -v -N #{tunnel} #{uri} -i #{ssh_private_key_path}  -o UserKnownHostsFile=#{ssh_known_hosts_path}"
puts "executing #{cmd}"

PTY.spawn( cmd ) do |stdout_and_err, stdin, pid| 
	begin
	  stdout_and_err.each do |line| 
	  	print line
	  end
	rescue Errno::EIO
		#ignore - see http://stackoverflow.com/questions/10238298/ruby-on-linux-pty-goes-away-without-eof-raises-errnoeio
	ensure
		Process.wait(pid)
	end
end
