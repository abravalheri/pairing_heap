defmodule PairingHeap.Node do
  @moduledoc """
  Defines the `PairingHeap.Node` struct and functions for creating and
  combining nodes.

  The functions `PairingHeap.Node.merge/3` and `ParingHeap.Node.merge/2`
  combine pairs and lists of nodes, respectively, in a way that preserves the
  heap property. Both of these functions take as an argument the predicate
  `ordered?/2`, where `ordered?.(node1, node2)` returns `true` if `node1`
  is correctly ordered relatively to `node2` according to the heap property.
  """

  alias __MODULE__, as: Node

  defstruct [:item, :children]

  @type item() :: any()
  @type ordered_fn() :: (t(), t() -> boolean())

  @type t :: %Node{
          item: item(),
          children: [t()]
        }

  @doc """
  Create a new pairing-heap node with an item and a list of zero or more child
  nodes.
  """
  @spec new(item(), [t()]) :: t()
  def new(item, children), do: %Node{item: item, children: children}

  @doc """
  Link a pair of nodes into a single node that satisfies the heap property.

  One of the given nodes is a parent and the other is the child, as determined
  by `ordered?/2`. The child node is prepended to the list of child nodes for
  the parent. No other maintenance is required for the individual nodes in a
  pairing heap. It follows that `meld` runs in `O(1)` time.
  """
  @spec merge(t(), t(), ordered_fn()) :: t()
  def merge(
        %Node{children: children1} = node1,
        %Node{children: children2} = node2,
        ordered?
      ) do
    if ordered?.(node1, node2) do
      %{node1 | children: [node2 | children1]}
    else
      %{node2 | children: [node1 | children2]}
    end
  end

  @doc """
  Merge a list of nodes into a single node that satisfies the heap property.

  The pairwise recursive merger follows the algorithm described in the
  [original paper](https://www.cs.cmu.edu/~sleator/papers/pairing-heaps.pdf),
  which has `O(log n)` amortized run time.
  """
  @spec merge([t()], ordered_fn()) :: t()
  def merge([node], _ordered?), do: node
  def merge([node1, node2], ordered?), do: merge(node1, node2, ordered?)

  def merge([node1, node2 | rest], ordered?) do
    merge(
      merge(node1, node2, ordered?),
      merge(rest, ordered?),
      ordered?
    )
  end

  @doc """
  Return `true` if any node in the tree defined by `node` contains `item`, and
  `false` otherwise.
  """
  @spec member?(t(), any(), ordered_fn()) :: boolean()
  def member?(node, item, ordered?) do
    do_member?(node, new(item, []), ordered?)
  end

  defp do_member?(node, node_target, ordered?) do
    cond do
      node.item == node_target.item ->
        true

      ordered?.(node, node_target) ->
        Enum.any?(node.children, fn n -> do_member?(n, node_target, ordered?) end)

      true ->
        false
    end
  end

  @doc """
  Return a list of all items in the tree defined by the given node.
  """
  @spec dump(t()) :: [item()]
  def dump(%Node{item: item, children: children}), do: [item | Enum.flat_map(children, &dump/1)]

  @doc """
  Find the node with the given item in the tree defined by node and cut it
  from the tree.

  If the item is found, this returns `{:ok, node, parent}`

  NOTE: I don't just want the updated parent, I want the whole tree without the
  node. I think this means the tree needs to be reconstructed during recursion.
  Repeated merge during recursion might turn out to be simpler, but will not
  be cheap if the item is not found.

  Walk through the tree and build it back through repeated merges.
  """
  @spec cut(t(), item(), ordered_fn()) :: {:ok, t(), t() | nil} | :error
  def cut(%Node{item: node_item}, item, _ordered?) when node_item == item,
    do: {:ok, new(item, []), nil}

  def cut(%Node{children: children} = node, item, ordered?) do
    do_cut(node, children, new(item, []), ordered?)
  end

  defp do_cut(_parent, [], _target, _ordered?), do: :error

  defp do_cut(parent, children, target, ordered?) do
    case do_cut_children([], children, target) do
      {:ok, front, node, back} ->
        {:ok, node, %{parent | children: front ++ back}}

      :error ->
        ordered_nodes = Enum.filter(children, &ordered?.(&1, target))
        do_cut_ordered(ordered_nodes, target, ordered?)
    end
  end

  defp do_cut_children(_front, [], _target), do: :error

  defp do_cut_children(front, [node | rest], target) when node.item == target.item,
    do: {:ok, front, node, rest}

  defp do_cut_children(front, [node | rest], target),
    do: do_cut_children([node | front], rest, target)

  defp do_cut_ordered([], _target, _ordered?), do: :error

  defp do_cut_ordered([node | rest], target, ordered?) do
    case do_cut(node, node.children, target, ordered?) do
      {:ok, _, _} = result -> result
      :error -> do_cut_ordered(rest, target, ordered?)
    end
  end
end
