require 'net/smtp'

module Net
  class SMTP
    # only a merging 1 part
    def send_merge_message( msgstr, from_addr, verp = true,  to_addrs_with_variables = [])      
      raise IOError, 'closed session' unless @socket
      xmrg_from from_addr, verp
      to_addrs_with_variables.each do |addr|
        xmrg_to addr[:address], addr[:variables]
      end
      
      # With mail merge, we don't send DATA command, we send XPRT command
      res = critical {
        check_continue get_response('XPRT 1 LAST')
        @socket.write_message msgstr
        recv_response()
      }
      check_response res
      res
    end
    
    private
    def xmrg_from(fromaddr, verp)
      if $SAFE > 0
        raise SecurityError, 'tainted from_addr' if from_addr.tainted?
      end
      if verp
        getok("XMRG FROM:<#{fromaddr}> VERP")
      else
        getok("XMRG FROM:<#{fromaddr}>")
      end
    end
    
    def xmrg_to(to, variables = {})
      return unless to
      variables ||= {}
      variables.merge!("*parts" => "1") unless variables["*parts"]
      variables.each do |key,value|
        getok("XDFN #{key.to_s}=\"#{value.to_s}\"")
      end   
      begin   
        getok("RCPT TO:<#{to}>")
      rescue
        #puts "Bad address: #{to}. #{$!}"
      end
    end
  end
end