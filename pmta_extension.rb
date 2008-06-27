require 'net/smtp'

module Net
  class SMTP
    # only a merging 1 part
    def send_merge_message( msgstr, from_addr, verp = true,  to_addrs_with_variables = [])      
      send_merge0(from_addr, verp, to_addrs_with_variables) {
        @socket.write_message msgstr
      }
    end
    
    private
    def send_merge0( from_addr, verp, to_addrs_with_variables )
      # {"foo@bar.com" => {"subject" => "this is the subject", "the_link" => "yahoo.com"}}
      raise IOError, 'closed session' unless @socket
      raise ArgumentError, 'mail destination not given' if to_addrs_with_variables.empty?
      if $SAFE > 0
        raise SecurityError, 'tainted from_addr' if from_addr.tainted?
        to_addrs_with_variables.each do |to| 
          raise SecurityError, 'tainted to_addr' if to.tainted?
        end
      end

      xmrg_from(from_addr, verp)
      
      to_addrs_with_variables.each do |addr|
        xmrg_to addr[:address], addr[:variables]
      end
      res = critical {
        check_response(get_response('XPRT 1 LAST'), true)
        yield
        recv_response()
      }
      check_response(res)
    end
    
    def xmrg_from(fromaddr, verp)
      if verp
        getok('XMRG FROM:<%s> VERP', fromaddr)
      else
        getok('XMRG FROM:<%s>', fromaddr)
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
        getok('RCPT TO:<%s>', to)
      rescue
        #puts "Bad address: #{to}. #{$!}"
      end
    end
      
    
  end
end