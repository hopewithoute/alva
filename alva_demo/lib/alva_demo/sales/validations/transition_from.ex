defmodule AlvaDemo.Sales.Validations.TransitionFrom do
  use Ash.Resource.Validation

  def init(opts) do
    if Keyword.has_key?(opts, :state) do
      {:ok, opts}
    else
      {:error, "state is required"}
    end
  end

  def validate(changeset, opts, _context) do
    expected_state = Keyword.fetch!(opts, :state)

    if changeset.data.lifecycle_status == expected_state do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :lifecycle_status,
         message: "Order must be in #{expected_state} state to transition"
       )}
    end
  end
end
