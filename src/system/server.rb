require 'webrick'
require 'tempfile'
require 'json'

class EditorServer < WEBrick::HTTPServlet::AbstractServlet

  def do_POST(request, response)
    request = JSON.parse(request.body)
    status, content_type, body = self.send(request['method'].to_sym,request)

    response.status          = status
    response['Content-Type'] = content_type
    response.body            = body
  end

  def open_editor(request)
    editor = request['editor']
    tmpfile = Tempfile.new('editor')
    tmpfile.write request['data']
    tmpfile.flush
    editor = 'gvim -f' if editor == 'gvim' # Foreground: Don't fork when starting GUI
    system("#{editor} #{tmpfile.path}")
    text = File.read(tmpfile.path)
    tmpfile.delete

    return 200, "text/plain", text
  end

  def get_configure(request)
    config_file = File.join(ENV['HOME'],'.vromerc')
    vromeConfig = {:set => {}};

    if File.exist?(config_file)
      File.read(config_file).split("\n").map do |x|
        array = x.split(/\s+/)
        case x
        when /^imap\s+/
          vromeConfig[:imap] = (vromeConfig[:imap] || []).concat([{ array[1] => array[2] }])
        when /^map\s+/
          vromeConfig[:map] = (vromeConfig[:map] || []).concat([{ array[1] => array[2] }])
        when /^cmap\s+/
          vromeConfig[:cmap] = (vromeConfig[:cmap] || []).concat([{ array[1] => array[2] }])
        when /^set\s+/
          array = x.split(/\s+/,2)
          array = array[1].split(/\+?=/,2)
          vromeConfig[:set][array[0]] = [array[1], x =~ /^set\s+\w+\+=/]
        end
      end

      return 200, "text/plain", vromeConfig.to_json
    end
  end
end

server = WEBrick::HTTPServer.new(:Port => 20000)
server.mount "/", EditorServer
trap(:INT) { server.shutdown }
server.start
