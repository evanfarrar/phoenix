defmodule Phoenix.Router.Route do
  # This module defines the Route struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Route

  @doc """
  The `Phoenix.Router.Route` struct. It stores:

    * :verb - the HTTP verb as an upcased string
    * :path - the normalized path as string
    * :host - the request host or host prefix
    * :controller - the controller module
    * :action - the action as an atom
    * :helper - the name of the helper as a string (may be nil)
    * :private - the private route info
    * :pipe_through - the pipeline names as a list of atoms

  """
  defstruct [:verb, :path, :host, :controller, :action,
             :helper, :private, :pipe_through]

  @type t :: %Route{}

  @doc """
  Receives the verb, path, controller, action and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(String.t, String.t, String.t | nil, atom, atom, atom | nil, atom, %{}) :: t
  def build(verb, path, host, controller, action, helper, pipe_through, private)
      when is_binary(verb) and is_binary(path) and (is_binary(host) or is_nil(host)) and
           is_atom(controller) and is_atom(action) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) and is_map(private) do
    %Route{verb: verb, path: path, host: host, private: private,
           controller: controller, action: action, helper: helper,
           pipe_through: pipe_through}
  end

  @doc """
  Builds the expressions used by the route.
  """
  def exprs(route) do
    {path, binding} = build_path_and_binding(route.path)

    exprs = %{path: path,
              host: build_host(route.host),
              binding: binding,
              private: maybe_merge(:private, route.private),
              pipes: build_pipes(route.pipe_through),
              dispatch: nil}

    %{exprs | dispatch: build_dispatch(route, exprs)}
  end

  defp build_path_and_binding(path) do
    {params, segments} = Plug.Router.Utils.build_path_match(path)

    binding = Enum.map(params, fn var ->
      {Atom.to_string(var), Macro.var(var, nil)}
    end)

    {segments, binding}
  end

  defp build_host(host) do
    cond do
      is_nil(host)             -> quote do: _
      String.last(host) == "." -> quote do: unquote(host) <> _
      true                     -> host
    end
  end

  defp build_dispatch(route, exprs) do
    quote do
      unquote(exprs.private)
      var!(conn) = dispatch(var!(conn), unquote(route.controller), unquote(route.action),
                            unquote({:%{}, [], exprs.binding}), unquote(route.pipe_through))
      unquote(exprs.pipes)
    end
  end

  defp maybe_merge(key, data) do
    if map_size(data) > 0 do
      quote do
        var!(conn) =
          update_in var!(conn).unquote(key), &Map.merge(&1, unquote(Macro.escape(data)))
      end
    end
  end

  defp build_pipes(pipe_through) do
    Enum.reduce(pipe_through, quote(do: var!(conn)), &{&1, [], [&2, []]})
  end
end
