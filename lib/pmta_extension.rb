require 'net/smtp'

module Net
  class PowerMTA < Net::SMTP
    def initialize(address, port = nil)
      super(address, port)
      @xack = true
    end

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
    
    # Enable/Disable XACK to ignore ACKs from SMTP Server on multiple RCPT TO calls
    def enable_xack
      getok('XACK ON')
      @xack = true
    end
    
    def disable_xack
      getok('XACK OFF')
      @xack = false
    end
    
    private
    
    def expect_ack?(command)
      @xack || !command.match(/^(RCPT TO:|XDFN)/)
    end

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
    
    def xmrg_to(to_addr, variables = {})
      return unless to_addr
      variables ||= {}
      variables.merge!("*parts" => "1") unless variables["*parts"]
      variables.each do |key,value|
        getok("XDFN #{key.to_s}=\"#{value.to_s}\"")
      end   
      begin
        rcptto(to_addr)
      rescue
        #puts "Bad address: #{to}. #{$!}"
      end
    end
    
    def getok(reqline)
      logging "<< #{reqline}"
      res = critical {
        @socket.writeline reqline
        recv_response() if expect_ack?( reqline )
      }

      return nil unless expect_ack?( reqline )
      check_response res
      res
    end
    
    def recv_response
      buf = ''
      while true
        line = @socket.readline
        buf << line << "\n"
        break unless line[3,1] == '-'   # "210-PIPELINING"
      end
      logging ">> #{buf}"
      Response.parse(buf)
    end
    
    def get_response(reqline)
      logging "<< #{reqline}"
      @socket.writeline reqline
      recv_response()
    end
  end
end
