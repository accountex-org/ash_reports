defmodule Cldr.Http do
  @moduledoc """
  Supports securely downloading https content.

  """

  @cldr_unsafe_https "CLDR_UNSAFE_HTTPS"
  @cldr_default_timeout "120000"
  @cldr_default_connection_timeout "60000"

  @doc """
  Securely download https content from
  a URL.

  This function uses the built-in `:httpc`
  client but enables certificate verification
  which is not enabled by `:httc` by default.

  See also https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl

  ### Arguments

  * `url` is a binary URL or a `{url, list_of_headers}` tuple. If
    provided the headers are a list of `{'header_name', 'header_value'}`
    tuples. Note that the name and value are both charlists, not
    strings.

  * `options` is a keyword list of options.

  ### Options

  * `:verify_peer` is a boolean value indicating
    if peer verification should be done for this request.
    The default is `true` in which case the default
    `:ssl` options follow the [erlef guidelines](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl)
    noted above.

  * `:timeout` is the number of milliseconds available
    for the request to complete. The default is
    #{inspect @cldr_default_timeout}. This option may also be
    set with the `CLDR_HTTP_TIMEOUT` environment variable.

  * `:connection_timeout` is the number of milliseconds
    available for the a connection to be estabklished to
    the remote host. The default is #{inspect @cldr_default_connection_timeout}.
    This option may also be set with the
    `CLDR_HTTP_CONNECTION_TIMEOUT` environment variable.

  ### Returns

  * `{:ok, body}` if the return is successful.

  * `{:not_modified, headers}` if the request would result in
    returning the same results as one matching an etag.

  * `{:error, error}` if the download is
     unsuccessful. An error will also be logged
     in these cases.

  ### Unsafe HTTPS

  If the environment variable `CLDR_UNSAFE_HTTPS` is
  set to anything other than `FALSE`, `false`, `nil`
  or `NIL` then no peer verification of certificates
  is performed. Setting this variable is not recommended
  but may be required is where peer verification for
  unidentified reasons. Please [open an issue](https://github.com/elixir-cldr/cldr/issues)
  if this occurs.

  ### Certificate stores

  In order to keep dependencies to a minimum,
  `get/1` attempts to locate an already installed
  certificate store. It will try to locate a
  store in the following order which is intended
  to satisfy most host systems. The certificate
  store is expected to be a path name on the
  host system.

  ```elixir
  # A certificate store configured by the
  # developer
  Application.get_env(:ex_cldr, :cacertfile)

  # Populated if hex package `CAStore` is configured
  CAStore.file_path()

  # Populated if hex package `certfi` is configured
  :certifi.cacertfile()

  # Debian/Ubuntu/Gentoo etc.
  "/etc/ssl/certs/ca-certificates.crt",

  # Fedora/RHEL 6
  "/etc/pki/tls/certs/ca-bundle.crt",

  # OpenSUSE
  "/etc/ssl/ca-bundle.pem",

  # OpenELEC
  "/etc/pki/tls/cacert.pem",

  # CentOS/RHEL 7
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",

  # Open SSL on MacOS
  "/usr/local/etc/openssl/cert.pem",

  # MacOS & Alpine Linux
  "/etc/ssl/cert.pem"
  ```

  """
  @spec get(String.t | {String.t, list()}, options :: Keyword.t) ::
    {:ok, binary} | {:not_modified, any()} | {:error, any}

  def get(url, options \\ [])

  def get(url, options) when is_binary(url) and is_list(options) do
    case get_with_headers(url, options) do
      {:ok, _headers, body} -> {:ok, body}
      other -> other
    end
  end

  def get({url, headers}, options) when is_binary(url) and is_list(headers) and is_list(options) do
    case get_with_headers({url, headers}, options) do
      {:ok, _headers, body} -> {:ok, body}
      other -> other
    end
  end

  @doc """
  Securely download https content from
  a URL.

  This function uses the built-in `:httpc`
  client but enables certificate verification
  which is not enabled by `:httc` by default.

  See also https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl

  ### Arguments

  * `url` is a binary URL or a `{url, list_of_headers}` tuple. If
    provided the headers are a list of `{'header_name', 'header_value'}`
    tuples. Note that the name and value are both charlists, not
    strings.

  * `options` is a keyword list of options.

  ### Options

  * `:verify_peer` is a boolean value indicating
    if peer verification should be done for this request.
    The default is `true` in which case the default
    `:ssl` options follow the [erlef guidelines](https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl)
    noted above.

  * `:timeout` is the number of milliseconds available
    for the request to complete. The default is
    #{inspect @cldr_default_timeout}. This option may also be
    set with the `CLDR_HTTP_TIMEOUT` environment variable.

  * `:connection_timeout` is the number of milliseconds
    available for the a connection to be estabklished to
    the remote host. The default is #{inspect @cldr_default_connection_timeout}.
    This option may also be set with the
    `CLDR_HTTP_CONNECTION_TIMEOUT` environment variable.

  * `:https_proxy` is the URL of an https proxy to be used. The
    default is `nil`.

  ### Returns

  * `{:ok, body, headers}` if the return is successful.

  * `{:not_modified, headers}` if the request would result in
    returning the same results as one matching an etag.

  * `{:error, error}` if the download is
     unsuccessful. An error will also be logged
     in these cases.

  ### Unsafe HTTPS

  If the environment variable `CLDR_UNSAFE_HTTPS` is
  set to anything other than `FALSE`, `false`, `nil`
  or `NIL` then no peer verification of certificates
  is performed. Setting this variable is not recommended
  but may be required is where peer verification for
  unidentified reasons. Please [open an issue](https://github.com/elixir-cldr/cldr/issues)
  if this occurs.

  ### Https Proxy

  `Cldr.Http.get/2` will look for a proxy URL in the following
  locales in the order presented:

  * `options[:https_proxy]`
  * `ex_cldr` compile-time configuration under the
    key `:ex_cldr[:https_proxy]`
  * The environment variable `HTTPS_PROXY`
  * The environment variable `https_proxy`

  ### Certificate stores

  In order to keep dependencies to a minimum,
  `get/1` attempts to locate an already installed
  certificate store. It will try to locate a
  store in the following order which is intended
  to satisfy most host systems. The certificate
  store is expected to be a path name on the
  host system.

  ```elixir
  # A certificate store configured by the
  # developer
  Application.get_env(:ex_cldr, :cacertfile)

  # Populated if hex package `CAStore` is configured
  CAStore.file_path()

  # Populated if hex package `certfi` is configured
  :certifi.cacertfile()

  # Debian/Ubuntu/Gentoo etc.
  "/etc/ssl/certs/ca-certificates.crt",

  # Fedora/RHEL 6
  "/etc/pki/tls/certs/ca-bundle.crt",

  # OpenSUSE
  "/etc/ssl/ca-bundle.pem",

  # OpenELEC
  "/etc/pki/tls/cacert.pem",

  # CentOS/RHEL 7
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",

  # Open SSL on MacOS
  "/usr/local/etc/openssl/cert.pem",

  # MacOS & Alpine Linux
  "/etc/ssl/cert.pem"
  ```

  """
  @doc since: "2.21.0"

  @spec get_with_headers(String.t | {String.t, list()}, options :: Keyword.t) ::
    {:ok, list(), binary} | {:not_modified, any()} | {:error, any}

  def get_with_headers(request, options \\ [])

  def get_with_headers(url, options) when is_binary(url) do
    get_with_headers({url, []}, options)
  end

  def get_with_headers({url, headers}, options) when is_binary(url) and is_list(headers) and is_list(options) do
    require Logger

    hostname = String.to_charlist(URI.parse(url).host)
    url = String.to_charlist(url)
    http_options = http_opts(hostname, options)
    https_proxy = https_proxy(options)
    ip_family = :inet6fb4

    if https_proxy do
      case URI.parse(https_proxy) do
        %{host: host, port: port} when is_binary(host) and is_integer(port) ->
          :ok = :httpc.set_options(https_proxy: {{String.to_charlist(host), port}, []}, ipfamily: ip_family)
        _other ->
          Logger.bare_log(:warning, "https_proxy was set to an invalid value. Found #{inspect https_proxy}.")
      end
    else
      :ok = :httpc.set_options(ipfamily: ip_family)
    end

    case :httpc.request(:get, {url, headers}, http_options, []) do
      {:ok, {{_version, 200, _}, headers, body}} ->
        {:ok, headers, body}

      {:ok, {{_version, 304, _}, headers, _body}} ->
        {:not_modified, headers}

      {_, {{_version, code, message}, _headers, _body}} ->
        Logger.bare_log(
          :error,
          "Failed to download #{url}. " <>
            "HTTP Error: (#{code}) #{inspect(message)}"
        )

        {:error, code}

      {:error, {:failed_connect, [{:to_address, {host, _port}}, {:inet6, _, _}, {_, _, :timeout}]}} ->
        Logger.bare_log(
          :error,
          "Timeout connecting to #{inspect(host)} to download #{inspect url}. " <>
          "Connection time exceeded #{http_options[:connect_timeout]}ms."
        )

        {:error, :connection_timeout}

      {:error, {:failed_connect, [{:to_address, {host, _port}}, {:inet6, _, _}, {_, _, :nxdomain}]}} ->
        Logger.bare_log(
          :error,
          "Failed to resolve host #{inspect(host)} to download #{inspect url}"
        )

        {:error, :nxdomain}

      {:error, {other}} ->
        Logger.bare_log(
          :error,
          "Failed to download #{inspect url}. Error #{inspect other}"
        )

        {:error, other}

      {:error, :timeout} ->
        Logger.bare_log(
          :error,
          "Timeout downloading from #{inspect url}. " <>
          "Request exceeded #{http_options[:timeout]}ms."
        )
        {:error, :timeout}
    end
  end

  @static_certificate_locations [
    # Debian/Ubuntu/Gentoo etc.
    "/etc/ssl/certs/ca-certificates.crt",

    # Fedora/RHEL 6
    "/etc/pki/tls/certs/ca-bundle.crt",

    # OpenSUSE
    "/etc/ssl/ca-bundle.pem",

    # OpenELEC
    "/etc/pki/tls/cacert.pem",

    # CentOS/RHEL 7
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",

    # Open SSL on MacOS
    "/usr/local/etc/openssl/cert.pem",

    # MacOS & Alpine Linux
    "/etc/ssl/cert.pem"
  ]

  defp dynamic_certificate_locations do
    [
      # Configured cacertfile
      Application.get_env(:ex_cldr, :cacertfile),

      # Populated if hex package CAStore is configured
      if(Code.ensure_loaded?(CAStore), do: apply(CAStore, :file_path, [])),

      # Populated if hex package certfi is configured
      if(Code.ensure_loaded?(:certifi), do: apply(:certifi, :cacertfile, []) |> List.to_string())
    ]
    |> Enum.reject(&is_nil/1)
  end

  def certificate_locations() do
    dynamic_certificate_locations() ++ @static_certificate_locations
  end

  @doc false
  defp certificate_store do
    certificate_locations()
    |> Enum.find(&File.exists?/1)
    |> raise_if_no_cacertfile!
    |> :erlang.binary_to_list()
  end

  defp raise_if_no_cacertfile!(nil) do
    raise RuntimeError, """
    No certificate trust store was found.
    Tried looking for: #{inspect(certificate_locations())}

    A certificate trust store is required in
    order to download locales for your configuration.

    Since ex_cldr could not detect a system
    installed certificate trust store one of the
    following actions may be taken:

    1. Install the hex package `castore`. It will
       be automatically detected after recompilation.

    2. Install the hex package `certifi`. It will
       be automatically detected after recomilation.

    3. Specify the location of a certificate trust store
       by configuring it in `config.exs` or `runtime.exs`:

       config :ex_cldr,
         cacertfile: "/path/to/cacertfile",
         ...

    """
  end

  defp raise_if_no_cacertfile!(file) do
    file
  end

  defp http_opts(hostname, options) do
    default_timeout =
      "CLDR_HTTP_TIMEOUT"
      |> System.get_env(@cldr_default_timeout)
      |> String.to_integer()

    default_connection_timeout =
      "CLDR_HTTP_CONNECTION_TIMEOUT"
      |> System.get_env(@cldr_default_connection_timeout)
      |> String.to_integer()

    verify_peer? = Keyword.get(options, :verify_peer, true)
    ssl_options = https_ssl_opts(hostname, verify_peer?)
    timeout = Keyword.get(options, :timeout, default_timeout)
    connection_timeout = Keyword.get(options, :connection_timeout, default_connection_timeout)

    [timeout: timeout, connect_timeout: connection_timeout, ssl: ssl_options]
  end

  defp https_ssl_opts(hostname, verify_peer?) do
    if secure_ssl?() and verify_peer? do
      [
        verify: :verify_peer,
        cacertfile: certificate_store(),
        depth: 4,
        ciphers: preferred_ciphers(),
        versions: protocol_versions(),
        eccs: preferred_eccs(),
        reuse_sessions: true,
        server_name_indication: hostname,
        secure_renegotiate: true,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    else
      [
        verify: :verify_none,
        server_name_indication: hostname,
        secure_renegotiate: true,
        reuse_sessions: true,
        versions: protocol_versions(),
        ciphers: preferred_ciphers(),
        versions: protocol_versions(),
      ]
    end
  end

  defp preferred_ciphers do
    preferred_ciphers =
      [
        # Cipher suites (TLS 1.3): TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        %{cipher: :aes_128_gcm, key_exchange: :any, mac: :aead, prf: :sha256},
        %{cipher: :aes_256_gcm, key_exchange: :any, mac: :aead, prf: :sha384},
        %{cipher: :chacha20_poly1305, key_exchange: :any, mac: :aead, prf: :sha256},
        # Cipher suites (TLS 1.2): ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:
        # ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:
        # ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        %{cipher: :aes_128_gcm, key_exchange: :ecdhe_ecdsa, mac: :aead, prf: :sha256},
        %{cipher: :aes_128_gcm, key_exchange: :ecdhe_rsa, mac: :aead, prf: :sha256},
        %{cipher: :aes_256_gcm, key_exchange: :ecdh_ecdsa, mac: :aead, prf: :sha384},
        %{cipher: :aes_256_gcm, key_exchange: :ecdh_rsa, mac: :aead, prf: :sha384},
        %{cipher: :chacha20_poly1305, key_exchange: :ecdhe_ecdsa, mac: :aead, prf: :sha256},
        %{cipher: :chacha20_poly1305, key_exchange: :ecdhe_rsa, mac: :aead, prf: :sha256},
        %{cipher: :aes_128_gcm, key_exchange: :dhe_rsa, mac: :aead, prf: :sha256},
        %{cipher: :aes_256_gcm, key_exchange: :dhe_rsa, mac: :aead, prf: :sha384}
      ]

    :ssl.filter_cipher_suites(preferred_ciphers, [])
  end

  defp protocol_versions do
    if otp_version() < 25 do
      [:"tlsv1.2"]
    else
      [:"tlsv1.2", :"tlsv1.3"]
    end
  end

  defp preferred_eccs do
    # TLS curves: X25519, prime256v1, secp384r1
    preferred_eccs = [:secp256r1, :secp384r1]
    :ssl.eccs() -- (:ssl.eccs() -- preferred_eccs)
  end

  defp secure_ssl? do
    case System.get_env(@cldr_unsafe_https) do
      nil -> true
      "FALSE" -> false
      "false" -> false
      "nil" -> false
      "NIL" -> false
      _other -> true
    end
  end

  defp https_proxy(options) do
    options[:https_proxy] ||
    Application.get_env(:ex_cldr, :https_proxy) ||
    System.get_env("HTTPS_PROXY") ||
    System.get_env("https_proxy")
  end

  def otp_version do
    :erlang.system_info(:otp_release) |> List.to_integer
  end
end
