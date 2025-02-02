require "./openssl/lib_ssl"
require "./openssl/error"

# NOTE: To use `OpenSSL`, you must explicitly import it with `require "openssl"`
#
# ## OpenSSL Integration
#
# - TLS sockets need a context, potentially with keys (required for servers) and configuration.
# - TLS sockets will wrap the underlying TCP socket, and any further communication must happen through the `OpenSSL::SSL::Socket` only.
#
# ## Usage Example
#
# Recommended ciphers can be taken from:
# - [OWASP Wiki](https://www.owasp.org/index.php/Transport_Layer_Protection_Cheat_Sheet#Rule_-_Only_Support_Strong_Cryptographic_Ciphers)
# - [Cipherli.st](https://cipherli.st/)
# - A full list is available at the [OpenSSL Docs](https://www.openssl.org/docs/man1.1.0/apps/ciphers.html#CIPHER-STRINGS)
#
# Do note that:
# - Crystal does its best to provide sane configuration defaults (see [Mozilla-Intermediate](https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28default.29)).
# - Linked version of OpenSSL need to be checked for supporting specific protocols and ciphers.
# - If any configurations or choices in Crystal regarding SSL settings and security are found to be lacking or need
#   improvement please [open an issue](https://github.com/crystal-lang/crystal/issues/new) and let us know.
#
# ### Server side
#
# NOTE: For the below example to work, a key pair should be attained.
#
# ```
# require "socket"
# require "openssl"
#
# def server
#   # Bind new TCPSocket to port 5555
#   socket = TCPServer.new(5555)
#
#   context = OpenSSL::SSL::Context::Server.new
#   context.private_key = "/path/to/private.key"
#   context.certificate_chain = "/path/to/public.cert"
#
#   puts "Server is up"
#
#   socket.accept do |client|
#     puts "Got client"
#
#     bytes = Bytes.new(20)
#
#     ssl_socket = OpenSSL::SSL::Socket::Server.new(client, context)
#     ssl_socket.read(bytes)
#
#     puts String.new(bytes)
#   end
# end
# ```
#
# ### Client side
#
# ```
# require "socket"
# require "openssl"
#
# def client
#   socket = TCPSocket.new("127.0.0.1", 5555)
#   context = OpenSSL::SSL::Context::Client.new
#
#   ssl_socket = OpenSSL::SSL::Socket::Client.new(socket, context)
#   ssl_socket << "Testing"
# end
# ```
module OpenSSL
  module SSL
    alias Modes = LibSSL::Modes
    alias Options = LibSSL::Options
    alias VerifyMode = LibSSL::VerifyMode
    alias ErrorType = LibSSL::SSLError
    {% if LibCrypto.has_constant?(:X509VerifyFlags) %}
      alias X509VerifyFlags = LibCrypto::X509VerifyFlags
    {% end %}

    class Error < OpenSSL::Error
      getter error : ErrorType
      getter? underlying_eof : Bool = false

      def initialize(ssl : LibSSL::SSL, return_code : LibSSL::Int, func = nil)
        @error = LibSSL.ssl_get_error(ssl, return_code)

        case @error
        when .none?
          message = "Raised erroneously"
        when .syscall?
          @code, message = fetch_error_details
          if @code == 0
            errno = {% if flag?(:win32) %} WinError.wsa_value {% else %} Errno.value {% end %}
            success = {% if flag?(:win32) %} errno.error_success? {% else %} errno.none? {% end %}
            if success
              message = "Unexpected EOF"
              @underlying_eof = true
            else
              cause = RuntimeError.from_os_error(func || "OpenSSL", os_error: errno)
              message = "I/O error"
            end
          end
        when .ssl?
          @code, message = fetch_error_details
        else
          message = @error.to_s
        end

        super(func ? "#{func}: #{message}" : message, true, cause: cause)
      end
    end
  end
end

require "./openssl/bio"
require "./openssl/ssl/*"
require "./openssl/digest"
require "./openssl/md5"
require "./openssl/x509/x509"
require "./openssl/pkcs5"
require "./openssl/cipher"
