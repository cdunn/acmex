defmodule Acmex.Request do
  @moduledoc false

  alias Acmex.Crypto

  @repo_url "https://www.github.com/sergioaugrod/acmex"
  @user_agent "Acmex v#{Mix.Project.config()[:version]} (#{@repo_url})"
  @default_headers [{"User-Agent", @user_agent}, {"Content-Type", "application/jose+json"}]

  def get(url, headers \\ [], handler \\ :decode) do
    resp = HTTPoison.get(url, @default_headers ++ headers, hackney: hackney_opts())
    if handler, do: handle_response(resp, handler), else: handle_response(resp)
  end

  def post(url, jwk, payload, nonce, kid \\ nil, headers \\ [], handler \\ :decode) do
    encoded_payload = if is_nil(payload) do
      # POST-as-GET
      ""
    else
      Jason.encode!(payload)
    end
    jws = Crypto.sign(jwk, encoded_payload, jws_headers(url, nonce, kid))

    resp = HTTPoison.post(url, Jason.encode!(jws), @default_headers, hackney: hackney_opts())

    if handler, do: handle_response(resp, handler), else: handle_response(resp)
  end

  def post_as_get(url, jwk, nonce, kid \\ nil, headers \\ [], handler \\ :decode) do
    jws = Crypto.sign(jwk, "", jws_headers(url, nonce, kid))

    resp =
      HTTPoison.post(url, Jason.encode!(jws), @default_headers ++ headers, hackney: hackney_opts())

    if handler, do: handle_response(resp, handler), else: handle_response(resp)
  end

  def head(url) do
    url
    |> HTTPoison.head([], hackney: hackney_opts())
    |> handle_response()
  end

  def get_header(headers, key) do
    case List.keyfind(headers, key, 0) do
      nil -> nil
      {_, value} -> value
    end
  end

  defp handle_response(result, :decode) do
    case result do
      {:ok, %{status_code: 200} = resp} -> {:ok, decode_response(resp)}
      {:ok, %{status_code: 201} = resp} -> {:ok, decode_response(resp)}
      {:ok, %{status_code: 400} = resp} -> {:error, decode_response(resp)}
      {:ok, resp} -> {:error, resp}
      {:error, error} -> {:error, error}
    end
  end

  defp handle_response(result) do
    case result do
      {:ok, %{status_code: 200} = resp} -> {:ok, resp}
      {:ok, %{status_code: 204} = resp} -> {:ok, resp}
      {:ok, resp} -> {:error, resp}
      {:error, error} -> {:error, error}
    end
  end

  defp hackney_opts, do: Application.get_env(:acmex, :hackney_opts, [])

  defp decode_response(resp),
    do: %{resp | body: Jason.decode!(resp.body, keys: :atoms)}

  defp jws_headers(url, nonce, kid) when is_nil(kid),
    do: %{"url" => url, "nonce" => nonce}

  defp jws_headers(url, nonce, kid),
    do: %{"url" => url, "nonce" => nonce, "kid" => kid}
end
