class SourceServer
  @challenge_number = nil
  @ip_address = nil
  @map_name = ""
  @ping = nil
  @port_number = nil
  @server_name = nil
  @socket = nil
  
  def initialize(ip_address, port_number = 27015)
    unless ip_address.is_a? IPAddr
      raise TypeError("The IP address has to be of type IPAddr")
    end
    
    unless port_number.is_a? Numeric and port_number > 0
      raise TypeError("The listening port of the server has to be a number greater than 0.")
    end
    
    @ip_address = ip_address
    @port_number = port_number
    @socket = SteamSocket.new ip_address, port_number
  end
  
  def init
    get_ping
    get_server_info
    get_challenge_number
  end

  def get_player_info
    send_request A2A_PLAYER_RequestPacket.new(@challenge_number)
    @player_array = get_reply.get_player_array
  end

  def get_rules_info
    send_request A2A_RULES_RequestPacket.new(@challenge_number)
    @rules_hash = get_reply.get_rules_hash
  end
  
  def get_server_info
    send_request A2A_INFO_RequestPacket.new
    parse_server_info get_reply
  end
  
  private

  def get_challenge_number
    send_request A2A_SERVERQUERY_GETCHALLENGE_RequestPacket.new
    @challenge_number = get_reply.get_challenge_number    
  end
 
  def get_ping
    send_request A2A_PING_RequestPacket.new
    start_time = Time.now
    get_reply
    end_time = Time.now
    return @ping = (end_time - start_time) * 1000
  end

  def get_reply
    @socket.get_reply
  end
  
  def parse_server_info(info_response)
    @map_name = info_response.get_map_name
    @server_name = info_response.get_server_name
  end
  
  def send_request packet
    @socket.send packet
  end
end