
def stomp_connect_hash
  host = { login:    'guest',
           passcode: 'guest',
           host:     '10.0.0.150',
           port:     61613,
           ssl:      false        }

  {hosts: [host], reliable: false}
end

def redis_connect_hash
  { host: '127.0.0.1', 
    port: 6379, 
    db: 0       }

end

