require 'json'
require 'net/http'
require 'socket'
require 'openssl'

config=File.open("config.json","rt"){|f| JSON.parse(f.read)}
ip=IPSocket::getaddress(config["domain"]) 

def update_dns(ip, config)
	req = Net::HTTP::Get.new("/api2/admin/dns/list?domain=#{config["domain"]}")
	req['PddToken'] = config["token"]
	res = Net::HTTP.start("pddimp.yandex.ru", 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER ) do |http|
		http.request(req)
	end
	id=0
	JSON.parse(res.body)["records"].each do |r|
		if (r["fqdn"]==config["domain"] && r["type"]=="A") then
			id=r["record_id"]
		end
	end
	
	req = Net::HTTP::Post.new("/api2/admin/dns/edit")
	req['PddToken'] = config["token"]
	req.set_form_data({"domain"=> config["domain"], "content" => ip, "record_id"=> id})
	res = Net::HTTP.start("pddimp.yandex.ru", 443, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER ) do |http|
		http.request(req)
	end
	ans=JSON.parse(res.body)
	
	p "Error" if (ans["success"]!="ok")
	p ans["success"]
end

req = Net::HTTP::Get.new("/ping")

begin
	res = Net::HTTP.start(config["dns"]["normal"]["ip"], 80, open_timeout: 10) do |http|
		http.request(req)
	end
	#main machine works
	if (config["dns"]["normal"]["ip"]!=ip) then
		#main machine is not used
		update_dns(config["dns"]["normal"]["ip"], config)
	end
rescue Exception => e
	#machine not works
	if (config["dns"]["recovery"]["ip"]!=ip) then
		#need to change
		update_dns(config["dns"]["recovery"]["ip"], config)
	end
end